local hud_ability_bar = {}

local abilitiesSystem = require("src.systems.abilities")
local ui_theme = require("src.core.ui_theme")
local combatSystem = require("src.systems.combat")
local ability_icons = require("src.render.hud.ability_icons")

function hud_ability_bar.draw(player, colors)
    local font = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local abilities = abilitiesSystem.getUiState()
    if #abilities > 0 then
        local size = 44
        local spacing = 12
        local keyLabelHeight = 18
        local totalHeight = size + keyLabelHeight
        local totalWidth = #abilities * size + (#abilities - 1) * spacing
        local startX = (screenW - totalWidth) / 2
        local y = screenH - totalHeight - 40

        local abilityStyle = ui_theme.abilityBar

        -- Primary weapon cooldown bar
        local weaponProgress, weaponRemaining, weaponInterval = combatSystem.getWeaponCooldownState(player)
        if weaponInterval and weaponInterval > 0 and weaponRemaining then
            local idleFadeWindow = 1.2
            if weaponRemaining <= -idleFadeWindow then goto skip_weapon_bar end

            local barHeight = 5
            local barPadding = 8
            local barX = startX
            local barY = y - barHeight - barPadding
            local barW = totalWidth
            local fadeAlpha = 0.9

            if weaponRemaining <= 0 then
                local idleAge = -weaponRemaining
                fadeAlpha = 0.9 * (1.0 - math.min(idleAge / idleFadeWindow, 1))
            end

            if fadeAlpha > 0 then
                local bg = colors.uiCooldownBg or { 0, 0, 0, 0.6 }
                love.graphics.setColor(bg[1], bg[2], bg[3], bg[4] * fadeAlpha)
                love.graphics.rectangle("fill", barX, barY, barW, barHeight, 2, 2)

                local clampedProgress = math.max(0, math.min(weaponProgress or 0, 1))
                local fillW = math.floor(barW * clampedProgress + 0.5)
                if fillW > 0 then
                    local ac = colors.uiAbilityActive or { 0.3, 0.8, 1.0, 1.0 }
                    love.graphics.setColor(ac[1], ac[2], ac[3], ac[4] * fadeAlpha)
                    love.graphics.rectangle("fill", barX, barY, fillW, barHeight, 2, 2)
                end
            end
        end
        ::skip_weapon_bar::

        for i, a in ipairs(abilities) do
            local x = startX + (i - 1) * (size + spacing)

            -- Glow effect when ability is active
            if a.active then
                local glowColor = colors.uiAbilityActive or { 0.3, 0.8, 1.0, 1.0 }
                local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
                love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.3 * pulse)
                love.graphics.rectangle("fill", x - 4, y - 4, size + 8, size + 8, 8, 8)
            end

            -- Slot background
            love.graphics.setColor(
                abilityStyle.slotBackground[1],
                abilityStyle.slotBackground[2],
                abilityStyle.slotBackground[3],
                abilityStyle.slotBackground[4]
            )
            love.graphics.rectangle("fill", x, y, size, size, 6, 6)

            -- Border
            local borderColor = a.active and colors.uiAbilityActive or abilityStyle.slotBorderInactive
            love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], a.active and 0.95 or borderColor[4])
            love.graphics.setLineWidth(a.active and 2 or 1.5)
            love.graphics.rectangle("line", x, y, size, size, 6, 6)

            -- Draw ability icon
            local iconColor = a.active and colors.uiAbilityActive or { 0.7, 0.85, 0.95, 0.9 }
            if a.cooldown and a.cooldown > 0 then
                iconColor = { 0.4, 0.45, 0.5, 0.6 }
            end
            ability_icons.draw(a.id, x, y, size, iconColor)

            -- Cooldown overlay
            if a.cooldownMax and a.cooldownMax > 0 and a.cooldown > 0 then
                local ratio = a.cooldown / a.cooldownMax
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("fill", x, y, size, size * ratio, 6, 6)

                local cdText = string.format("%.1f", a.cooldown)
                local cdW = font:getWidth(cdText)
                love.graphics.setColor(colors.uiCooldownText[1], colors.uiCooldownText[2], colors.uiCooldownText[3], 0.95)
                love.graphics.print(cdText, x + size / 2 - cdW / 2, y + size / 2 - font:getHeight() / 2)
            end

            -- Key label below slot
            local label = string.upper(a.key or "?")
            local labelW = font:getWidth(label)
            local labelX = x + size / 2 - labelW / 2
            local labelY = y + size + 4

            -- Key label background pill
            local pillW = labelW + 12
            local pillH = font:getHeight() + 4
            local pillX = x + size / 2 - pillW / 2
            local pillY = labelY - 2
            love.graphics.setColor(0.07, 0.07, 0.07, 0.9)
            love.graphics.rectangle("fill", pillX, pillY, pillW, pillH, 4, 4)
            love.graphics.setColor(0.50, 0.50, 0.50, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", pillX, pillY, pillW, pillH, 4, 4)

            -- Key label text
            love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
            love.graphics.print(label, labelX, labelY)
        end
    end
end

return hud_ability_bar
