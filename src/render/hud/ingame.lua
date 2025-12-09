local hud_ingame = {}

local hud_status = require("src.render.hud.status")
local hud_debug = require("src.render.hud.debug")
local hud_ability_bar = require("src.render.hud.ability_bar")
local hud_target_panel = require("src.render.hud.target_panel")
local hud_minimap = require("src.render.hud.minimap")

function hud_ingame.draw(player, colors)
    hud_status.draw(player, colors)
    hud_debug.draw(player, colors)
    hud_minimap.draw(player, colors)
    hud_ability_bar.draw(player, colors)
    -- Draw target information panel (top-center) showing data about the
    -- currently locked/selected enemy or asteroid.
    hud_target_panel.draw(colors)
end

return hud_ingame
