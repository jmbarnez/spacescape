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
    local closestEnemy = nil
    local closestDistSq = nil
    local maxRadiusSq = maxRadius and maxRadius * maxRadius or nil

    local function considerEntity(e)
        local dx = e.x - x
        local dy = e.y - y
        local distSq = dx * dx + dy * dy

        if (not maxRadiusSq or distSq <= maxRadiusSq) and (not closestDistSq or distSq < closestDistSq) then
            closestDistSq = distSq
            closestEnemy = e
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

function combat.reset()
    targetEnemy = nil
    fireTimer = 0
    lockTarget = nil
    lockTimer = 0
end

return combat
