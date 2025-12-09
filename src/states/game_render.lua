local game_render = {}

local lockOnShader = nil
local lockLabelLockedAt = nil

-- Config import used for hover selection radius, matching input selection
-- behavior so that hovering "feels" similar to clicking.
local config = require("src.core.config")

local function beginWorldTransform(camera)
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

local function drawMovementIndicator(player, colors)
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
            love.graphics.setColor(colors.velocityVector)
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

-- Finds the best candidate entity (enemy or asteroid) currently under the
-- mouse cursor, using a radius-based hit test similar to the click selection
-- logic in systems/combat.lua. This keeps the hover behavior intuitive:
-- if it would be easy to click something, it is also easy to hover it.
local function findHoveredEntity(ctx)
    local enemyModule = ctx.enemyModule
    local asteroidModule = ctx.asteroidModule
    local camera = ctx.camera

    if not enemyModule or not asteroidModule or not camera then
        return nil
    end

    -- Read mouse position in screen-space and convert to world-space so we
    -- can compare directly against entity positions.
    local sx, sy = love.mouse.getPosition()
    local worldX, worldY = camera.screenToWorld(sx, sy)

    -- Padding radius (in world units) applied on top of each entity's
    -- collision radius/size. This matches the click selection radius so
    -- hovering and clicking are consistent.
    local paddingRadius = (config.input and config.input.selectionRadius) or 0

    local closestEntity = nil
    local closestDistSq = nil

    local function considerEntity(e)
        if not e or not e.x or not e.y then
            return
        end

        local dx = e.x - worldX
        local dy = e.y - worldY
        local distSq = dx * dx + dy * dy

        -- Approximate the entity's physical size. Prefer any explicit
        -- bounding radius (for ships), then collision radius, then size.
        local entityRadius = 0
        if e.ship and e.ship.boundingRadius then
            entityRadius = e.ship.boundingRadius
        else
            entityRadius = e.collisionRadius or e.size or 0
        end

        local hitRadius = entityRadius + paddingRadius
        if hitRadius <= 0 then
            hitRadius = paddingRadius
        end

        if hitRadius > 0 then
            local hitRadiusSq = hitRadius * hitRadius
            if distSq <= hitRadiusSq and (not closestDistSq or distSq < closestDistSq) then
                closestDistSq = distSq
                closestEntity = e
            end
        end
    end

    -- Check all active enemies
    for _, e in ipairs(enemyModule.list or {}) do
        considerEntity(e)
    end

    -- Check all active asteroids
    for _, a in ipairs(asteroidModule.list or {}) do
        considerEntity(a)
    end

    return closestEntity
end

local function drawTargetIndicator(colors, combatSystem, camera)
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

        love.graphics.setColor(colors.white)
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

    local showWorldLockLabel = false
    if showWorldLockLabel then
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
end

local function drawWorldObjects(ctx)
    local player = ctx.player
    local playerModule = ctx.playerModule
    local asteroidModule = ctx.asteroidModule
    local itemModule = ctx.itemModule
    local projectileModule = ctx.projectileModule
    local projectileShards = ctx.projectileShards
    local enemyModule = ctx.enemyModule
    local engineTrail = ctx.engineTrail
    local particlesModule = ctx.particlesModule
    local explosionFx = ctx.explosionFx
    local floatingText = ctx.floatingText
    local colors = ctx.colors
    local camera = ctx.camera
    local gameState = ctx.gameState

    -- Determine which entity (if any) is currently hovered by the mouse
    -- cursor. We only compute this while the game is active; during menus or
    -- game over the hover outline is suppressed.
    local hoveredEntity = nil
    if gameState == "playing" or gameState == "paused" then
        hoveredEntity = findHoveredEntity(ctx)
    end

    drawMovementIndicator(player, colors)
    asteroidModule.draw(camera)
    if itemModule and itemModule.draw then
        itemModule.draw(colors)
    end
    projectileModule.draw(colors)
    projectileShards.draw()
    enemyModule.draw(colors)
    
    if gameState == "playing" or gameState == "paused" then
        engineTrail.draw()
        playerModule.draw(colors)
    end

    -- Draw a cyan outline around the hovered entity so that the player gets
    -- immediate visual feedback about what their mouse is currently over.
    -- This outline is rendered after ships/asteroids but before particles
    -- and explosions so that combat effects can still sit on top.
    if hoveredEntity then
        local radius = 0
        if hoveredEntity.ship and hoveredEntity.ship.boundingRadius then
            radius = hoveredEntity.ship.boundingRadius
        else
            radius = hoveredEntity.collisionRadius or hoveredEntity.size or 0
        end

        if radius and radius > 0 then
            local outlineColor = colors.hoverOutline or {0.3, 0.95, 1.0, 0.95}
            love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
            love.graphics.setLineWidth(2)
            -- Slight padding so the outline sits just outside the visual body
            love.graphics.circle("line", hoveredEntity.x, hoveredEntity.y, radius + 6)
        end
    end

    -- Draw impact / explosion particles on top so they are clearly visible
    local cameraScale = (camera and camera.scale) or 1.0
    particlesModule.draw(cameraScale)
    explosionFx.draw()
    floatingText.draw()
end

local function drawOverlay(ctx)
    local ui = ctx.ui
    local player = ctx.player
    local colors = ctx.colors
    local gameState = ctx.gameState
    local combatSystem = ctx.combatSystem
    local camera = ctx.camera
    local pauseMenu = ctx.pauseMenu

    drawTargetIndicator(colors, combatSystem, camera)
    ui.drawHUD(player, colors)
    
    if gameState == "gameover" then
        ui.drawGameOver(player)
    elseif gameState == "paused" then
        ui.drawPause(player, colors, pauseMenu)
    end
end

function game_render.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/lock_on.glsl")
    if ok then
        lockOnShader = shader
    end
end

function game_render.draw(ctx)
    local camera = ctx.camera
    beginWorldTransform(camera)
    drawWorldObjects(ctx)
    endWorldTransform()

    drawOverlay(ctx)
end

return game_render
