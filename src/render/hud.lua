local hud = {}

local abilitiesSystem = require("src.systems.abilities")

function hud.drawHUD(player, colors)
    local barWidth = 200
    local barHeight = 20
    local barX = 20
    local barY = 20

    love.graphics.setColor(colors.healthBg)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 5, 5)

    local healthWidth = (player.health / player.maxHealth) * barWidth
    love.graphics.setColor(colors.health)
    love.graphics.rectangle("fill", barX, barY, healthWidth, barHeight, 5, 5)

    love.graphics.setColor(colors.uiPanelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 5, 5)

    love.graphics.setColor(colors.uiText)
    love.graphics.print("HP: " .. player.health .. "/" .. player.maxHealth, barX + 5, barY + 2)

    local fps = love.timer.getFPS()
    local fpsText = "FPS: " .. fps
    local font = love.graphics.getFont()
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
                local font = love.graphics.getFont()
                local w = font:getWidth(cdText)
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
