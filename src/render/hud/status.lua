local hud_status = {}

local config = require("src.core.config")
local ui_theme = require("src.core.ui_theme")

function hud_status.draw(player, colors)
    local font = love.graphics.getFont()
    local hudPanelStyle = ui_theme.hudPanel

    -- Player stats
    local level = player.level or 1
    local hull = player.hull or player.health or 0
    local maxHull = player.maxHull or player.maxHealth or hull
    local shield = player.shield or 0
    local maxShield = player.maxShield or shield
    local expRatio = math.max(0, math.min(1, player.expRatio or player.xpRatio or 0))

    if maxHull <= 0 then maxHull = 1 end
    if maxShield <= 0 then maxShield = 1 end

    -- Layout constants
    local baseX = 40
    local baseY = 48
    local barWidth = 200
    local barHeight = 10
    local barSpacing = 6
    local ringRadius = 24
    local ringThickness = 5

    -- Level ring position
    local levelCenterX = baseX + ringRadius
    -- Center ring vertically between the two bars
    local barsCenterY = baseY + barHeight + barSpacing / 2
    local levelCenterY = barsCenterY

    local contentLeft = baseX
    local contentRight = levelCenterX + ringRadius + 16 + barWidth
    local contentTop = levelCenterY - ringRadius
    -- Extend the content bottom to leave space for the XP/currency block below the bars.
    local contentBottom = levelCenterY + ringRadius + 22
    local panelPaddingX = 12
    local panelPaddingY = 12
    local panelX = contentLeft - panelPaddingX
    local panelY = contentTop - panelPaddingY
    local panelWidth = (contentRight - contentLeft) + panelPaddingX * 2
    local panelHeight = (contentBottom - contentTop) + panelPaddingY * 2

    love.graphics.setColor(
        hudPanelStyle.background[1],
        hudPanelStyle.background[2],
        hudPanelStyle.background[3],
        hudPanelStyle.background[4]
    )
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)

    local borderColor = hudPanelStyle.border or colors.uiPanelBorder or {1, 1, 1, 0.6}
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8, 8)

    -- Draw level number
    local levelText = tostring(level)
    local levelTextWidth = font:getWidth(levelText)
    local levelTextHeight = font:getHeight()

    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
    love.graphics.print(levelText, levelCenterX - levelTextWidth / 2, levelCenterY - levelTextHeight / 2)

    -- Draw XP ring as a circular bar.
    -- The faint full ring is the track, and the colored arc is the current XP.
    local trackRadius = ringRadius - ringThickness / 2

    -- Background track: full circle so player sees the total XP path.
    love.graphics.setLineWidth(ringThickness)
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.2)
    love.graphics.circle("line", levelCenterX, levelCenterY, trackRadius, 48)

    -- Foreground XP progress: only the bar (arc) around the ring represents current XP.
    if expRatio > 0 then
        -- Extra clamp safeguard before drawing.
        expRatio = math.max(0, math.min(1, expRatio))

        -- Start at the top of the circle and sweep clockwise based on XP ratio.
        local startAngle = -math.pi / 2
        local endAngle = startAngle + (2 * math.pi) * expRatio
        local segments = math.max(16, math.floor(64 * expRatio))

        local vertices = {}
        for i = 0, segments do
            local t = i / segments
            local angle = startAngle + (endAngle - startAngle) * t
            table.insert(vertices, levelCenterX + math.cos(angle) * trackRadius)
            table.insert(vertices, levelCenterY + math.sin(angle) * trackRadius)
        end

        love.graphics.setColor(colors.health[1], colors.health[2], colors.health[3], 0.95)
        love.graphics.setLineWidth(ringThickness)
        love.graphics.line(vertices)
    end

    -- Bars start position (right of level ring)
    local barsX = levelCenterX + ringRadius + 16
    local barsY = baseY

    -- Hull bar
    local hullRatio = math.max(0, math.min(1, hull / maxHull))

    love.graphics.setColor(
        hudPanelStyle.barBackground[1],
        hudPanelStyle.barBackground[2],
        hudPanelStyle.barBackground[3],
        hudPanelStyle.barBackground[4]
    )
    love.graphics.rectangle("fill", barsX, barsY, barWidth, barHeight, 4, 4)

    love.graphics.setColor(colors.damagePlayer[1], colors.damagePlayer[2], colors.damagePlayer[3], 0.9)
    love.graphics.rectangle("fill", barsX, barsY, barWidth * hullRatio, barHeight, 4, 4)
    love.graphics.setLineWidth(3)
    -- Match the shield bar with a clean black outline so both bars share the
    -- same high-contrast frame.
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("line", barsX, barsY, barWidth, barHeight, 4, 4)

    -- Shield bar
    local shieldBarY = barsY + barHeight + barSpacing
    local shieldRatio = math.max(0, math.min(1, shield / maxShield))

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", barsX, shieldBarY, barWidth, barHeight, 4, 4)

    love.graphics.setColor(colors.projectile[1], colors.projectile[2], colors.projectile[3], 0.8)
    love.graphics.rectangle("fill", barsX, shieldBarY, barWidth * shieldRatio, barHeight, 4, 4)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("line", barsX, shieldBarY, barWidth, barHeight, 4, 4)

    ------------------------------------------------------------------------
    -- XP and Currency counters (below the bars, inside the status panel)
    ------------------------------------------------------------------------
    local infoBaseY = shieldBarY + barHeight + 6

    -- Lifetime XP
    local totalXp = math.max(0, math.floor(player.totalXp or 0))
    -- Generic currency/token placeholder
    local totalCurrency = math.max(0, math.floor(player.currency or player.credits or 0))

    local iconRadius = 5

    -- XP icon position (aligned with left edge of bars)
    local xpIconCenterX = barsX + iconRadius
    local xpIconCenterY = infoBaseY + font:getHeight() * 0.5

    -- XP core orb
    love.graphics.setColor(0.2, 1.0, 0.4, 1.0)
    love.graphics.circle("fill", xpIconCenterX, xpIconCenterY, iconRadius, 24)

    -- XP highlight
    love.graphics.setColor(0.8, 1.0, 0.8, 0.85)
    love.graphics.circle("fill", xpIconCenterX - iconRadius * 0.35, xpIconCenterY - iconRadius * 0.25, iconRadius * 0.4, 16)

    -- XP outline
    love.graphics.setColor(0.0, 0.25, 0.0, 0.9)
    love.graphics.setLineWidth(1.2)
    love.graphics.circle("line", xpIconCenterX, xpIconCenterY, iconRadius + 0.5, 24)

    -- XP text
    local xpText = string.format("%d", totalXp)
    local xpTextX = xpIconCenterX + iconRadius + 6
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
    love.graphics.print(xpText, xpTextX, infoBaseY)

    -- Currency token position (to the right of XP)
    local xpTextWidth = font:getWidth(xpText)
    local tokenSpacing = 12
    local tokenCenterX = xpTextX + xpTextWidth + tokenSpacing + iconRadius
    local tokenCenterY = xpIconCenterY

    -- Token base (hexagonal coin shape)
    local hexPoints = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 2
        hexPoints[#hexPoints + 1] = tokenCenterX + math.cos(angle) * iconRadius
        hexPoints[#hexPoints + 1] = tokenCenterY + math.sin(angle) * iconRadius
    end

    -- Token shadow/depth
    love.graphics.setColor(0.6, 0.45, 0.1, 0.9)
    love.graphics.polygon("fill", hexPoints)

    -- Token face (slightly smaller, offset for 3D effect)
    local innerHexPoints = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 2
        innerHexPoints[#innerHexPoints + 1] = tokenCenterX + math.cos(angle) * (iconRadius * 0.85) - 0.5
        innerHexPoints[#innerHexPoints + 1] = tokenCenterY + math.sin(angle) * (iconRadius * 0.85) - 0.5
    end
    love.graphics.setColor(1.0, 0.85, 0.3, 1.0)
    love.graphics.polygon("fill", innerHexPoints)

    -- Inner emblem (star/diamond shape)
    local emblemSize = iconRadius * 0.45
    love.graphics.setColor(0.9, 0.65, 0.1, 0.9)
    love.graphics.polygon("fill",
        tokenCenterX, tokenCenterY - emblemSize,
        tokenCenterX + emblemSize * 0.6, tokenCenterY,
        tokenCenterX, tokenCenterY + emblemSize,
        tokenCenterX - emblemSize * 0.6, tokenCenterY
    )

    -- Highlight
    love.graphics.setColor(1.0, 1.0, 0.9, 0.7)
    love.graphics.circle("fill", tokenCenterX - iconRadius * 0.25, tokenCenterY - iconRadius * 0.3, iconRadius * 0.25, 12)

    -- Token outline
    love.graphics.setColor(0.45, 0.3, 0.05, 1.0)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", hexPoints)

    -- Currency text
    local currencyText = string.format("%d", totalCurrency)
    local currencyTextX = tokenCenterX + iconRadius + 6
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
    love.graphics.print(currencyText, currencyTextX, infoBaseY)
end

return hud_status
