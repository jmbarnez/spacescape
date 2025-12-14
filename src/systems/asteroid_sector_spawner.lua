local config = require("src.core.config")
local ecsWorld = require("src.ecs.world")
local sectorConfig = require("src.core.sector_config")
local intentGenerator = require("src.utils.asteroid_intent_generator")

local spawner = {}

local spawnedIds = {}
local sectorCache = {}

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

local function getPlayerPos(player)
    if not player then
        return 0, 0
    end

    local px = (player.position and player.position.x) or player.x or 0
    local py = (player.position and player.position.y) or player.y or 0
    return px, py
end

local function isSectorActive(activeSet, key)
    return activeSet[key] == true
end

function spawner.reset()
    spawnedIds = {}
    sectorCache = {}

    local asteroids = ecsWorld:query({ "asteroid" }) or {}
    for i = #asteroids, 1, -1 do
        safeDestroyEcsEntity(asteroids[i])
    end
end

function spawner.update(dt, ctx)
    if not (config.sectors and config.sectors.enabled) then
        return
    end

    if not ctx then
        return
    end

    local player = ctx.player
    local px, py = getPlayerPos(player)

    local radius = (config.sectors and config.sectors.activeRadius) or 2
    local cullRadius = (config.sectors and config.sectors.cullRadius) or (radius + 1)

    local csx, csy = sectorConfig.getSectorIndex(px, py)

    local active = {}

    local function ensureSectorCached(sx, sy)
        local key = sectorConfig.getSectorKey(sx, sy)
        if sectorCache[key] then
            return key, sectorCache[key].cfg, sectorCache[key].intents
        end

        local _, cfg, intents = intentGenerator.generateSectorIntents(sx, sy)
        sectorCache[key] = {
            cfg = cfg,
            intents = intents,
        }
        return key, cfg, intents
    end

    for sy = csy - radius, csy + radius do
        for sx = csx - radius, csx + radius do
            local key, _, intents = ensureSectorCached(sx, sy)
            active[key] = true

            if not spawnedIds[key] then
                spawnedIds[key] = {}
            end

            for i = 1, #intents do
                local intent = intents[i]
                if not spawnedIds[key][intent.id] then
                    local e = ecsWorld:spawnAsteroid(intent.x, intent.y, intent.data, intent.size)

                    if e and e.velocity then
                        e.velocity.vx = intent.vx or 0
                        e.velocity.vy = intent.vy or 0
                    end

                    if e and e.rotation and intent.rotationAngle ~= nil then
                        e.rotation.angle = intent.rotationAngle
                        e.rotation.targetAngle = intent.rotationAngle
                    end

                    if e then
                        e.rotationSpeed = intent.rotationSpeed or 0
                        e.asteroidVariant = intent.variant
                        e.spawnId = intent.id
                        e.sectorKey = key
                    end

                    spawnedIds[key][intent.id] = true
                end
            end
        end
    end

    for key, _ in pairs(sectorCache) do
        local sxStr, syStr = tostring(key):match("^([^:]+):([^:]+)$")
        local sx = tonumber(sxStr)
        local sy = tonumber(syStr)

        if sx and sy then
            local dsx = math.abs(sx - csx)
            local dsy = math.abs(sy - csy)
            if dsx > cullRadius or dsy > cullRadius then
                sectorCache[key] = nil
                spawnedIds[key] = nil
            end
        end
    end

    local asteroids = ecsWorld:query({ "asteroid", "position" }) or {}

    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        if a and not a._removed and not a.removed then
            local ax = a.position and a.position.x or 0
            local ay = a.position and a.position.y or 0
            local akey = a.sectorKey
            local asx, asy
            if not akey then
                asx, asy = sectorConfig.getSectorIndex(ax, ay)
                akey = sectorConfig.getSectorKey(asx, asy)
            else
                local sxStr, syStr = tostring(akey):match("^([^:]+):([^:]+)$")
                asx = tonumber(sxStr)
                asy = tonumber(syStr)
            end

            asx = asx or select(1, sectorConfig.getSectorIndex(ax, ay))
            asy = asy or select(2, sectorConfig.getSectorIndex(ax, ay))

            local dsx = math.abs(asx - csx)
            local dsy = math.abs(asy - csy)

            if dsx > cullRadius or dsy > cullRadius then
                if not isSectorActive(active, akey) then
                    safeDestroyEcsEntity(a)
                end
            end
        end
    end
end

return spawner
