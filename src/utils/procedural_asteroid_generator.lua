local asteroid_generator = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function flattenPoints(points)
    local flat = {}
    if not points then
        return flat
    end
    for i = 1, #points do
        local p = points[i]
        flat[#flat + 1] = p[1]
        flat[#flat + 1] = p[2]
    end
    return flat
end

local function computeBoundingRadius(points)
    local radius = 0
    if not points then
        return radius
    end
    for i = 1, #points do
        local p = points[i]
        local x, y = p[1], p[2]
        local d = math.sqrt(x * x + y * y)
        if d > radius then
            radius = d
        end
    end
    return radius
end

-------------------------------------------------------------------------------
-- Simplified asteroid material model
--
-- All asteroids are now generated as a mix of only three components:
--   * stone   - baseline rocky body
--   * ice     - volatile ices that brighten and cool the surface
--   * mithril - rare, valuable metal that only appears occasionally
--
-- The generator stores numeric fractions for these components so the rest of
-- the game (mining, loot, HUD text, etc.) can reason about them, while
-- rendering uses a blended color derived from the same composition data.
-------------------------------------------------------------------------------

local BASE_COLORS = {
    stone = {0.45, 0.38, 0.32},  -- neutral, slightly warm rock
    ice = {0.72, 0.80, 0.88},    -- bright, cool icy deposits
    mithril = {0.82, 0.96, 1.00} -- pale, luminous metal highlights
}

-- Build a stone/ice mix with an optional mithril component.
-- options.composition (optional) can override the defaults:
--   * mithrilChance   - probability [0, 1] of any mithril being present
--   * minMithrilShare - lower bound on mithril fraction when present
--   * maxMithrilShare - upper bound on mithril fraction when present
local function generateComposition(options)
    local compositionOptions = (options and options.composition) or {}

    local mithrilChance = compositionOptions.mithrilChance or 0.08
    local minMithrilShare = compositionOptions.minMithrilShare or 0.04
    local maxMithrilShare = compositionOptions.maxMithrilShare or 0.20

    -- Decide how much mithril this body has, if any.
    local mithrilShare = 0
    if math.random() < mithrilChance then
        local span = math.max(0, maxMithrilShare - minMithrilShare)
        mithrilShare = minMithrilShare + math.random() * span
    end

    -- Split the remaining mass between stone and ice.
    local baseRockVsIce = compositionOptions.baseRockVsIce or math.random()
    local remaining = math.max(0, 1.0 - mithrilShare)
    local stoneShare = remaining * baseRockVsIce
    local iceShare = remaining * (1.0 - baseRockVsIce)

    -- Normalize to make sure stone + ice + mithril = 1, even after overrides.
    local total = stoneShare + iceShare + mithrilShare
    if total <= 0 then
        stoneShare, iceShare, mithrilShare = 1, 0, 0
        total = 1
    end

    stoneShare = stoneShare / total
    iceShare = iceShare / total
    mithrilShare = mithrilShare / total

    return {
        stone = stoneShare,
        ice = iceShare,
        mithril = mithrilShare,
    }
end

-- Convert the numeric composition into a base RGB color that the draw
-- function can feed into its shading model. This keeps visuals and gameplay
-- in sync.
local function blendColorFromComposition(composition)
    composition = composition or {}

    local stoneShare = composition.stone or 0
    local iceShare = composition.ice or 0
    local mithrilShare = composition.mithril or 0

    local total = stoneShare + iceShare + mithrilShare
    if total <= 0 then
        stoneShare, iceShare, mithrilShare = 1, 0, 0
        total = 1
    end

    stoneShare = stoneShare / total
    iceShare = iceShare / total
    mithrilShare = mithrilShare / total

    local stoneColor = BASE_COLORS.stone
    local iceColor = BASE_COLORS.ice
    local mithrilColor = BASE_COLORS.mithril

    local r = stoneShare * stoneColor[1] + iceShare * iceColor[1] + mithrilShare * mithrilColor[1]
    local g = stoneShare * stoneColor[2] + iceShare * iceColor[2] + mithrilShare * mithrilColor[2]
    local b = stoneShare * stoneColor[3] + iceShare * iceColor[3] + mithrilShare * mithrilColor[3]

    -- Tiny color jitter so nearby asteroids with identical composition do not
    -- look like perfect clones.
    local jitter = 0.04
    r = math.max(0, math.min(1, r + (math.random() - 0.5) * jitter))
    g = math.max(0, math.min(1, g + (math.random() - 0.5) * jitter))
    b = math.max(0, math.min(1, b + (math.random() - 0.5) * jitter))

    return {r, g, b}
end

function asteroid_generator.generate(size, options)
    options = options or {}
    size = size or 30

    local complexity = options.complexity or (0.4 + math.random() * 0.6)
    local segments = 10 + math.floor(complexity * 10)
    local roughness = options.roughness or (0.6 + math.random() * 0.4)

    local points = {}
    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2
        local noise = 1 + (math.random() - 0.5) * roughness
        local r = size * lerp(0.8, 1.2, noise)
        local x = math.cos(angle) * r
        local y = math.sin(angle) * r
        table.insert(points, {x, y})
    end

    -- Craters disabled per request: keep table empty so downstream logic stays stable
    local craters = {}

    local shape = {
        points = points,
        flatPoints = flattenPoints(points),
        craters = craters,
        boundingRadius = computeBoundingRadius(points)
    }

    -- Generate a physical composition (stone / ice / mithril) and derive a
    -- corresponding surface color so HUD text and visuals stay in sync.
    local composition = generateComposition(options)

    local color = blendColorFromComposition(composition)

    local asteroid = {
        size = size,
        complexity = complexity,
        roughness = roughness,
        shape = shape,
        color = color,
        composition = composition,
        seed = math.random() * 1000
    }

    return asteroid
end

function asteroid_generator.draw(asteroid)
    if not asteroid or not asteroid.shape or not asteroid.shape.points then
        return
    end

    local shape = asteroid.shape
    local c = asteroid.color
    local baseR, baseG, baseB
    if c then
        baseR, baseG, baseB = c[1], c[2], c[3]
    else
        baseR, baseG, baseB = 0.45, 0.38, 0.32
    end

    ------------------------------------------------------------------------
    -- BASE FILL
    -- Slightly brighten the base color for the main body so shadows and veins
    -- have room to push darker/lighter on top.
    ------------------------------------------------------------------------
    local fillR = math.min(1, baseR * 1.12)
    local fillG = math.min(1, baseG * 1.12)
    local fillB = math.min(1, baseB * 1.12)

    love.graphics.setColor(fillR, fillG, fillB, 1)
    love.graphics.polygon("fill", shape.flatPoints)

    -- Crater drawing intentionally left disabled for this project; we keep a
    -- clean, solid body and rely on the outline for separation from the
    -- background.

    ------------------------------------------------------------------------
    -- OUTLINE / RIM
    ------------------------------------------------------------------------
    local outlineR = baseR * 0.20
    local outlineG = baseG * 0.20
    local outlineB = baseB * 0.20

    love.graphics.setColor(outlineR, outlineG, outlineB, 0.95)
    love.graphics.setLineWidth(2.5)
    love.graphics.polygon("line", shape.flatPoints)
end

return asteroid_generator
