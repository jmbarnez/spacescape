local enemyModule = require("src.entities.enemy")
local world = require("src.core.world")

local spawn = {
    spawnTimer = 0,
    spawnInterval = 2,
    initialEnemyCount = 15
}

local function spawnInitialEnemies()
    for i = 1, spawn.initialEnemyCount do
        enemyModule.spawn(world)
    end
end

function spawn.update(dt)
end

function spawn.reset()
    spawn.spawnTimer = 0
    spawn.spawnInterval = 2
    spawnInitialEnemies()
end

return spawn
