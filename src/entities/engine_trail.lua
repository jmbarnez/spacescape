local engine_trail = {}

engine_trail.points = {}
engine_trail.shader = nil
engine_trail.mesh = nil
engine_trail.spawnInterval = 0.012
engine_trail.timeSinceLast = 0
engine_trail.maxPoints = 450
engine_trail.trailLifetime = 0.8
engine_trail.time = 0

function engine_trail.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/engine_trail.glsl")
    if ok then
        engine_trail.shader = shader
        local format = {
            {"VertexPosition", "float", 2},
            {"VertexUserData", "float", 4}
        }
        engine_trail.mesh = love.graphics.newMesh(format, engine_trail.maxPoints, "points", "dynamic")
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

    if player.isThrusting and engine_trail.timeSinceLast >= engine_trail.spawnInterval then
        engine_trail.timeSinceLast = 0
        local offset = player.size * 0.9
        local baseDirX = math.cos(player.angle + math.pi)
        local baseDirY = math.sin(player.angle + math.pi)
        local rightX = -baseDirY
        local rightY = baseDirX

        local baseSpeed = 120
        local speedJitter = 60
        local dirJitter = 0.8

        for n = 1, 3 do
            local lateral = (math.random() - 0.5) * player.size * 0.9
            local ox = baseDirX * offset + rightX * lateral
            local oy = baseDirY * offset + rightY * lateral

            local dir = player.angle + math.pi + (math.random() - 0.5) * dirJitter
            local speed = baseSpeed + math.random() * speedJitter

            table.insert(engine_trail.points, 1, {
                x = player.x + ox,
                y = player.y + oy,
                vx = math.cos(dir) * speed,
                vy = math.sin(dir) * speed,
                life = engine_trail.trailLifetime,
                maxLife = engine_trail.trailLifetime,
                noiseOffset = math.random() * math.pi * 2,
                spawnTime = engine_trail.time,
                size = 18,
                seed = math.random()
            })
        end

        while #engine_trail.points > engine_trail.maxPoints do
            table.remove(engine_trail.points)
        end
    end

    local drag = 0.86
    local turbulenceStrength = 35

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

    if engine_trail.mesh then
        local count = #engine_trail.points
        if count > 0 then
            for i = 1, count do
                local p = engine_trail.points[i]
                local spawn = p.spawnTime or (engine_trail.time - (p.maxLife or engine_trail.trailLifetime) + (p.life or 0))
                local size = p.size or 4
                local seed = p.seed or 0
                engine_trail.mesh:setVertex(i, p.x, p.y, spawn, size, seed, 0)
            end
            engine_trail.mesh:setDrawRange(1, count)
        end
    end
end

function engine_trail.draw()
    if #engine_trail.points == 0 then
        return
    end

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    if engine_trail.shader and engine_trail.mesh then
        love.graphics.setShader(engine_trail.shader)
        love.graphics.setBlendMode("add", "alphamultiply")

        engine_trail.shader:send("u_time", engine_trail.time)
        engine_trail.shader:send("u_trailLifetime", engine_trail.trailLifetime)
        engine_trail.shader:send("u_colorMode", 2)
        engine_trail.shader:send("u_colorA", {0.22, 0.55, 1.0})
        engine_trail.shader:send("u_colorB", {0.9, 0.95, 1.0})
        engine_trail.shader:send("u_intensity", 3.5)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(engine_trail.mesh)

        love.graphics.setBlendMode(prevBlend, prevAlpha)
        love.graphics.setShader(previousShader)
        return
    end

    love.graphics.setBlendMode("add", "alphamultiply")

    for i, p in ipairs(engine_trail.points) do
        local life01 = p.life / p.maxLife
        local size = 3 + (1 - life01) * 6

        local blueStart = {0.22, 0.55, 1.0}
        local blueEnd   = {0.9, 0.95, 1.0}
        local t = 1 - life01

        local r = blueStart[1] + (blueEnd[1] - blueStart[1]) * t
        local g = blueStart[2] + (blueEnd[2] - blueStart[2]) * t
        local b = blueStart[3] + (blueEnd[3] - blueStart[3]) * t

        local alpha = 0.25 + 0.9 * life01

        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle("fill", p.x, p.y, size)
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
end

return engine_trail