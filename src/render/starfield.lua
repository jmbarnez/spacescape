local starfield = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local config = {
    layers = {
        [0] = { count = 320, baseSpeed = 0.005, sizeMod = 0.0, brightnessMod = 0.0, dim = 0.7 },
        [1] = { count = 260, baseSpeed = 0.030, sizeMod = 0.2, brightnessMod = 0.1, dim = 0.8 },
        [2] = { count = 150, baseSpeed = 0.100, sizeMod = 0.4, brightnessMod = 0.2, dim = 0.9 },
        [3] = { count = 60,  baseSpeed = 0.250, sizeMod = 0.6, brightnessMod = 0.3, dim = 1.0 },
    },
    starColors = {
        { threshold = 0.05, r = 0.7, g = 0.8, b = 1.0 },   -- Blue giants
        { threshold = 0.20, r = 0.9, g = 0.95, b = 1.0 },  -- White-blue
        { threshold = 0.55, r = 1.0, g = 0.96, b = 0.84 }, -- Yellow-white (sun-like)
        { threshold = 0.85, r = 1.0, g = 0.85, b = 0.7 },  -- Orange
        { threshold = 1.00, r = 1.0, g = 0.76, b = 0.6 },  -- Red dwarfs
    },
    twinkle = {
        speedMin = 0.5,
        speedMax = 2.0,
        intensityMin = 0.7,
        intensityMax = 1.0,
    },
    glow = {
        minSize = 1.2,
        multiplier = 2.0,
        alpha = 0.25,
        outerMultiplier = 3.5,
        outerAlpha = 0.08,
    },
    parallax = {
        scale = 0.05,
    },
    fallbackBackground = { r = 0.02, g = 0.05, b = 0.15 },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

starfield.stars = {}
starfield.nebulaCanvas = nil
starfield.nebulaShader = nil
starfield.time = 0
starfield.paletteVariant = nil

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

local function pickStarColor(layer)
    local t = math.random()
    local layerConfig = config.layers[layer]
    local dim = layerConfig and layerConfig.dim or 1.0
    
    for _, colorDef in ipairs(config.starColors) do
        if t < colorDef.threshold then
            return colorDef.r * dim, colorDef.g * dim, colorDef.b * dim
        end
    end
    
    local last = config.starColors[#config.starColors]
    return last.r * dim, last.g * dim, last.b * dim
end

local function createStar(layer, width, height)
    local layerConfig = config.layers[layer]
    local baseX = math.random()
    local baseY = math.random()
    local colorR, colorG, colorB = pickStarColor(layer)
    
    return {
        x = baseX * width,
        y = baseY * height,
        baseX = baseX,
        baseY = baseY,
        size = math.random() * 0.6 + 0.2 + layerConfig.sizeMod,
        brightness = math.random() * 0.3 + 0.5 + layerConfig.brightnessMod,
        twinkleSpeed = math.random() * (config.twinkle.speedMax - config.twinkle.speedMin) + config.twinkle.speedMin,
        twinkleOffset = math.random() * math.pi * 2,
        layer = layer,
        parallaxFactor = layerConfig.baseSpeed,
        colorR = colorR,
        colorG = colorG,
        colorB = colorB,
    }
end

local function refreshNebula(width, height)
    if not starfield.nebulaShader then
        local success, shader = pcall(love.graphics.newShader, "assets/shaders/nebula.glsl")
        if success then
            starfield.nebulaShader = shader
        else
            starfield.nebulaCanvas = nil
            return
        end
    end

    starfield.nebulaCanvas = love.graphics.newCanvas(width, height)
    if not starfield.nebulaCanvas then
        return
    end

    if not starfield.paletteVariant then
        starfield.paletteVariant = math.random(0, 2)
    end

    love.graphics.setCanvas(starfield.nebulaCanvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(starfield.nebulaShader)
    starfield.nebulaShader:send("time", 0)
    starfield.nebulaShader:send("resolution", { width, height })
    starfield.nebulaShader:send("paletteVariant", starfield.paletteVariant)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setShader()
    love.graphics.setCanvas()
end

local function wrapCoordinate(value, max)
    return value - math.floor(value / max) * max
end

local function calculateTwinkle(star, time)
    local twinklePhase = math.sin(time * star.twinkleSpeed + star.twinkleOffset)
    local twinkleRange = config.twinkle.intensityMax - config.twinkle.intensityMin
    return config.twinkle.intensityMin + (twinklePhase * 0.5 + 0.5) * twinkleRange
end

--------------------------------------------------------------------------------
-- Drawing Helpers
--------------------------------------------------------------------------------

local function drawStarCore(star, alpha)
    love.graphics.setColor(star.colorR, star.colorG, star.colorB, alpha)
    love.graphics.circle("fill", star.x, star.y, math.max(star.size, 0.6))
end

local function drawStarGlow(star, alpha)
    local glowConfig = config.glow
    
    if star.size < glowConfig.minSize then
        return
    end
    
    -- Inner glow
    love.graphics.setColor(star.colorR, star.colorG, star.colorB, alpha * glowConfig.alpha)
    love.graphics.circle("fill", star.x, star.y, star.size * glowConfig.multiplier)
    
    -- Outer glow for brightest stars
    if star.layer >= 2 and star.brightness > 0.7 then
        love.graphics.setColor(star.colorR, star.colorG, star.colorB, alpha * glowConfig.outerAlpha)
        love.graphics.circle("fill", star.x, star.y, star.size * glowConfig.outerMultiplier)
    end
end

local function drawBackground(width, height)
    if starfield.nebulaCanvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(starfield.nebulaCanvas, 0, 0)
    else
        local bg = config.fallbackBackground
        love.graphics.setColor(bg.r, bg.g, bg.b, 1)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end
end

local function drawStarsForLayer(layer, time)
    for _, star in ipairs(starfield.stars) do
        if star.layer == layer then
            local twinkle = calculateTwinkle(star, time)
            local alpha = star.brightness * twinkle
            
            drawStarGlow(star, alpha)
            drawStarCore(star, alpha)
        end
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function starfield.generate()
    starfield.stars = {}
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    for layer = 0, 3 do
        local layerConfig = config.layers[layer]
        for _ = 1, layerConfig.count do
            table.insert(starfield.stars, createStar(layer, width, height))
        end
    end

    refreshNebula(width, height)
end

function starfield.resize()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    refreshNebula(width, height)
end

function starfield.update(dt, playerX, playerY)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local centerX = width / 2
    local centerY = height / 2
    local parallaxScale = config.parallax.scale
    
    starfield.time = starfield.time + dt
    
    for _, star in ipairs(starfield.stars) do
        local baseX = star.baseX * width
        local baseY = star.baseY * height
        local offsetX = (playerX - centerX) * star.parallaxFactor * parallaxScale
        local offsetY = (playerY - centerY) * star.parallaxFactor * parallaxScale

        star.x = wrapCoordinate(baseX - offsetX, width)
        star.y = wrapCoordinate(baseY - offsetY, height)
    end
end

function starfield.draw()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    drawBackground(width, height)

    -- Draw stars layer by layer (far to near) for proper depth
    for layer = 0, 3 do
        drawStarsForLayer(layer, starfield.time)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return starfield
