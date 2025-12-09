local ice = {
    --------------------------------------------------------------------------
    -- Ice resource definition
    --------------------------------------------------------------------------
    id = "ice",
    displayName = "Ice",
    description = "Volatile ices and frozen gases prized for fuel and life support.",
    rarity = "common",
    color = {0.78, 0.86, 0.96, 1.0},
    outlineColor = {0.10, 0.16, 0.26, 0.9},
    icon = {
        shape = "chunk",   -- Softer, more rounded silhouette than stone
        radius = 1.05,
        segments = 6,
        jaggedness = 0.20,
    },
}

local function snap(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end

--- Draw the in-world icon for ice.
function ice.drawIcon(it, palette, baseRadius, pulse)
    local cx, cy = it.x, it.y
    local icon = ice.icon or {}

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local col = palette or {}
    local baseColor = ice.color or col.itemCore or {0.78, 0.86, 0.96, 1.0}
    local outlineColor = ice.outlineColor or {0.10, 0.16, 0.26, 0.9}

    local segments = icon.segments or 6
    local jaggedness = icon.jaggedness or 0.20

    local points = {}
    local age = it.age or 0
    local spin = 0.3 * age

    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2 + spin
        local noise = 1 + math.sin(i * 2.7 + age * 2.1) * jaggedness
        local pr = r * (0.75 + 0.25 * noise)

        local px = cx + math.cos(angle) * pr
        local py = cy + math.sin(angle) * pr

        px = snap(px, 0.5)
        py = snap(py, 0.5)

        points[#points + 1] = px
        points[#points + 1] = py
    end

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.0)
    love.graphics.polygon("fill", points)

    -- Softer inner ice body to give a sense of translucency.
    local innerPoints = {}
    for i = 1, #points, 2 do
        local px, py = points[i], points[i + 1]
        local ix = cx + (px - cx) * 0.75
        local iy = cy + (py - cy) * 0.75

        ix = snap(ix, 0.5)
        iy = snap(iy, 0.5)

        innerPoints[#innerPoints + 1] = ix
        innerPoints[#innerPoints + 1] = iy
    end

    local innerR = math.min(1.0, baseColor[1] * 1.05)
    local innerG = math.min(1.0, baseColor[2] * 1.05)
    local innerB = math.min(1.0, baseColor[3] * 1.05)
    love.graphics.setColor(innerR, innerG, innerB, (baseColor[4] or 1.0) * 0.95)
    love.graphics.polygon("fill", innerPoints)

    -- Crisp outline to keep the silhouette strong.
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", points)

    -- Subtle inner facet line running across the body.
    love.graphics.setColor(baseColor[1] * 1.10, baseColor[2] * 1.10, baseColor[3] * 1.10, 0.9)
    love.graphics.setLineWidth(1.0)
    love.graphics.line(cx, cy - r * 0.4, cx + r * 0.3, cy + r * 0.5)

    -- Frosty specular highlight near the top-left edge.
    local hx = snap(cx - r * 0.35, 0.5)
    local hy = snap(cy - r * 0.35, 0.5)
    local hr = r * 0.22
    love.graphics.setColor(innerR, innerG, innerB, 0.85)
    love.graphics.circle("fill", hx, hy, hr)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setLineWidth(0.8)
    love.graphics.circle("line", hx, hy, hr)
end

return ice
