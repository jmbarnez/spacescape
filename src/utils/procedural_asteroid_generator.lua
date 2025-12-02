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

    local craterCount = math.floor(1 + complexity * 3)
    local craters = {}
    for i = 1, craterCount do
        local r = size * (0.08 + math.random() * 0.1)
        local cx = (math.random() - 0.5) * size * 0.8
        local cy = (math.random() - 0.5) * size * 0.8
        table.insert(craters, {
            x = cx,
            y = cy,
            radius = r
        })
    end

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
        color = color
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

    love.graphics.setColor(baseR, baseG, baseB, 1)
    love.graphics.polygon("fill", shape.flatPoints)

    if shape.craters then
        for _, c in ipairs(shape.craters) do
            love.graphics.setColor(baseR * 0.5, baseG * 0.5, baseB * 0.5, 1)
            love.graphics.circle("fill", c.x, c.y, c.radius)
            love.graphics.setColor(baseR * 0.8, baseG * 0.8, baseB * 0.8, 1)
            love.graphics.circle("line", c.x, c.y, c.radius)
        end
    end

    love.graphics.setColor(baseR * 0.3, baseG * 0.3, baseB * 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", shape.flatPoints)
end

return asteroid_generator
