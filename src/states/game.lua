-- Spacescape: RuneScape in Space
-- A top-down space shooter with right-click to move

-- Module imports
local playerModule = require("src.entities.player")
local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local ui = require("src.render.hud")
local projectileModule = require("src.entities.projectile")
local particlesModule = require("src.entities.particles")
local projectileShards = require("src.entities.projectile_shards")
local starfield = require("src.render.starfield")
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
local floatingText = require("src.entities.floating_text")
local gameRender = require("src.states.game_render")

-- Module definition
local game = {}

-- Local references for performance
local player = playerModule.state
local enemies = enemyModule.list

-- Game state
local gameState = "playing" -- "playing", "gameover"

local pauseMenu = {
	items = {
		{ id = "resume", label = "Resume" },
		{ id = "restart", label = "Restart" },
		{ id = "quit", label = "Quit to Desktop" },
	},
}

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
		engineTrail.update(dt, ctx.player)
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
    collisionSystem.init()  -- Register collision callbacks with physics
    playerModule.reset()
    world.initFromPlayer(player)
    camera.centerOnPlayer(player)
    starfield.generate()
    spawnSystem.reset()
    combatSystem.reset()
    particlesModule.load()
    engineTrail.load()
    engineTrail.reset()
    explosionFx.load()
    floatingText.clear()
    abilitiesSystem.load(player)
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
		player = player,
		world = world,
		camera = camera,
		inputSystem = inputSystem,
	}

	systems.runUpdate(dt, updateCtx)
	game.checkCollisions()
end

function game.checkCollisions()
    local playerDied = collisionSystem.update(player, particlesModule, colors, DAMAGE_PER_HIT)
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

	if gameState == "paused" then
		if button == 1 then
			local index, item = ui.hitTestPauseMenu(pauseMenu, x, y)
			if item then
				pauseMenu.selected = index
				if item.id == "resume" then
					gameState = "playing"
				elseif item.id == "restart" then
					game.restartGame()
				elseif item.id == "quit" then
					love.event.quit()
				end
			end
		end
		return
	end

	if gameState ~= "playing" then
		return
	end

	inputSystem.mousepressed(x, y, button, player, world, camera)
end

function game.wheelmoved(x, y)
	if gameState ~= "playing" then
		return
	end

	inputSystem.wheelmoved(x, y, camera)
end

function game.keypressed(key)
	if key == "escape" then
		if gameState == "playing" then
			gameState = "paused"
		elseif gameState == "paused" then
			gameState = "playing"
		end
		return
	end

	if gameState ~= "playing" then
		return
	end

	abilitiesSystem.keypressed(key, player, world, camera)
end

function game.resize(w, h)
    starfield.resize()
end

--------------------------------------------------------------------------------
-- Game State Management
--------------------------------------------------------------------------------

function game.restartGame()
    playerModule.reset()
    world.initFromPlayer(player)
    camera.centerOnPlayer(player)
    
    projectileModule.clear()
    projectileShards.clear()
    enemyModule.clear()
    asteroidModule.clear()
    particlesModule.clear()
    engineTrail.reset()
    explosionFx.clear()
    floatingText.clear()
    collisionSystem.clear()
    
    spawnSystem.reset()
    combatSystem.reset()
    abilitiesSystem.reset(player)
    gameState = "playing"
end

--- Rendering
--------------------------------------------------------------------------------

function game.draw()
    starfield.draw()

	local renderCtx = {
		camera = camera,
		ui = ui,
		player = player,
		playerModule = playerModule,
		asteroidModule = asteroidModule,
		projectileModule = projectileModule,
		projectileShards = projectileShards,
		enemyModule = enemyModule,
		engineTrail = engineTrail,
		particlesModule = particlesModule,
		explosionFx = explosionFx,
		floatingText = floatingText,
		colors = colors,
		gameState = gameState,
		combatSystem = combatSystem,
		pauseMenu = pauseMenu,
	}

	gameRender.draw(renderCtx)
end

return game
