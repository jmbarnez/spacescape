local asteroid = {}

asteroid.list = {}

local asteroid_generator = require("src.utils.procedural_asteroid_generator")

local HEALTH_PER_SIZE = 2.0

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
        local size = 20 + math.random() * 50

        local data = asteroid_generator.generate(size)
        local collisionRadius = (data and data.shape and data.shape.boundingRadius) or size

        local maxHealth = size * HEALTH_PER_SIZE

        table.insert(asteroid.list, {
            x = x,
            y = y,
            size = size,
            angle = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 0.4,
            data = data,
            collisionRadius = collisionRadius,
            health = maxHealth,
            maxHealth = maxHealth
        })
    end
end

function asteroid.update(dt)
    for _, a in ipairs(asteroid.list) do
        a.angle = a.angle + (a.rotationSpeed or 0) * dt
    end
end

function asteroid.draw()
    for _, a in ipairs(asteroid.list) do
        love.graphics.push()
        love.graphics.translate(a.x, a.y)
        love.graphics.rotate(a.angle)
        asteroid_generator.draw(a.data)
        love.graphics.pop()

        if a.maxHealth and a.health and a.health < a.maxHealth then
            local radius = a.collisionRadius or a.size or 10
            local barWidth = radius * 0.9
            local barHeight = 3
            local barX = a.x - barWidth
            local barY = a.y - radius - 10

            love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2, barHeight)

            local ratio = math.max(0, math.min(1, a.health / a.maxHealth))
            love.graphics.setColor(1.0, 1.0, 0.3, 1.0)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, barHeight)
        end
    end
end

function asteroid.clear()
    for i = #asteroid.list, 1, -1 do
        table.remove(asteroid.list, i)
    end
end

return asteroid
