local projectile = {}

projectile.list = {}

local physics = require("src.core.physics")

local function calculateHitChance(weapon, distance)
    local hitMax = weapon.hitMax
    local hitMin = weapon.hitMin
    local optimalRange = weapon.optimalRange
    local maxRange = weapon.maxRange

    if not hitMax and not hitMin then
        return 1.0
    end

    hitMax = hitMax or hitMin
    hitMin = hitMin or hitMax

    if not optimalRange or not maxRange or maxRange <= optimalRange then
        return hitMax
    end

    if distance <= optimalRange then
        return hitMax
    elseif distance >= maxRange then
        return hitMin
    else
        local t = (distance - optimalRange) / (maxRange - optimalRange)
        return hitMax + (hitMin - hitMax) * t
    end
end

projectile.calculateHitChance = calculateHitChance

local function isOffscreen(p, world)
    if world then
        local margin = 100
        return p.x < world.minX - margin or p.x > world.maxX + margin or
               p.y < world.minY - margin or p.y > world.maxY + margin
    else
        local lg = love and love.graphics
        if lg and lg.getWidth and lg.getHeight then
            return p.x < -50 or p.x > lg.getWidth() + 50 or
                   p.y < -50 or p.y > lg.getHeight() + 50
        else
            local margin = 10000
            return p.x < -margin or p.x > margin or
                   p.y < -margin or p.y > margin
        end
    end
end

function projectile.spawn(shooter, targetX, targetY, targetEntity)

    local dx = targetX - shooter.x
    local dy = targetY - shooter.y
    local angle = math.atan2(dy, dx)

    local weapon = shooter.weapon or {}
    local speed = weapon.projectileSpeed or 600
    local damage = weapon.damage or 20
    local faction = shooter.faction or "player"

    local x = shooter.x + math.cos(angle) * shooter.size
    local y = shooter.y + math.sin(angle) * shooter.size

    -- Create projectile entity first (so we can pass it to physics)
    local newProjectile = {
        x = x,
        y = y,
        angle = angle,
        speed = speed,
        damage = damage,
        faction = faction,
        owner = shooter,
        target = targetEntity,
        weapon = weapon,
        distanceTraveled = 0,
        projectileConfig = weapon.projectile,
        body = nil,
        shape = nil,
        fixture = nil
    }
    
    -- Determine collision category based on faction
    local categoryName = (faction == "enemy") and "ENEMY_PROJECTILE" or "PLAYER_PROJECTILE"
    
    -- Create physics body with proper collision filtering
    newProjectile.body, newProjectile.shape, newProjectile.fixture = physics.createCircleBody(
        x, y,
        4,  -- Projectile radius
        categoryName,
        newProjectile,
        { isSensor = true, isBullet = true }  -- Sensors don't cause physical response, bullets have CCD
    )
    
    -- Set velocity if body was created
    if newProjectile.body then
        newProjectile.body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    end

    table.insert(projectile.list, newProjectile)
    shooter.angle = angle
end

function projectile.update(dt, world)
    for i = #projectile.list, 1, -1 do
        local p = projectile.list[i]
        local target = p.target

        local oldX = p.x
        local oldY = p.y

        if p.body then
            p.x, p.y = p.body:getPosition()

            if target and target.x and target.y then
                local dx = target.x - p.x
                local dy = target.y - p.y
                local distSq = dx * dx + dy * dy
                if distSq > 0 then
                    local angle = math.atan2(dy, dx)
                    p.angle = angle
                    p.body:setLinearVelocity(math.cos(angle) * p.speed, math.sin(angle) * p.speed)
                end
            end
        else
            if target and target.x and target.y then
                local dx = target.x - p.x
                local dy = target.y - p.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    p.angle = math.atan2(dy, dx)
                end
            end

            p.x = p.x + math.cos(p.angle) * p.speed * dt
            p.y = p.y + math.sin(p.angle) * p.speed * dt
        end

        if oldX and oldY then
            local dx = p.x - oldX
            local dy = p.y - oldY
            local stepDist = math.sqrt(dx * dx + dy * dy)
            p.distanceTraveled = (p.distanceTraveled or 0) + stepDist
        end

        -- Remove projectiles that are off screen
        if isOffscreen(p, world) then
            if p.body then
                p.body:destroy()
            end
            table.remove(projectile.list, i)
        end
    end
end

local function drawBeamProjectile(p, colors, config)
    local length = (config and config.length) or 20
    local width = (config and config.width) or 2
    local outerAlpha = (config and config.outerGlowAlpha) or 0.3
    local tipLength = (config and config.tipLength) or 3
    local color = (config and config.color) or colors.projectile

    local tailX = p.x - math.cos(p.angle) * length
    local tailY = p.y - math.sin(p.angle) * length

    -- Outer glow
    love.graphics.setColor(color[1], color[2], color[3], outerAlpha)
    love.graphics.setLineWidth(width + 2)
    love.graphics.line(p.x, p.y, tailX, tailY)

    -- Core beam
    love.graphics.setColor(color)
    love.graphics.setLineWidth(width)
    love.graphics.line(p.x, p.y, tailX, tailY)

    -- Bright tip
    love.graphics.setColor(color)
    love.graphics.setLineWidth(width)
    love.graphics.line(
        p.x,
        p.y,
        p.x + math.cos(p.angle) * tipLength,
        p.y + math.sin(p.angle) * tipLength
    )
end

function projectile.draw(colors)
    for _, p in ipairs(projectile.list) do
        local config = p.projectileConfig
        local style = (config and config.style) or "beam"

        if style == "beam" then
            drawBeamProjectile(p, colors, config)
        else
            drawBeamProjectile(p, colors, config)
        end
    end
    love.graphics.setLineWidth(1)
end

function projectile.clear()
    for i = #projectile.list, 1, -1 do
        local p = projectile.list[i]
        if p.body then
            p.body:destroy()
        end
        table.remove(projectile.list, i)
    end
end

return projectile
