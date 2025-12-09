local item_icons = {}

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

-- Small utility to optionally snap coordinates to a coarse grid. This can
-- help procedural shapes feel a bit more "pixel" without using textures.
local function snap(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end

--------------------------------------------------------------------------------
-- PER-RESOURCE DRAWERS
-- Each resource type gets its own dedicated drawer so designs stay highly
-- customizable in this single file.
--------------------------------------------------------------------------------

-- Draw a chunky stone shard. Assumes light from top-left.
local function drawStonePickup(it, def, palette, baseRadius, pulse)
    local cx, cy = it.x, it.y
    local icon = def.icon or {}

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local col = palette or {}
    local baseColor = def.color or col.itemCore or {0.55, 0.50, 0.44, 1.0}
    local outlineColor = def.outlineColor or {0.05, 0.05, 0.05, 0.9}

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

    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", points)
end

-- Draw a cooler, smoother ice shard.
local function drawIcePickup(it, def, palette, baseRadius, pulse)
    local cx, cy = it.x, it.y
    local icon = def.icon or {}

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local col = palette or {}
    local baseColor = def.color or col.itemCore or {0.78, 0.86, 0.96, 1.0}
    local outlineColor = def.outlineColor or {0.10, 0.16, 0.26, 0.9}

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

    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", points)

    -- Subtle inner facet line
    love.graphics.setColor(baseColor[1] * 1.1, baseColor[2] * 1.1, baseColor[3] * 1.1, 0.9)
    love.graphics.setLineWidth(1.0)
    love.graphics.line(cx, cy - r * 0.4, cx + r * 0.3, cy + r * 0.5)
end

-- Draw a tall faceted crystal for mithril.
local function drawMithrilPickup(it, def, palette, baseRadius, pulse)
    local cx, cy = it.x, it.y
    local icon = def.icon or {}

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local col = palette or {}
    local baseColor = def.color or col.itemCore or {0.86, 0.98, 1.00, 1.0}
    local outlineColor = def.outlineColor or {0.08, 0.24, 0.32, 0.95}

    local pr = r * (1.0 + 0.05 * pulse)

    local topX, topY = cx, cy - pr
    local rightX, rightY = cx + pr * 0.75, cy
    local bottomX, bottomY = cx, cy + pr * 1.10
    local leftX, leftY = cx - pr * 0.75, cy

    topX, topY = snap(topX, 0.5), snap(topY, 0.5)
    rightX, rightY = snap(rightX, 0.5), snap(rightY, 0.5)
    bottomX, bottomY = snap(bottomX, 0.5), snap(bottomY, 0.5)
    leftX, leftY = snap(leftX, 0.5), snap(leftY, 0.5)

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.0)
    love.graphics.polygon(
        "fill",
        topX, topY,
        rightX, rightY,
        bottomX, bottomY,
        leftX, leftY
    )

    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon(
        "line",
        topX, topY,
        rightX, rightY,
        bottomX, bottomY,
        leftX, leftY
    )

    love.graphics.setColor(baseColor[1] * 1.2, baseColor[2] * 1.2, baseColor[3] * 1.2, 0.95)
    love.graphics.setLineWidth(1.0)
    love.graphics.line(cx, cy - pr * 0.5, cx, cy + pr * 0.7)
end

-- Generic chunk/crystal fallback for any future resources that do not yet
-- have a dedicated drawer above.
local function drawGenericResource(it, def, palette, baseRadius, pulse)
    local icon = def.icon or {}
    local cx, cy = it.x, it.y

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local col = palette or {}
    local baseColor = def.color or col.itemCore or {0.3, 1.0, 0.7, 1.0}
    local outlineColor = def.outlineColor or {0.0, 0.0, 0.0, 0.85}

    local shape = icon.shape or "chunk"

    if shape == "crystal" then
        return drawMithrilPickup(it, def, palette, baseRadius, pulse)
    end

    local segments = icon.segments or 7
    local jaggedness = icon.jaggedness or 0.35

    local points = {}
    local age = it.age or 0
    local spin = 0.4 * age

    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2 + spin
        local noise = 1 + math.sin(i * 2.3 + age * 2.7) * jaggedness
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

    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.9)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", points)
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

-- Simple orb fallback (used for legacy XP items or unknown types).
function item_icons.drawSimpleOrb(it, palette, baseRadius, pulse)
    local col = palette or {}
    local coreColor = col.itemCore or {0.3, 1.0, 0.7, 1.0}

    local r = baseRadius * (0.9 + 0.2 * pulse)

    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], coreColor[4] or 1.0)
    love.graphics.circle("fill", it.x, it.y, r)

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.setLineWidth(1.4)
    love.graphics.circle("line", it.x, it.y, r + 0.4)
end

-- Main entry point for resource pickups. Chooses a specific drawer based on
-- the resource id, so each material can have a bespoke procedural design.
function item_icons.drawResource(it, def, palette, baseRadius, pulse)
    -- Prefer a per-resource custom icon drawer if one is provided on the
    -- definition table. This lets each resource live in its own file and own
    -- 100% of its procedural design.
    if def then
        local drawer = def.drawIcon or def.drawPickup
        if type(drawer) == "function" then
            drawer(it, palette, baseRadius, pulse)
            return
        end
    end

    -- Fallback: use the generic chunk/crystal renderer driven purely by the
    -- data fields on the resource definition.
    drawGenericResource(it, def or {}, palette, baseRadius, pulse)
end

return item_icons
