local asteroid_generator = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function fract(x)
    return x - math.floor(x)
end

local function seededRand(seed, n)
    return fract(math.sin(seed * 12.9898 + n * 78.233) * 43758.5453)
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
    dirt = {0.28, 0.23, 0.18},   -- darker soil / dust
    stone = {0.45, 0.38, 0.32},  -- neutral, slightly warm rock
    ice = {0.70, 0.78, 0.86},    -- cool deposits (kept subtle in base color)
    mithril = {0.55, 0.46, 0.98} -- indigo metal highlights
}

local function resolveRand(options)
    if options and type(options.rng) == "function" then
        return options.rng
    end
    return function()
        return math.random()
    end
end

local function buildEarthyBaseColor(seed)
    local dirt = BASE_COLORS.dirt
    local stone = BASE_COLORS.stone

    -- Blend between dirt and stone so every asteroid reads as an earthy mix.
    local t = seededRand(seed, 77)
    local r = lerp(dirt[1], stone[1], t)
    local g = lerp(dirt[2], stone[2], t)
    local b = lerp(dirt[3], stone[3], t)

    local jitter = 0.08
    r = math.max(0, math.min(1, r + (seededRand(seed, 101) - 0.5) * jitter))
    g = math.max(0, math.min(1, g + (seededRand(seed, 102) - 0.5) * jitter))
    b = math.max(0, math.min(1, b + (seededRand(seed, 103) - 0.5) * jitter))
    return { r, g, b }
end

-- Build a stone/ice mix with an optional mithril component.
-- options.composition (optional) can override the defaults:
--   * mithrilChance   - probability [0, 1] of any mithril being present
--   * minMithrilShare - lower bound on mithril fraction when present
--   * maxMithrilShare - upper bound on mithril fraction when present
local function generateComposition(options, rand01)
    local compositionOptions = (options and options.composition) or {}

    local mithrilChance = compositionOptions.mithrilChance or 0.08
    local minMithrilShare = compositionOptions.minMithrilShare or 0.04
    local maxMithrilShare = compositionOptions.maxMithrilShare or 0.20

    -- Decide how much mithril this body has, if any.
    local mithrilShare = 0
    if rand01() < mithrilChance then
        local span = math.max(0, maxMithrilShare - minMithrilShare)
        mithrilShare = minMithrilShare + rand01() * span
    end

    -- Split the remaining mass between stone and ice.
    local baseRockVsIce = compositionOptions.baseRockVsIce or rand01()
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
local function blendColorFromComposition(composition, rand01)
    composition = composition or {}

    rand01 = rand01 or function()
        return math.random()
    end

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
    r = math.max(0, math.min(1, r + (rand01() - 0.5) * jitter))
    g = math.max(0, math.min(1, g + (rand01() - 0.5) * jitter))
    b = math.max(0, math.min(1, b + (rand01() - 0.5) * jitter))

    return {r, g, b}
end

function asteroid_generator.generate(size, options)
    options = options or {}
    size = size or 30

    local rand01 = resolveRand(options)

    local seed = options.seed or (rand01() * 1000)

    local complexity = options.complexity or (0.4 + rand01() * 0.6)
    local segments = 10 + math.floor(complexity * 10)
    local roughness = options.roughness or (0.6 + rand01() * 0.4)

    local points = {}
    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2
        local noise = 1 + (rand01() - 0.5) * roughness
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
    local composition = generateComposition(options, rand01)

    -- Keep the base in an earthy dirt/stone range, then apply a subtle
    -- composition tint so ice/mithril don't turn the whole rock into a flat
    -- bright pastel.
    local earthy = buildEarthyBaseColor(seed)
    local tint = blendColorFromComposition(composition, rand01)
    local tintStrength = 0.22
    local color = {
        lerp(earthy[1], tint[1], tintStrength),
        lerp(earthy[2], tint[2], tintStrength),
        lerp(earthy[3], tint[3], tintStrength),
    }

    local asteroid = {
        size = size,
        complexity = complexity,
        roughness = roughness,
        shape = shape,
        color = color,
        composition = composition,
        seed = seed,
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

    local glow = asteroid.glowColor
    if glow and type(glow) == "table" then
        local seed = asteroid.seed or 0
        local gx, gy, gb = glow[1] or 0.35, glow[2] or 0.75, glow[3] or 1.0
        local strength = asteroid.glowStrength or 1.0

        local oldMode, oldAlpha = love.graphics.getBlendMode()
        local oldStencilMode, oldStencilValue = love.graphics.getStencilTest()

        -- Clip glow inside the asteroid silhouette so the glow reads like
        -- embedded ore rather than a decal floating outside the rock.
        love.graphics.stencil(function()
            love.graphics.polygon("fill", shape.flatPoints)
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        love.graphics.setBlendMode("add", "alphamultiply")

        local rMax = (shape.boundingRadius or 30) * 0.55

        local function drawGooPoly(cx, cy, radius, seedBase, rot, stretchX, stretchY, r, g, b, a, irregularity)
            local sides = 9 + math.floor(seededRand(seed, seedBase + 1) * 7)
            local verts = {}

            rot = rot or 0
            stretchX = stretchX or 1
            stretchY = stretchY or 1
            irregularity = irregularity or 0.38

            local cr = math.cos(rot)
            local sr = math.sin(rot)

            for i = 0, sides - 1 do
                local t = (i / sides) * math.pi * 2
                local n = seededRand(seed, seedBase + 17 + i * 9)

                local jitter = (1 - irregularity) + n * (irregularity * 2)
                if jitter < 0.18 then
                    jitter = 0.18
                end

                local rr = radius * jitter
                local x = math.cos(t) * rr * stretchX
                local y = math.sin(t) * rr * stretchY

                local rx = x * cr - y * sr
                local ry = x * sr + y * cr

                verts[#verts + 1] = cx + rx
                verts[#verts + 1] = cy + ry
            end

            love.graphics.setColor(r, g, b, a)
            love.graphics.polygon("fill", verts)
        end

        -- Pick a couple "vein" centers so glow doesn't cover the whole surface.
        local centers = {}
        local centerCount = 2
        for i = 1, centerCount do
            local a = seededRand(seed, 410 + i * 29) * math.pi * 2
            local rr = (seededRand(seed, 430 + i * 31) ^ 0.8) * rMax
            centers[i] = { x = math.cos(a) * rr, y = math.sin(a) * rr }
        end

        -- Outer "goo" bloom: fewer blobs, tighter spread, higher intensity.
        local blobCount = 14
        local spread = rMax * 0.42
        for i = 1, blobCount do
            local c = centers[(i - 1) % centerCount + 1]

            local a = seededRand(seed, 500 + i * 13) * math.pi * 2
            local rr = (seededRand(seed, 700 + i * 17) ^ 0.7) * spread
            local x = c.x + math.cos(a) * rr
            local y = c.y + math.sin(a) * rr

            local blob = (5 + seededRand(seed, 900 + i * 19) * 14)
            local alpha = (0.22 + seededRand(seed, 1100 + i * 23) * 0.26) * (strength * 1.9)
            love.graphics.setColor(gx, gy, gb, alpha)
            drawGooPoly(x, y, blob, 3000 + i * 41, seededRand(seed, 3200 + i * 7) * math.pi * 2,
                1.0, 1.0, gx, gy, gb, alpha, 0.42)
        end

        -- Smears: short random-walk trails to make it feel liquid/abstract.
        local smearCount = 4
        for s = 1, smearCount do
            local c = centers[(s - 1) % centerCount + 1]
            local a0 = seededRand(seed, 1400 + s * 31) * math.pi * 2
            local r0 = (seededRand(seed, 1500 + s * 37) ^ 0.75) * (spread * 0.7)
            local x = c.x + math.cos(a0) * r0
            local y = c.y + math.sin(a0) * r0

            local steps = 9 + math.floor(seededRand(seed, 1600 + s * 41) * 10)
            local dir = seededRand(seed, 1700 + s * 43) * math.pi * 2

            for j = 1, steps do
                dir = dir + (seededRand(seed, 1800 + s * 47 + j * 11) - 0.5) * 1.4
                local stepLen = 4 + seededRand(seed, 1900 + s * 53 + j * 7) * 10
                x = x + math.cos(dir) * stepLen
                y = y + math.sin(dir) * stepLen

                local blob = 4 + seededRand(seed, 2000 + s * 59 + j * 5) * 10
                local alpha = (0.18 + seededRand(seed, 2100 + s * 61 + j * 3) * 0.20) * (strength * 1.6)
                love.graphics.setColor(gx, gy, gb, alpha)
                drawGooPoly(x, y, blob, 4000 + s * 101 + j * 13, dir, 2.1, 0.7, gx, gy, gb, alpha, 0.35)
            end
        end

        -- Hot core highlights: fewer, brighter dots sitting on top.
        local coreCount = 8
        for i = 1, coreCount do
            local c = centers[(i - 1) % centerCount + 1]
            local a = seededRand(seed, 2400 + i * 19) * math.pi * 2
            local rr = (seededRand(seed, 2500 + i * 23) ^ 0.85) * (spread * 0.55)
            local x = c.x + math.cos(a) * rr
            local y = c.y + math.sin(a) * rr

            local blob = 1.5 + seededRand(seed, 2600 + i * 29) * 5
            local alpha = (0.45 + seededRand(seed, 2700 + i * 31) * 0.38) * (strength * 2.2)
            love.graphics.setColor(0.85, 0.95, 1.0, alpha)
            drawGooPoly(x, y, blob, 5000 + i * 73, seededRand(seed, 5100 + i * 11) * math.pi * 2,
                0.95, 0.95, 0.85, 0.95, 1.0, alpha, 0.72)
        end

        love.graphics.setBlendMode(oldMode, oldAlpha)

        if oldStencilMode then
            love.graphics.setStencilTest(oldStencilMode, oldStencilValue or 0)
        else
            love.graphics.setStencilTest()
        end
    end

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
