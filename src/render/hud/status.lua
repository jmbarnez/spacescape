local hud_status = {}

local config = require("src.core.config")

function hud_status.draw(player, colors)
    local font = love.graphics.getFont()

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
    local contentBottom = levelCenterY + ringRadius
    local panelPaddingX = 12
    local panelPaddingY = 12
    local panelX = contentLeft - panelPaddingX
    local panelY = contentTop - panelPaddingY
    local panelWidth = (contentRight - contentLeft) + panelPaddingX * 2
    local panelHeight = (contentBottom - contentTop) + panelPaddingY * 2

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)

    local borderColor = colors.uiPanelBorder or {1, 1, 1, 0.6}
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

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", barsX, barsY, barWidth, barHeight, 4, 4)

    love.graphics.setColor(colors.damagePlayer[1], colors.damagePlayer[2], colors.damagePlayer[3], 0.9)
    love.graphics.rectangle("fill", barsX, barsY, barWidth * hullRatio, barHeight, 4, 4)
    love.graphics.setLineWidth(3)
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
    -- Ship + total XP metadata block (bottom of the status panel)
    --
    -- This small text block makes the new player/ship separation visible in
    -- game: it shows which ship the player is currently piloting and how
    -- much total XP they have earned during this run.
    ------------------------------------------------------------------------
    local infoBaseY = shieldBarY + barHeight + 6

    -- Resolve a friendly ship name from the owned ship layout if present.
    local shipName = nil
    if player.ship and player.ship.metadata and player.ship.metadata.displayName then
        shipName = player.ship.metadata.displayName
    elseif player.ship and player.ship.id then
        shipName = tostring(player.ship.id)
    else
        shipName = "Player Ship"
    end

    -- Lifetime XP is tracked on player.totalXp; clamp and floor for display so
    -- the number stays clean and readable.
    local totalXp = math.max(0, math.floor(player.totalXp or 0))

    local shipText = "Ship: " .. shipName
    local xpText = string.format("Total XP: %d", totalXp)

    -- Draw ship name in primary UI text color, then total XP slightly dimmer
    -- so the most important label (the ship) stands out first.
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
    love.graphics.print(shipText, barsX, infoBaseY)

    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.75)
    love.graphics.print(xpText, barsX, infoBaseY + font:getHeight())
end

return hud_status
