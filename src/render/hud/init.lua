local hud = {}

local hud_ingame = require("src.render.hud.ingame")
local hud_pause = require("src.render.hud.pause")
local hud_gameover = require("src.render.hud.gameover")
local hud_cargo = require("src.render.hud.cargo")
local hud_world_map = require("src.render.hud.world_map")

function hud.drawHUD(player, colors, enemyList, asteroidList)
    -- Pass through the optional enemy / asteroid lists so in-game HUD widgets
    -- (such as the minimap) can render additional context without coupling to
    -- global modules.
    hud_ingame.draw(player, colors, enemyList, asteroidList)
end

-- Full-screen world map overlay (toggled via M). This is drawn from the
-- game_render overlay layer once mapOpen is true.
function hud.drawWorldMap(player, colors, enemyList, asteroidList)
	 hud_world_map.draw(player, colors, enemyList, asteroidList)
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

function hud.pauseMousepressed(menu, x, y, button)
	return hud_pause.mousepressed(menu, x, y, button)
end

function hud.pauseMousereleased(menu, x, y, button)
	return hud_pause.mousereleased(menu, x, y, button)
end

function hud.pauseMousemoved(menu, x, y)
	return hud_pause.mousemoved(menu, x, y)
end

function hud.resetPause()
	return hud_pause.reset()
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

-- World map window mouse handlers (mirror the cargo API so overlays can be
-- managed consistently from the game state).
function hud.mapMousepressed(x, y, button)
    return hud_world_map.mousepressed(x, y, button)
end

function hud.mapMousereleased(x, y, button)
    return hud_world_map.mousereleased(x, y, button)
end

function hud.mapMousemoved(x, y)
    return hud_world_map.mousemoved(x, y)
end

function hud.resetWorldMap()
    return hud_world_map.reset()
end

return hud
