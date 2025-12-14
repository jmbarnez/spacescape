local config = require("src.core.config")
local rngLib = require("src.utils.rng")
local sectorConfig = require("src.core.sector_config")
local asteroid_generator = require("src.utils.procedural_asteroid_generator")
local mithrilItem = require("src.data.items.mithril")

local generator = {}

local function applyVariantVisuals(variant, asteroidData)
    if not asteroidData then
        return
    end

    if variant == "mithril_ore" then
        -- Darker blue glow so it reads as deep ore seepage instead of bright cyan.
        asteroidData.glowColor = { 0.18, 0.10, 0.72 }
        asteroidData.glowStrength = 3.0
    end
end

local function pickWeighted(rng, weights)
    local total = 0
    for _, w in pairs(weights or {}) do
        total = total + (tonumber(w) or 0)
    end

    if total <= 0 then
        return "ice"
    end

    local roll = rng:range(0, total)
    local acc = 0
    for k, w in pairs(weights) do
        acc = acc + (tonumber(w) or 0)
        if roll <= acc then
            return k
        end
    end

    return "ice"
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function tryPlace(points, x, y, r, minSep)
    local sep = minSep or 0
    local rr = r + sep
    local rrSq = rr * rr

    for i = 1, #points do
        local p = points[i]
        local dx = x - p.x
        local dy = y - p.y
        local minD = rr + p.r
        if (dx * dx + dy * dy) < (minD * minD) then
            return false
        end
    end

    table.insert(points, { x = x, y = y, r = r })
    return true
end

local function buildVariantOptions(variant, rng)
    if variant == "mithril_ore" then
        return {
            composition = {
                mithrilChance = 1.0,
                minMithrilShare = 0.78,
                maxMithrilShare = 1.00,
                baseRockVsIce = 0.1 + rng:range(0, 0.6),
            },
            rng = function()
                return rng:next()
            end,
        }
    end

    return {
        composition = {
            mithrilChance = 0.0,
            baseRockVsIce = 0.05 + rng:range(0, 0.35),
        },
        rng = function()
            return rng:next()
        end,
    }
end

local function generateUniform(intents, points, sectorOriginX, sectorOriginY, size, cfg, rng)
    local margin = cfg.edgeMargin or 0
    local minX = sectorOriginX + margin
    local maxX = sectorOriginX + size - margin
    local minY = sectorOriginY + margin
    local maxY = sectorOriginY + size - margin

    local attemptsPerAsteroid = 25

    for i = 1, cfg.count do
        local placed = false

        local variant = pickWeighted(rng, cfg.variantWeights)
        local aSize = rng:range(cfg.sizeMin, cfg.sizeMax)
        local radius = aSize

        for _ = 1, attemptsPerAsteroid do
            local x = rng:range(minX, maxX)
            local y = rng:range(minY, maxY)

            if tryPlace(points, x, y, radius, cfg.minSeparation) then
                local driftSpeed = rng:range(cfg.driftSpeedMin, cfg.driftSpeedMax)
                local driftAngle = rng:range(0, math.pi * 2)
                local rotationAngle = rng:range(0, math.pi * 2)
                local rotationSpeed = (rng:next() - 0.5) * cfg.rotationSpeedRange

                local options = buildVariantOptions(variant, rng)
                local data = asteroid_generator.generate(aSize, options)
                applyVariantVisuals(variant, data)

                table.insert(intents, {
                    x = x,
                    y = y,
                    size = aSize,
                    variant = variant,
                    vx = math.cos(driftAngle) * driftSpeed,
                    vy = math.sin(driftAngle) * driftSpeed,
                    rotationAngle = rotationAngle,
                    rotationSpeed = rotationSpeed,
                    data = data,
                    index = i,
                })

                placed = true
                break
            end
        end

        if not placed then
            local x = rng:range(minX, maxX)
            local y = rng:range(minY, maxY)
            local driftSpeed = rng:range(cfg.driftSpeedMin, cfg.driftSpeedMax)
            local driftAngle = rng:range(0, math.pi * 2)
            local rotationAngle = rng:range(0, math.pi * 2)
            local rotationSpeed = (rng:next() - 0.5) * cfg.rotationSpeedRange

            local options = buildVariantOptions(variant, rng)
            local data = asteroid_generator.generate(aSize, options)
            applyVariantVisuals(variant, data)

            table.insert(intents, {
                x = x,
                y = y,
                size = aSize,
                variant = variant,
                vx = math.cos(driftAngle) * driftSpeed,
                vy = math.sin(driftAngle) * driftSpeed,
                rotationAngle = rotationAngle,
                rotationSpeed = rotationSpeed,
                data = data,
                index = i,
            })
        end
    end
end

local function generateBelt(intents, points, sectorOriginX, sectorOriginY, size, cfg, rng)
    local margin = cfg.edgeMargin or 0
    local minX = sectorOriginX + margin
    local maxX = sectorOriginX + size - margin
    local minY = sectorOriginY + margin
    local maxY = sectorOriginY + size - margin

    local laneCount = clamp(rng:int(2, 4), 1, 6)
    local lanes = {}
    for i = 1, laneCount do
        local t = (i - 0.5) / laneCount
        local y = minY + t * (maxY - minY)
        lanes[i] = y
    end

    for i = 1, cfg.count do
        local variant = pickWeighted(rng, cfg.variantWeights)
        local aSize = rng:range(cfg.sizeMin, cfg.sizeMax)
        local radius = aSize

        local lane = lanes[rng:int(1, laneCount)]
        local x = rng:range(minX, maxX)
        local y = lane + rng:range(-size * 0.06, size * 0.06)

        y = clamp(y, minY, maxY)

        if not tryPlace(points, x, y, radius, cfg.minSeparation) then
            x = rng:range(minX, maxX)
            y = rng:range(minY, maxY)
            tryPlace(points, x, y, radius, 0)
        end

        local driftSpeed = rng:range(cfg.driftSpeedMin, cfg.driftSpeedMax)
        local driftAngle = rng:range(0, math.pi * 2)
        local rotationAngle = rng:range(0, math.pi * 2)
        local rotationSpeed = (rng:next() - 0.5) * cfg.rotationSpeedRange

        local options = buildVariantOptions(variant, rng)
        local data = asteroid_generator.generate(aSize, options)
        applyVariantVisuals(variant, data)

        table.insert(intents, {
            x = x,
            y = y,
            size = aSize,
            variant = variant,
            vx = math.cos(driftAngle) * driftSpeed,
            vy = math.sin(driftAngle) * driftSpeed,
            rotationAngle = rotationAngle,
            rotationSpeed = rotationSpeed,
            data = data,
            index = i,
        })
    end
end

local function generateCluster(intents, points, sectorOriginX, sectorOriginY, size, cfg, rng)
    local margin = cfg.edgeMargin or 0
    local minX = sectorOriginX + margin
    local maxX = sectorOriginX + size - margin
    local minY = sectorOriginY + margin
    local maxY = sectorOriginY + size - margin

    local clusterCount = clamp(rng:int(2, 4), 1, 6)
    local clusters = {}
    for i = 1, clusterCount do
        clusters[i] = {
            x = rng:range(minX, maxX),
            y = rng:range(minY, maxY),
        }
    end

    for i = 1, cfg.count do
        local variant = pickWeighted(rng, cfg.variantWeights)
        local aSize = rng:range(cfg.sizeMin, cfg.sizeMax)
        local radius = aSize

        local c = clusters[rng:int(1, clusterCount)]

        local spread = size * 0.18
        local x = c.x + rng:range(-spread, spread)
        local y = c.y + rng:range(-spread, spread)

        x = clamp(x, minX, maxX)
        y = clamp(y, minY, maxY)

        if not tryPlace(points, x, y, radius, cfg.minSeparation) then
            x = rng:range(minX, maxX)
            y = rng:range(minY, maxY)
            tryPlace(points, x, y, radius, 0)
        end

        local driftSpeed = rng:range(cfg.driftSpeedMin, cfg.driftSpeedMax)
        local driftAngle = rng:range(0, math.pi * 2)
        local rotationAngle = rng:range(0, math.pi * 2)
        local rotationSpeed = (rng:next() - 0.5) * cfg.rotationSpeedRange

        local options = buildVariantOptions(variant, rng)
        local data = asteroid_generator.generate(aSize, options)
        applyVariantVisuals(variant, data)

        table.insert(intents, {
            x = x,
            y = y,
            size = aSize,
            variant = variant,
            vx = math.cos(driftAngle) * driftSpeed,
            vy = math.sin(driftAngle) * driftSpeed,
            rotationAngle = rotationAngle,
            rotationSpeed = rotationSpeed,
            data = data,
            index = i,
        })
    end
end

function generator.generateSectorIntents(sx, sy)
    local sectorSeed = (config.sectors and config.sectors.seed) or 1337
    local key = sectorConfig.getSectorKey(sx, sy)

    local cfg = sectorConfig.getAsteroidSectorConfig(sx, sy)
    local bounds = sectorConfig.getSectorBounds(sx, sy)
    local size = (bounds and bounds.size) or ((config.sectors and config.sectors.size) or 800)

    local seedU32 = rngLib.hash2u32(sectorSeed, sx, sy)
    local rng = rngLib.new(seedU32)

    cfg.count = rng:int(cfg.countMin, cfg.countMax)

    local sectorOriginX = bounds and bounds.minX or (sx * size)
    local sectorOriginY = bounds and bounds.minY or (sy * size)

    local intents = {}
    local points = {}

    if cfg.count <= 0 then
        return key, cfg, intents
    end

    if cfg.pattern == "belt" then
        generateBelt(intents, points, sectorOriginX, sectorOriginY, size, cfg, rng)
    elseif cfg.pattern == "cluster" then
        generateCluster(intents, points, sectorOriginX, sectorOriginY, size, cfg, rng)
    else
        generateUniform(intents, points, sectorOriginX, sectorOriginY, size, cfg, rng)
    end

    for i = 1, #intents do
        intents[i].id = key .. ":" .. tostring(intents[i].index)
        intents[i].sectorKey = key
        intents[i].sx = sx
        intents[i].sy = sy
    end

    return key, cfg, intents
end

return generator
