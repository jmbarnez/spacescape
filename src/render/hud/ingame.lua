local hud_ingame = {}

local hud_status = require("src.render.hud.status")
local hud_debug = require("src.render.hud.debug")
local hud_ability_bar = require("src.render.hud.ability_bar")

function hud_ingame.draw(player, colors)
    hud_status.draw(player, colors)
    hud_debug.draw(player, colors)
    hud_ability_bar.draw(player, colors)
end

return hud_ingame
