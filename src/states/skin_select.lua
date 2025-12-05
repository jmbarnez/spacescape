local skins = require("src.core.skins")
local state_machine = require("src.core.state_machine")
local starfield = require("src.render.starfield")
local playerModule = require("src.entities.player")

local skin_select = {}

local selectedIndex = 1

local function getSkins()
    return skins.getList()
end

function skin_select.load()
    starfield.generate()
end

function skin_select.update(dt)
    starfield.update(dt, 0, 0)
end

function skin_select.draw()
    starfield.draw()

    local list = getSkins()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- Panel
    love.graphics.setColor(0, 0, 0, 0.6)
    local panelW = w * 0.55
    local panelH = h * 0.6
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)

    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    local title = "CHOOSE DRONE SKIN"
    local font = love.graphics.getFont()
    local tw = font and font:getWidth(title) or 0
    love.graphics.print(title, panelX + (panelW - tw) / 2, panelY + 20)

    -- Skins list with small previews
    local itemY = panelY + 70
    local itemSpacing = 70

    for i, skin in ipairs(list) do
        local isSelected = (i == selectedIndex)
        local c = skin.colors
        local centerX = panelX + panelW * 0.25
        local centerY = itemY + (i - 1) * itemSpacing

        -- Preview: draw the actual drone design at reduced size
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        playerModule.renderDrone(c, 16)
        love.graphics.pop()

        -- Name and label
        if isSelected then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.8, 0.8, 0.8, 0.9)
        end
        local nameText = skin.name
        love.graphics.print(nameText, centerX + 40, centerY - 10)
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1, 0.9)
    local hint = "Use UP/DOWN to choose, ENTER to launch"
    local hw = font and font:getWidth(hint) or 0
    love.graphics.print(hint, panelX + (panelW - hw) / 2, panelY + panelH - 40)
end

function skin_select.keypressed(key)
    local list = getSkins()
    if key == "down" or key == "s" then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #list then
            selectedIndex = 1
        end
    elseif key == "up" or key == "w" then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then
            selectedIndex = #list
        end
    elseif key == "return" or key == "space" then
        local chosen = list[selectedIndex]
        skins.setCurrent(chosen.id)
        state_machine.change("game")
    elseif key == "escape" then
        love.event.quit()
    end
end

function skin_select.mousepressed(x, y, button)
    if button ~= 1 then return end
    local list = getSkins()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    local panelW = w * 0.55
    local panelH = h * 0.6
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    local itemY = panelY + 70
    local itemSpacing = 70

    for i, _ in ipairs(list) do
        local cy = itemY + (i - 1) * itemSpacing
        local hitX1 = panelX
        local hitX2 = panelX + panelW
        local hitY1 = cy - 25
        local hitY2 = cy + 25
        if x >= hitX1 and x <= hitX2 and y >= hitY1 and y <= hitY2 then
            selectedIndex = i
            break
        end
    end
end

function skin_select.resize(w, h)
    starfield.generate()
end

return skin_select
