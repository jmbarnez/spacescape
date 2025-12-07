local hud = {}

local hud_ingame = require("src.render.hud.ingame")
local hud_pause = require("src.render.hud.pause")
local hud_gameover = require("src.render.hud.gameover")

function hud.drawHUD(player, colors)
    hud_ingame.draw(player, colors)
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

return hud
