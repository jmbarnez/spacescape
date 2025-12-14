local config = require("src.core.config")
local world = require("src.core.world")
local ecsWorld = require("src.ecs.world")

local asteroidModule = require("src.entities.asteroid")
local playerModule = require("src.entities.player")

local spawn = {}

-- Internal timer for periodic enemy spawns.
local spawnTimer = 0

local function getEnemyEntities()
    local ships = ecsWorld:query({ "ship", "faction", "position" }) or {}
    local enemies = {}
    for _, e in ipairs(ships) do
        if e.faction and e.faction.name == "enemy" and not e._removed and not e.removed then
            table.insert(enemies, e)
        end
    end
    return enemies
end

local function safeDestroyEcsEntity(e)
    if not e then
        return
    end

    if e.physics and e.physics.body then
        pcall(function()
            if e.physics.body.isDestroyed and not e.physics.body:isDestroyed() then
                e.physics.body:destroy()
            end
        end)
    end

    if e.destroy then
        e:destroy()
    end
end

-- Helper: get a stable player position for spawn calculations.
local function getPlayerPos()
    local p = playerModule and playerModule.getEntity and playerModule.getEntity() or nil
    if not p then
        return world.centerX or 0, world.centerY or 0
    end
    local px = (p.position and p.position.x) or p.x or (world.centerX or 0)
    local py = (p.position and p.position.y) or p.y or (world.centerY or 0)
    return px, py
end

-- Helper: pick a random point in the world bounds, attempting to stay outside
-- a safety radius around the player.
local function pickSpawnPointOutsideRadius(minRadius)
    local margin = (config.enemy and config.enemy.spawnMargin) or 50
    local cx, cy = getPlayerPos()

    local minX = (world.minX or 0) + margin
    local maxX = (world.maxX or 0) - margin
    local minY = (world.minY or 0) + margin
    local maxY = (world.maxY or 0) - margin

    -- Avoid invalid bounds (can happen if world is not initialized yet).
    if maxX <= minX or maxY <= minY then
        return cx, cy
    end

    local minRadiusSq = (minRadius or 0) ^ 2

    -- Try a few times to find a point outside the safety radius.
    for _ = 1, 30 do
        local x = math.random(minX, maxX)
        local y = math.random(minY, maxY)

        if minRadiusSq <= 0 then
            return x, y
        end

        local dx = x - cx
        local dy = y - cy
        if (dx * dx + dy * dy) >= minRadiusSq then
            return x, y
        end
    end

    -- Fallback: just return any point.
    return math.random(minX, maxX), math.random(minY, maxY)
end

local function spawnOneEnemy()
    local safeRadius = (config.spawn and config.spawn.safeEnemyRadius) or 0
    local x, y = pickSpawnPointOutsideRadius(safeRadius)

    ecsWorld:spawnEnemy(x, y, nil)
end

-- Reset spawn state and (re)populate initial entities.
function spawn.reset()
    spawnTimer = 0

    -- Reset the population so restarts are deterministic and don't accumulate.
    local enemies = getEnemyEntities()
    for i = #enemies, 1, -1 do
        safeDestroyEcsEntity(enemies[i])
    end

    if asteroidModule.populate then
        asteroidModule.populate(world, config.spawn and config.spawn.initialAsteroidCount or 0)
    end

    local initialEnemies = (config.spawn and config.spawn.initialEnemyCount) or 0
    for _ = 1, initialEnemies do
        spawnOneEnemy()
    end
end

-- Periodic spawning: keep enemies topped up to a configured maximum.
function spawn.update(dt)
    local interval = (config.spawn and config.spawn.spawnInterval) or 0
    if interval <= 0 then
        return
    end

    spawnTimer = spawnTimer + (dt or 0)

    while spawnTimer >= interval do
        spawnTimer = spawnTimer - interval

        local enemies = getEnemyEntities()
        local maxEnemies = (config.spawn and config.spawn.maxEnemies) or 0
        if maxEnemies > 0 and #enemies >= maxEnemies then
            -- Already at cap.
            break
        end

        local perSpawn = (config.spawn and config.spawn.enemiesPerSpawn) or 1
        if perSpawn < 1 then
            perSpawn = 1
        end

        for _ = 1, perSpawn do
            enemies = getEnemyEntities()
            if maxEnemies > 0 and #enemies >= maxEnemies then
                break
            end
            spawnOneEnemy()
        end
    end
end

return spawn
