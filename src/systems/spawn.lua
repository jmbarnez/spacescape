local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local world = require("src.core.world")

local spawn = {
    spawnTimer = 0,
    spawnInterval = 2,
    initialEnemyCount = 15,
    initialAsteroidCount = 80,
    safeEnemyRadius = 2500
}

local function spawnInitialEnemies()
    for i = 1, spawn.initialEnemyCount do
        enemyModule.spawn(world, spawn.safeEnemyRadius)
    end
end

local function spawnInitialAsteroids()
    asteroidModule.populate(world, spawn.initialAsteroidCount)
end

function spawn.update(dt)
end

function spawn.reset()
    spawn.spawnTimer = 0
    spawn.spawnInterval = 2
    spawnInitialEnemies()
    spawnInitialAsteroids()
end

return spawn
