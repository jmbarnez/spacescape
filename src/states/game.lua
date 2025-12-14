-- Spacescape: RuneScape in Space
-- A top-down space shooter with right-click to move

-- Module imports
local playerModule = require("src.entities.player")
local windowManager = require("src.render.hud.window_manager")
local world = require("src.core.world")
local camera = require("src.core.camera")
local config = require("src.core.config")
local systems = require("src.core.systems")
local inputSystem = require("src.systems.input")
local abilitiesSystem = require("src.systems.abilities")
local input = require("src.core.input")
local gameInput = require("src.states.game_input")
local gameBootstrap = require("src.states.game_bootstrap")
local gameDraw = require("src.states.game_draw")
local gameRespawn = require("src.states.game_respawn")

-- Module definition
local game = {}

-- Game state
local gameState = "playing" -- "playing", "dead", "paused"

local initialSpawn = { x = 0, y = 0 }

local pauseMenu = {
	items = {
		{ id = "resume", label = "Resume" },
		{ id = "quit",   label = "Quit to Desktop" },
	},
}

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

local function processInputActions()
	gameInput.process({
		input = input,
		windowManager = windowManager,
		inputSystem = inputSystem,
		playerModule = playerModule,
		world = world,
		camera = camera,
		config = config,
		getGameState = function()
			return gameState
		end,
		setGameState = function(nextState)
			gameState = nextState
		end,
		respawn = function()
			game.respawn()
		end,
		getPauseMenu = function()
			return pauseMenu
		end,
		setPauseMenu = function(nextMenu)
			pauseMenu = nextMenu
		end,
		onQuit = function()
			love.event.quit()
		end,
	})
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function game.load()
	gameBootstrap.load(initialSpawn)
end

--------------------------------------------------------------------------------
-- Update Logic
--------------------------------------------------------------------------------

function game.update(dt)
	local playerEntity = playerModule.getEntity()

	-- Update the input wrapper every frame so pressed/released transitions are
	-- detected reliably, even while paused or on the death screen.
	input.update(dt)

	-- Process all UI + gameplay input as action checks (Baton) instead of Love
	-- callbacks.
	processInputActions()

	-- Ability casts are gated behind the "playing" state so the player cannot
	-- trigger combat actions while paused or dead.
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
	local playerEntity = playerModule.getEntity()
	if playerEntity and playerEntity.health and playerEntity.health.current and playerEntity.health.current <= 0 then
		gameState = "dead"
	end
end

function game.respawn()
	if gameState ~= "dead" then
		return
	end

	gameRespawn.respawn(initialSpawn)

	gameState = "playing"
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
	require("src.render.starfield").resize()
end

--------------------------------------------------------------------------------
-- Game State Management
--------------------------------------------------------------------------------

--- Rendering
--------------------------------------------------------------------------------

function game.draw()
	gameDraw.draw(gameState, pauseMenu, camera)
end

return game
