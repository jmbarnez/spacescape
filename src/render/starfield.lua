local starfield = {}

starfield.stars = {}
starfield.nebulaCanvas = nil
starfield.nebulaShader = nil
starfield.time = 0

local function pickStarColorForLayer(layer)
    local t = math.random()
    local r, g, b

    if t < 0.05 then
        r, g, b = 0.7, 0.8, 1.0
    elseif t < 0.20 then
        r, g, b = 0.9, 0.95, 1.0
    elseif t < 0.55 then
        r, g, b = 1.0, 0.96, 0.84
    elseif t < 0.85 then
        r, g, b = 1.0, 0.85, 0.7
    else
        r, g, b = 1.0, 0.76, 0.6
    end

    local dim = 1.0
    if layer == 0 then
        dim = 0.7
    elseif layer == 1 then
        dim = 0.8
    elseif layer == 2 then
        dim = 0.9
    end

    return r * dim, g * dim, b * dim
end

function starfield.generate()
    starfield.stars = {}
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    -- Create parallax star layers (far, mid, near)
    for layer = 0, 3 do
        local starCount
        local baseSpeed

        if layer == 0 then
            starCount = 320
            baseSpeed = 0.005
        elseif layer == 1 then
            starCount = 260
            baseSpeed = 0.03
        elseif layer == 2 then
            starCount = 150
            baseSpeed = 0.10
        elseif layer == 3 then
            starCount = 60
            baseSpeed = 0.25
        end

        for i = 1, starCount do
            local baseX = math.random() * width
            local baseY = math.random() * height
            local colorR, colorG, colorB = pickStarColorForLayer(layer)
            table.insert(starfield.stars, {
                x = baseX,
                y = baseY,
                size = math.random() * 0.6 + 0.2 + (layer * 0.2),
                brightness = math.random() * 0.3 + 0.5 + (layer * 0.1),
                twinkleSpeed = math.random() * 1.5 + 0.5,
                twinkleOffset = math.random() * math.pi * 2,
                layer = layer,
                parallaxFactor = baseSpeed,
                baseX = baseX,
                baseY = baseY,
                colorR = colorR,
                colorG = colorG,
                colorB = colorB
            })
        end
    end

    -- Initialize nebula shader
    local success, shader = pcall(love.graphics.newShader, "assets/shaders/nebula.glsl")
    if success then
        starfield.nebulaShader = shader
    end

    starfield.nebulaCanvas = love.graphics.newCanvas(width, height)

    if starfield.nebulaShader and starfield.nebulaCanvas then
        love.graphics.setCanvas(starfield.nebulaCanvas)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setShader(starfield.nebulaShader)
        starfield.nebulaShader:send("time", 0)
        starfield.nebulaShader:send("resolution", {width, height})
        local paletteVariant = math.random(0, 2)
        starfield.nebulaShader:send("paletteVariant", paletteVariant)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setShader()
        love.graphics.setCanvas()
    end
end

function starfield.update(dt, playerX, playerY)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local centerX = width / 2
    local centerY = height / 2
    
    starfield.time = starfield.time + dt
    
    for _, star in ipairs(starfield.stars) do
        local offsetX = (playerX - centerX) * star.parallaxFactor * 0.05
        local offsetY = (playerY - centerY) * star.parallaxFactor * 0.05
        
        local newX = star.baseX - offsetX
        local newY = star.baseY - offsetY
        
        -- Proper modulo wrapping
        star.x = newX - math.floor(newX / width) * width
        star.y = newY - math.floor(newY / height) * height
    end
end

function starfield.draw()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Draw nebula background
    if starfield.nebulaCanvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(starfield.nebulaCanvas, 0, 0)
    else
        -- Fallback gradient background
        love.graphics.setColor(0.02, 0.01, 0.05, 1)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end

    -- Draw stars by layer (far to near)
    for layer = 0, 3 do
        for _, star in ipairs(starfield.stars) do
            if star.layer == layer then
                local alpha = star.brightness
                
                love.graphics.setColor(star.colorR, star.colorG, star.colorB, alpha)
                love.graphics.circle("fill", star.x, star.y, math.max(star.size, 0.6))
                
                -- Add subtle glow for brighter stars
                if star.size > 1.0 and star.layer == 3 then
                    love.graphics.setColor(star.colorR, star.colorG, star.colorB, alpha * 0.3)
                    love.graphics.circle("fill", star.x, star.y, star.size * 1.6)
                end
            end
        end
    end
end

return starfield
