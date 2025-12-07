local colors = require("src.core.colors")

local asteroid = {}

asteroid.list = {}
asteroid.shader = nil

local asteroid_generator = require("src.utils.procedural_asteroid_generator")
local physics = require("src.core.physics")

local MIN_SIZE = 20
local MAX_SIZE = 70
local MIN_HEALTH = 10
local MAX_HEALTH = 40

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

function asteroid.load()
    asteroid.shader = nil
end

function asteroid.populate(world, count)
    asteroid.clear()

    if not world then
        return
    end

    count = count or 80
    local margin = 80

    for i = 1, count do
        local x = math.random(world.minX + margin, world.maxX - margin)
        local y = math.random(world.minY + margin, world.maxY - margin)
        local size = MIN_SIZE + math.random() * (MAX_SIZE - MIN_SIZE)

        local data = asteroid_generator.generate(size)
        local collisionRadius = (data and data.shape and data.shape.boundingRadius) or size

        local t = (size - MIN_SIZE) / (MAX_SIZE - MIN_SIZE)
        t = math.max(0, math.min(1, t))
        local maxHealth = MIN_HEALTH + t * (MAX_HEALTH - MIN_HEALTH)
        
        -- Zero-g drift velocity (asteroids drift slowly through space)
        local consts = physics.constants
        local driftSpeed = consts.asteroidMinDrift + math.random() * (consts.asteroidMaxDrift - consts.asteroidMinDrift)
        local driftAngle = math.random() * math.pi * 2

        -- Get collision vertices from the asteroid's shape
        local collisionVertices = nil
        if data and data.shape and data.shape.flatPoints then
            collisionVertices = data.shape.flatPoints
        end
        
        -- Create the asteroid entity first (so we can pass it to physics)
        local newAsteroid = {
            x = x,
            y = y,
            -- Drift velocity for zero-g feel
            vx = math.cos(driftAngle) * driftSpeed,
            vy = math.sin(driftAngle) * driftSpeed,
            size = size,
            angle = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 0.3,  -- Slower rotation
            data = data,
            collisionRadius = collisionRadius,
            collisionVertices = collisionVertices,
            health = maxHealth,
            maxHealth = maxHealth,
            body = nil,
            shapes = nil,   -- Table of shapes (polygon body may have multiple)
            fixtures = nil  -- Table of fixtures
        }
        
        -- Create physics body with polygon collision from asteroid shape
        if collisionVertices and #collisionVertices >= 6 then
            newAsteroid.body, newAsteroid.shapes, newAsteroid.fixtures = physics.createPolygonBody(
                x, y,
                collisionVertices,
                "ASTEROID",
                newAsteroid,
                {}
            )
        else
            -- Fallback to circle if no valid shape vertices
            local body, shape, fixture = physics.createCircleBody(
                x, y,
                collisionRadius,
                "ASTEROID",
                newAsteroid,
                {}
            )
            newAsteroid.body = body
            newAsteroid.shapes = shape and {shape} or nil
            newAsteroid.fixtures = fixture and {fixture} or nil
        end
        
        table.insert(asteroid.list, newAsteroid)
    end
end

function asteroid.update(dt, world)
    for _, a in ipairs(asteroid.list) do
        -- Update rotation
        a.angle = a.angle + (a.rotationSpeed or 0) * dt
        
        -- Update position based on drift velocity (zero-g momentum)
        if a.vx and a.vy then
            a.x = a.x + a.vx * dt
            a.y = a.y + a.vy * dt
            
            -- Wrap around world boundaries (asteroids drift endlessly)
            if world then
                local margin = a.collisionRadius or a.size
                if a.x < world.minX - margin then
                    a.x = world.maxX + margin
                elseif a.x > world.maxX + margin then
                    a.x = world.minX - margin
                end
                if a.y < world.minY - margin then
                    a.y = world.maxY + margin
                elseif a.y > world.maxY + margin then
                    a.y = world.minY - margin
                end
            end
            
            -- Sync physics body position
            if a.body then
                a.body:setPosition(a.x, a.y)
            end
        end
    end
end

-- Draw asteroids with shader; camera supplies screen-to-world info so noise stays static
-- @param camera table optional camera {x, y, scale}
function asteroid.draw(camera)
    for _, a in ipairs(asteroid.list) do
        love.graphics.push()
        love.graphics.translate(a.x, a.y)
        love.graphics.rotate(a.angle)

        asteroid_generator.draw(a.data)
        love.graphics.pop()

        if a.maxHealth and a.health and a.health < a.maxHealth then
            local radius = a.collisionRadius or a.size or 10
            local barWidth = radius * 0.9
            local barHeight = 4
            local barX = a.x - barWidth
            local barY = a.y - radius - 18
            local outlinePad = 1

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle("fill", barX - outlinePad, barY - outlinePad, barWidth * 2 + outlinePad * 2, barHeight + outlinePad * 2)

            love.graphics.setColor(colors.asteroidHealthBg)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2, barHeight)

            local ratio = math.max(0, math.min(1, a.health / a.maxHealth))
            love.graphics.setColor(colors.asteroidHealth)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, barHeight)
        end
    end
end

function asteroid.clear()
    for i = #asteroid.list, 1, -1 do
        local a = asteroid.list[i]
        if a.body then
            a.body:destroy()
        end
        table.remove(asteroid.list, i)
    end
end

return asteroid
