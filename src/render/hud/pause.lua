local hud_pause = {}

function hud_pause.draw(player, colors, menu)
    local font = love.graphics.getFont()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, w, h)

    if not colors then
        return
    end

    love.graphics.setColor(colors.uiGameOverText)
    local title = "PAUSED"
    local titleWidth = font:getWidth(title)
    local titleHeight = font:getHeight()
    love.graphics.print(title, w / 2 - titleWidth / 2, h / 2 - titleHeight - 30)

    local baseY = h / 2
    local spacing = 26

    if menu and menu.items then
        for i, item in ipairs(menu.items) do
            local label = item.label
            local itemWidth = font:getWidth(label)
            local itemHeight = font:getHeight()
            local x = w / 2 - itemWidth / 2
            local y = baseY + (i - 1) * spacing

            local rectX = x - 16
            local rectY = y - 4
            local rectW = itemWidth + 32
            local rectH = itemHeight + 8

            local hovered = mx >= rectX and mx <= rectX + rectW and my >= rectY and my <= rectY + rectH

            if hovered then
                love.graphics.setColor(0, 0, 0, 0.7)
            else
                love.graphics.setColor(0, 0, 0, 0.5)
            end
            love.graphics.rectangle("fill", rectX, rectY, rectW, rectH, 4, 4)

            if hovered then
                love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.7)
                love.graphics.rectangle("line", rectX - 2, rectY - 2, rectW + 4, rectH + 4, 5, 5)
                love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
            else
                love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.95)
            end
            love.graphics.print(label, x, y)
        end
    end

    love.graphics.setColor(colors.uiGameOverSubText)
    local hint = "Esc: Resume  |  Click a button"
    local hintWidth = font:getWidth(hint)
    love.graphics.print(hint, w / 2 - hintWidth / 2, baseY + spacing * 3.5)
end

function hud_pause.hitTestPauseMenu(menu, mx, my)
    if not menu or not menu.items then
        return nil
    end

    local font = love.graphics.getFont()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local baseY = h / 2
    local spacing = 26

    for i, item in ipairs(menu.items) do
        local label = item.label
        local itemWidth = font:getWidth(label)
        local itemHeight = font:getHeight()
        local x = w / 2 - itemWidth / 2
        local y = baseY + (i - 1) * spacing

        local rectX = x - 16
        local rectY = y - 4
        local rectW = itemWidth + 32
        local rectH = itemHeight + 8

        if mx >= rectX and mx <= rectX + rectW and my >= rectY and my <= rectY + rectH then
            return i, item
        end
    end

    return nil
end

return hud_pause
