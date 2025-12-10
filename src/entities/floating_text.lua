local colors = require("src.core.colors")
local xpTokenIcons = require("src.render.hud.xp_token_icons")

local floating_text = {}

floating_text.list = {}
floating_text.font = nil

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

function floating_text.spawn(text, x, y, color, options)
    options = options or {}

    local stackKey = options.stackKey
    local stackCountIncrement = options.stackCountIncrement or 1
    local stackValueIncrement = options.stackValueIncrement
    local baseText = tostring(text)
    local stackBaseText = options.stackBaseText
    local iconPreset = options.iconPreset

    if stackKey then
        for i = #floating_text.list, 1, -1 do
            local f = floating_text.list[i]
            if f.stackKey == stackKey then
                if stackValueIncrement ~= nil then
                    f.stackValue = (f.stackValue or 0) + stackValueIncrement
                    local labelText = stackBaseText or f.baseText or baseText
                    local value = f.stackValue
                    if value and value > 0 then
                        f.text = labelText .. " x" .. value
                    else
                        f.text = labelText
                    end
                else
                    f.stackCount = (f.stackCount or 1) + stackCountIncrement
                    f.baseText = f.baseText or f.text or baseText

                    if f.stackCount > 1 then
                        f.text = f.baseText .. " x" .. f.stackCount
                    else
                        f.text = f.baseText
                    end
                end

                f.t = 0
                if options.duration then
                    f.life = options.duration
                end

                return
            end
        end
    end

    local life = options.duration or 1.2
    local riseSpeed = options.riseSpeed or 25
    local vx = options.vx or 0
    local vy = options.vy or -riseSpeed
    local scale = options.scale or 0.8
    local alphaStart = options.alpha or 1
    local bgColor = options.bgColor or colors.floatingBg
    local textColor = options.textColor or colors.floatingText

    local offsetX = (math.random() - 0.5) * 80
    local offsetY = (math.random() - 0.5) * 60

    if stackKey and stackValueIncrement ~= nil then
        local labelText = stackBaseText or baseText
        local value = stackValueIncrement
        local initialText
        if value and value > 0 then
            initialText = labelText .. " x" .. value
        else
            initialText = labelText
        end

        table.insert(floating_text.list, {
            text = initialText,
            x = x + offsetX,
            y = y + offsetY,
            vx = vx,
            vy = vy,
            t = 0,
            life = life,
            alphaStart = alphaStart,
            scale = scale,
            bgColor = bgColor,
            textColor = textColor,
            stackKey = stackKey,
            stackCount = nil,
            stackValue = value,
            baseText = labelText,
            iconPreset = iconPreset,
        })
    else
        table.insert(floating_text.list, {
            text = baseText,
            x = x + offsetX,
            y = y + offsetY,
            vx = vx,
            vy = vy,
            t = 0,
            life = life,
            alphaStart = alphaStart,
            scale = scale,
            bgColor = bgColor,
            textColor = textColor,
            stackKey = stackKey,
            stackCount = stackKey and stackCountIncrement or nil,
            baseText = baseText,
            iconPreset = iconPreset,
        })
    end
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

function floating_text.update(dt)
    for i = #floating_text.list, 1, -1 do
        local f = floating_text.list[i]

        f.t = f.t + dt
        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt

        if f.t >= f.life then
            table.remove(floating_text.list, i)
        end
    end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function floating_text.draw()
    if #floating_text.list == 0 then
        return
    end

    if not floating_text.font then
        floating_text.font = love.graphics.newFont("assets/fonts/Orbitron-Bold.ttf", 16)
    end

    local prevFont = love.graphics.getFont()
    love.graphics.setFont(floating_text.font)

    local font = floating_text.font

    for _, f in ipairs(floating_text.list) do
        local progress = math.min(math.max(f.t / f.life, 0), 1)
        local alpha = (1 - progress) * f.alphaStart
        
        -- Measure text at desired scale so we can center it around (x, y)
        local text = f.text
        local scale = f.scale
        local w = font:getWidth(text) * scale
        local h = font:getHeight() * scale

        local baseX = f.x
        local baseY = f.y

        if f.iconPreset == "xp_only" or f.iconPreset == "token_only" or f.iconPreset == "xp_token" then
            local iconRadius = 5 * scale
            local margin = 6 * scale
            local iconCenterY = baseY

            if f.iconPreset == "xp_only" then
                local xpCenterX = baseX - w / 2 - margin - iconRadius
                xpTokenIcons.drawXpIcon(xpCenterX, iconCenterY, iconRadius, alpha)
            elseif f.iconPreset == "token_only" then
                local tokenCenterX = baseX - w / 2 - margin - iconRadius
                xpTokenIcons.drawTokenIcon(tokenCenterX, iconCenterY, iconRadius, alpha)
            elseif f.iconPreset == "xp_token" then
                local xpCenterX = baseX - w / 2 - margin - iconRadius
                local tokenCenterX = baseX + w / 2 + margin + iconRadius
                xpTokenIcons.drawXpIcon(xpCenterX, iconCenterY, iconRadius, alpha)
                xpTokenIcons.drawTokenIcon(tokenCenterX, iconCenterY, iconRadius, alpha)
            end
        end

        local tc = f.textColor
        love.graphics.setColor(tc[1], tc[2], tc[3], alpha)
        love.graphics.print(text, baseX - w / 2, baseY - h / 2, 0, scale, scale)
    end

    love.graphics.setFont(prevFont)
    love.graphics.setColor(colors.white)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function floating_text.clear()
    floating_text.list = {}
end

return floating_text
