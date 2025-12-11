--------------------------------------------------------------------------------
-- ASTEROID MODULE (ECS-BACKED)
-- Spawns asteroids as ECS entities, provides legacy API compatibility
--------------------------------------------------------------------------------

local asteroid = {}

local ecsWorld = require("src.ecs.world")
local Concord = require("lib.concord")
local physics = require("src.core.physics")
local config = require("src.core.config")
local colors = require("src.core.colors")
local asteroid_generator = require("src.utils.procedural_asteroid_generator")

asteroid.shader = nil

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function buildCompositionText(asteroidData)
    if not asteroidData or not asteroidData.composition then
        return 'Stone and ice'
    end

    local c = asteroidData.composition
    local stone = c.stone or 0
    local ice = c.ice or 0
    local mithril = c.mithril or 0

    local total = stone + ice + mithril
    if total <= 0 then
        return 'Stone and ice'
    end

    stone = stone / total
    ice = ice / total
    mithril = mithril / total

    local stonePercent = math.floor(stone * 100 + 0.5)
    local icePercent = math.floor(ice * 100 + 0.5)
    local mithrilPercent = math.floor(mithril * 100 + 0.5)

    if mithrilPercent >= 10 then
        return string.format('Stone %d%%, Ice %d%%, Mithril %d%%', stonePercent, icePercent, mithrilPercent)
    elseif mithrilPercent > 0 then
        return string.format('Stone %d%%, Ice %d%%, traces of Mithril', stonePercent, icePercent)
    end

    return string.format('Stone %d%%, Ice %d%%', stonePercent, icePercent)
end

--------------------------------------------------------------------------------
-- LEGACY LIST (computed from ECS world)
--------------------------------------------------------------------------------

function asteroid.getList()
    return ecsWorld:query({ "asteroid", "position" }) or {}
end

setmetatable(asteroid, {
    __index = function(t, k)
        if k == "list" then
            return asteroid.getList()
        end
        return rawget(t, k)
    end
})

--------------------------------------------------------------------------------
-- LOAD
--------------------------------------------------------------------------------

function asteroid.load()
    asteroid.shader = nil
end

--------------------------------------------------------------------------------
-- POPULATE
--------------------------------------------------------------------------------

function asteroid.populate(world, count)
    asteroid.clear()
    if not world then return end

    count = count or 80
    local margin = 80

    for i = 1, count do
        local x = math.random(world.minX + margin, world.maxX - margin)
        local y = math.random(world.minY + margin, world.maxY - margin)
        local size = config.asteroid.minSize + math.random() * (config.asteroid.maxSize - config.asteroid.minSize)

        local data = asteroid_generator.generate(size)
        local collisionRadius = (data and data.shape and data.shape.boundingRadius) or size

        local t = (size - config.asteroid.minSize) / (config.asteroid.maxSize - config.asteroid.minSize)
        t = math.max(0, math.min(1, t))
        local maxHealth = config.asteroid.minHealth + t * (config.asteroid.maxHealth - config.asteroid.minHealth)

        local consts = physics.constants
        local driftSpeed = consts.asteroidMinDrift + math.random() * (consts.asteroidMaxDrift - consts.asteroidMinDrift)
        local driftAngle = math.random() * math.pi * 2
        local composition = buildCompositionText(data)

        -- Create ECS entity
        local e = Concord.entity(ecsWorld)
        e:give("position", x, y)
            :give("velocity", math.cos(driftAngle) * driftSpeed, math.sin(driftAngle) * driftSpeed)
            :give("rotation", math.random() * math.pi * 2)
            :give("asteroid")
            :give("damageable")
            :give("health", maxHealth, maxHealth)
            :give("size", size)
            :give("collisionRadius", collisionRadius)
            :give("asteroidVisual", data)

        -- Resource yield from composition
        if data and data.composition then
            e:give("resourceYield", data.composition)
        end

        -- Extra data for rendering/mining
        e.rotationSpeed = (math.random() - 0.5) * config.asteroid.rotationSpeedRange
        e.composition = composition
        e.data = data

        -- Create physics body
        local collisionVertices = nil
        if data and data.shape and data.shape.flatPoints then
            collisionVertices = data.shape.flatPoints
        end

        local body, shapes, fixtures
        if collisionVertices and #collisionVertices >= 6 then
            body, shapes, fixtures = physics.createPolygonBody(x, y, collisionVertices, "ASTEROID", e, {})
        else
            local b, s, f = physics.createCircleBody(x, y, collisionRadius, "ASTEROID", e, {})
            body = b
            shapes = s and { s } or nil
            fixtures = f and { f } or nil
        end

        if body then
            e:give("physics", body, shapes, fixtures)
        end
    end
end

--------------------------------------------------------------------------------
-- UPDATE
--------------------------------------------------------------------------------

function asteroid.update(dt, world)
    local asteroids = asteroid.getList()

    for _, a in ipairs(asteroids) do
        -- Update rotation
        local rot = a.rotation
        if rot and a.rotationSpeed then
            rot.angle = rot.angle + a.rotationSpeed * dt
        end

        -- Update position from velocity
        local pos = a.position
        local vel = a.velocity
        if pos and vel then
            pos.x = pos.x + vel.vx * dt
            pos.y = pos.y + vel.vy * dt

            -- Wrap around world boundaries
            if world then
                local radius = a.collisionRadius and a.collisionRadius.radius or 20
                if pos.x < world.minX - radius then
                    pos.x = world.maxX + radius
                elseif pos.x > world.maxX + radius then
                    pos.x = world.minX - radius
                end
                if pos.y < world.minY - radius then
                    pos.y = world.maxY + radius
                elseif pos.y > world.maxY + radius then
                    pos.y = world.minY - radius
                end
            end

            -- Sync physics body
            if a.physics and a.physics.body and not a.physics.body:isDestroyed() then
                a.physics.body:setPosition(pos.x, pos.y)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function asteroid.draw(camera)
    local asteroids = asteroid.getList()

    for _, a in ipairs(asteroids) do
        local px = a.position.x
        local py = a.position.y
        local angle = a.rotation and a.rotation.angle or 0
        local data = a.asteroidVisual and a.asteroidVisual.data or a.data

        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(angle)

        if data then
            asteroid_generator.draw(data)
        end
        love.graphics.pop()

        -- Health bar (ECS component)
        local healthComp = a.health
        local healthCurrent = healthComp and healthComp.current or 0
        local healthMax = healthComp and healthComp.max or 0

        if healthCurrent and healthMax and healthCurrent < healthMax then
            local radius = (type(a.collisionRadius) == "table" and a.collisionRadius.radius) or a.collisionRadius or 10
            local barWidth = radius * 0.9
            local barHeight = 4
            local barX = px - barWidth
            local barY = py - radius - 18

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth * 2 + 2, barHeight + 2)

            love.graphics.setColor(colors.asteroidHealthBg)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2, barHeight)

            local ratio = math.max(0, math.min(1, healthCurrent / healthMax))
            love.graphics.setColor(colors.asteroidHealth)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, barHeight)
        end
    end
end

--------------------------------------------------------------------------------
-- CLEAR
--------------------------------------------------------------------------------

function asteroid.clear()
    local asteroids = asteroid.getList()

    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        if a.physics and a.physics.body then
            a.physics.body:destroy()
        end
        a:destroy()
    end
end

return asteroid
