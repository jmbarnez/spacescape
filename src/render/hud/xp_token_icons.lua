local xp_token_icons = {}

function xp_token_icons.drawXpIcon(centerX, centerY, iconRadius, alpha)
    alpha = alpha or 1.0
    love.graphics.setColor(0.2, 1.0, 0.4, 1.0 * alpha)
    love.graphics.circle("fill", centerX, centerY, iconRadius, 24)
    love.graphics.setColor(0.8, 1.0, 0.8, 0.85 * alpha)
    love.graphics.circle("fill", centerX - iconRadius * 0.35, centerY - iconRadius * 0.25, iconRadius * 0.4, 16)
    love.graphics.setColor(0.0, 0.25, 0.0, 0.9 * alpha)
    love.graphics.setLineWidth(1.2)
    love.graphics.circle("line", centerX, centerY, iconRadius + 0.5, 24)
end

local function buildHexPoints(centerX, centerY, radius)
    local points = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 2
        points[#points + 1] = centerX + math.cos(angle) * radius
        points[#points + 1] = centerY + math.sin(angle) * radius
    end
    return points
end

function xp_token_icons.drawTokenIcon(centerX, centerY, iconRadius, alpha)
    alpha = alpha or 1.0
    local hexPoints = buildHexPoints(centerX, centerY, iconRadius)
    love.graphics.setColor(0.6, 0.45, 0.1, 0.9 * alpha)
    love.graphics.polygon("fill", hexPoints)
    local innerRadius = iconRadius * 0.85
    local innerHexPoints = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 2
        innerHexPoints[#innerHexPoints + 1] = centerX + math.cos(angle) * innerRadius - 0.5
        innerHexPoints[#innerHexPoints + 1] = centerY + math.sin(angle) * innerRadius - 0.5
    end
    love.graphics.setColor(1.0, 0.85, 0.3, 1.0 * alpha)
    love.graphics.polygon("fill", innerHexPoints)
    local emblemSize = iconRadius * 0.45
    love.graphics.setColor(0.9, 0.65, 0.1, 0.9 * alpha)
    love.graphics.polygon("fill",
        centerX, centerY - emblemSize,
        centerX + emblemSize * 0.6, centerY,
        centerX, centerY + emblemSize,
        centerX - emblemSize * 0.6, centerY
    )
    love.graphics.setColor(1.0, 1.0, 0.9, 0.7 * alpha)
    love.graphics.circle("fill", centerX - iconRadius * 0.25, centerY - iconRadius * 0.3, iconRadius * 0.25, 12)
    love.graphics.setColor(0.45, 0.3, 0.05, 1.0 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", hexPoints)
end

return xp_token_icons
