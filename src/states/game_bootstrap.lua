local physics = require("src.core.physics")
local world = require("src.core.world")
local camera = require("src.core.camera")

local collisionSystem = require("src.systems.collision")
local spawnSystem = require("src.systems.spawn")
local combatSystem = require("src.systems.combat")
local abilitiesSystem = require("src.systems.abilities")

local playerModule = require("src.entities.player")
local particlesModule = require("src.entities.particles")
local engineTrail = require("src.entities.engine_trail")
local explosionFx = require("src.entities.explosion_fx")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local floatingText = require("src.entities.floating_text")

local starfield = require("src.render.starfield")
local gameRender = require("src.states.game_render")

local updatePipeline = require("src.states.game_update_pipeline")

local game_bootstrap = {}

function game_bootstrap.load(initialSpawn)
	love.window.setTitle("Spacescape")
	math.randomseed(os.time())

	local font = love.graphics.newFont("assets/fonts/Orbitron-Bold.ttf", 16)
	love.graphics.setFont(font)

	physics.init()
	collisionSystem.init()

	playerModule.reset(initialSpawn.x, initialSpawn.y)
	local playerEntity = playerModule.getEntity()

	world.initFromPlayer(playerEntity)
	camera.centerOnEntity(playerEntity)

	starfield.generate()
	spawnSystem.reset()
	combatSystem.reset()
	particlesModule.load()
	engineTrail.load()
	engineTrail.reset()
	explosionFx.load()
	shieldImpactFx.load()
	floatingText.clear()
	abilitiesSystem.load(playerEntity)
	gameRender.load()
	updatePipeline.register()
end

return game_bootstrap
