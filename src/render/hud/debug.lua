local hud_debug = {}

local ui_theme = require("src.core.ui_theme")
local perf = require("src.core.perf")

local smallFont

function hud_debug.draw(player, colors)
    local font = love.graphics.getFont()
    if not smallFont then
        smallFont = love.graphics.newFont(12)
    end

    love.graphics.setFont(smallFont)
    local debugFont = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- FPS (stacked under minimap)
    local fps = love.timer.getFPS()
    local fpsText = "R " .. fps .. " FPS"
    local simUps = perf.getSimUps() or 0
    local upsText = "S " .. tostring(math.floor(simUps + 0.5)) .. " UPS"
    local fpsWidth = math.max(debugFont:getWidth(fpsText), debugFont:getWidth(upsText))
    local fpsColor = ui_theme.debug.fps or colors.uiFps
    love.graphics.setColor(fpsColor[1], fpsColor[2], fpsColor[3], fpsColor[4] or 0.7)

    -- Match minimap layout so FPS can sit directly underneath it
    local panelMarginRight = 12
    local panelMarginTop = 12
    local panelWidth = 200
    local panelHeight = 150

    local panelX = screenW - panelWidth - panelMarginRight
    local panelY = panelMarginTop

    local fpsX = panelX + panelWidth / 2 - fpsWidth / 2
    local fpsY = panelY + panelHeight + 4

    love.graphics.print(fpsText, fpsX, fpsY)
    love.graphics.print(upsText, fpsX, fpsY + debugFont:getHeight() + 2)

    love.graphics.setFont(font)

    -- Controls hint (bottom-left, very subtle)
    local hintColor = ui_theme.debug.hint or {1, 1, 1, 0.3}
    love.graphics.setColor(hintColor[1], hintColor[2], hintColor[3], hintColor[4] or 0.3)
    love.graphics.print("RMB Move | Q/E Abilities", 20, screenH - 30)
end

return hud_debug
