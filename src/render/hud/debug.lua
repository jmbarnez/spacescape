local hud_debug = {}

function hud_debug.draw(player, colors)
    local font = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- FPS (top-right, subtle)
    local fps = love.timer.getFPS()
    local fpsText = fps .. " FPS"
    local fpsWidth = font:getWidth(fpsText)
    love.graphics.setColor(colors.uiFps[1], colors.uiFps[2], colors.uiFps[3], 0.5)
    love.graphics.print(fpsText, screenW - fpsWidth - 20, 20)

    -- Controls hint (bottom-left, very subtle)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.print("RMB Move | Q/E Abilities", 20, screenH - 30)
end

return hud_debug
