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
    local baseX = 24
    local baseY = 24
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

    -- Draw level number
    local levelText = tostring(level)
    local levelTextWidth = font:getWidth(levelText)
    local levelTextHeight = font:getHeight()

    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
    love.graphics.print(levelText, levelCenterX - levelTextWidth / 2, levelCenterY - levelTextHeight / 2)

    -- Draw XP ring background
    local outerRadius = ringRadius
    local innerRadius = ringRadius - ringThickness

    love.graphics.setLineWidth(2)
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.2)
    love.graphics.circle("line", levelCenterX, levelCenterY, outerRadius, 48)
    love.graphics.circle("line", levelCenterX, levelCenterY, innerRadius, 48)

    -- Draw XP ring fill
    if expRatio > 0 then
        local startAngle = -math.pi / 2
        local gapAngle = math.rad(8)
        local fullSpan = (2 * math.pi) - gapAngle
        local endAngle = startAngle + fullSpan * expRatio
        local segments = math.max(8, math.floor(48 * expRatio))
        local vertices = {}

        for i = 0, segments do
            local angle = startAngle + (endAngle - startAngle) * (i / segments)
            table.insert(vertices, levelCenterX + math.cos(angle) * outerRadius)
            table.insert(vertices, levelCenterY + math.sin(angle) * outerRadius)
        end

        for i = segments, 0, -1 do
            local angle = startAngle + (endAngle - startAngle) * (i / segments)
            table.insert(vertices, levelCenterX + math.cos(angle) * innerRadius)
            table.insert(vertices, levelCenterY + math.sin(angle) * innerRadius)
        end

        love.graphics.setColor(colors.health[1], colors.health[2], colors.health[3], 0.95)
        love.graphics.polygon("fill", vertices)
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
end

return hud_status
