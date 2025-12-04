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

-- Module definition
local game = {}

-- Local references for performance
local player = playerModule.state
local enemies = enemyModule.list

-- Game state
local gameState = "playing" -- "playing", "gameover"

-- Color palette
local colors = {
    ship = {0.2, 0.6, 1},
    shipOutline = {0.4, 0.8, 1},
    projectile = {0.3, 0.7, 1.0},
    enemy = {1, 0.3, 0.3},
    enemyOutline = {1, 0.5, 0.5},
    health = {0.3, 1, 0.3},
    healthBg = {0.3, 0.3, 0.3},
    movementIndicator = {0.3, 1, 0.3, 0.5},
    star = {1, 1, 1},
    targetRing = {1, 0, 0, 0.9}
}

-- Constants
local SCORE_PER_KILL = 100
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
    asteroidModule.update(dt)
    projectileModule.update(dt, world)
    enemyModule.update(dt, player, world)
    particlesModule.update(dt)
    explosionFx.update(dt)
    floatingText.update(dt)
    abilitiesSystem.update(dt, player, world, camera)
    spawnSystem.update(dt)
    combatSystem.updateAutoShoot(dt, player)
    game.checkCollisions()
end

function game.checkCollisions()
    local playerDied = collisionSystem.update(player, particlesModule, colors, SCORE_PER_KILL, DAMAGE_PER_HIT)
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
    starfield.generate()
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
    particlesModule.clear()
    engineTrail.reset()
    explosionFx.clear()
    floatingText.clear()
    
    spawnSystem.reset()
    combatSystem.reset()
    abilitiesSystem.reset(player)
    gameState = "playing"
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

local function beginWorldTransform()
    love.graphics.push()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local scale = camera.scale or 1
    love.graphics.translate(math.floor(width / 2), math.floor(height / 2))
    love.graphics.scale(scale, scale)
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
end

local function endWorldTransform()
    love.graphics.pop()
end

local function drawMovementIndicator()
    if not player.isMoving then
        return
    end
    
    local markerSize = 10
    
    -- Draw target crosshair
    love.graphics.setColor(colors.movementIndicator)
    love.graphics.setLineWidth(2)
    love.graphics.line(
        player.targetX - markerSize, player.targetY,
        player.targetX + markerSize, player.targetY
    )
    love.graphics.line(
        player.targetX, player.targetY - markerSize,
        player.targetX, player.targetY + markerSize
    )
    
    -- Draw path line
    love.graphics.setColor(
        colors.movementIndicator[1],
        colors.movementIndicator[2],
        colors.movementIndicator[3],
        0.2
    )
    love.graphics.setLineWidth(1)
    love.graphics.line(player.x, player.y, player.targetX, player.targetY)
end

local function drawTargetIndicator()
    local targetEnemy = combatSystem.getTargetEnemy()
    if not targetEnemy then
        return
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local scale = camera.scale or 1

    local halfW = math.floor(width / 2)
    local halfH = math.floor(height / 2)
    local camX = math.floor(camera.x)
    local camY = math.floor(camera.y)

    local sx = (targetEnemy.x - camX) * scale + halfW
    local sy = (targetEnemy.y - camY) * scale + halfH

    local radius = targetEnemy.size or 0
    if targetEnemy.ship and targetEnemy.ship.boundingRadius then
        radius = targetEnemy.ship.boundingRadius
    elseif targetEnemy.collisionRadius then
        radius = targetEnemy.collisionRadius
    end

    local screenRadius = (radius + 8) * scale

    love.graphics.setColor(colors.targetRing)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", sx, sy, screenRadius)
end

local function drawWorldObjects()
    drawMovementIndicator()
    asteroidModule.draw()
    particlesModule.draw()
    projectileModule.draw(colors)
    enemyModule.draw(colors)
    explosionFx.draw()
    
    if gameState == "playing" then
        engineTrail.draw()
        playerModule.draw(colors)
    end
    
    floatingText.draw()
end

local function drawOverlay()
    drawTargetIndicator()
    ui.drawHUD(player, colors)
    
    if gameState == "gameover" then
        ui.drawGameOver(player)
    end
end

function game.draw()
    starfield.draw()
    
    beginWorldTransform()
    drawWorldObjects()
    endWorldTransform()
    
    drawOverlay()
end

return game
