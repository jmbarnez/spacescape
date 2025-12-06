local particles = {}

particles.list = {}
particles.time = 0

-- No shader-based rendering; we use a simple circle renderer for clarity.
function particles.load()
    -- Kept for API compatibility; nothing to initialize.
end

function particles.explosion(x, y, color, count, speedMult)
    count = count or 10
    speedMult = speedMult or 1.0
    color = color or {1, 0.8, 0.4}
    
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = (math.random() * 200 + 50) * speedMult
        local life = math.random() * 0.5 + 0.3
        
        table.insert(particles.list, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            maxLife = life,
            color = {color[1] or 1, color[2] or 1, color[3] or 1},
            size = math.random() * 6 + 3,
            drag = 0.98
        })
    end
end

function particles.impact(x, y, color, count)
    count = count or 16
    color = color or {1, 1, 1}

    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = math.random() * 260 + 220
        local life = math.random() * 0.25 + 0.2

        table.insert(particles.list, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            maxLife = life,
            color = {color[1] or 1, color[2] or 1, color[3] or 1},
            size = math.random() * 3 + 3,
            drag = 0.92
        })
    end
end

function particles.spark(x, y, color, count)
    count = count or 10
    color = color or {1, 1, 0.8}

    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = math.random() * 190 + 140
        local life = math.random() * 0.25 + 0.15

        table.insert(particles.list, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            maxLife = life,
            color = {color[1] or 1, color[2] or 1, color[3] or 1},
            size = math.random() * 2.5 + 2,
            drag = 0.94
        })
    end
end

function particles.update(dt)
    particles.time = particles.time + dt
    
    for i = #particles.list, 1, -1 do
        local p = particles.list[i]
        
        p.vx = p.vx * (p.drag or 1.0)
        p.vy = p.vy * (p.drag or 1.0)
        
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        
        if p.life <= 0 then
            table.remove(particles.list, i)
        end
    end
    
end

function particles.draw()
    if #particles.list == 0 then
        return
    end
    
    local prevShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    love.graphics.setBlendMode("add", "alphamultiply")
    
    for _, p in ipairs(particles.list) do
        local lifeRatio = math.max(0, p.life / p.maxLife)
        local size = p.size * (0.5 + lifeRatio * 0.5)
        local alpha = lifeRatio
        
        local r, g, b = p.color[1], p.color[2], p.color[3]
        
        love.graphics.setColor(r * 0.3, g * 0.3, b * 0.3, alpha * 0.4)
        love.graphics.circle("fill", p.x, p.y, size * 2)
        
        love.graphics.setColor(r * 0.6, g * 0.6, b * 0.6, alpha * 0.6)
        love.graphics.circle("fill", p.x, p.y, size * 1.3)
        
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle("fill", p.x, p.y, size)
        
        love.graphics.setColor(1, 1, 1, alpha * 0.8)
        love.graphics.circle("fill", p.x, p.y, size * 0.3)
    end
    
    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(prevShader)
end

function particles.clear()
    particles.list = {}
end

return particles
