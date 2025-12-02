local enemy = {}

enemy.list = {}

local ship_generator = require("src.utils.procedural_ship_generator")

function enemy.spawn(world)
    local side = math.random(1, 4)
    local x, y

    if world then
        local margin = 50
        x = math.random(world.minX + margin, world.maxX - margin)
        y = math.random(world.minY + margin, world.maxY - margin)
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
    local ship = ship_generator.generate(size)
    local maxHealth = (ship and ship.hull and ship.hull.maxHealth) or 1

    table.insert(enemy.list, {
        x = x,
        y = y,
        size = size,
        speed = 80 + math.random() * 60,
        health = maxHealth,
        maxHealth = maxHealth,
        angle = 0,
        ship = ship
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

        if e.maxHealth and e.health and e.health < e.maxHealth then
            local radius = (e.ship and e.ship.boundingRadius) or e.size or 10
            local barWidth = radius * 0.9
            local barHeight = 3
            local barX = e.x - barWidth
            local barY = e.y - radius - 10

            love.graphics.setColor(colors.healthBg)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2, barHeight)

            local ratio = math.max(0, math.min(1, e.health / e.maxHealth))
            love.graphics.setColor(colors.health)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, barHeight)
        end
    end
end

function enemy.clear()
    for i = #enemy.list, 1, -1 do
        table.remove(enemy.list, i)
    end
end

return enemy
