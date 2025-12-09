local mithril = {
    --------------------------------------------------------------------------
    -- Mithril resource definition
    --------------------------------------------------------------------------
    id = "mithril",
    displayName = "Mithril",
    description = "Dense, high-value exotic alloy that amplifies field conduits and weapon cores.",
    rarity = "rare",
    color = {0.86, 0.98, 1.00, 1.0},
    outlineColor = {0.08, 0.24, 0.32, 0.95},
    icon = {
        shape = "crystal",
        radius = 1.15,
    },
}

local function snap(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end

--- Draw the in-world icon for mithril.
function mithril.drawIcon(it, palette, baseRadius, pulse)
    local cx, cy = it.x, it.y
    local icon = mithril.icon or {}

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local col = palette or {}
    local baseColor = mithril.color or col.itemCore or {0.86, 0.98, 1.00, 1.0}
    local outlineColor = mithril.outlineColor or {0.08, 0.24, 0.32, 0.95}

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

    -- Inner core crystal: a smaller, brighter diamond inside the main one to
    -- make mithril feel dense and valuable.
    local coreScale = 0.6
    local cTopX,    cTopY    = cx,            cy - pr * coreScale
    local cRightX,  cRightY  = cx + pr * 0.55, cy
    local cBottomX, cBottomY = cx,            cy + pr * coreScale
    local cLeftX,   cLeftY   = cx - pr * 0.55, cy

    cTopX,    cTopY    = snap(cTopX, 0.5),    snap(cTopY, 0.5)
    cRightX,  cRightY  = snap(cRightX, 0.5),  snap(cRightY, 0.5)
    cBottomX, cBottomY = snap(cBottomX, 0.5), snap(cBottomY, 0.5)
    cLeftX,   cLeftY   = snap(cLeftX, 0.5),   snap(cLeftY, 0.5)

    local coreR = math.min(1.0, baseColor[1] * 1.15)
    local coreG = math.min(1.0, baseColor[2] * 1.15)
    local coreB = math.min(1.0, baseColor[3] * 1.15)
    love.graphics.setColor(coreR, coreG, coreB, 0.96)
    love.graphics.polygon(
        "fill",
        cTopX, cTopY,
        cRightX, cRightY,
        cBottomX, cBottomY,
        cLeftX, cLeftY
    )

    -- Extra diagonal facet catching the light.
    love.graphics.setColor(coreR, coreG, coreB, 0.9)
    love.graphics.setLineWidth(0.9)
    love.graphics.line(cx - pr * 0.35, cy, cx + pr * 0.45, cy + pr * 0.6)
end

return mithril
