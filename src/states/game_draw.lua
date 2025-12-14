local playerModule = require("src.entities.player")
local particlesModule = require("src.entities.particles")
local projectileShards = require("src.entities.projectile_shards")
local starfield = require("src.render.starfield")
local engineTrail = require("src.entities.engine_trail")
local explosionFx = require("src.entities.explosion_fx")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local floatingText = require("src.entities.floating_text")

local ui = require("src.render.hud")
local windowManager = require("src.render.hud.window_manager")
local gameRender = require("src.states.game_render")
local colors = require("src.core.colors")

local combatSystem = require("src.systems.combat")

local gameQueries = require("src.states.game_queries")

local game_draw = {}

function game_draw.draw(gameState, pauseMenu, camera)
	starfield.draw()

	local renderCtx = {
		camera = camera,
		ui = ui,
		player = playerModule.getEntity(),
		playerModule = playerModule,

		projectileShards = projectileShards,
		enemyList = gameQueries.getEnemyEntities(),
		engineTrail = engineTrail,
		particlesModule = particlesModule,
		explosionFx = explosionFx,
		shieldImpactFx = shieldImpactFx,
		floatingText = floatingText,
		colors = colors,
		gameState = gameState,
		combatSystem = combatSystem,
		pauseMenu = pauseMenu,
	}

	gameRender.draw(renderCtx)
end

return game_draw
