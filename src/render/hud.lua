local hud = {}

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

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 5, 5)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player.health .. "/" .. player.maxHealth, barX + 5, barY + 2)

    local fps = love.timer.getFPS()
    local fpsText = "FPS: " .. fps
    local font = love.graphics.getFont()
    local fpsWidth = font:getWidth(fpsText)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print(fpsText, love.graphics.getWidth() - fpsWidth - 20, 20)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("Right-click: Move | Left-click: Shoot", 20, love.graphics.getHeight() - 30)
end

function hud.drawGameOver()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 0.3, 0.3)
    local font = love.graphics.getFont()
    local text = "GAME OVER"
    local textWidth = font:getWidth(text)
    love.graphics.print(text, love.graphics.getWidth() / 2 - textWidth / 2, love.graphics.getHeight() / 2 - 50)

    love.graphics.setColor(0.7, 0.7, 0.7)
    local restartText = "Click to restart"
    local restartWidth = font:getWidth(restartText)
    love.graphics.print(restartText, love.graphics.getWidth() / 2 - restartWidth / 2, love.graphics.getHeight() / 2 + 40)
end

return hud
