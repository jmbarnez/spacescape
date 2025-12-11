local colors = require("src.core.colors")

local particles = {}

-- Maximum number of GPU particle sprites we keep in the mesh at once
local MAX_PARTICLES = 512

-- Particle type identifiers (must match particles.glsl expectations)
local PARTICLE_TYPE_EXPLOSION = 0
local PARTICLE_TYPE_IMPACT    = 1
local PARTICLE_TYPE_SPARK     = 2

-- Base sprite sizes in pixels for each particle category
local BASE_SIZE_EXPLOSION = 72
local BASE_SIZE_IMPACT    = 48
local BASE_SIZE_SPARK     = 24

-- Per-type brightness multipliers sent into the shader
local INTENSITY_EXPLOSION = 7.0
local INTENSITY_IMPACT    = 5.5
local INTENSITY_SPARK     = 6.0

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
            {"VertexColor", "float", 3},
        }

        particles.mesh = love.graphics.newMesh(format, particles.maxParticles, "points", "dynamic")
    else
        particles.shader = nil
        particles.mesh = nil
    end
end

function particles.explosion(x, y, color, count, speedMult, sizeMult)
    count = count or 36
    speedMult = speedMult or 1.0
    color = color or colors.explosion
    
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = (math.random() * 220 + 80) * speedMult
        local life = math.random() * 0.5 + 0.4
        
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

function particles.impact(x, y, color, count, normalX, normalY)
    count = count or 24
    color = color or colors.particleImpact

    ------------------------------------------------------------------
    -- Interpret the supplied normal (if any) as pointing "out of" the
    -- surface. We then build a tangent so some fragments skid along the
    -- surface instead of only blasting straight out.
    ------------------------------------------------------------------
    local hasNormal = normalX and normalY and (normalX ~= 0 or normalY ~= 0)
    local baseAngle = nil
    local tx, ty = 0, 0
    if hasNormal then
        -- Base angle for outward-facing dust cone
        baseAngle = math.atan2(normalY, normalX)

        -- Tangent vector (perpendicular to normal) for surface chips
        tx, ty = -normalY, normalX
        local tLen = math.sqrt(tx * tx + ty * ty)
        if tLen > 0 then
            tx, ty = tx / tLen, ty / tLen
        else
            tx, ty = 1, 0
        end
    end

    -- Fraction of particles that behave like grazing surface shards
    local shatterFrac = 0.55
    -- Outward dust cone spread around the normal
    local halfSpread = math.pi * 0.35

    for i = 1, count do
        local vx, vy
        local speed
        local life
        local drag

        if hasNormal and math.random() < shatterFrac then
            ------------------------------------------------------
            -- SURFACE SHARDS
            -- These travel mostly along the tangent with a bit of
            -- outward push so they appear to peel off the surface.
            ------------------------------------------------------
            local sign = (math.random() < 0.5) and -1 or 1
            local mixT = 0.8  -- dominant tangent component
            local mixN = 0.4  -- small outward component
            local dirX = tx * sign * mixT + (normalX or 0) * mixN
            local dirY = ty * sign * mixT + (normalY or 0) * mixN
            local dLen = math.sqrt(dirX * dirX + dirY * dirY)
            if dLen > 0 then
                dirX, dirY = dirX / dLen, dirY / dLen
            else
                -- Fallback: slide straight along the normal
                dirX, dirY = normalX or 1, normalY or 0
            end

            -- Slightly slower than the core dust but live longer
            -- so you can read individual chips skidding away.
            speed = math.random() * 220 + 260   -- ~260 - 480
            life = math.random() * 0.30 + 0.26 -- ~0.26 - 0.56s
            drag = 0.92
            vx = dirX * speed
            vy = dirY * speed
        else
            ------------------------------------------------------
            -- OUTWARD DUST
            -- A tighter cone around the normal to read as a
            -- directional blast away from the impact point.
            ------------------------------------------------------
            local angle
            if hasNormal and baseAngle then
                angle = baseAngle + (math.random() - 0.5) * (halfSpread * 2)
            else
                angle = math.random() * math.pi * 2
            end
            speed = math.random() * 360 + 360   -- ~360 - 720
            life = math.random() * 0.20 + 0.16 -- ~0.16 - 0.36s
            drag = 0.86
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
        end

        ----------------------------------------------------------
        -- Common particle fields for GPU path
        ----------------------------------------------------------
        table.insert(particles.list, {
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            life = life,
            maxLife = life,
            color = {color[1] or 1, color[2] or 1, color[3] or 1},
            size = math.random() * 1.2 + 1.0,
            drag = drag,

            -- GPU rendering metadata
            type = PARTICLE_TYPE_IMPACT,
            seed = math.random(),
        })
    end
end

function particles.spark(x, y, color, count)
    -- Spark particles are meant to look like sharp, fast metal sparks.
    -- Keep the default count modest; callers can override when they need more.
    count = count or 20
    color = color or colors.particleSpark

    for i = 1, count do
        -- Random direction around the contact point
        local angle = math.random() * math.pi * 2

        -- High initial speed so sparks streak out quickly
        local speed = math.random() * 220 + 260 -- ~260 - 480

        -- Very short lifetime so they "flash" and disappear like real sparks
        local life = math.random() * 0.12 + 0.06 -- ~0.06 - 0.18s

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

function particles.draw(cameraScale)
    -- Default camera scale (1.0 = no extra scaling)
    cameraScale = cameraScale or 1.0

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

        -- Scale sprite size by camera zoom so particles stay visually strong
        baseSize = baseSize * cameraScale

        local seed = p.seed or 0.0
        local c = p.color or {1, 1, 1}

        -- VertexUserData: life phase, base size, type id, random seed
        mesh:setVertex(i, p.x, p.y, lifePhase, baseSize, pType, seed, c[1], c[2], c[3])
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
