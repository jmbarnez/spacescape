-- Spacescape: RuneScape in Space
-- A top-down space shooter with right-click to move

-- Module imports
local playerModule = require("src.entities.player")
local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local ui = require("src.render.hud")
local projectileModule = require("src.entities.projectile")
local particlesModule = require("src.entities.particles")
local starfield = require("src.render.starfield")
local world = require("src.core.world")
local camera = require("src.core.camera")
local physics = require("src.core.physics")
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

-- Color palette used for rendering
local colors = {
    ship = {0.2, 0.6, 1.0},
    projectile = {0.3, 0.7, 1.0},
    enemy = {1.0, 0.3, 0.3},
    enemyOutline = {1.0, 0.5, 0.5},
    health = {0.3, 1.0, 0.3},
    healthBg = {0.3, 0.3, 0.3},
    movementIndicator = {0.3, 1.0, 0.3, 0.5},
    star = {1.0, 1.0, 1.0},
    targetRing = {1.0, 0.0, 0.0, 0.9},
    targetRingLocking = {1.0, 1.0, 0.0, 0.9},
    targetRingLocked = {0.9, 0.1, 0.1, 0.95}
}

-- Constants
local DAMAGE_PER_HIT = 20
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
    gameRender.load()
end

--------------------------------------------------------------------------------
-- Update Logic
--------------------------------------------------------------------------------

function game.update(dt)
    if gameState == "gameover" then
        return
    end
    
    inputSystem.update(dt, player, world, camera)

    physics.update(dt)
    playerModule.update(dt, world)
    engineTrail.update(dt, player)
    camera.update(dt, player)
    starfield.update(dt, camera.x, camera.y)
    asteroidModule.update(dt, world)
    projectileModule.update(dt, world)
    enemyModule.update(dt, player, world)
    particlesModule.update(dt)
    floatingText.update(dt)
    abilitiesSystem.update(dt, player, world, camera)
    spawnSystem.update(dt)
    combatSystem.updateAutoShoot(dt, player)
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
    
    inputSystem.mousepressed(x, y, button, player, world, camera)
end

function game.wheelmoved(x, y)
    if gameState == "gameover" then
        return
    end

    inputSystem.wheelmoved(x, y, camera)
end

function game.keypressed(key)
    if gameState ~= "playing" then
        return
    end

    abilitiesSystem.keypressed(key, player, world, camera)
end

function game.resize(w, h)
end

--------------------------------------------------------------------------------
-- Game State Management
--------------------------------------------------------------------------------

function game.restartGame()
    playerModule.reset()
    world.initFromPlayer(player)
    camera.centerOnPlayer(player)
    
    projectileModule.clear()
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
    
    gameRender.draw(
		camera,
		ui,
		player,
		playerModule,
		asteroidModule,
		projectileModule,
		enemyModule,
		engineTrail,
		particlesModule,
		explosionFx,
		floatingText,
		colors,
		gameState,
		combatSystem
	)
end

return game
