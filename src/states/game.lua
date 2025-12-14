-- Spacescape: RuneScape in Space
-- A top-down space shooter with right-click to move

-- Module imports
local playerModule = require("src.entities.player")
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
local input = require("src.core.input")

local function getEnemyEntities()
	local ships = ecsWorld:query({ "ship", "faction", "position" }) or {}
	local enemies = {}
	for _, e in ipairs(ships) do
		if e.faction and e.faction.name == "enemy" and not e._removed and not e.removed then
			table.insert(enemies, e)
		end
	end
	return enemies
end

local function clearEnemyEntities()
	local enemies = getEnemyEntities()
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		if e and e.physics and e.physics.body then
			pcall(function()
				if e.physics.body.isDestroyed and not e.physics.body:isDestroyed() then
					e.physics.body:destroy()
				end
			end)
		end
		if e and e.destroy then
			e:destroy()
		end
	end
end

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

--------------------------------------------------------------------------------
-- INPUT PROCESSING (ACTION-BASED)
--
-- We intentionally process gameplay + HUD input once per frame using the
-- src.core.input wrapper (Baton + mouse/wheel helpers) instead of spreading
-- logic across Love callbacks.
--
-- Key invariants:
--   - HUD gets first chance to consume left-clicks / wheel input.
--   - Esc closes top-most in-play overlay first; otherwise it toggles pause.
--   - Game simulation only advances when gameState == "playing".
--------------------------------------------------------------------------------

local function processUiMouseMove()
	local mx, my = input.getMousePosition()
	local dx, dy = input.getMouseDelta()

	-- Mouse-move is primarily used for dragging HUD windows (pause/cargo/map).
	-- Even if dx/dy is 0, the handlers are cheap and keep logic consistent.
	local uiCtx = createUiContext()
	windowManager.mousemoved(uiCtx, mx, my, dx, dy)
	applyUiContext(uiCtx)
end

local function processUiMouseButtons()
	local mx, my = input.getMousePosition()
	local pressX, pressY = input.getMousePressedPosition(1)
	local releaseX, releaseY = input.getMouseReleasedPosition(1)
	local rightPressX, rightPressY = input.getMousePressedPosition(2)
	if not pressX then
		pressX, pressY = mx, my
	end
	if not releaseX then
		releaseX, releaseY = mx, my
	end
	if not rightPressX then
		rightPressX, rightPressY = mx, my
	end

	-- Press: route left-click into the HUD first, then (if unhandled) into
	-- gameplay selection.
	if input.pressed("mouse_primary") then
		if gameState == "gameover" then
			game.restartGame()
			return
		end

		local uiCtx = createUiContext()
		local handled, action = windowManager.mousepressed(uiCtx, pressX, pressY, 1)
		applyUiContext(uiCtx)

		if action == "quit_to_desktop" then
			love.event.quit()
			return
		elseif action == "restart" then
			game.restartGame()
			return
		end

		if handled then
			return
		end

		if gameState ~= "playing" then
			return
		end

		-- Gameplay left-click: loot/target selection.
		inputSystem.mousepressed(pressX, pressY, 1, playerModule.getEntity(), world, camera)
	end

	-- Release: always forward to HUD so it can clear any drag state.
	if input.released("mouse_primary") then
		local uiCtx = createUiContext()
		windowManager.mousereleased(uiCtx, releaseX, releaseY, 1)
		applyUiContext(uiCtx)
	end

	-- Right-click movement: the legacy input system sets the move target on
	-- press *and* while the button is held. We keep the press behavior here so
	-- quick taps still move the ship.
	if input.pressed("mouse_secondary") and gameState == "playing" then
		inputSystem.mousepressed(rightPressX, rightPressY, 2, playerModule.getEntity(), world, camera)
	end
end

local function processUiMouseWheel()
	local wx, wy = input.getWheelDelta()
	if (not wy) or wy == 0 then
		return
	end

	local uiCtx = createUiContext()
	local handled = windowManager.wheelmoved(uiCtx, wx, wy)
	applyUiContext(uiCtx)

	-- If no HUD overlay consumed the wheel event, treat it as gameplay camera
	-- zoom (matching the legacy inputSystem.wheelmoved behavior).
	if not handled and gameState == "playing" then
		camera.zoom(wy * config.camera.zoomWheelScale)
	end
end

local function processUiKeyboardActions()
	-- Fullscreen toggle (F11)
	if input.pressed("toggle_fullscreen") then
		local isFullscreen = love.window.getFullscreen()
		love.window.setFullscreen(not isFullscreen, "desktop")
		return
	end

	-- Escape: close top-most in-play overlay first (cargo/map), otherwise toggle
	-- pause.
	if input.pressed("pause") then
		if gameState == "playing" then
			local uiCtx = createUiContext()
			local handled = windowManager.keypressed(uiCtx, "escape")
			applyUiContext(uiCtx)

			if handled then
				return
			end

			gameState = "paused"
			windowManager.setWindowOpen("cargo", false)
			return
		elseif gameState == "paused" then
			gameState = "playing"
			return
		end
	end

	-- Cargo overlay toggle (Tab)
	if input.pressed("toggle_cargo") and gameState == "playing" then
		local nowOpen = not windowManager.isWindowOpen("cargo")
		windowManager.setWindowOpen("cargo", nowOpen)
		if not nowOpen then
			windowManager.resetWindow("cargo")
		end
		return
	end

	-- Galaxy/world map overlay toggle (M)
	if input.pressed("toggle_map") and gameState == "playing" then
		windowManager.toggleWindow("map")
		return
	end
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

	-- Update kinematic transforms BEFORE stepping Box2D so beginContact events
	-- are generated in the same frame (instead of one frame late).
	-- Update kinematic transforms BEFORE stepping Box2D so beginContact events
	-- are generated in the same frame (instead of one frame late).
	-- [DELETED] Legacy playerModule.update (Moved to PlayerControlSystem)


	-- ECS pre-physics: update AI/movement and sync ECS kinematic bodies into Box2D.
	systems.registerUpdate("ecsPrePhysics", function(dt, ctx)
		-- Removed proxy sync steps, as we use direct ECS components now.
		if ecsWorld and ecsWorld.emit then
			ecsWorld:emit("prePhysics", dt, ctx.player, ctx.world)
		end
	end, 25)


	-- Asteroids still run through their legacy update loop, but are ECS-backed.
	-- They must update BEFORE physics so their bodies are in the correct place
	-- when Box2D evaluates contacts.
	-- Asteroids still run through their legacy update loop, but are ECS-backed.
	-- They must update BEFORE physics so their bodies are in the correct place
	-- when Box2D evaluates contacts.
	-- [DELETED] Legacy asteroidModule.update (Moved to ECS Systems)


	-- Wrecks have sensor bodies; keep their transforms in sync before physics.
	-- Wrecks have sensor bodies; keep their transforms in sync before physics.
	-- [DELETED] Legacy wreckModule.update (Moved to ECS Systems)


	systems.registerUpdate("physics", function(dt, ctx)
		physics.update(dt)
	end, 40)

	-- ECS post-physics: drain Box2D collision queue + copy physics-driven bodies
	-- (projectiles) back into ECS positions.
	systems.registerUpdate("ecsPostPhysics", function(dt, ctx)
		if ecsWorld and ecsWorld.emit then
			ecsWorld:emit("postPhysics", dt, ctx.player, ctx.world)
		end
		-- Removed ECS -> playerModule.state sync.
	end, 45)


	systems.registerUpdate("engineTrail", function(dt, ctx)
		engineTrail.update(dt, ctx.player, getEnemyEntities())
	end, 40)

	systems.registerUpdate("camera", function(dt, ctx)
		camera.update(dt, ctx.player)
	end, 50)

	systems.registerUpdate("starfield", function(dt, ctx)
		starfield.update(dt, ctx.camera.x, ctx.camera.y)
	end, 60)

	systems.registerUpdate("projectiles", function(dt, ctx)
		projectileModule.update(dt, ctx.world)
	end, 80)

	systems.registerUpdate("projectileShards", function(dt, ctx)
		projectileShards.update(dt)
	end, 85)

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

	-- NOTE: wrecks are updated in the pre-physics phase now.
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
	playerModule.reset() -- Spawns new player ECS entity
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
	asteroidModule.load()
	gameRender.load()
	registerUpdateSystems()
end

--------------------------------------------------------------------------------
-- Update Logic
--------------------------------------------------------------------------------

function game.update(dt)
	local playerEntity = playerModule.getEntity()

	-- Update the input wrapper every frame so pressed/released transitions are
	-- detected reliably, even while paused or on the game-over screen.
	input.update(dt)

	-- Process all UI + gameplay input as action checks (Baton) instead of Love
	-- callbacks.
	processUiMouseMove()
	processUiMouseButtons()
	processUiMouseWheel()
	processUiKeyboardActions()

	-- Ability casts are gated behind the "playing" state so the player cannot
	-- trigger combat actions while paused or game-over.
	if gameState == "playing" then
		if input.pressed("ability_overcharge") then
			abilitiesSystem.castOvercharge(playerEntity)
		end
		if input.pressed("ability_vector_dash") then
			abilitiesSystem.castVectorDash(playerEntity, world, camera)
		end
	end

	if gameState ~= "playing" then
		return
	end

	local updateCtx = {
		player = playerEntity,
		world = world,
		camera = camera,
		inputSystem = inputSystem,
	}


	systems.runUpdate(dt, updateCtx)

	game.checkCollisions()
end

function game.checkCollisions()
	local playerDied = collisionSystem.update(playerModule.getEntity(), particlesModule, colors, DAMAGE_PER_HIT)
	if playerDied then
		gameState = "gameover"
	end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

function game.mousepressed(x, y, button)
	input.mousepressed(x, y, button)
end

function game.mousereleased(x, y, button)
	input.mousereleased(x, y, button)
end

function game.mousemoved(x, y, dx, dy)
	-- Intentionally handled by polling in game.update().
end

function game.wheelmoved(x, y)
	-- Wheel is event-driven in LOVE, so we forward it into the input wrapper
	-- which records a per-frame delta consumed in game.update().
	input.wheelmoved(x, y)
end

function game.keypressed(key)
	input.keypressed(key)
end

function game.keyreleased(key)
	input.keyreleased(key)
end

function game.resize(w, h)
	starfield.resize()
end

--------------------------------------------------------------------------------
-- Game State Management
--------------------------------------------------------------------------------

function game.restartGame()
	projectileModule.clear()

	projectileShards.clear()
	asteroidModule.clear()
	particlesModule.clear()
	itemModule.clear()
	wreckModule.clear()
	engineTrail.reset()
	explosionFx.clear()
	shieldImpactFx.clear()
	floatingText.clear()
	collisionSystem.clear()
	clearEnemyEntities()
	-- Clear ECS entities before respawning the player so we don't delete the
	-- newly spawned player entity.
	ecsWorld:clear()
	playerModule.entity = nil
	playerModule.reset()
	local playerEntity = playerModule.getEntity()
	world.initFromPlayer(playerEntity)
	camera.centerOnEntity(playerEntity)

	spawnSystem.reset()
	combatSystem.reset()
	abilitiesSystem.reset(playerEntity)
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
		player = playerModule.getEntity(),
		playerModule = playerModule,

		asteroidModule = asteroidModule,
		itemModule = itemModule,
		wreckModule = wreckModule,
		projectileModule = projectileModule,
		projectileShards = projectileShards,
		enemyList = getEnemyEntities(),
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
