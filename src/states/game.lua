-- Spacescape: RuneScape in Space
-- A top-down space shooter with right-click to move

-- Module imports
local playerModule = require("src.entities.player")
local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local ui = require("src.render.hud")
local windowManager = require("src.render.hud.window_manager")
local projectileModule = require("src.entities.projectile")
local particlesModule = require("src.entities.particles")
local projectileShards = require("src.entities.projectile_shards")
local itemModule = require("src.entities.item")
local starfield = require("src.render.starfield")
local wreckModule = require("src.entities.wreck")
local world = require("src.core.world")
local camera = require("src.core.camera")
local physics = require("src.core.physics")
local config = require("src.core.config")
local systems = require("src.core.systems")
local spawnSystem = require("src.systems.spawn")
local combatSystem = require("src.systems.combat")
local collisionSystem = require("src.systems.collision")
local inputSystem = require("src.systems.input")
local abilitiesSystem = require("src.systems.abilities")
local engineTrail = require("src.entities.engine_trail")
local explosionFx = require("src.entities.explosion_fx")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local floatingText = require("src.entities.floating_text")
local gameRender = require("src.states.game_render")
local ecsWorld = require("src.ecs.world")

local ecsPlayerProxy = {
	position = { x = 0, y = 0 }
}

-- Module definition
local game = {}

-- Game state
local gameState = "playing" -- "playing", "gameover", "paused"

local pauseMenu = {
	items = {
		{ id = "resume", label = "Resume" },
		{ id = "quit",   label = "Quit to Desktop" },
	},
}

-- Helper to create UI context for window manager calls
local function createUiContext()
	return {
		gameState = gameState,
		pauseMenu = pauseMenu,
	}
end

-- Helper to apply UI context changes from window manager
local function applyUiContext(uiCtx)
	gameState = uiCtx.gameState
	pauseMenu = uiCtx.pauseMenu
end

-- Color palette used for rendering
local colors = require("src.core.colors")

-- Constants
local DAMAGE_PER_HIT = config.combat.damagePerHit

local function registerUpdateSystems()
	systems.clear()

	systems.registerUpdate("input", function(dt, ctx)
		ctx.inputSystem.update(dt, ctx.player, ctx.world, ctx.camera)
	end, 10)

	systems.registerUpdate("physics", function(dt, ctx)
		physics.update(dt)
	end, 20)

	systems.registerUpdate("player", function(dt, ctx)
		playerModule.update(dt, ctx.world)
	end, 30)

	systems.registerUpdate("engineTrail", function(dt, ctx)
		engineTrail.update(dt, ctx.player, enemyModule.list)
	end, 40)

	systems.registerUpdate("camera", function(dt, ctx)
		camera.update(dt, ctx.player)
	end, 50)

	systems.registerUpdate("starfield", function(dt, ctx)
		starfield.update(dt, ctx.camera.x, ctx.camera.y)
	end, 60)

	systems.registerUpdate("asteroids", function(dt, ctx)
		asteroidModule.update(dt, ctx.world)
	end, 70)

	systems.registerUpdate("projectiles", function(dt, ctx)
		projectileModule.update(dt, ctx.world)
	end, 80)

	systems.registerUpdate("projectileShards", function(dt, ctx)
		projectileShards.update(dt)
	end, 85)

	systems.registerUpdate("enemies", function(dt, ctx)
		enemyModule.update(dt, ctx.player, ctx.world)
	end, 90)

	systems.registerUpdate("particles", function(dt, ctx)
		particlesModule.update(dt)
	end, 100)

	systems.registerUpdate("shieldImpactFx", function(dt, ctx)
		shieldImpactFx.update(dt)
	end, 105)

	systems.registerUpdate("floatingText", function(dt, ctx)
		floatingText.update(dt)
	end, 110)

	systems.registerUpdate("abilities", function(dt, ctx)
		abilitiesSystem.update(dt, ctx.player, ctx.world, ctx.camera)
	end, 120)

	systems.registerUpdate("spawn", function(dt, ctx)
		spawnSystem.update(dt)
	end, 130)

	systems.registerUpdate("combat", function(dt, ctx)
		combatSystem.updateAutoShoot(dt, ctx.player)
	end, 140)

	-- Items / pickups are updated after ships so that magnets use the latest
	-- player position, but before particles so they remain part of the core
	-- world simulation rather than just an effect layer.
	systems.registerUpdate("items", function(dt, ctx)
		itemModule.update(dt, ctx.player, ctx.world)
	end, 95)

	systems.registerUpdate("wrecks", function(dt, ctx)
		wreckModule.update(dt, ctx.world)
	end, 96)
end
--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function game.load()
	love.window.setTitle("Spacescape")
	math.randomseed(os.time())

	local font = love.graphics.newFont("assets/fonts/Orbitron-Bold.ttf", 16)
	love.graphics.setFont(font)

	physics.init()
	collisionSystem.init() -- Register collision callbacks with physics
	playerModule.reset()
	world.initFromPlayer(playerModule.state)
	camera.centerOnPlayer(playerModule.state)
	starfield.generate()
	spawnSystem.reset()
	combatSystem.reset()
	particlesModule.load()
	engineTrail.load()
	engineTrail.reset()
	explosionFx.load()
	shieldImpactFx.load()
	floatingText.clear()
	abilitiesSystem.load(playerModule.state)
	asteroidModule.load()
	gameRender.load()
	registerUpdateSystems()
end

--------------------------------------------------------------------------------
-- Update Logic
--------------------------------------------------------------------------------

function game.update(dt)
	if gameState ~= "playing" then
		return
	end

	local updateCtx = {
		player = playerModule.state,
		world = world,
		camera = camera,
		inputSystem = inputSystem,
	}

	systems.runUpdate(dt, updateCtx)

	-- ECS world update (emits update to all systems)
	if playerModule.state then
		ecsPlayerProxy.position.x = playerModule.state.x
		ecsPlayerProxy.position.y = playerModule.state.y
	end

	ecsWorld:emit("update", dt, ecsPlayerProxy)

	game.checkCollisions()
end

function game.checkCollisions()
	local playerDied = collisionSystem.update(playerModule.state, particlesModule, colors, DAMAGE_PER_HIT)
	if playerDied then
		gameState = "gameover"
	end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

function game.mousepressed(x, y, button)
	if gameState == "gameover" then
		if button == 1 then
			game.restartGame()
		end
		return
	end

	-- Route all HUD window-style input through the centralized window manager so
	-- the game state no longer needs to know per-window frame details.
	local uiCtx = createUiContext()

	local handled, action = windowManager.mousepressed(uiCtx, x, y, button)

	-- Persist any changes the window manager made to the HUD-related state.
	applyUiContext(uiCtx)

	if action == "quit_to_desktop" then
		love.event.quit()
		return
	end

	if handled then
		return
	end

	if gameState ~= "playing" then
		return
	end

	inputSystem.mousepressed(x, y, button, playerModule.state, world, camera)
end

function game.mousereleased(x, y, button)
	if gameState == "gameover" then
		return
	end

	local uiCtx = createUiContext()

	local handled = windowManager.mousereleased(uiCtx, x, y, button)

	applyUiContext(uiCtx)

	if handled then
		return
	end
end

function game.mousemoved(x, y, dx, dy)
	if gameState == "gameover" then
		return
	end

	local uiCtx = createUiContext()

	local handled = windowManager.mousemoved(uiCtx, x, y, dx, dy)

	applyUiContext(uiCtx)

	if handled then
		return
	end
end

function game.wheelmoved(x, y)
	if gameState ~= "playing" then
		return
	end

	local uiCtx = createUiContext()
	local handled = windowManager.wheelmoved(uiCtx, x, y)
	applyUiContext(uiCtx)
	if handled then
		return
	end

	inputSystem.wheelmoved(x, y, camera)
end

function game.keypressed(key)
	-- Delegate keyboard input to the window manager first. This allows Escape
	-- to close in-play overlay windows (cargo, map) before toggling pause.
	local uiCtx = createUiContext()
	local handled, action = windowManager.keypressed(uiCtx, key)
	applyUiContext(uiCtx)

	if handled then
		-- An in-play window was closed; do not proceed to pause toggle.
		return
	end

	if key == "escape" then
		if gameState == "playing" then
			gameState = "paused"
			windowManager.setWindowOpen("cargo", false) -- Close cargo when pausing
		elseif gameState == "paused" then
			gameState = "playing"
		end
		return
	end

	if key == "tab" and gameState == "playing" then
		local nowOpen = not windowManager.isWindowOpen("cargo")
		windowManager.setWindowOpen("cargo", nowOpen)
		if not nowOpen then
			windowManager.resetWindow("cargo") -- Use centralized reset
		end
		return
	end

	-- Toggle the full-screen world map overlay. We treat this similarly to the
	-- cargo window: it is an overlay drawn during normal gameplay, without
	-- changing the core game state.
	if key == "m" and gameState == "playing" then
		windowManager.toggleWindow("map")
		return
	end

	if gameState ~= "playing" then
		return
	end

	abilitiesSystem.keypressed(key, playerModule.state, world, camera)
end

function game.resize(w, h)
	starfield.resize()
end

--------------------------------------------------------------------------------
-- Game State Management
--------------------------------------------------------------------------------

function game.restartGame()
	playerModule.reset()
	world.initFromPlayer(playerModule.state)
	camera.centerOnPlayer(playerModule.state)

	projectileModule.clear()
	projectileShards.clear()
	enemyModule.clear()
	asteroidModule.clear()
	particlesModule.clear()
	itemModule.clear()
	wreckModule.clear()
	engineTrail.reset()
	explosionFx.clear()
	shieldImpactFx.clear()
	floatingText.clear()
	collisionSystem.clear()
	ecsWorld:clear()

	spawnSystem.reset()
	combatSystem.reset()
	abilitiesSystem.reset(playerModule.state)
	gameState = "playing"
	windowManager.setWindowOpen("cargo", false)
	windowManager.setWindowOpen("map", false)
end

--- Rendering
--------------------------------------------------------------------------------

function game.draw()
	starfield.draw()

	local renderCtx = {
		camera = camera,
		ui = ui,
		player = playerModule.state,
		playerModule = playerModule,
		asteroidModule = asteroidModule,
		itemModule = itemModule,
		wreckModule = wreckModule,
		projectileModule = projectileModule,
		projectileShards = projectileShards,
		enemyModule = enemyModule,
		engineTrail = engineTrail,
		particlesModule = particlesModule,
		explosionFx = explosionFx,
		shieldImpactFx = shieldImpactFx,
		floatingText = floatingText,
		colors = colors,
		gameState = gameState,
		combatSystem = combatSystem,
		pauseMenu = pauseMenu,
		cargoOpen = windowManager.isWindowOpen("cargo"),
		mapOpen = windowManager.isWindowOpen("map"),
	}

	gameRender.draw(renderCtx)
end

return game
