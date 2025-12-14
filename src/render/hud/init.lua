local hud = {}

local hud_ingame = require("src.render.hud.ingame")
local hud_pause = require("src.render.hud.pause")
local hud_death = require("src.render.hud.death")
local hud_cargo = require("src.render.hud.cargo")
local hud_world_map = require("src.render.hud.world_map")
local hud_loot_panel = require("src.render.hud.loot_panel")
local hud_skills = require("src.render.hud.skills")

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

function hud.drawDeath(player, colors)
    hud_death.draw(player, colors)
end

function hud.drawPause(player, colors, menu)
    hud_pause.draw(player, colors, menu)
end

function hud.drawCargo(player, colors)
    hud_cargo.draw(player, colors)
end

function hud.drawSkills(player, colors)
    hud_skills.draw(player, colors)
end

function hud.drawLootPanel(player, colors)
    hud_loot_panel.draw(player, colors)
end

-- NOTE: Mouse handlers and reset functions have been moved to window_manager.lua
-- for centralized routing. Use window_manager.keypressed(), window_manager.mousepressed(),
-- window_manager.mousereleased(), window_manager.mousemoved(), and window_manager.resetWindow()
-- instead of the individual per-window functions.

return hud
