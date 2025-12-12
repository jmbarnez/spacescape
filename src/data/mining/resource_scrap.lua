local scrap = {
    --------------------------------------------------------------------------
    -- Scrap resource definition
    --
    -- This is the salvage material that drops from destroyed ships / wrecks.
    -- It needs a proper resource definition so the same icon renderer
    -- (src.render.item_icons) can draw it consistently in-world and in the HUD.
    --------------------------------------------------------------------------
    id = "scrap",
    displayName = "Scrap",
    description = "Twisted ship plating and components recovered from wrecks.",
    rarity = "common",
    color = { 0.6, 0.55, 0.5, 1.0 },
    outlineColor = { 0.25, 0.22, 0.18, 0.95 },
    icon = {
        shape = "plate",
        radius = 1.0,
    },
}

--- Draw the in-world icon for scrap.
--
-- We intentionally match the simple "scrap" HUD icon so the material looks
-- identical whether it is floating in space, shown in the loot panel, or
-- stored in the cargo grid.
function scrap.drawIcon(it, _palette, baseRadius, _pulse)
    local cx, cy = it.x, it.y
    local icon = scrap.icon or {}

    local radiusScale = icon.radius or 1.0
    local r = baseRadius * radiusScale

    local c = scrap.color
    local o = scrap.outlineColor

    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1.0)
    love.graphics.rectangle("fill", cx - r * 0.9, cy - r * 0.45, r * 1.8, r * 0.9, 2, 2)

    love.graphics.setColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 0.85)
    love.graphics.setLineWidth(1.0)
    love.graphics.line(cx - r * 0.35, cy - r * 0.45, cx - r * 0.35, cy + r * 0.45)
    love.graphics.line(cx + r * 0.35, cy - r * 0.45, cx + r * 0.35, cy + r * 0.45)

    love.graphics.setColor(o[1], o[2], o[3], o[4] or 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", cx - r * 0.9, cy - r * 0.45, r * 1.8, r * 0.9, 2, 2)
end

return scrap
