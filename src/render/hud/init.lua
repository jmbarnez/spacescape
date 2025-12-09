local hud = {}

local hud_ingame = require("src.render.hud.ingame")
local hud_pause = require("src.render.hud.pause")
local hud_gameover = require("src.render.hud.gameover")
local hud_cargo = require("src.render.hud.cargo")

function hud.drawHUD(player, colors, enemyList, asteroidList)
    -- Pass through the optional enemy / asteroid lists so in-game HUD widgets
    -- (such as the minimap) can render additional context without coupling to
    -- global modules.
    hud_ingame.draw(player, colors, enemyList, asteroidList)
end

function hud.drawGameOver(player)
    hud_gameover.draw(player)
end

function hud.drawPause(player, colors, menu)
    hud_pause.draw(player, colors, menu)
end

function hud.hitTestPauseMenu(menu, mx, my)
    return hud_pause.hitTestPauseMenu(menu, mx, my)
end

function hud.drawCargo(player, colors)
    hud_cargo.draw(player, colors)
end

-- Cargo window mouse handlers
function hud.cargoMousepressed(x, y, button)
    return hud_cargo.mousepressed(x, y, button)
end

function hud.cargoMousereleased(x, y, button)
    return hud_cargo.mousereleased(x, y, button)
end

function hud.cargoMousemoved(x, y)
    return hud_cargo.mousemoved(x, y)
end

function hud.resetCargo()
    return hud_cargo.reset()
end

return hud
