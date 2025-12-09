local stone = {
    --------------------------------------------------------------------------
    -- Stone resource definition
    --------------------------------------------------------------------------
    id = "stone",
    displayName = "Stone",
    description = "Common asteroid rock used as a basic structural material and trade good.",
    rarity = "common",
    -- Base tint used by procedural item rendering.
    color = {0.55, 0.50, 0.44, 1.0},
    outlineColor = {0.05, 0.05, 0.05, 0.9},
    -- Icon hints: kept for generic fallback code, but the primary design lives
    -- in drawIcon below.
    icon = {
        shape = "chunk",
        radius = 1.0,
        segments = 7,
        jaggedness = 0.35,
    },
}

-- Small utility to optionally snap coordinates to a coarse grid. This can
-- help procedural shapes feel a bit more "pixel" without using textures.
local function snap(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end

--- Draw the in-world icon for stone.
-- @param it table Item instance (position, age, etc.)
-- @param palette table Global colors table (src.core.colors)
-- @param baseRadius number Base item radius from config
-- @param pulse number 0..1 pulse amount based on age
function stone.drawIcon(it, palette, baseRadius, pulse)
    local cx, cy = it.x, it.y
    local icon = stone.icon or {}

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local col = palette or {}
    local baseColor = stone.color or col.itemCore or {0.55, 0.50, 0.44, 1.0}
    local outlineColor = stone.outlineColor or {0.05, 0.05, 0.05, 0.9}

    local segments = icon.segments or 7
    local jaggedness = icon.jaggedness or 0.35

    local points = {}
    local age = it.age or 0
    local spin = 0.4 * age

    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2 + spin
        local noise = 1 + math.sin(i * 2.1 + age * 3.0) * jaggedness
        local pr = r * (0.7 + 0.3 * noise)

        local px = cx + math.cos(angle) * pr
        local py = cy + math.sin(angle) * pr

        px = snap(px, 0.5)
        py = snap(py, 0.5)

        points[#points + 1] = px
        points[#points + 1] = py
    end

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.0)
    love.graphics.polygon("fill", points)

    -- Slightly lighter inner polygon to suggest a faceted rock interior.
    local innerPoints = {}
    for i = 1, #points, 2 do
        local px, py = points[i], points[i + 1]
        local ix = cx + (px - cx) * 0.7
        local iy = cy + (py - cy) * 0.7

        ix = snap(ix, 0.5)
        iy = snap(iy, 0.5)

        innerPoints[#innerPoints + 1] = ix
        innerPoints[#innerPoints + 1] = iy
    end

    local highlightR = math.min(1.0, baseColor[1] * 1.06)
    local highlightG = math.min(1.0, baseColor[2] * 1.06)
    local highlightB = math.min(1.0, baseColor[3] * 1.06)
    love.graphics.setColor(highlightR, highlightG, highlightB, baseColor[4] or 1.0)
    love.graphics.polygon("fill", innerPoints)

    -- Hairline chips for extra texture. These are very short segments just
    -- inside a few vertices so the shard feels chipped without long rays.
    local crackR = baseColor[1] * 0.45
    local crackG = baseColor[2] * 0.45
    local crackB = baseColor[3] * 0.45
    love.graphics.setColor(crackR, crackG, crackB, 0.95)
    love.graphics.setLineWidth(1.0)
    for i = 1, #points - 3, 6 do
        local sx, sy = points[i], points[i + 1]
        -- Short segment pointing a bit toward the centre.
        local dx = cx - sx
        local dy = cy - sy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            dx = dx / len
            dy = dy / len
            local seg = r * 0.18
            local ex = sx + dx * seg
            local ey = sy + dy * seg

            ex = snap(ex, 0.5)
            ey = snap(ey, 0.5)

            love.graphics.line(sx, sy, ex, ey)
        end
    end

    -- Final dark outline keeps the shard readable over bright backgrounds.
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", points)
end

return stone
