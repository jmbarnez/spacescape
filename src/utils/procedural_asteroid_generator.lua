local asteroid_generator = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function flattenPoints(points)
    local flat = {}
    if not points then
        return flat
    end
    for i = 1, #points do
        local p = points[i]
        flat[#flat + 1] = p[1]
        flat[#flat + 1] = p[2]
    end
    return flat
end

local function computeBoundingRadius(points)
    local radius = 0
    if not points then
        return radius
    end
    for i = 1, #points do
        local p = points[i]
        local x, y = p[1], p[2]
        local d = math.sqrt(x * x + y * y)
        if d > radius then
            radius = d
        end
    end
    return radius
end

-------------------------------------------------------------------------------
-- Material definitions for realistic asteroid looks
--
-- These are intentionally subtle and grounded (no neon sci-fi colors). Each
-- material has a base color range; shading and veins are derived at draw
-- time so we can keep the generator simple and fast.
-------------------------------------------------------------------------------

local MATERIAL_TYPES = {"carbonaceous", "silicate", "metallic", "icy", "crystalline"}

local MATERIAL_COLOR_RANGES = {
    -- Dark, slightly bluish/neutral carbon-rich rock
    carbonaceous = {
        r = {0.18, 0.26},
        g = {0.18, 0.25},
        b = {0.20, 0.28},
    },
    -- Warmer silicate rock (common stony asteroids)
    silicate = {
        r = {0.42, 0.52},
        g = {0.34, 0.44},
        b = {0.30, 0.38},
    },
    -- Cooler high-contrast metallic surfaces
    metallic = {
        r = {0.50, 0.62},
        g = {0.50, 0.60},
        b = {0.52, 0.65},
    },
    -- Icy / volatile-rich bodies (slightly brighter, cooler tones)
    icy = {
        r = {0.60, 0.72},
        g = {0.66, 0.78},
        b = {0.74, 0.86},
    },
    -- Rock with embedded crystalline veins (neutral base, veins colored later)
    crystalline = {
        r = {0.40, 0.50},
        g = {0.38, 0.46},
        b = {0.46, 0.56},
    },
}

function asteroid_generator.generate(size, options)
    options = options or {}
    size = size or 30

    local complexity = options.complexity or (0.4 + math.random() * 0.6)
    local segments = 10 + math.floor(complexity * 10)
    local roughness = options.roughness or (0.6 + math.random() * 0.4)

    local points = {}
    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2
        local noise = 1 + (math.random() - 0.5) * roughness
        local r = size * lerp(0.8, 1.2, noise)
        local x = math.cos(angle) * r
        local y = math.sin(angle) * r
        table.insert(points, {x, y})
    end

    -- Craters disabled per request: keep table empty so downstream logic stays stable
    local craters = {}

    local shape = {
        points = points,
        flatPoints = flattenPoints(points),
        craters = craters,
        boundingRadius = computeBoundingRadius(points)
    }

    -- Pick a material first so we can later tie visual style and HUD flavor
    -- text together. If an explicit material is requested, honor it.
    local material = options.material
    if not material then
        material = MATERIAL_TYPES[math.random(1, #MATERIAL_TYPES)]
    end

    local range = MATERIAL_COLOR_RANGES[material] or MATERIAL_COLOR_RANGES.silicate
    local rRange, gRange, bRange = range.r, range.g, range.b

    local color = {
        (rRange[1] or 0.45) + math.random() * ((rRange[2] or rRange[1] or 0.45) - (rRange[1] or 0.45)),
        (gRange[1] or 0.38) + math.random() * ((gRange[2] or gRange[1] or 0.38) - (gRange[1] or 0.38)),
        (bRange[1] or 0.32) + math.random() * ((bRange[2] or bRange[1] or 0.32) - (bRange[1] or 0.32)),
    }

    local asteroid = {
        size = size,
        complexity = complexity,
        roughness = roughness,
        shape = shape,
        color = color,
        material = material,
        seed = math.random() * 1000
    }

    return asteroid
end

function asteroid_generator.draw(asteroid)
    if not asteroid or not asteroid.shape or not asteroid.shape.points then
        return
    end

    local shape = asteroid.shape
    local c = asteroid.color
    local baseR, baseG, baseB
    if c then
        baseR, baseG, baseB = c[1], c[2], c[3]
    else
        baseR, baseG, baseB = 0.45, 0.38, 0.32
    end

    ------------------------------------------------------------------------
    -- BASE FILL
    -- Slightly brighten the base color for the main body so shadows and veins
    -- have room to push darker/lighter on top.
    ------------------------------------------------------------------------
    local fillR = math.min(1, baseR * 1.12)
    local fillG = math.min(1, baseG * 1.12)
    local fillB = math.min(1, baseB * 1.12)

    love.graphics.setColor(fillR, fillG, fillB, 1)
    love.graphics.polygon("fill", shape.flatPoints)

    -- Crater drawing intentionally left disabled for this project; we keep a
    -- clean, solid body and rely on the outline for separation from the
    -- background.

    ------------------------------------------------------------------------
    -- OUTLINE / RIM
    ------------------------------------------------------------------------
    local outlineR = baseR * 0.20
    local outlineG = baseG * 0.20
    local outlineB = baseB * 0.20

    love.graphics.setColor(outlineR, outlineG, outlineB, 0.95)
    love.graphics.setLineWidth(2.5)
    love.graphics.polygon("line", shape.flatPoints)
end

return asteroid_generator
