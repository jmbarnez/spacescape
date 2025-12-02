local enemy = {}

enemy.list = {}

local ship_generator = require("src.utils.procedural_ship_generator")

function enemy.spawn(world)
    local side = math.random(1, 4)
    local x, y

    if world then
        if side == 1 then
            x = math.random(world.minX, world.maxX)
            y = world.minY - 30
        elseif side == 2 then
            x = world.maxX + 30
            y = math.random(world.minY, world.maxY)
        elseif side == 3 then
            x = math.random(world.minX, world.maxX)
            y = world.maxY + 30
        else
            x = world.minX - 30
            y = math.random(world.minY, world.maxY)
        end
    else
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()

        if side == 1 then
            x = math.random(0, width)
            y = -30
        elseif side == 2 then
            x = width + 30
            y = math.random(0, height)
        elseif side == 3 then
            x = math.random(0, width)
            y = height + 30
        else
            x = -30
            y = math.random(0, height)
        end
    end

    local size = 15 + math.random() * 10

    table.insert(enemy.list, {
        x = x,
        y = y,
        size = size,
        speed = 80 + math.random() * 60,
        health = 1,
        angle = 0,
        ship = ship_generator.generate(size)
    })
end

function enemy.update(dt, playerState, world)
    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]

        local dx = playerState.x - e.x
        local dy = playerState.y - e.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance > 0 then
            e.x = e.x + (dx / distance) * e.speed * dt
            e.y = e.y + (dy / distance) * e.speed * dt
            e.angle = math.atan2(dy, dx)
        end

        if world then
            local margin = e.size
            e.x = math.max(world.minX + margin, math.min(world.maxX - margin, e.x))
            e.y = math.max(world.minY + margin, math.min(world.maxY - margin, e.y))
        end
    end
end

function enemy.draw(colors)
    for _, e in ipairs(enemy.list) do
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.rotate(e.angle)

        ship_generator.draw(e.ship, colors)

        love.graphics.pop()
    end
end

function enemy.clear()
    for i = #enemy.list, 1, -1 do
        table.remove(enemy.list, i)
    end
end

return enemy
