local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local projectileModule = require("src.entities.projectile")
local config = require("src.core.config")

local combat = {}

local enemies = enemyModule.list
local asteroids = asteroidModule.list

local targetEnemy = nil
local fireTimer = 0
local fireInterval = config.combat.fireInterval
local lockTarget = nil
local lockTimer = 0
local lockDuration = config.combat.lockDuration

local function isEnemyValid(e)
    if not e then
        return false
    end

    for i = 1, #enemies do
        if enemies[i] == e then
            return true
        end
    end

    for i = 1, #asteroids do
        if asteroids[i] == e then
            return true
        end
    end

    return false
end

local function findEnemyAtPosition(x, y, maxRadius)
    -- NOTE: "maxRadius" here is treated as a *padding* value around the
    --       natural size of the entity. The effective click radius is:
    --          entityRadius + maxRadius
    --       where entityRadius comes from collisionRadius/size. This means
    --       you no longer have to click the exact center of an enemy or
    --       asteroid; clicking anywhere within its visible body (plus a
    --       small buffer) will select it.

    local closestEnemy = nil
    local closestDistSq = nil

    local function considerEntity(e)
        local dx = e.x - x
        local dy = e.y - y
        local distSq = dx * dx + dy * dy

        -- Derive an approximate radius for the entity. This prefers
        -- collisionRadius (physics / hitbox) but falls back to size if
        -- needed. If both are nil/zero we will only use the padding radius.
        local entityRadius = e.collisionRadius or e.size or 0

        -- Config-driven padding radius. This is the "selectionRadius" that
        -- input.lua passes in, used as a buffer so you don't have to click
        -- pixel-perfect on small targets.
        local paddingRadius = maxRadius or 0

        -- Effective hit radius for this entity. Large objects (big
        -- asteroids, capital ships) get a correspondingly large clickable
        -- area; tiny objects still get at least the padding radius.
        local hitRadius = entityRadius + paddingRadius
        if hitRadius <= 0 then
            hitRadius = paddingRadius
        end

        if hitRadius > 0 then
            local hitRadiusSq = hitRadius * hitRadius
            if distSq <= hitRadiusSq and (not closestDistSq or distSq < closestDistSq) then
                closestDistSq = distSq
                closestEnemy = e
            end
        end
    end

    for _, e in ipairs(enemies) do
        considerEntity(e)
    end

    for _, a in ipairs(asteroids) do
        considerEntity(a)
    end

    return closestEnemy
end

function combat.updateAutoShoot(dt, player)
    if lockTarget and not isEnemyValid(lockTarget) then
        lockTarget = nil
        lockTimer = 0
    end

    if targetEnemy and not isEnemyValid(targetEnemy) then
        targetEnemy = nil
        fireTimer = 0
    end

    if lockTarget and not targetEnemy then
        lockTimer = lockTimer + dt
        if lockDuration > 0 and lockTimer >= lockDuration then
            lockTimer = lockDuration
            targetEnemy = lockTarget
            fireTimer = 0
        end
    end

    if not targetEnemy then
        return
    end

    fireTimer = fireTimer + dt
    local interval = fireInterval
    if player.weapon and player.weapon.fireInterval then
        interval = player.weapon.fireInterval
    end

    local bonus = player.attackSpeedBonus or 0
    if bonus > 0 then
        interval = interval / (1 + bonus)
    end

    if fireTimer >= interval then
        fireTimer = 0
        projectileModule.spawn(player, targetEnemy.x, targetEnemy.y, targetEnemy)
    end
end

function combat.handleLeftClick(worldX, worldY, selectionRadius)
    local enemy = findEnemyAtPosition(worldX, worldY, selectionRadius)

    if enemy then
        if enemy ~= targetEnemy then
            lockTarget = enemy
            lockTimer = 0
            targetEnemy = nil
            fireTimer = 0
        end
    else
        targetEnemy = nil
        lockTarget = nil
        lockTimer = 0
        fireTimer = 0
    end
end

function combat.getTargetEnemy()
    if isEnemyValid(targetEnemy) then
        return targetEnemy
    end

    return nil
end

function combat.getLockStatus()
    if lockTarget and isEnemyValid(lockTarget) then
        return lockTarget, lockTimer, lockDuration, targetEnemy
    end

    return nil
end

-- Returns the entity that should be considered the "current HUD target",
-- along with lock state flags so UI code can present targeting information.
-- This mirrors the logic used by the world-space lock indicator in
-- states/game_render.lua (drawTargetIndicator).
--
-- Returns:
--   targetEntity or nil,
--   isLocked (boolean),
--   isLocking (boolean),
--   progress (0..1 lock progress)
function combat.getCurrentHudTarget()
    local currentTarget = nil
    local isLocking = false
    local isLocked = false
    local progress = 0

    -- First, resolve which entity we are visually focusing on
    if lockTarget and isEnemyValid(lockTarget) and (not targetEnemy or lockTarget ~= targetEnemy) then
        currentTarget = lockTarget
        if lockDuration and lockDuration > 0 then
            progress = math.max(0, math.min(1, lockTimer / lockDuration))
            isLocking = true
        end
    elseif targetEnemy and isEnemyValid(targetEnemy) then
        currentTarget = targetEnemy
    end

    -- Determine locked state
    if currentTarget and not isLocking and targetEnemy and currentTarget == targetEnemy then
        isLocked = true
        progress = 1
    end

    return currentTarget, isLocked, isLocking, progress
end

function combat.reset()
    targetEnemy = nil
    fireTimer = 0
    lockTarget = nil
    lockTimer = 0
end

return combat
