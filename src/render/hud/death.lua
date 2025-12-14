local hud_death = {}

function hud_death.draw(player, colors)
    local palette = colors or require("src.core.colors")

    love.graphics.setColor(palette.uiGameOverBg)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(palette.uiGameOverText)
    local font = love.graphics.getFont()
    local text = "YOU DIED"
    local textWidth = font:getWidth(text)
    love.graphics.print(text, love.graphics.getWidth() / 2 - textWidth / 2, love.graphics.getHeight() / 2 - 50)

    love.graphics.setColor(palette.uiGameOverSubText)
    local hintText = "Click to respawn  |  Esc to quit"
    local hintWidth = font:getWidth(hintText)
    love.graphics.print(hintText, love.graphics.getWidth() / 2 - hintWidth / 2, love.graphics.getHeight() / 2 + 40)
end

return hud_death
