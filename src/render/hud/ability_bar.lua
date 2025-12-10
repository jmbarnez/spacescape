local hud_ability_bar = {}

local abilitiesSystem = require("src.systems.abilities")
local ui_theme = require("src.core.ui_theme")

function hud_ability_bar.draw(player, colors)
    local font = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Ability slots (centered bottom)
    local abilities = abilitiesSystem.getUiState()
    if #abilities > 0 then
        local size = 40
        local spacing = 8
        local totalWidth = #abilities * size + (#abilities - 1) * spacing
        local startX = (screenW - totalWidth) / 2
        local y = screenH - size - 50

        local abilityStyle = ui_theme.abilityBar

        for i, a in ipairs(abilities) do
            local x = startX + (i - 1) * (size + spacing)

            -- Slot background
            love.graphics.setColor(
                abilityStyle.slotBackground[1],
                abilityStyle.slotBackground[2],
                abilityStyle.slotBackground[3],
                abilityStyle.slotBackground[4]
            )
            love.graphics.rectangle("fill", x, y, size, size, 6, 6)

            -- Border
            if a.active then
                love.graphics.setColor(
                    colors.uiAbilityActive[1],
                    colors.uiAbilityActive[2],
                    colors.uiAbilityActive[3],
                    0.95
                )
            else
                love.graphics.setColor(
                    abilityStyle.slotBorderInactive[1],
                    abilityStyle.slotBorderInactive[2],
                    abilityStyle.slotBorderInactive[3],
                    abilityStyle.slotBorderInactive[4]
                )
            end
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", x, y, size, size, 6, 6)

            -- Key label
            love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.8)
            local label = string.upper(a.key or "?")
            local labelW = font:getWidth(label)
            love.graphics.print(label, x + size / 2 - labelW / 2, y + size / 2 - font:getHeight() / 2)

            -- Cooldown overlay
            if a.cooldownMax and a.cooldownMax > 0 and a.cooldown > 0 then
                local ratio = a.cooldown / a.cooldownMax
                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.rectangle("fill", x, y, size, size * ratio, 6, 6)

                local cdText = string.format("%.1f", a.cooldown)
                local cdW = font:getWidth(cdText)
                love.graphics.setColor(colors.uiCooldownText[1], colors.uiCooldownText[2], colors.uiCooldownText[3], 0.95)
                love.graphics.print(cdText, x + size / 2 - cdW / 2, y + size / 2 - font:getHeight() / 2)
            end
        end
    end
end

return hud_ability_bar
