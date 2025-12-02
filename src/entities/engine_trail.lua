local engine_trail = {}

engine_trail.points = {}
engine_trail.shader = nil
engine_trail.spawnInterval = 0.01
engine_trail.timeSinceLast = 0
engine_trail.maxPoints = 80
engine_trail.trailLifetime = 0.4
engine_trail.time = 0

function engine_trail.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/engine_trail.glsl")
    if ok then
        engine_trail.shader = shader
    end
end

function engine_trail.reset()
    engine_trail.points = {}
    engine_trail.timeSinceLast = 0
    engine_trail.time = 0
end

function engine_trail.update(dt, player)
    engine_trail.timeSinceLast = engine_trail.timeSinceLast + dt
    engine_trail.time = engine_trail.time + dt

    if player.isMoving and engine_trail.timeSinceLast >= engine_trail.spawnInterval then
        engine_trail.timeSinceLast = 0
        local offset = player.size * 0.9
        local ox = math.cos(player.angle + math.pi) * offset
        local oy = math.sin(player.angle + math.pi) * offset

        local baseSpeed = 80
        local speedJitter = 40
        local dirJitter = 0.3
        local dir = player.angle + math.pi + (math.random() - 0.5) * dirJitter
        local speed = baseSpeed + math.random() * speedJitter

        table.insert(engine_trail.points, 1, {
            x = player.x + ox,
            y = player.y + oy,
            vx = math.cos(dir) * speed,
            vy = math.sin(dir) * speed,
            life = engine_trail.trailLifetime,
            maxLife = engine_trail.trailLifetime,
            noiseOffset = math.random() * math.pi * 2
        })

        if #engine_trail.points > engine_trail.maxPoints then
            table.remove(engine_trail.points)
        end
    end

    local drag = 0.8
    local turbulenceStrength = 25

    for i = #engine_trail.points, 1, -1 do
        local p = engine_trail.points[i]
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(engine_trail.points, i)
        else
            local t = engine_trail.time * 1.5 + p.noiseOffset
            local nx = math.cos(t)
            local ny = math.sin(t * 1.1)

            p.vx = p.vx + nx * turbulenceStrength * dt
            p.vy = p.vy + ny * turbulenceStrength * dt

            local dragFactor = (1 - (1 - drag) * dt * 4)
            p.vx = p.vx * dragFactor
            p.vy = p.vy * dragFactor

            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

function engine_trail.draw()
    if #engine_trail.points == 0 then
        return
    end

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    if engine_trail.shader then
        love.graphics.setShader(engine_trail.shader)
        local t = love.timer.getTime()
        engine_trail.shader:send("u_time", t)
        engine_trail.shader:send("u_trailLifetime", engine_trail.trailLifetime)
        engine_trail.shader:send("u_colorMode", 2)
        engine_trail.shader:send("u_colorA", {0.3, 0.7, 1.0})
        engine_trail.shader:send("u_colorB", {0.8, 0.9, 1.0})
        engine_trail.shader:send("u_intensity", 1.0)
    end

    love.graphics.setBlendMode("add", "alphamultiply")

    for i, p in ipairs(engine_trail.points) do
        local life01 = p.life / p.maxLife
        local size = 2 + (1 - life01) * 4

        local blueStart = {0.25, 0.6, 1.0}
        local blueEnd   = {0.6, 0.9, 1.0}
        local t = 1 - life01

        local r = blueStart[1] + (blueEnd[1] - blueStart[1]) * t
        local g = blueStart[2] + (blueEnd[2] - blueStart[2]) * t
        local b = blueStart[3] + (blueEnd[3] - blueStart[3]) * t

        local alpha = 0.15 + 0.85 * life01

        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle("fill", p.x, p.y, size)
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
end

return engine_trail