local asteroid = {}

asteroid.list = {}

local asteroid_generator = require("src.utils.procedural_asteroid_generator")

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

        table.insert(asteroid.list, {
            x = x,
            y = y,
            size = size,
            angle = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 0.4,
            data = data
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
    end
end

function asteroid.clear()
    for i = #asteroid.list, 1, -1 do
        table.remove(asteroid.list, i)
    end
end

return asteroid
