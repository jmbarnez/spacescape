local colors = require("src.core.colors")
local config = require("src.core.config")

local engine_trail = {}

-- ###########################################################################
-- BUBBLY ENGINE TRAIL - supports player (cyan) and enemies (red)
-- Uses QUAD-BASED rendering to bypass OpenGL point size limits
-- ###########################################################################

-- All bubble particles (from any entity)
engine_trail.points = {}
engine_trail.shader = nil

-- Per-entity spawn timers (weak keys to auto-clean when entities are removed)
engine_trail.entityTimers = setmetatable({}, { __mode = "k" })

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
    engine_trail.entityTimers = {}
    engine_trail.time = 0
end

-- Spawn bubbles for a single entity (player or enemy)
-- colorA, colorB are the gradient colors for this entity's trail
local function spawnBubblesForEntity(entity, colorA, colorB)
    if not entity then
        return
    end

    -- ECS-aware property resolution
    local ex = entity.position and entity.position.x or entity.x
    local ey = entity.position and entity.position.y or entity.y
    if ex == nil or ey == nil then
        return
    end

    -- Check if entity is thrusting.
    -- NOTE: This module supports BOTH:
    --   - ECS entities where `thrust` is a component table (with `isThrusting`)
    --   - Legacy/player state where `thrust` is a numeric power and `isThrusting`
    --     is stored directly on the entity/state table.
    local isMoving = nil
    if type(entity.thrust) == "table" then
        isMoving = entity.thrust.isThrusting
    end
    if isMoving == nil then
        isMoving = entity.isThrusting
    end
    if isMoving == nil then
        -- For enemies, check if they have velocity
        local vx = (entity.velocity and entity.velocity.vx) or entity.vx or 0
        local vy = (entity.velocity and entity.velocity.vy) or entity.vy or 0
        isMoving = (vx * vx + vy * vy) > 100
    end

    if not isMoving then
        return
    end

    -- Get or create timer for this entity (use entity table as key for weak ref)
    engine_trail.entityTimers[entity] = (engine_trail.entityTimers[entity] or 0)

    if engine_trail.entityTimers[entity] < config.engineTrail.spawnInterval then
        return
    end
    engine_trail.entityTimers[entity] = 0

    -- Spawn behind the entity
    local size = 15
    if entity.size then
        size = type(entity.size) == "table" and (entity.size.value or 15) or entity.size
    elseif entity.collisionRadius then
        size = type(entity.collisionRadius) == "table" and (entity.collisionRadius.radius or 15) or entity.collisionRadius
    end

    local angle = (entity.rotation and entity.rotation.angle) or entity.angle or 0
    local offset = size * 0.85
    local baseDirX = math.cos(angle + math.pi)
    local baseDirY = math.sin(angle + math.pi)
    local rightX = -baseDirY
    local rightY = baseDirX

    -- Bubble drift speed
    local baseSpeed = 80
    local speedJitter = 40
    local dirJitter = 0.8

    for n = 1, config.engineTrail.bubblesPerSpawn do
        -- Spread bubbles across exhaust width (thin focused stream)
        local lateral = (math.random() - 0.5) * size * 0.4

        local ox = baseDirX * offset + rightX * lateral
        local oy = baseDirY * offset + rightY * lateral

        local dir = angle + math.pi + (math.random() - 0.5) * dirJitter
        local speed = baseSpeed + math.random() * speedJitter

        -- Random size within range
        local bubbleSize = config.engineTrail.bubbleSizeMin +
        math.random() * (config.engineTrail.bubbleSizeMax - config.engineTrail.bubbleSizeMin)

        table.insert(engine_trail.points, 1, {
            x = ex + ox,
            y = ey + oy,
            vx = math.cos(dir) * speed,
            vy = math.sin(dir) * speed,
            life = config.engineTrail.lifetime,
            maxLife = config.engineTrail.lifetime,
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
    for entity, timer in pairs(engine_trail.entityTimers) do
        engine_trail.entityTimers[entity] = timer + dt
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
                spawnBubblesForEntity(enemy, colors.enemyEngineTrailA, colors.enemyEngineTrailB)
            end
        end
    end

    -- Cap total particles
    while #engine_trail.points > config.engineTrail.maxPoints do
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
    engine_trail.shader:send("u_intensity", config.engineTrail.intensity)

    love.graphics.setColor(1, 1, 1, 1)

    -- Draw each bubble as a QUAD (bypasses gl_PointSize limit!)
    for i, p in ipairs(engine_trail.points) do
        local age = engine_trail.time - p.spawnTime
        local life01 = math.min(age / config.engineTrail.lifetime, 1.0)

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
