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

    local color = {
        0.45 + math.random() * 0.05,
        0.38 + math.random() * 0.05,
        0.32 + math.random() * 0.05
    }

    local asteroid = {
        size = size,
        complexity = complexity,
        roughness = roughness,
        shape = shape,
        color = color,
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

    local fillR = math.min(1, baseR * 1.15)
    local fillG = math.min(1, baseG * 1.15)
    local fillB = math.min(1, baseB * 1.15)

    love.graphics.setColor(fillR, fillG, fillB, 1)
    love.graphics.polygon("fill", shape.flatPoints)

    -- Crater drawing removed: we intentionally leave craters out for a clean surface

    local outlineR = baseR * 0.22
    local outlineG = baseG * 0.22
    local outlineB = baseB * 0.22

    love.graphics.setColor(outlineR, outlineG, outlineB, 1)
    love.graphics.setLineWidth(2.5)
    love.graphics.polygon("line", shape.flatPoints)
end

return asteroid_generator
