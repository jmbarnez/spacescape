local hud_gameover = {}

function hud_gameover.draw(player)
    local colors = require("src.core.colors")

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

return hud_gameover
