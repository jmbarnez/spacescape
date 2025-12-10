local hud_ability_bar = {}

local abilitiesSystem = require("src.systems.abilities")
local ui_theme = require("src.core.ui_theme")
local combatSystem = require("src.systems.combat")

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

        -- --------------------------------------------------------------------
        -- Primary weapon cooldown bar
        -- --------------------------------------------------------------------
        -- Query the combat system for the current primary weapon cooldown so we
        -- can present it as a slim bar directly above the ability buttons.
        --
        --   progress 0..1 : how "ready" the weapon is (0 = just fired,
        --                    1 = fully ready / off cooldown)
        --   remaining      : seconds remaining, not used directly here but
        --                    useful if you ever want numeric text
        --   interval       : total cooldown duration in seconds
        local weaponProgress, weaponRemaining, weaponInterval = combatSystem.getWeaponCooldownState(player)

        -- Draw the bar while the weapon is cooling down, and for a short time
        -- *after* it has become ready so we can gently fade it out when the
        -- player is idle (not attacking).
        if weaponInterval and weaponInterval > 0 and weaponRemaining then
            -- How long the bar should linger after the weapon becomes ready
            -- before disappearing completely. This uses the "time since ready"
            -- (negative remaining) from combat.getWeaponCooldownState().
            local idleFadeWindow = 1.2

            -- If the weapon has been ready for longer than the idle fade
            -- window, we hide the bar entirely.
            if weaponRemaining <= -idleFadeWindow then
                -- Too long since last shot & weapon has been ready for a while:
                -- nothing to draw.
                goto skip_weapon_bar
            end

            local barHeight = 6
            local barPadding = 6
            local barX = startX
            local barY = y - barHeight - barPadding
            local barW = totalWidth

            -- Base alpha range for the bar; we will use the remaining/idle
            -- time to interpolate within this range.
            local minAlpha = 0.0
            local maxAlpha = 0.9
            local fadeAlpha = maxAlpha

            if weaponRemaining > 0 then
                -- Still on cooldown: keep the bar fully visible so the player
                -- can track the cooldown clearly.
                fadeAlpha = maxAlpha
            else
                -- Weapon is ready, but we are within the idle fade window.
                -- Convert remaining (negative) to "time since ready" and fade
                -- alpha down to 0 over idleFadeWindow seconds.
                local idleAge = -weaponRemaining
                local t = math.max(0, math.min(idleAge / idleFadeWindow, 1))
                fadeAlpha = maxAlpha * (1.0 - t)
            end

            if fadeAlpha > 0 then
                -- Background track for the cooldown / readiness bar
                local bg = colors.uiCooldownBg or {0, 0, 0, 0.6}
                local bgAlpha = (bg[4] or 0.6) * fadeAlpha
                love.graphics.setColor(bg[1], bg[2], bg[3], bgAlpha)
                love.graphics.rectangle("fill", barX, barY, barW, barHeight, 3, 3)

                -- Filled portion representing how close the weapon is to being
                -- ready. The bar grows from left (just fired) to right (ready).
                local clampedProgress = math.max(0, math.min(weaponProgress or 0, 1))
                local fillW = math.floor(barW * clampedProgress + 0.5)

                if fillW > 0 then
                    local ac = colors.uiAbilityActive or {0.3, 0.8, 1.0, 1.0}
                    local fillAlpha = (ac[4] or 0.9) * fadeAlpha
                    love.graphics.setColor(ac[1], ac[2], ac[3], fillAlpha)
                    love.graphics.rectangle("fill", barX, barY, fillW, barHeight, 3, 3)
                end

                -- Tiny numeric cooldown text centered on the bar. We clamp the
                -- displayed time at 0 so it never shows as negative; once the
                -- weapon is ready the text smoothly approaches 0.0s while the
                -- bar fades out.
                local displayRemaining = math.max(0, weaponRemaining)
                local cdText = string.format("%.1fs", displayRemaining)
            local textScale = 0.7
            local textW = font:getWidth(cdText) * textScale
            local textH = font:getHeight() * textScale
            local textX = barX + barW / 2 - textW / 2
            local textY = barY + barHeight / 2 - textH / 2

            local tc = colors.uiCooldownText or {1, 1, 1, 1}
            local textAlpha = (tc[4] or 1.0) * fadeAlpha
            love.graphics.setColor(tc[1], tc[2], tc[3], textAlpha)

            love.graphics.push()
            love.graphics.translate(textX, textY)
            love.graphics.scale(textScale, textScale)
            love.graphics.print(cdText, 0, 0)
            love.graphics.pop()
            end
        end

        ::skip_weapon_bar::

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
