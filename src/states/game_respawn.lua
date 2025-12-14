local playerModule = require("src.entities.player")
local world = require("src.core.world")
local camera = require("src.core.camera")
local windowManager = require("src.render.hud.window_manager")

local combatSystem = require("src.systems.combat")
local abilitiesSystem = require("src.systems.abilities")
local engineTrail = require("src.entities.engine_trail")

local game_respawn = {}

function game_respawn.respawn(initialSpawn)
	playerModule.reset(initialSpawn.x, initialSpawn.y)
	local playerEntity = playerModule.getEntity()
	world.initFromPlayer(playerEntity)
	camera.centerOnEntity(playerEntity)

	combatSystem.reset()
	abilitiesSystem.reset(playerEntity)
	engineTrail.reset()

	windowManager.setWindowOpen("cargo", false)
	windowManager.setWindowOpen("map", false)
end

return game_respawn
