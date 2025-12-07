local colors = require("src.core.colors")

local particles = {}

-- Maximum number of GPU particle sprites we keep in the mesh at once
local MAX_PARTICLES = 512

-- Particle type identifiers (must match particles.glsl expectations)
local PARTICLE_TYPE_EXPLOSION = 0
local PARTICLE_TYPE_IMPACT    = 1
local PARTICLE_TYPE_SPARK     = 2

-- Base sprite sizes in pixels for each particle category
local BASE_SIZE_EXPLOSION = 18
local BASE_SIZE_IMPACT    = 12
local BASE_SIZE_SPARK     = 7

-- Per-type brightness multipliers sent into the shader
local INTENSITY_EXPLOSION = 2.3
local INTENSITY_IMPACT    = 1.6
local INTENSITY_SPARK     = 1.9

particles.list = {}
particles.time = 0
particles.shader = nil
particles.mesh = nil
particles.maxParticles = MAX_PARTICLES

-- Shader-based particle renderer for explosions / impacts / sparks
function particles.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/particles.glsl")
    if ok and shader then
        particles.shader = shader

        local format = {
            {"VertexPosition", "float", 2},  -- world-space position
            {"VertexUserData", "float", 4},  -- life phase, base size, type, seed
        }

        particles.mesh = love.graphics.newMesh(format, particles.maxParticles, "points", "dynamic")
    else
        particles.shader = nil
        particles.mesh = nil
    end
end

function particles.explosion(x, y, color, count, speedMult, sizeMult)
    count = count or 10
    speedMult = speedMult or 1.0
    color = color or colors.explosion
    
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
            size = (math.random() * 6 + 3) * (sizeMult or 1.0),
            drag = 0.98,

            -- GPU rendering metadata
            type = PARTICLE_TYPE_EXPLOSION,
            seed = math.random(),
        })
    end
end

function particles.impact(x, y, color, count)
    count = count or 10
    color = color or colors.particleImpact

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
            size = math.random() * 1.2 + 1.0,
            drag = 0.92,

            -- GPU rendering metadata
            type = PARTICLE_TYPE_IMPACT,
            seed = math.random(),
        })
    end
end

function particles.spark(x, y, color, count)
    -- Spark particles are meant to look like sharp, fast metal sparks.
    -- Keep the default count modest; callers can override when they need more.
    count = count or 8
    color = color or colors.particleSpark

    for i = 1, count do
        -- Random direction around the contact point
        local angle = math.random() * math.pi * 2

        -- High initial speed so sparks streak out quickly
        local speed = math.random() * 160 + 220 -- ~220 - 380

        -- Very short lifetime so they "flash" and disappear like real sparks
        local life = math.random() * 0.10 + 0.05 -- ~0.05 - 0.15s

        table.insert(particles.list, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            maxLife = life,
            color = {color[1] or 1, color[2] or 1, color[3] or 1},

            -- Small radius so they render as tight points rather than big glows
            size = math.random() * 0.7 + 0.5, -- ~0.5 - 1.2

            -- Light drag so they retain most of their velocity during their short life
            drag = 0.96,

            -- GPU rendering metadata
            type = PARTICLE_TYPE_SPARK,
            seed = math.random(),
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
    -- Skip rendering if there are no particles or the GPU path is unavailable
    if #particles.list == 0 or not particles.shader or not particles.mesh then
        return
    end

    local mesh = particles.mesh
    local shader = particles.shader

    -- Encode per-particle data into the mesh as point sprites
    local count = math.min(#particles.list, particles.maxParticles)
    if count <= 0 then
        return
    end

    for i = 1, count do
        local p = particles.list[i]
        local maxLife = p.maxLife or 0.001
        local lifeRatio = math.max(0.0, p.life / maxLife)
        local lifePhase = 1.0 - lifeRatio

        local pType = p.type or PARTICLE_TYPE_EXPLOSION
        local baseSize
        if pType == PARTICLE_TYPE_IMPACT then
            baseSize = BASE_SIZE_IMPACT
        elseif pType == PARTICLE_TYPE_SPARK then
            baseSize = BASE_SIZE_SPARK
        else
            baseSize = BASE_SIZE_EXPLOSION
        end

        local seed = p.seed or 0.0

        -- VertexUserData: life phase, base size, type id, random seed
        mesh:setVertex(i, p.x, p.y, lifePhase, baseSize, pType, seed)
    end

    mesh:setDrawRange(1, count)

    local prevShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    love.graphics.setShader(shader)
    love.graphics.setBlendMode("add", "alphamultiply")

    -- Global uniforms for all particle types
    shader:send("u_time", particles.time)
    shader:send("u_colorExplosion", {colors.explosion[1], colors.explosion[2], colors.explosion[3]})
    shader:send("u_colorImpact", {colors.particleImpact[1], colors.particleImpact[2], colors.particleImpact[3]})
    shader:send("u_colorSpark", {colors.particleSpark[1], colors.particleSpark[2], colors.particleSpark[3]})
    shader:send("u_intensityExplosion", INTENSITY_EXPLOSION)
    shader:send("u_intensityImpact", INTENSITY_IMPACT)
    shader:send("u_intensitySpark", INTENSITY_SPARK)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(prevShader)
end

function particles.clear()
    particles.list = {}
end

return particles
