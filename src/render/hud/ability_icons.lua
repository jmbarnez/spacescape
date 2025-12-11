-- Procedural icons for player abilities
local ability_icons = {}

-- Draw a lightning bolt / overcharge icon (attack speed boost)
function ability_icons.drawOvercharge(x, y, size, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.setLineWidth(2)

    local cx, cy = x + size / 2, y + size / 2
    local s = size * 0.35

    -- Bolt shape: 3 connected lines forming a zigzag
    local points = {
        cx - s * 0.2, cy - s,
        cx + s * 0.3, cy - s * 0.1,
        cx - s * 0.1, cy + s * 0.1,
        cx + s * 0.2, cy + s,
    }
    love.graphics.line(points)

    -- Small energy arcs around the bolt
    local arcRadius = s * 0.7
    love.graphics.arc("line", "open", cx, cy, arcRadius, -2.4, -1.8, 8)
    love.graphics.arc("line", "open", cx, cy, arcRadius, 1.2, 1.8, 8)
end

-- Draw a dash / arrow icon (vector dash)
function ability_icons.drawDash(x, y, size, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.setLineWidth(2)

    local cx, cy = x + size / 2, y + size / 2
    local s = size * 0.3

    -- Arrow pointing right
    local tip = cx + s
    local tail = cx - s * 0.8
    love.graphics.line(tail, cy, tip, cy)
    love.graphics.line(tip, cy, tip - s * 0.5, cy - s * 0.5)
    love.graphics.line(tip, cy, tip - s * 0.5, cy + s * 0.5)

    -- Motion lines behind arrow
    love.graphics.setLineWidth(1.5)
    love.graphics.line(tail - s * 0.6, cy - s * 0.3, tail - s * 0.2, cy - s * 0.3)
    love.graphics.line(tail - s * 0.7, cy, tail - s * 0.3, cy)
    love.graphics.line(tail - s * 0.6, cy + s * 0.3, tail - s * 0.2, cy + s * 0.3)
end

-- Registry mapping ability IDs to draw functions
ability_icons.registry = {
    overcharge = ability_icons.drawOvercharge,
    vector_dash = ability_icons.drawDash,
}

-- Draw icon by ability ID
function ability_icons.draw(abilityId, x, y, size, color)
    local fn = ability_icons.registry[abilityId]
    if fn then
        fn(x, y, size, color)
    end
end

return ability_icons
