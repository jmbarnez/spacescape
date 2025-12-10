local colors = require("src.core.colors")

local engine_trail = {}

-- ###########################################################################
-- BUBBLY ENGINE TRAIL - supports player (cyan) and enemies (red)
-- Uses QUAD-BASED rendering to bypass OpenGL point size limits
-- ###########################################################################

-- Bubble sizes in pixels (very small bubbles)
local BUBBLE_SIZE_MIN = 3
local BUBBLE_SIZE_MAX = 8

-- Spawn per entity per interval
local BUBBLES_PER_SPAWN = 2

-- Glow intensity (1.0 = no extra glow)
local TRAIL_INTENSITY = 1.0

-- All bubble particles (from any entity)
engine_trail.points = {}
engine_trail.shader = nil

-- Spawn rate
engine_trail.spawnInterval = 0.035

-- Per-entity spawn timers (keyed by entity)
engine_trail.entityTimers = {}

-- Max bubbles in memory
engine_trail.maxPoints = 400

-- How long each bubble lives
engine_trail.trailLifetime = 0.9

engine_trail.time = 0

-- Create a simple 1x1 white image for the shader to work with
local bubbleImage = nil

-- Red color palette for enemies
local ENEMY_COLOR_A = { 1.0, 0.3, 0.2 }
local ENEMY_COLOR_B = { 0.8, 0.1, 0.1 }

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
    engine_trail.entityTimers = {}
    engine_trail.time = 0
end

-- Spawn bubbles for a single entity (player or enemy)
-- colorA, colorB are the gradient colors for this entity's trail
local function spawnBubblesForEntity(entity, colorA, colorB)
    if not entity or not entity.x or not entity.y then
        return
    end

    -- Check if entity is thrusting (enemies always thrust when moving)
    local isMoving = entity.isThrusting
    if isMoving == nil then
        -- For enemies, check if they have velocity
        local vx = entity.vx or 0
        local vy = entity.vy or 0
        isMoving = (vx * vx + vy * vy) > 100
    end

    if not isMoving then
        return
    end

    -- Get or create timer for this entity
    local entityId = tostring(entity)
    engine_trail.entityTimers[entityId] = (engine_trail.entityTimers[entityId] or 0)

    if engine_trail.entityTimers[entityId] < engine_trail.spawnInterval then
        return
    end
    engine_trail.entityTimers[entityId] = 0

    -- Spawn behind the entity
    local size = entity.size or 15
    local angle = entity.angle or 0
    local offset = size * 0.85
    local baseDirX = math.cos(angle + math.pi)
    local baseDirY = math.sin(angle + math.pi)
    local rightX = -baseDirY
    local rightY = baseDirX

    -- Bubble drift speed
    local baseSpeed = 80
    local speedJitter = 40
    local dirJitter = 0.8

    for n = 1, BUBBLES_PER_SPAWN do
        -- Spread bubbles across exhaust width (thin focused stream)
        local lateral = (math.random() - 0.5) * size * 0.4

        local ox = baseDirX * offset + rightX * lateral
        local oy = baseDirY * offset + rightY * lateral

        local dir = angle + math.pi + (math.random() - 0.5) * dirJitter
        local speed = baseSpeed + math.random() * speedJitter

        -- Random size within range
        local bubbleSize = BUBBLE_SIZE_MIN + math.random() * (BUBBLE_SIZE_MAX - BUBBLE_SIZE_MIN)

        table.insert(engine_trail.points, 1, {
            x = entity.x + ox,
            y = entity.y + oy,
            vx = math.cos(dir) * speed,
            vy = math.sin(dir) * speed,
            life = engine_trail.trailLifetime,
            maxLife = engine_trail.trailLifetime,
            noiseOffset = math.random() * math.pi * 2,
            spawnTime = engine_trail.time,
            size = bubbleSize,
            seed = math.random(),
            colorA = colorA,
            colorB = colorB
        })
    end
end

-- Update entity timers
local function updateEntityTimers(dt)
    for entityId, timer in pairs(engine_trail.entityTimers) do
        engine_trail.entityTimers[entityId] = timer + dt
    end
end

function engine_trail.update(dt, player, enemies)
    engine_trail.time = engine_trail.time + dt
    updateEntityTimers(dt)

    -- Spawn for player (cyan)
    if player then
        spawnBubblesForEntity(player, colors.engineTrailA, colors.engineTrailB)
    end

    -- Spawn for all enemies (red)
    if enemies then
        for _, enemy in ipairs(enemies) do
            if not enemy._removed then
                spawnBubblesForEntity(enemy, ENEMY_COLOR_A, ENEMY_COLOR_B)
            end
        end
    end

    -- Cap total particles
    while #engine_trail.points > engine_trail.maxPoints do
        table.remove(engine_trail.points)
    end

    -- Update existing particles
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

    -- Send common uniforms
    engine_trail.shader:send("u_time", engine_trail.time)
    engine_trail.shader:send("u_colorMode", 2.0)
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

        -- Send per-bubble colors
        engine_trail.shader:send("u_colorA", p.colorA or colors.engineTrailA)
        engine_trail.shader:send("u_colorB", p.colorB or colors.engineTrailB)

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
        love.graphics.draw(bubbleImage, p.x, p.y, 0, size, size, 0.5, 0.5)
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
end

return engine_trail
