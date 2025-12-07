local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local world = require("src.core.world")
local config = require("src.core.config")

local spawn = {
    spawnTimer = 0,
    spawnInterval = config.spawn.spawnInterval,
    initialEnemyCount = config.spawn.initialEnemyCount,
    initialAsteroidCount = config.spawn.initialAsteroidCount,
    safeEnemyRadius = config.spawn.safeEnemyRadius,
    maxEnemies = config.spawn.maxEnemies,
    enemiesPerSpawn = config.spawn.enemiesPerSpawn,
}

local function spawnEnemies(count)
    for i = 1, count do
        enemyModule.spawn(world, spawn.safeEnemyRadius)
    end
end

local function spawnInitialEnemies()
    spawnEnemies(spawn.initialEnemyCount)
end

local function spawnInitialAsteroids()
    asteroidModule.populate(world, spawn.initialAsteroidCount)
end

function spawn.update(dt)
    spawn.spawnTimer = spawn.spawnTimer + dt

    local enemies = enemyModule.list
    local enemyCount = enemies and #enemies or 0
    local maxEnemies = spawn.maxEnemies or enemyCount

    if enemyCount >= maxEnemies then
        return
    end

    while spawn.spawnTimer >= spawn.spawnInterval do
        spawn.spawnTimer = spawn.spawnTimer - spawn.spawnInterval

        enemyCount = enemies and #enemies or 0
        if enemyCount >= maxEnemies then
            break
        end

        local toSpawn = spawn.enemiesPerSpawn or 1
        for i = 1, toSpawn do
            enemyCount = enemies and #enemies or 0
            if enemyCount >= maxEnemies then
                break
            end
            enemyModule.spawn(world, spawn.safeEnemyRadius)
        end
    end
end

function spawn.reset()
    spawn.spawnTimer = 0
    spawn.spawnInterval = config.spawn.spawnInterval
    spawnInitialEnemies()
    spawnInitialAsteroids()
end

return spawn
