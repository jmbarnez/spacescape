local bullet = {}

bullet.list = {}

local function isOffscreen(b, world)
    if world then
        local margin = 100
        return b.x < world.minX - margin or b.x > world.maxX + margin or
               b.y < world.minY - margin or b.y > world.maxY + margin
    else
        return b.x < -50 or b.x > love.graphics.getWidth() + 50 or
               b.y < -50 or b.y > love.graphics.getHeight() + 50
    end
end

function bullet.spawn(player, targetX, targetY)
    local angle = math.atan2(targetY - player.y, targetX - player.x)

    table.insert(bullet.list, {
        x = player.x + math.cos(angle) * player.size,
        y = player.y + math.sin(angle) * player.size,
        angle = angle,
        speed = 600
    })

    player.angle = angle
end

function bullet.update(dt, world)
    for i = #bullet.list, 1, -1 do
        local b = bullet.list[i]
        b.x = b.x + math.cos(b.angle) * b.speed * dt
        b.y = b.y + math.sin(b.angle) * b.speed * dt

        -- Remove bullets that are off screen
        if isOffscreen(b, world) then
            table.remove(bullet.list, i)
        end
    end
end

function bullet.draw(colors)
    love.graphics.setColor(colors.bullet)
    for _, b in ipairs(bullet.list) do
        love.graphics.circle("fill", b.x, b.y, 4)

        -- Bullet trail
        love.graphics.setColor(colors.bullet[1], colors.bullet[2], colors.bullet[3], 0.3)
        local trailX = b.x - math.cos(b.angle) * 15
        local trailY = b.y - math.sin(b.angle) * 15
        love.graphics.line(b.x, b.y, trailX, trailY)
        love.graphics.setColor(colors.bullet)
    end
end

function bullet.clear()
    for i = #bullet.list, 1, -1 do
        table.remove(bullet.list, i)
    end
end

return bullet
