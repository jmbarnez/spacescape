local particles = {}

particles.list = {}

function particles.explosion(x, y, color)
    for i = 1, 20 do
        local angle = math.random() * math.pi * 2
        local speed = math.random() * 200 + 50
        table.insert(particles.list, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = math.random() * 0.5 + 0.3,
            maxLife = 0.8,
            color = color,
            size = math.random() * 4 + 2
        })
    end
end

function particles.update(dt)
    for i = #particles.list, 1, -1 do
        local p = particles.list[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(particles.list, i)
        end
    end
end

function particles.draw()
    for _, p in ipairs(particles.list) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    end
end

function particles.clear()
    for i = #particles.list, 1, -1 do
        table.remove(particles.list, i)
    end
end

return particles
