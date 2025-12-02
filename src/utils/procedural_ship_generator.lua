local ship_generator = {}

-- Ship component types
local HULL_TYPES = {"diamond", "hexagon", "arrow", "wedge", "crescent"}
local WING_STYLES = {"swept", "angular", "curved", "delta", "split"}
local ENGINE_CONFIGS = {"single", "dual", "triple", "quad", "ring"}

-- Color palettes for different ship factions/types
local COLOR_PALETTES = {
    military = {
        primary = {0.3, 0.35, 0.4},
        secondary = {0.2, 0.25, 0.3},
        accent = {0.8, 0.4, 0.1},
        glow = {1, 0.6, 0.2}
    },
    civilian = {
        primary = {0.7, 0.7, 0.75},
        secondary = {0.5, 0.5, 0.55},
        accent = {0.2, 0.6, 0.9},
        glow = {0.4, 0.8, 1}
    },
    pirate = {
        primary = {0.15, 0.1, 0.1},
        secondary = {0.3, 0.15, 0.15},
        accent = {0.9, 0.2, 0.2},
        glow = {1, 0.3, 0.3}
    },
    alien = {
        primary = {0.2, 0.4, 0.3},
        secondary = {0.1, 0.3, 0.25},
        accent = {0.3, 1, 0.6},
        glow = {0.5, 1, 0.7}
    },
    elite = {
        primary = {0.1, 0.1, 0.2},
        secondary = {0.15, 0.15, 0.3},
        accent = {0.6, 0.4, 0.9},
        glow = {0.8, 0.5, 1}
    }
}

local PALETTE_NAMES = {}
for name, _ in pairs(COLOR_PALETTES) do
    table.insert(PALETTE_NAMES, name)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return {
        lerp(c1[1], c2[1], t),
        lerp(c1[2], c2[2], t),
        lerp(c1[3], c2[3], t)
    }
end

local function generateHullPoints(hullType, size, complexity)
    local points = {}
    
    if hullType == "diamond" then
        local frontExtend = size * (1 + complexity * 0.3)
        local sideWidth = size * (0.4 + complexity * 0.15)
        local rearIndent = size * (0.5 + complexity * 0.2)
        
        table.insert(points, {frontExtend, 0})
        table.insert(points, {size * 0.3, -sideWidth * 0.6})
        table.insert(points, {0, -sideWidth})
        table.insert(points, {-rearIndent * 0.5, -sideWidth * 0.8})
        table.insert(points, {-rearIndent, -sideWidth * 0.3})
        table.insert(points, {-rearIndent * 0.7, 0})
        table.insert(points, {-rearIndent, sideWidth * 0.3})
        table.insert(points, {-rearIndent * 0.5, sideWidth * 0.8})
        table.insert(points, {0, sideWidth})
        table.insert(points, {size * 0.3, sideWidth * 0.6})
        
    elseif hullType == "hexagon" then
        local segments = 6 + math.floor(complexity * 4)
        for i = 0, segments - 1 do
            local angle = (i / segments) * math.pi * 2 - math.pi / 2
            local radius = size * (0.6 + math.sin(angle * 2) * 0.2 * complexity)
            if angle > -math.pi / 2 and angle < math.pi / 2 then
                radius = radius * (1.2 + complexity * 0.3)
            end
            table.insert(points, {math.cos(angle) * radius, math.sin(angle) * radius})
        end
        
    elseif hullType == "arrow" then
        local tipLength = size * (1.3 + complexity * 0.4)
        local bodyWidth = size * (0.35 + complexity * 0.1)
        local wingSpan = size * (0.6 + complexity * 0.25)
        
        table.insert(points, {tipLength, 0})
        table.insert(points, {size * 0.2, -bodyWidth})
        table.insert(points, {-size * 0.2, -bodyWidth})
        table.insert(points, {-size * 0.4, -wingSpan})
        table.insert(points, {-size * 0.7, -wingSpan * 0.8})
        table.insert(points, {-size * 0.5, -bodyWidth * 0.5})
        table.insert(points, {-size * 0.6, 0})
        table.insert(points, {-size * 0.5, bodyWidth * 0.5})
        table.insert(points, {-size * 0.7, wingSpan * 0.8})
        table.insert(points, {-size * 0.4, wingSpan})
        table.insert(points, {-size * 0.2, bodyWidth})
        table.insert(points, {size * 0.2, bodyWidth})
        
    elseif hullType == "wedge" then
        local length = size * (1.1 + complexity * 0.3)
        local width = size * (0.5 + complexity * 0.2)
        
        table.insert(points, {length, 0})
        table.insert(points, {length * 0.6, -width * 0.3})
        table.insert(points, {0, -width * 0.7})
        table.insert(points, {-length * 0.5, -width})
        table.insert(points, {-length * 0.7, -width * 0.6})
        table.insert(points, {-length * 0.6, 0})
        table.insert(points, {-length * 0.7, width * 0.6})
        table.insert(points, {-length * 0.5, width})
        table.insert(points, {0, width * 0.7})
        table.insert(points, {length * 0.6, width * 0.3})
        
    elseif hullType == "crescent" then
        local outerRadius = size * (0.9 + complexity * 0.2)
        local innerRadius = size * (0.5 + complexity * 0.15)
        local arcSpan = math.pi * (0.7 + complexity * 0.2)
        local segments = 8 + math.floor(complexity * 6)
        
        -- Outer arc
        for i = 0, segments do
            local angle = -arcSpan / 2 + (i / segments) * arcSpan
            table.insert(points, {
                math.cos(angle) * outerRadius + size * 0.3,
                math.sin(angle) * outerRadius
            })
        end
        -- Inner arc (reverse)
        for i = segments, 0, -1 do
            local angle = -arcSpan / 2 + (i / segments) * arcSpan
            table.insert(points, {
                math.cos(angle) * innerRadius + size * 0.3,
                math.sin(angle) * innerRadius
            })
        end
    end
    
    return points
end

local function generateWingGeometry(wingStyle, size, complexity, side)
    local mirror = side == "top" and -1 or 1
    local wings = {}
    
    if wingStyle == "swept" then
        table.insert(wings, {
            points = {
                {size * 0.1, mirror * size * 0.3},
                {-size * 0.3, mirror * size * 0.35},
                {-size * 0.6, mirror * size * (0.7 + complexity * 0.3)},
                {-size * 0.75, mirror * size * (0.6 + complexity * 0.25)},
                {-size * 0.5, mirror * size * 0.25}
            },
            type = "main"
        })
        
    elseif wingStyle == "angular" then
        table.insert(wings, {
            points = {
                {size * 0.05, mirror * size * 0.25},
                {-size * 0.1, mirror * size * (0.6 + complexity * 0.3)},
                {-size * 0.35, mirror * size * (0.65 + complexity * 0.3)},
                {-size * 0.5, mirror * size * (0.5 + complexity * 0.2)},
                {-size * 0.45, mirror * size * 0.2}
            },
            type = "main"
        })
        -- Secondary winglet
        if complexity > 0.5 then
            table.insert(wings, {
                points = {
                    {-size * 0.35, mirror * size * (0.55 + complexity * 0.2)},
                    {-size * 0.55, mirror * size * (0.8 + complexity * 0.2)},
                    {-size * 0.7, mirror * size * (0.7 + complexity * 0.15)},
                    {-size * 0.55, mirror * size * (0.5 + complexity * 0.15)}
                },
                type = "secondary"
            })
        end
        
    elseif wingStyle == "curved" then
        local wingPoints = {}
        local segments = 6 + math.floor(complexity * 4)
        for i = 0, segments do
            local t = i / segments
            local x = lerp(size * 0.1, -size * 0.6, t)
            local baseY = size * 0.25
            local peakY = size * (0.7 + complexity * 0.35)
            local y = baseY + math.sin(t * math.pi) * (peakY - baseY)
            table.insert(wingPoints, {x, mirror * y})
        end
        table.insert(wings, {points = wingPoints, type = "main"})
        
    elseif wingStyle == "delta" then
        table.insert(wings, {
            points = {
                {size * 0.3, mirror * size * 0.15},
                {size * 0.1, mirror * size * 0.2},
                {-size * 0.7, mirror * size * (0.8 + complexity * 0.3)},
                {-size * 0.8, mirror * size * (0.6 + complexity * 0.2)},
                {-size * 0.6, mirror * size * 0.15}
            },
            type = "main"
        })
        
    elseif wingStyle == "split" then
        -- Upper wing section
        table.insert(wings, {
            points = {
                {size * 0.05, mirror * size * 0.28},
                {-size * 0.2, mirror * size * (0.45 + complexity * 0.15)},
                {-size * 0.5, mirror * size * (0.5 + complexity * 0.15)},
                {-size * 0.55, mirror * size * 0.35},
                {-size * 0.3, mirror * size * 0.25}
            },
            type = "main"
        })
        -- Lower wing section
        table.insert(wings, {
            points = {
                {-size * 0.25, mirror * size * 0.3},
                {-size * 0.4, mirror * size * (0.65 + complexity * 0.25)},
                {-size * 0.65, mirror * size * (0.75 + complexity * 0.25)},
                {-size * 0.75, mirror * size * (0.55 + complexity * 0.15)},
                {-size * 0.5, mirror * size * 0.28}
            },
            type = "secondary"
        })
    end
    
    return wings
end

local function generateEnginePositions(engineConfig, size, complexity)
    local engines = {}
    
    if engineConfig == "single" then
        table.insert(engines, {x = -size * 0.6, y = 0, radius = size * 0.15})
        
    elseif engineConfig == "dual" then
        local spread = size * (0.2 + complexity * 0.1)
        table.insert(engines, {x = -size * 0.55, y = -spread, radius = size * 0.12})
        table.insert(engines, {x = -size * 0.55, y = spread, radius = size * 0.12})
        
    elseif engineConfig == "triple" then
        local spread = size * (0.25 + complexity * 0.1)
        table.insert(engines, {x = -size * 0.6, y = 0, radius = size * 0.1})
        table.insert(engines, {x = -size * 0.5, y = -spread, radius = size * 0.08})
        table.insert(engines, {x = -size * 0.5, y = spread, radius = size * 0.08})
        
    elseif engineConfig == "quad" then
        local innerSpread = size * 0.15
        local outerSpread = size * (0.35 + complexity * 0.1)
        table.insert(engines, {x = -size * 0.55, y = -innerSpread, radius = size * 0.09})
        table.insert(engines, {x = -size * 0.55, y = innerSpread, radius = size * 0.09})
        table.insert(engines, {x = -size * 0.55, y = -outerSpread, radius = size * 0.06})
        table.insert(engines, {x = -size * 0.55, y = outerSpread, radius = size * 0.06})
        
    elseif engineConfig == "ring" then
        local ringRadius = size * (0.4 + complexity * 0.1)
        local ringSegments = 8 + math.floor(complexity * 6)
        for i = 0, ringSegments do
            local angle = (i / ringSegments) * math.pi * 2
            table.insert(engines, {x = math.cos(angle) * ringRadius, y = math.sin(angle) * ringRadius, radius = size * 0.05})
        end
    end

    return engines
end

local function randomFrom(list)
    if not list or #list == 0 then
        return nil
    end
    return list[math.random(1, #list)]
end

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
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

local function choosePalette(preferredName)
    local name = preferredName
    if name and COLOR_PALETTES[name] then
        return name, COLOR_PALETTES[name]
    end

    if #PALETTE_NAMES > 0 then
        name = PALETTE_NAMES[math.random(1, #PALETTE_NAMES)]
        return name, COLOR_PALETTES[name]
    end

    return "default", {
        primary = {1, 1, 1},
        secondary = {0.7, 0.7, 0.7},
        accent = {1, 0.5, 0.5},
        glow = {1, 0.8, 0.6}
    }
end

local function generateGreebles(size, complexity)
    local greebles = {}

    local panelCount = 2 + math.floor(complexity * 4)
    for i = 1, panelCount do
        local t = math.random()
        local x = lerp(-size * 0.2, size * 0.7, t)
        local yOffset = size * (0.15 + math.random() * 0.2)
        local y = math.random() < 0.5 and yOffset or -yOffset
        local length = size * (0.12 + math.random() * 0.12)
        local width = size * (0.04 + math.random() * 0.04)
        local angle = (math.random() - 0.5) * 0.6

        table.insert(greebles, {
            type = "panel",
            x = x,
            y = y,
            length = length,
            width = width,
            angle = angle
        })
    end

    local lightCount = 1 + math.floor(complexity * 3)
    for i = 1, lightCount do
        local x = lerp(0, size * 0.9, math.random())
        local y = (math.random() - 0.5) * size * 0.3
        local radius = size * (0.04 + math.random() * 0.03)

        table.insert(greebles, {
            type = "light",
            x = x,
            y = y,
            radius = radius
        })
    end

    return greebles
end

local function computeBoundingRadius(ship)
    local radius = ship.size or 0

    if ship.hull and ship.hull.points then
        for _, p in ipairs(ship.hull.points) do
            local x, y = p[1], p[2]
            local d = math.sqrt(x * x + y * y)
            if d > radius then
                radius = d
            end
        end
    end

    if ship.wings then
        for _, wing in ipairs(ship.wings) do
            if wing.points then
                for _, p in ipairs(wing.points) do
                    local x, y = p[1], p[2]
                    local d = math.sqrt(x * x + y * y)
                    if d > radius then
                        radius = d
                    end
                end
            end
        end
    end

    if ship.engines then
        for _, engine in ipairs(ship.engines) do
            local ex = engine.x or 0
            local ey = engine.y or 0
            local r = (engine.radius or (ship.size or 0)) * 1.5
            local d = math.sqrt(ex * ex + ey * ey) + r
            if d > radius then
                radius = d
            end
        end
    end

    if ship.greebles then
        for _, g in ipairs(ship.greebles) do
            if g.type == "panel" then
                local cx, cy = g.x or 0, g.y or 0
                local halfLen = (g.length or 0) * 0.5
                local halfWid = (g.width or 0) * 0.5
                local cornerRadius = math.sqrt(halfLen * halfLen + halfWid * halfWid)
                local d = math.sqrt(cx * cx + cy * cy) + cornerRadius
                if d > radius then
                    radius = d
                end
            elseif g.type == "light" then
                local cx, cy = g.x or 0, g.y or 0
                local r = g.radius or ((ship.size or 0) * 0.06)
                local d = math.sqrt(cx * cx + cy * cy) + r
                if d > radius then
                    radius = d
                end
            end
        end
    end

    return radius
end

function ship_generator.generate(size, options)
    options = options or {}
    size = size or 20

    local complexity = options.complexity or (0.6 + math.random() * 0.4)
    complexity = clamp01(complexity)

    local baseHullHealth = options.hullHealth or math.floor(40 + size * 1.5 + complexity * 60)

    local hullType = options.hullType or randomFrom(HULL_TYPES)
    local wingStyle = options.wingStyle or randomFrom(WING_STYLES)
    local engineConfig = options.engineConfig or randomFrom(ENGINE_CONFIGS)

    local paletteName, palette = choosePalette(options.faction)

    local hullPoints = generateHullPoints(hullType, size, complexity)
    local topWings = generateWingGeometry(wingStyle, size, complexity, "top")
    local bottomWings = generateWingGeometry(wingStyle, size, complexity, "bottom")
    local engines = generateEnginePositions(engineConfig, size, complexity)
    local greebles = generateGreebles(size, complexity)

    local ship = {
        size = size,
        complexity = complexity,
        hullType = hullType,
        wingStyle = wingStyle,
        engineConfig = engineConfig,
        faction = paletteName,
        palette = palette,
        hull = {
            points = hullPoints,
            maxHealth = baseHullHealth
        },
        baseOutline = flattenPoints(hullPoints),
        wings = {},
        engines = engines,
        greebles = greebles
    }

    for _, wing in ipairs(topWings) do
        table.insert(ship.wings, wing)
    end
    for _, wing in ipairs(bottomWings) do
        table.insert(ship.wings, wing)
    end

    ship.boundingRadius = computeBoundingRadius(ship)

    return ship
end

function ship_generator.getHullMaxHealth(ship)
    if ship and ship.hull and ship.hull.maxHealth then
        return ship.hull.maxHealth
    end

    return nil
end

function ship_generator.getBaseOutline(ship)
    if not ship then
        return nil
    end

    if ship.baseOutline then
        return ship.baseOutline
    end

    if ship.hull and ship.hull.points then
        return flattenPoints(ship.hull.points)
    end

    return nil
end

function ship_generator.draw(ship, colors)
    if not ship then
        return
    end

    local palette = ship.palette or COLOR_PALETTES.military
    local primary = palette.primary or {1, 1, 1}
    local secondary = palette.secondary or primary
    local accent = palette.accent or primary
    local glow = palette.glow or accent

    local baseColor = (colors and colors.enemy) or primary
    local outlineColor = (colors and colors.enemyOutline) or {1, 1, 1}

    local panelColor = lerpColor(baseColor, secondary, 0.5)
    local accentColor = lerpColor(baseColor, accent, 0.7)

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 1)
    if ship.hull and ship.hull.points then
        love.graphics.polygon("fill", flattenPoints(ship.hull.points))
    end

    if ship.wings then
        for _, wing in ipairs(ship.wings) do
            local c = panelColor
            if wing.type == "secondary" then
                c = accentColor
            end

            if wing.points then
                love.graphics.setColor(c[1], c[2], c[3], 1)
                love.graphics.polygon("fill", flattenPoints(wing.points))
            end
        end
    end

    if ship.engines then
        for _, engine in ipairs(ship.engines) do
            local r = engine.radius or (ship.size * 0.1)

            love.graphics.setColor(0.1, 0.1, 0.1, 1)
            love.graphics.circle("fill", engine.x, engine.y, r)

            love.graphics.setColor(glow[1], glow[2], glow[3], 0.9)
            love.graphics.circle("fill", engine.x, engine.y, r * 0.7)

            love.graphics.setColor(glow[1], glow[2], glow[3], 0.4)
            love.graphics.circle("fill", engine.x, engine.y, r * 1.5)
        end
    end

    if ship.greebles then
        for _, g in ipairs(ship.greebles) do
            if g.type == "panel" then
                love.graphics.push()
                love.graphics.translate(g.x, g.y)
                love.graphics.rotate(g.angle or 0)
                love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], 0.9)
                love.graphics.rectangle("fill", -g.length * 0.5, -g.width * 0.5, g.length, g.width, g.width * 0.3, g.width * 0.3)
                love.graphics.pop()
            elseif g.type == "light" then
                local r = g.radius or (ship.size * 0.06)
                love.graphics.setColor(glow[1], glow[2], glow[3], 0.8)
                love.graphics.circle("fill", g.x, g.y, r)
            end
        end
    end

    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], 1)
    love.graphics.setLineWidth(2)

    if ship.hull and ship.hull.points then
        love.graphics.polygon("line", flattenPoints(ship.hull.points))
    end

    if ship.wings then
        for _, wing in ipairs(ship.wings) do
            if wing.points then
                love.graphics.polygon("line", flattenPoints(wing.points))
            end
        end
    end
end

return ship_generator
