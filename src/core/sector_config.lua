local config = require("src.core.config")
local rng = require("src.utils.rng")

local sector_config = {}

local function loadSectorDefinition()
    local id = (config.sectors and config.sectors.definitionId) or "initial"
    local ok, def = pcall(require, "src.data.sectors." .. tostring(id))
    if ok and type(def) == "table" then
        return def
    end
    return nil
end

local sectorDefinition = loadSectorDefinition()

local function getSectorSize()
    if sectorDefinition and sectorDefinition.size then
        return tonumber(sectorDefinition.size) or ((config.sectors and config.sectors.size) or 800)
    end
    return (config.sectors and config.sectors.size) or 800
end

function sector_config.getSectorIndex(x, y)
    local size = getSectorSize()

    -- Center sector (0,0) on world origin so the initial world bounds
    -- [-size/2..+size/2] map cleanly to a single sector.
    local eps = 1e-6
    local sx = math.floor(((x or 0) + size / 2 - eps) / size)
    local sy = math.floor(((y or 0) + size / 2 - eps) / size)
    return sx, sy, size
end

function sector_config.getSectorBounds(sx, sy)
    local size = getSectorSize()
    local originX = (sx or 0) * size - size / 2
    local originY = (sy or 0) * size - size / 2
    return {
        minX = originX,
        maxX = originX + size,
        minY = originY,
        maxY = originY + size,
        size = size,
    }
end

function sector_config.getSectorKey(sx, sy)
    return tostring(sx) .. ":" .. tostring(sy)
end

local function classifySector(seed, sx, sy)
    local v = rng.hash01(seed, sx, sy)

    if v < 0.14 then
        return "empty"
    end
    if v < 0.55 then
        return "sparse"
    end
    if v < 0.85 then
        return "belt"
    end

    return "rich"
end

function sector_config.getAsteroidSectorConfig(sx, sy)
    -- If we're using an authored sector definition, only that sector is active.
    if sectorDefinition and sectorDefinition.asteroids then
        if (sx or 0) ~= 0 or (sy or 0) ~= 0 then
            return {
                sectorType = "empty",
                sizeMin = (config.asteroid and config.asteroid.minSize) or 20,
                sizeMax = (config.asteroid and config.asteroid.maxSize) or 70,
                driftSpeedMin = (config.physics and config.physics.asteroidMinDrift) or 0.6,
                driftSpeedMax = (config.physics and config.physics.asteroidMaxDrift) or 4.5,
                rotationSpeedRange = (config.asteroid and config.asteroid.rotationSpeedRange) or 0.09,
                edgeMargin = (sectorDefinition.asteroids.edgeMargin) or ((config.sectors and config.sectors.edgeMargin) or 90),
                minSeparation = (sectorDefinition.asteroids.minSeparation) or ((config.sectors and config.sectors.minSeparation) or 10),
                variantWeights = { ice = 1.0 },
                countMin = 0,
                countMax = 0,
                pattern = "uniform",
            }
        end

        local a = sectorDefinition.asteroids
        return {
            sectorType = "defined",
            sizeMin = (config.asteroid and config.asteroid.minSize) or 20,
            sizeMax = (config.asteroid and config.asteroid.maxSize) or 70,
            driftSpeedMin = (config.physics and config.physics.asteroidMinDrift) or 0.6,
            driftSpeedMax = (config.physics and config.physics.asteroidMaxDrift) or 4.5,
            rotationSpeedRange = (config.asteroid and config.asteroid.rotationSpeedRange) or 0.09,
            edgeMargin = (a.edgeMargin) or ((config.sectors and config.sectors.edgeMargin) or 90),
            minSeparation = (a.minSeparation) or ((config.sectors and config.sectors.minSeparation) or 10),
            variantWeights = (a.variantWeights) or { ice = 1.0 },
            countMin = tonumber(a.countMin) or 0,
            countMax = tonumber(a.countMax) or (tonumber(a.countMin) or 0),
            pattern = a.pattern or "uniform",
        }
    end

    local seed = (config.sectors and config.sectors.seed) or 1337
    local sectorType = classifySector(seed, sx, sy)

    if math.abs(sx or 0) <= 1 and math.abs(sy or 0) <= 1 then
        if sectorType == "empty" then
            sectorType = "sparse"
        end
    end

    local base = {
        sectorType = sectorType,
        sizeMin = (config.asteroid and config.asteroid.minSize) or 20,
        sizeMax = (config.asteroid and config.asteroid.maxSize) or 70,
        driftSpeedMin = (config.physics and config.physics.asteroidMinDrift) or 0.6,
        driftSpeedMax = (config.physics and config.physics.asteroidMaxDrift) or 4.5,
        rotationSpeedRange = (config.asteroid and config.asteroid.rotationSpeedRange) or 0.09,
        edgeMargin = (config.sectors and config.sectors.edgeMargin) or 90,
        minSeparation = (config.sectors and config.sectors.minSeparation) or 10,
        variantWeights = {
            ice = 1.0,
        },
        countMin = 0,
        countMax = 0,
        pattern = "uniform",
    }

    if sectorType == "empty" then
        base.countMin = 0
        base.countMax = 2
        base.variantWeights = { ice = 1.0 }
        base.pattern = "uniform"
    elseif sectorType == "sparse" then
        base.countMin = 3
        base.countMax = 10
        base.variantWeights = { ice = 0.90, mithril_ore = 0.10 }
        base.pattern = "uniform"
    elseif sectorType == "belt" then
        base.countMin = 10
        base.countMax = 22
        base.variantWeights = { ice = 0.90, mithril_ore = 0.10 }
        base.pattern = "belt"
    elseif sectorType == "rich" then
        base.countMin = 14
        base.countMax = 30
        base.variantWeights = { ice = 0.84, mithril_ore = 0.16 }
        base.pattern = "cluster"
    end

    return base
end

return sector_config
