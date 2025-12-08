local colors = require("src.core.colors")

local engine_trail = {}

-- ###########################################################################
-- Engine trail visual tuning constants
-- These are the primary knobs to tweak the look / feel of the exhaust.
-- ###########################################################################

-- Radius range used to derive the base sprite size for the shader.
-- Slightly larger again so each particle has more visual "body" on screen.
local TRAIL_RADIUS_MIN = 4      -- smallest visual radius near the end of life
local TRAIL_RADIUS_MAX = 10     -- largest visual radius when freshly spawned

-- How many trail points to spawn per emission step while thrusting.
-- Lowered a bit so the trail feels less like a solid fog and more like
-- distinct chunky particles.
local TRAIL_SPAWN_PER_STEP = 4

-- Base visual size used by the shader (in pixels); tuned from the radius range.
-- Slightly bigger to give each particle more thickness without needing as
-- many overlapping neighbors.
local TRAIL_BASE_SIZE = (TRAIL_RADIUS_MIN + TRAIL_RADIUS_MAX) * 2.4

-- Overall brightness multiplier for the shader trail.
-- The shader also applies its own glow/halo, so this should stay moderate.
local TRAIL_INTENSITY = 4.5

engine_trail.points = {}
engine_trail.shader = nil
engine_trail.mesh = nil

-- How frequently we emit a batch of points while thrusting.
-- Slightly slower so the trail is less dense overall.
engine_trail.spawnInterval = 0.012

engine_trail.timeSinceLast = 0

-- Safety cap on the number of live trail points in the mesh.
engine_trail.maxPoints = 700

-- Lifetime (seconds) of each spawned trail point.
-- Slightly shorter so the plume does not stretch too far behind the ship.
engine_trail.trailLifetime = 0.7

engine_trail.time = 0

function engine_trail.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/engine_trail.glsl")
    if ok and shader then
        -- Store the compiled shader so we can use it as the default trail renderer
        engine_trail.shader = shader

        -- GPU-backed point mesh: each vertex carries position + custom user data
        local format = {
            {"VertexPosition", "float", 2},  -- world position
            {"VertexUserData", "float", 4},  -- spawn time, base size, seed, unused
        }

        -- Preallocate a dynamic point mesh for the maximum number of trail points
        engine_trail.mesh = love.graphics.newMesh(format, engine_trail.maxPoints, "points", "dynamic")
    else
        -- If the shader fails to compile, disable GPU trail rendering entirely
        engine_trail.shader = nil
        engine_trail.mesh = nil
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
        -- Offset the spawn position slightly behind the ship based on its size.
        local offset = player.size * 0.9
        local baseDirX = math.cos(player.angle + math.pi)
        local baseDirY = math.sin(player.angle + math.pi)
        local rightX = -baseDirY
        local rightY = baseDirX

        -- Per-particle initial velocity controls how fast the plume drifts away
        -- from the ship. We still allow a cone, but tighten it and reduce
        -- variation so the plume is less smoky and more directional.
        local baseSpeed = 140         -- forward/back drift speed for the exhaust
        local speedJitter = 55        -- random variation around baseSpeed
        local dirJitter = 0.6         -- angular spread; smaller = tighter cone

        for n = 1, TRAIL_SPAWN_PER_STEP do
            -- Lateral offset spreads points across the ship width to avoid a
            -- perfectly razor-thin line, but still keep it fairly tight.
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
                -- Per-particle size variation so the plume feels like a cloud of
                -- distinct cyan particles instead of uniformly sized sprites.
                size = TRAIL_BASE_SIZE * (0.8 + math.random() * 0.5),
                seed = math.random()
            })
        end

        while #engine_trail.points > engine_trail.maxPoints do
            table.remove(engine_trail.points)
        end
    end

    -- Motion tuning: drag pulls velocities down over time, turbulence adds
    -- some curl so particles feel alive, but is toned down so the trail is
    -- less "pluemy" and more of a controlled spray.
    local drag = 0.90
    local turbulenceStrength = 30

    for i = #engine_trail.points, 1, -1 do
        local p = engine_trail.points[i]
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(engine_trail.points, i)
        else

            -- Time-based noise phase for gentle wobble / curl in the exhaust.
            local t = engine_trail.time * 1.1 + p.noiseOffset

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
        -- Upload engine trail points into the GPU mesh for shader-based rendering
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
    -- Do nothing if there is no trail data or the shader path is unavailable
    if #engine_trail.points == 0 or not engine_trail.shader or not engine_trail.mesh then
        return
    end

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    -- Use the GPU shader path as the only rendering mode for the engine trail
    love.graphics.setShader(engine_trail.shader)
    love.graphics.setBlendMode("add", "alphamultiply")

    -- Feed timing + color information into the shader every frame
    engine_trail.shader:send("u_time", engine_trail.time)
    engine_trail.shader:send("u_trailLifetime", engine_trail.trailLifetime)
    engine_trail.shader:send("u_colorMode", 2)
    engine_trail.shader:send("u_colorA", colors.engineTrailA)
    engine_trail.shader:send("u_colorB", colors.engineTrailB)
    engine_trail.shader:send("u_intensity", TRAIL_INTENSITY)

    -- Mesh already has world-space positions; draw as point sprites
    love.graphics.setColor(colors.white)
    love.graphics.draw(engine_trail.mesh)

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
end

return engine_trail