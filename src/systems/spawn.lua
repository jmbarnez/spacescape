local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local world = require("src.core.world")

local spawn = {
    spawnTimer = 0,
    spawnInterval = 2,
    initialEnemyCount = 15,
    initialAsteroidCount = 80,
    safeEnemyRadius = 2500,
    maxEnemies = 40,
    enemiesPerSpawn = 1
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
    spawn.spawnInterval = 2
    spawnInitialEnemies()
    spawnInitialAsteroids()
end

return spawn
