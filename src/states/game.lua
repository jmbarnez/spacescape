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
local engineTrail = require("src.entities.engine_trail")

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
    projectile = {1, 1, 0.3},
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
    
    physics.init()
    playerModule.reset()
    world.initFromPlayer(player)
    camera.centerOnPlayer(player)
    starfield.generate()
    spawnSystem.reset()
    combatSystem.reset()
    engineTrail.load()
    engineTrail.reset()
end

--------------------------------------------------------------------------------
-- Update Logic
--------------------------------------------------------------------------------

function game.update(dt)
    if gameState == "gameover" then
        return
    end
    
    inputSystem.update(dt)

    physics.update(dt)
    playerModule.update(dt, world)
    engineTrail.update(dt, player)
    camera.update(dt, player)
    starfield.update(dt, camera.x, camera.y)
    asteroidModule.update(dt)
    projectileModule.update(dt, world)
    enemyModule.update(dt, player, world)
    particlesModule.update(dt)
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
    
    inputSystem.mousepressed(x, y, button)
end

function game.wheelmoved(x, y)
    if gameState == "gameover" then
        return
    end

    inputSystem.wheelmoved(x, y)
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
    
    spawnSystem.reset()
    combatSystem.reset()
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

    love.graphics.setColor(colors.targetRing)
    love.graphics.setLineWidth(1)
    local radius = targetEnemy.size or 0
    if targetEnemy.ship and targetEnemy.ship.boundingRadius then
        radius = targetEnemy.ship.boundingRadius
    end
    love.graphics.circle("line", targetEnemy.x, targetEnemy.y, radius + 8)
end

local function drawWorldObjects()
    drawMovementIndicator()
    asteroidModule.draw()
    particlesModule.draw()
    projectileModule.draw(colors)
    enemyModule.draw(colors)
    drawTargetIndicator()
    
    if gameState == "playing" then
        engineTrail.draw()
        playerModule.draw(colors)
    end
end

local function drawOverlay()
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
