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
local mithrilItem = require("src.data.items.mithril")

asteroid.shader = nil

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local HEALTH_BAR_HEIGHT = 4
local HEALTH_BAR_OFFSET_Y = 18
local DEFAULT_ASTEROID_COUNT = 80
local SPAWN_MARGIN = 80
local DEFAULT_COLLISION_RADIUS = 20

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

--- Build a human-readable composition string from asteroid data.
-- @param asteroidData table Asteroid data containing composition
-- @return string Formatted composition text
local function buildCompositionText(asteroidData)
    if not asteroidData or not asteroidData.composition then
        return "Stone and ice"
    end

    local c = asteroidData.composition
    local stone = c.stone or 0
    local ice = c.ice or 0
    local mithril = c.mithril or 0

    local total = stone + ice + mithril
    if total <= 0 then
        return "Stone and ice"
    end

    -- Normalize to percentages
    local stonePercent = math.floor((stone / total) * 100 + 0.5)
    local icePercent = math.floor((ice / total) * 100 + 0.5)
    local mithrilPercent = math.floor((mithril / total) * 100 + 0.5)

    if mithrilPercent >= 10 then
        return string.format("Stone %d%%, Ice %d%%, Mithril %d%%", stonePercent, icePercent, mithrilPercent)
    elseif mithrilPercent > 0 then
        return string.format("Stone %d%%, Ice %d%%, traces of Mithril", stonePercent, icePercent)
    end

    return string.format("Stone %d%%, Ice %d%%", stonePercent, icePercent)
end

--- Calculate size interpolation factor for health scaling.
-- @param size number Asteroid size
-- @return number Clamped interpolation factor 0..1
local function calculateSizeInterpolation(size)
    local minSize = config.asteroid.minSize
    local maxSize = config.asteroid.maxSize
    local range = maxSize - minSize

    if range <= 0 then
        return 0
    end

    local t = (size - minSize) / range
    return math.max(0, math.min(1, t))
end

--- Get collision radius from entity, handling both table and number formats.
-- @param entity table ECS entity
-- @return number Collision radius
local function getCollisionRadius(entity)
    local cr = entity.collisionRadius
    if type(cr) == "table" then
        return cr.radius or DEFAULT_COLLISION_RADIUS
    elseif type(cr) == "number" then
        return cr
    end
    return DEFAULT_COLLISION_RADIUS
end

--------------------------------------------------------------------------------
-- LEGACY LIST (computed from ECS world)
--------------------------------------------------------------------------------

--- Get all asteroid entities from the ECS world.
-- @return table Array of asteroid entities
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
-- SPAWN SINGLE ASTEROID
--------------------------------------------------------------------------------

--- Spawn a single asteroid entity at the given position.
-- @param x number World X coordinate
-- @param y number World Y coordinate
-- @param size number Asteroid size (optional, random if not provided)
-- @param spec table Optional spawn spec (e.g. { variant = "mithril_ore" })
-- @return entity The created asteroid entity
function asteroid.spawn(x, y, size, spec)
    -- Back-compat: allow (x, y, specTable)
    if type(size) == "table" and spec == nil then
        spec = size
        size = nil
    end

    size = size or (config.asteroid.minSize + math.random() * (config.asteroid.maxSize - config.asteroid.minSize))

    local options = nil
    local variant = nil
    if type(spec) == "table" then
        variant = spec.variant or spec.type
    end

    -- Default to ice-rich asteroids until more types are added.
    if variant == nil or variant == "ice" then
        options = {
            composition = {
                mithrilChance = 0.0,
                baseRockVsIce = 0.05 + math.random() * 0.35,
            }
        }
        variant = variant or "ice"
    elseif variant == "mithril_ore" then
        options = {
            composition = {
                mithrilChance = 1.0,
                minMithrilShare = 0.78,
                maxMithrilShare = 1.00,
                baseRockVsIce = 0.1 + math.random() * 0.6,
            }
        }
    end

    local data = asteroid_generator.generate(size, options)
    local collisionRadius = (data and data.shape and data.shape.boundingRadius) or size

    local t = calculateSizeInterpolation(size)
    local maxHealth = config.asteroid.minHealth + t * (config.asteroid.maxHealth - config.asteroid.minHealth)

    local consts = physics.constants
    local driftSpeed = consts.asteroidMinDrift + math.random() * (consts.asteroidMaxDrift - consts.asteroidMinDrift)
    local driftAngle = math.random() * math.pi * 2
    local composition = buildCompositionText(data)

    local e = ecsWorld:spawnAsteroid(x, y, data, size)

    if e and e.velocity then
        e.velocity.vx = math.cos(driftAngle) * driftSpeed
        e.velocity.vy = math.sin(driftAngle) * driftSpeed
    end
    if e and e.health then
        e.health.current = maxHealth
        e.health.max = maxHealth
    end

    if e then
        e.rotationSpeed = (math.random() - 0.5) * config.asteroid.rotationSpeedRange
        e.composition = composition
        e.data = data

        if variant == "mithril_ore" then
            e.asteroidVariant = "mithril_ore"
            if mithrilItem and type(mithrilItem.color) == "table" then
                e.data.glowColor = { mithrilItem.color[1], mithrilItem.color[2], mithrilItem.color[3] }
            else
                e.data.glowColor = { 0.35, 0.75, 1.0 }
            end
        elseif variant == "ice" then
            e.asteroidVariant = "ice"
        end
    end

    -- Resource yield from composition
    if e and data and data.composition and not e.resourceYield then
        e:give("resourceYield", data.composition)
    end

    return e
end

function asteroid.spawnMithrilOre(x, y, size)
    return asteroid.spawn(x, y, size, { variant = "mithril_ore" })
end

--------------------------------------------------------------------------------
-- POPULATE
--------------------------------------------------------------------------------

--- Populate the world with asteroids.
-- @param world table World bounds table with minX, maxX, minY, maxY
-- @param count number Number of asteroids to spawn (default 80)
function asteroid.populate(world, count)
    asteroid.clear()

    if not world then
        return
    end

    count = count or DEFAULT_ASTEROID_COUNT

    local oreChance = (config.spawn and config.spawn.mithrilOreAsteroidChance) or 0

    local spawnedOre = 0

    for i = 1, count do
        local x = math.random(world.minX + SPAWN_MARGIN, world.maxX - SPAWN_MARGIN)
        local y = math.random(world.minY + SPAWN_MARGIN, world.maxY - SPAWN_MARGIN)

        local forceOre = (oreChance > 0) and (spawnedOre == 0) and (i == count)

        if forceOre or (oreChance > 0 and math.random() < oreChance) then
            asteroid.spawn(x, y, { variant = "mithril_ore" })
            spawnedOre = spawnedOre + 1
        else
            asteroid.spawn(x, y, { variant = "ice" })
        end
    end
end

--------------------------------------------------------------------------------
-- UPDATE
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

--- Draw health bar for an asteroid.
-- @param px number Position X
-- @param py number Position Y
-- @param radius number Asteroid radius
-- @param healthCurrent number Current health
-- @param healthMax number Maximum health
local function drawHealthBar(px, py, radius, healthCurrent, healthMax)
    local barWidth = radius * 0.9
    local barX = px - barWidth
    local barY = py - radius - HEALTH_BAR_OFFSET_Y

    -- Background outline
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth * 2 + 2, HEALTH_BAR_HEIGHT + 2)

    -- Background fill
    love.graphics.setColor(colors.asteroidHealthBg)
    love.graphics.rectangle("fill", barX, barY, barWidth * 2, HEALTH_BAR_HEIGHT)

    -- Health fill
    local ratio = math.max(0, math.min(1, healthCurrent / healthMax))
    love.graphics.setColor(colors.asteroidHealth)
    love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, HEALTH_BAR_HEIGHT)
end

--- Draw all asteroids.
-- @param camera table Camera object (unused but kept for API compatibility)
function asteroid.draw(camera)
    local asteroids = asteroid.getList()

    for _, a in ipairs(asteroids) do
        local px = a.position.x
        local py = a.position.y
        local angle = a.rotation and a.rotation.angle or 0
        local data = (a.asteroidVisual and a.asteroidVisual.data) or a.data

        -- Draw asteroid
        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(angle)

        if data then
            asteroid_generator.draw(data)
        end

        love.graphics.pop()

        -- Draw health bar if damaged
        local healthComp = a.health
        if healthComp then
            local healthCurrent = healthComp.current or 0
            local healthMax = healthComp.max or 0

            if healthCurrent > 0 and healthMax > 0 and healthCurrent < healthMax then
                local radius = getCollisionRadius(a)
                drawHealthBar(px, py, radius, healthCurrent, healthMax)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- CLEAR
--------------------------------------------------------------------------------

--- Remove all asteroids from the world.
function asteroid.clear()
    local asteroids = asteroid.getList()

    for i = #asteroids, 1, -1 do
        local a = asteroids[i]

        -- Destroy physics body first
        local phys = a.physics
        if phys and phys.body and not phys.body:isDestroyed() then
            phys.body:destroy()
        end

        -- Destroy entity
        a:destroy()
    end
end

--------------------------------------------------------------------------------
-- DAMAGE / DESTROY
--------------------------------------------------------------------------------

--- Apply damage to an asteroid.
-- @param entity table Asteroid entity
-- @param amount number Damage amount
-- @return boolean True if asteroid was destroyed
function asteroid.damage(entity, amount)
    if not entity or not entity.health then
        return false
    end

    entity.health.current = entity.health.current - amount

    if entity.health.current <= 0 then
        asteroid.destroy(entity)
        return true
    end

    return false
end

--- Destroy a single asteroid entity.
-- @param entity table Asteroid entity to destroy
function asteroid.destroy(entity)
    if not entity then
        return
    end

    -- Destroy physics body
    local phys = entity.physics
    if phys and phys.body and not phys.body:isDestroyed() then
        phys.body:destroy()
    end

    -- Destroy entity
    entity:destroy()
end

return asteroid
