local enemyModule = require("src.entities.enemy")
local projectileModule = require("src.entities.projectile")

local combat = {}

local enemies = enemyModule.list

local targetEnemy = nil
local fireTimer = 0
local fireInterval = 0.3

local function isEnemyValid(e)
    if not e then
        return false
    end

    for i = 1, #enemies do
        if enemies[i] == e then
            return true
        end
    end

    return false
end

local function findEnemyAtPosition(x, y, maxRadius)
    local closestEnemy = nil
    local closestDistSq = nil
    local maxRadiusSq = maxRadius and maxRadius * maxRadius or nil

    for _, e in ipairs(enemies) do
        local dx = e.x - x
        local dy = e.y - y
        local distSq = dx * dx + dy * dy

        if (not maxRadiusSq or distSq <= maxRadiusSq) and (not closestDistSq or distSq < closestDistSq) then
            closestDistSq = distSq
            closestEnemy = e
        end
    end

    return closestEnemy
end

function combat.updateAutoShoot(dt, player)
    if not targetEnemy or not isEnemyValid(targetEnemy) then
        targetEnemy = nil
        fireTimer = 0
        return
    end

    fireTimer = fireTimer + dt
    local interval = fireInterval
    if player.weapon and player.weapon.fireInterval then
        interval = player.weapon.fireInterval
    end

    if fireTimer >= interval then
        fireTimer = 0
        projectileModule.spawn(player, targetEnemy.x, targetEnemy.y)
    end
end

function combat.handleLeftClick(worldX, worldY, selectionRadius)
    local enemy = findEnemyAtPosition(worldX, worldY, selectionRadius)

    if enemy then
        targetEnemy = enemy
        fireTimer = 0
    else
        targetEnemy = nil
    end
end

function combat.shoot(player, targetX, targetY)
    projectileModule.spawn(player, targetX, targetY)
end

function combat.getTargetEnemy()
    if isEnemyValid(targetEnemy) then
        return targetEnemy
    end

    return nil
end

function combat.reset()
    targetEnemy = nil
    fireTimer = 0
end

return combat
