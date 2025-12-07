local hud = {}

local abilitiesSystem = require("src.systems.abilities")

function hud.drawHUD(player, colors)

    local panelX = 24
    local panelY = 20
    local panelWidth = 280
    local panelHeight = 120

    local level = player.level or 1
    local hull = player.hull or player.health or 0
    local maxHull = player.maxHull or player.maxHealth or hull
    local shield = player.shield or 0
    local maxShield = player.maxShield or shield

    if maxHull <= 0 then
        maxHull = 1
    end
    if maxShield <= 0 then
        maxShield = 1
    end

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", panelX + 3, panelY + 5, panelWidth, panelHeight, 12, 12)

    love.graphics.setColor(colors.uiAbilitySlotBg)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 12, 12)

    love.graphics.setColor(colors.uiPanelBorder)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", panelX + 0.5, panelY + 0.5, panelWidth - 1, panelHeight - 1, 12, 12)

    local font = love.graphics.getFont()

    local ringCenterX = panelX + 60
    local ringCenterY = panelY + panelHeight / 2
    local outerRadius = 26
    local innerRadius = 20

    love.graphics.setColor(colors.healthBg[1], colors.healthBg[2], colors.healthBg[3], 0.8)
    love.graphics.circle("fill", ringCenterX, ringCenterY, outerRadius)

    love.graphics.setColor(colors.uiPanelBorder[1], colors.uiPanelBorder[2], colors.uiPanelBorder[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", ringCenterX, ringCenterY, outerRadius)

    love.graphics.setColor(colors.projectile[1], colors.projectile[2], colors.projectile[3], 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", ringCenterX, ringCenterY, innerRadius)

    local levelValue = string.format("%02d", level)
    local levelWidth = font:getWidth(levelValue)
    local levelHeight = font:getHeight()

    love.graphics.push()
    love.graphics.translate(ringCenterX, ringCenterY)
    local levelScale = 1.6
    love.graphics.scale(levelScale, levelScale)
    love.graphics.setColor(colors.uiText)
    love.graphics.print(levelValue, -levelWidth / 2, -levelHeight / 2)
    love.graphics.pop()

    local rightPadding = 18
    local rightX = panelX + panelWidth - rightPadding
    local contentLeftX = ringCenterX + outerRadius + 24

    local dividerY = panelY + 30
    love.graphics.setColor(colors.uiPanelBorder[1], colors.uiPanelBorder[2], colors.uiPanelBorder[3], 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.line(contentLeftX, dividerY, rightX, dividerY)

    local barWidth = rightX - contentLeftX
    local barHeight = 14
    local hullY = dividerY + 12
    local shieldY = hullY + barHeight + 12

    love.graphics.setColor(colors.healthBg[1], colors.healthBg[2], colors.healthBg[3], 0.65)
    love.graphics.rectangle("fill", contentLeftX, hullY, barWidth, barHeight, 8, 8)
    local hullRatio = math.max(0, math.min(1, hull / maxHull))
    love.graphics.setColor(colors.damagePlayer)
    love.graphics.rectangle("fill", contentLeftX, hullY, barWidth * hullRatio, barHeight, 8, 8)

    love.graphics.setColor(colors.healthBg[1], colors.healthBg[2], colors.healthBg[3], 0.55)
    love.graphics.rectangle("fill", contentLeftX, shieldY, barWidth, barHeight, 8, 8)
    local shieldRatio = math.max(0, math.min(1, shield / maxShield))
    love.graphics.setColor(colors.projectile[1], colors.projectile[2], colors.projectile[3], 0.9)
    love.graphics.rectangle("fill", contentLeftX, shieldY, barWidth * shieldRatio, barHeight, 8, 8)
    love.graphics.setColor(colors.uiPanelBorder[1], colors.uiPanelBorder[2], colors.uiPanelBorder[3], 0.9)
    love.graphics.rectangle("line", contentLeftX, shieldY, barWidth, barHeight, 8, 8)

    local fps = love.timer.getFPS()
    local fpsText = "FPS: " .. fps
    local fpsWidth = font:getWidth(fpsText)
    love.graphics.setColor(colors.uiFps)
    love.graphics.print(fpsText, love.graphics.getWidth() - fpsWidth - 20, 20)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("Right-click: Move | Q/E: Abilities", 20, love.graphics.getHeight() - 30)

    local abilities = abilitiesSystem.getUiState()
    if #abilities > 0 then
        local size = 40
        local spacing = 10
        local totalWidth = #abilities * size + (#abilities - 1) * spacing
        local startX = (love.graphics.getWidth() - totalWidth) / 2
        local y = love.graphics.getHeight() - size - 20

        for i, a in ipairs(abilities) do
            local x = startX + (i - 1) * (size + spacing)

            love.graphics.setColor(colors.uiAbilitySlotBg)
            love.graphics.rectangle("fill", x, y, size, size, 4, 4)

            if a.active then
                love.graphics.setColor(colors.uiAbilityActive)
            else
                love.graphics.setColor(colors.uiAbilityInactive)
            end
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, size, size, 4, 4)

            love.graphics.setColor(colors.uiText)
            local label = string.upper(a.key or "?")
            love.graphics.print(label, x + 12, y + 10)

            if a.cooldownMax and a.cooldownMax > 0 and a.cooldown > 0 then
                local ratio = a.cooldown / a.cooldownMax
                local h = size * ratio
                love.graphics.setColor(colors.uiCooldownBg)
                love.graphics.rectangle("fill", x, y, size, h)

                local cdText = tostring(math.ceil(a.cooldown))
                local cdFont = love.graphics.getFont()
                local w = cdFont:getWidth(cdText)
                love.graphics.setColor(colors.uiCooldownText)
                love.graphics.print(cdText, x + size / 2 - w / 2, y + size / 2 - 8)
            end
        end
    end
end

function hud.drawGameOver(player)
    love.graphics.setColor(colors.uiGameOverBg)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(colors.uiGameOverText)
    local font = love.graphics.getFont()
    local text = "GAME OVER"
    local textWidth = font:getWidth(text)
    love.graphics.print(text, love.graphics.getWidth() / 2 - textWidth / 2, love.graphics.getHeight() / 2 - 50)

    love.graphics.setColor(colors.uiGameOverSubText)
    local restartText = "Click to restart"
    local restartWidth = font:getWidth(restartText)
    love.graphics.print(restartText, love.graphics.getWidth() / 2 - restartWidth / 2, love.graphics.getHeight() / 2 + 40)
end

return hud
