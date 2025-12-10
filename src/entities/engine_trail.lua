local colors = require("src.core.colors")

local engine_trail = {}

-- ###########################################################################
-- BUBBLY INTENSE CYAN GLOW TRAIL
-- Uses QUAD-BASED rendering to bypass OpenGL point size limits
-- ###########################################################################

-- Bubble sizes in pixels (tiny bubbles)
local BUBBLE_SIZE_MIN = 8
local BUBBLE_SIZE_MAX = 20

-- Spawn fewer but bigger bubbles
local BUBBLES_PER_SPAWN = 2

-- Glow intensity (1.0 = no extra glow)
local TRAIL_INTENSITY = 1.0

engine_trail.points = {}
engine_trail.shader = nil

-- Spawn rate
engine_trail.spawnInterval = 0.035

engine_trail.timeSinceLast = 0

-- Max bubbles in memory
engine_trail.maxPoints = 200

-- How long each bubble lives
engine_trail.trailLifetime = 0.9

engine_trail.time = 0

-- Create a simple 1x1 white image for the shader to work with
local bubbleImage = nil

function engine_trail.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/engine_trail.glsl")
    if ok and shader then
        engine_trail.shader = shader
    else
        engine_trail.shader = nil
    end

    -- Create a 1x1 white pixel image as a base for the shader
    local imageData = love.image.newImageData(1, 1)
    imageData:setPixel(0, 0, 1, 1, 1, 1)
    bubbleImage = love.graphics.newImage(imageData)
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

        -- Spawn behind the ship
        local offset = player.size * 0.85
        local baseDirX = math.cos(player.angle + math.pi)
        local baseDirY = math.sin(player.angle + math.pi)
        local rightX = -baseDirY
        local rightY = baseDirX

        -- Bubble drift speed
        local baseSpeed = 80
        local speedJitter = 40
        local dirJitter = 0.8

        for n = 1, BUBBLES_PER_SPAWN do
            -- Spread bubbles across exhaust width
            local lateral = (math.random() - 0.5) * player.size * 1.2

            local ox = baseDirX * offset + rightX * lateral
            local oy = baseDirY * offset + rightY * lateral

            local dir = player.angle + math.pi + (math.random() - 0.5) * dirJitter
            local speed = baseSpeed + math.random() * speedJitter

            -- Random size within range
            local bubbleSize = BUBBLE_SIZE_MIN + math.random() * (BUBBLE_SIZE_MAX - BUBBLE_SIZE_MIN)

            table.insert(engine_trail.points, 1, {
                x = player.x + ox,
                y = player.y + oy,
                vx = math.cos(dir) * speed,
                vy = math.sin(dir) * speed,
                life = engine_trail.trailLifetime,
                maxLife = engine_trail.trailLifetime,
                noiseOffset = math.random() * math.pi * 2,
                spawnTime = engine_trail.time,
                size = bubbleSize,
                seed = math.random()
            })
        end

        while #engine_trail.points > engine_trail.maxPoints do
            table.remove(engine_trail.points)
        end
    end

    -- Gentle motion - bubbles float and wobble
    local drag = 0.92
    local wobbleStrength = 25

    for i = #engine_trail.points, 1, -1 do
        local p = engine_trail.points[i]
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(engine_trail.points, i)
        else
            -- Gentle wobble for floating feel
            local t = engine_trail.time * 1.5 + p.noiseOffset

            local nx = math.cos(t)
            local ny = math.sin(t * 1.3)

            p.vx = p.vx + nx * wobbleStrength * dt
            p.vy = p.vy + ny * wobbleStrength * dt

            local dragFactor = (1 - (1 - drag) * dt * 3)
            p.vx = p.vx * dragFactor
            p.vy = p.vy * dragFactor

            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

function engine_trail.draw()
    if #engine_trail.points == 0 or not engine_trail.shader then
        return
    end

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    love.graphics.setShader(engine_trail.shader)
    love.graphics.setBlendMode("add", "alphamultiply")

    -- Send uniforms
    engine_trail.shader:send("u_time", engine_trail.time)
    engine_trail.shader:send("u_colorMode", 2.0)
    engine_trail.shader:send("u_colorA", colors.engineTrailA)
    engine_trail.shader:send("u_colorB", colors.engineTrailB)
    engine_trail.shader:send("u_intensity", TRAIL_INTENSITY)

    love.graphics.setColor(1, 1, 1, 1)

    -- Draw each bubble as a QUAD (bypasses gl_PointSize limit!)
    for i, p in ipairs(engine_trail.points) do
        local age = engine_trail.time - p.spawnTime
        local life01 = math.min(age / engine_trail.trailLifetime, 1.0)

        -- Calculate size with shrink and pulse
        local sizeMult = 1.0 - (life01 ^ 1.2) * 0.6
        local pulse = 1.0 + math.sin(p.seed * 25.0 + engine_trail.time * 10.0) * 0.2
        local size = p.size * sizeMult * pulse

        -- Send per-bubble data to shader
        engine_trail.shader:send("u_bubbleLifePhase", life01)
        engine_trail.shader:send("u_bubbleSeed", p.seed)

        -- Calculate alpha
        local fadeStart = 0.6
        local alpha = 1.0
        if life01 >= fadeStart then
            alpha = 1.0 - ((life01 - fadeStart) / (1.0 - fadeStart)) ^ 0.5
        end
        engine_trail.shader:send("u_bubbleAlpha", alpha)

        -- Draw as a scaled quad centered on the bubble position
        local halfSize = size / 2
        love.graphics.draw(bubbleImage, p.x, p.y, 0, size, size, 0.5, 0.5)
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
end

return engine_trail
