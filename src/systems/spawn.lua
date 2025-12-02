local enemyModule = require("src.entities.enemy")
local world = require("src.core.world")

local spawn = {
    spawnTimer = 0,
    spawnInterval = 2
}

function spawn.update(dt)
    spawn.spawnTimer = spawn.spawnTimer + dt

    if spawn.spawnTimer >= spawn.spawnInterval then
        spawn.spawnTimer = 0
        enemyModule.spawn(world)

        spawn.spawnInterval = math.max(0.5, spawn.spawnInterval - 0.05)
    end
end

function spawn.reset()
    spawn.spawnTimer = 0
    spawn.spawnInterval = 2
end

return spawn
