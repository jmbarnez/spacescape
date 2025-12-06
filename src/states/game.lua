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

local lockOnShader = nil
local lockLabelLockedAt = nil

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

    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/lock_on.glsl")
    if ok then
        lockOnShader = shader
    end
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
    explosionFx.update(dt)
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
    -- Check if target is far enough to show indicator
    local dx = player.targetX - player.x
    local dy = player.targetY - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 30 then
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
    
    -- Draw path line (shows intended direction, not actual trajectory)
    love.graphics.setColor(
        colors.movementIndicator[1],
        colors.movementIndicator[2],
        colors.movementIndicator[3],
        0.2
    )
    love.graphics.setLineWidth(1)
    love.graphics.line(player.x, player.y, player.targetX, player.targetY)
    
    -- Draw velocity vector (shows actual momentum)
    if player.vx and player.vy then
        local speed = math.sqrt(player.vx * player.vx + player.vy * player.vy)
        if speed > 5 then
            love.graphics.setColor(0.5, 0.8, 1.0, 0.4)
            love.graphics.setLineWidth(2)
            local velScale = 0.5  -- Scale velocity for visualization
            love.graphics.line(
                player.x, player.y,
                player.x + player.vx * velScale,
                player.y + player.vy * velScale
            )
        end
    end
end

local function drawTargetIndicator()
    local targetEnemy = combatSystem.getTargetEnemy()
    local lockTarget, lockTimer, lockDuration, lockedEnemy = combatSystem.getLockStatus()

    local drawEnemy = nil
    local isLocking = false
    local progress = 0

    if lockTarget and (not targetEnemy or lockTarget ~= targetEnemy) then
        drawEnemy = lockTarget
        if lockDuration and lockDuration > 0 then
            progress = math.max(0, math.min(1, lockTimer / lockDuration))
            isLocking = true
        end
    elseif targetEnemy then
        drawEnemy = targetEnemy
    end

    if not drawEnemy then
        return
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local scale = camera.scale or 1

    local halfW = math.floor(width / 2)
    local halfH = math.floor(height / 2)
    local camX = math.floor(camera.x)
    local camY = math.floor(camera.y)

    local sx = (drawEnemy.x - camX) * scale + halfW
    local sy = (drawEnemy.y - camY) * scale + halfH

    local radius = drawEnemy.size or 0
    if drawEnemy.ship and drawEnemy.ship.boundingRadius then
        radius = drawEnemy.ship.boundingRadius
    elseif drawEnemy.collisionRadius then
        radius = drawEnemy.collisionRadius
    end

    local screenRadius = (radius + 8) * scale

    local isLocked = (not isLocking) and targetEnemy ~= nil and drawEnemy == targetEnemy

    if isLocked then
        if not lockLabelLockedAt then
            lockLabelLockedAt = love.timer.getTime()
        end
    else
        lockLabelLockedAt = nil
    end

    local ringColor
    if isLocking then
        ringColor = colors.targetRingLocking or colors.targetRing
    elseif isLocked then
        ringColor = colors.targetRingLocked or colors.targetRing
    else
        ringColor = colors.targetRing
    end

    local shader = lockOnShader
    if shader and (isLocking or isLocked) then
        local prevShader = love.graphics.getShader()
        local prevBlend, prevAlpha = love.graphics.getBlendMode()

        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setShader(shader)

        local now = love.timer.getTime()
        shader:send("time", now)
        shader:send("center", {sx, sy})
        shader:send("radius", screenRadius)

        local sr = ringColor[1]
        local sg = ringColor[2]
        local sb = ringColor[3]
        local mix = 0.7
        sr = sr * (1 - mix) + 1.0 * mix
        sg = sg * (1 - mix) + 0.6 * mix
        sb = sb * (1 - mix) + 0.2 * mix

        shader:send("color", {sr, sg, sb})
        local lockProgress = isLocked and 1 or progress
        shader:send("progress", lockProgress)

        love.graphics.setColor(1, 1, 1, 1)
        local size = screenRadius * 1.7
        love.graphics.rectangle("fill", sx - size, sy - size, size * 2, size * 2)

        love.graphics.setBlendMode(prevBlend, prevAlpha)
        love.graphics.setShader(prevShader)
    else
        if isLocking then
            love.graphics.setColor(ringColor)
            love.graphics.setLineWidth(2)
            local startAngle = -math.pi / 2
            local endAngle = startAngle + 2 * math.pi * progress
            local segments = math.max(4, math.floor(32 * progress))
            local points = {}
            for i = 0, segments do
                local t = i / segments
                local angle = startAngle + (endAngle - startAngle) * t
                local px = sx + math.cos(angle) * screenRadius
                local py = sy + math.sin(angle) * screenRadius
                table.insert(points, px)
                table.insert(points, py)
            end
            if #points >= 4 then
                love.graphics.line(points)
            end
        else
            love.graphics.setColor(ringColor)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", sx, sy, screenRadius)
        end
    end

    local labelText
    local labelColor
    local labelAlpha = 1.0
    if isLocking then
        labelText = "LOCKING..."
        labelColor = colors.targetRingLocking or colors.targetRing
        labelAlpha = labelColor[4] or 1.0
    elseif isLocked then
        labelText = "LOCKED"
        labelColor = {1.0, 1.0, 1.0, 1.0}

        if lockLabelLockedAt then
            local now = love.timer.getTime()
            local elapsed = now - lockLabelLockedAt
            local visibleDuration = 0.6
            local fadeDuration = 0.4
            if elapsed >= visibleDuration + fadeDuration then
                labelText = nil
            else
                if elapsed > visibleDuration then
                    local tFade = (elapsed - visibleDuration) / fadeDuration
                    if tFade < 0 then tFade = 0 end
                    if tFade > 1 then tFade = 1 end
                    labelAlpha = (1.0 - tFade) * 0.7
                else
                    labelAlpha = 0.7
                end
            end
        else
            labelAlpha = 0.7
        end
    end

    if labelText then
        local font = love.graphics.getFont()
        if font then
            local textWidth = font:getWidth(labelText)
            local textHeight = font:getHeight()
            local textX = sx - textWidth / 2
            local textY = sy - screenRadius - textHeight - 4
            love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3], labelAlpha)
            love.graphics.print(labelText, textX, textY)
        end
    end
end

local function drawWorldObjects()
    drawMovementIndicator()
    asteroidModule.draw()
    projectileModule.draw(colors)
    enemyModule.draw(colors)
    
    if gameState == "playing" then
        engineTrail.draw()
        playerModule.draw(colors)
    end

    -- Draw impact / explosion particles on top so they are clearly visible
    particlesModule.draw()
    explosionFx.draw()
    floatingText.draw()

    -- Debug: visualize projectile impact contact points
    if collisionSystem.debugDraw then
        collisionSystem.debugDraw()
    end
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
