local hud_debug = {}

local ui_theme = require("src.core.ui_theme")

function hud_debug.draw(player, colors)
    local font = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- FPS (top-right, subtle)
    local fps = love.timer.getFPS()
    local fpsText = fps .. " FPS"
    local fpsWidth = font:getWidth(fpsText)
    local fpsColor = ui_theme.debug.fps or colors.uiFps
    love.graphics.setColor(fpsColor[1], fpsColor[2], fpsColor[3], fpsColor[4] or 0.7)
    love.graphics.print(fpsText, screenW - fpsWidth - 20, 20)

    -- Controls hint (bottom-left, very subtle)
    local hintColor = ui_theme.debug.hint or {1, 1, 1, 0.3}
    love.graphics.setColor(hintColor[1], hintColor[2], hintColor[3], hintColor[4] or 0.3)
    love.graphics.print("RMB Move | Q/E Abilities", 20, screenH - 30)
end

return hud_debug
