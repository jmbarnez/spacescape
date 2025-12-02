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

local function isOffscreen(p, world)
    if world then
        local margin = 100
        return p.x < world.minX - margin or p.x > world.maxX + margin or
               p.y < world.minY - margin or p.y > world.maxY + margin
    else
        return p.x < -50 or p.x > love.graphics.getWidth() + 50 or
               p.y < -50 or p.y > love.graphics.getHeight() + 50
    end
end

function projectile.spawn(shooter, targetX, targetY, targetEntity)

    local dx = targetX - shooter.x
    local dy = targetY - shooter.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)

    local weapon = shooter.weapon or {}
    local speed = weapon.projectileSpeed or 600
    local damage = weapon.damage or 20
    local faction = shooter.faction or "player"

    local hitChance = calculateHitChance(weapon, distance)
    local willHit = math.random() <= hitChance

    local x = shooter.x + math.cos(angle) * shooter.size
    local y = shooter.y + math.sin(angle) * shooter.size

    local physicsWorld = physics.getWorld()
    local body, shape, fixture
    if physicsWorld then
        body = love.physics.newBody(physicsWorld, x, y, "dynamic")
        shape = love.physics.newCircleShape(4)
        fixture = love.physics.newFixture(body, shape, 1)
        fixture:setSensor(true)
        body:setBullet(true)
        body:setFixedRotation(true)
        body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    end

    table.insert(projectile.list, {
        x = x,
        y = y,
        angle = angle,
        speed = speed,
        damage = damage,
        faction = faction,
        owner = shooter,
        target = targetEntity,
        willHit = willHit,
        body = body,
        shape = shape,
        fixture = fixture
    })

    shooter.angle = angle
end

function projectile.update(dt, world)
    for i = #projectile.list, 1, -1 do
        local p = projectile.list[i]
        local target = p.target

        if p.body then
            p.x, p.y = p.body:getPosition()

            if p.willHit and target and target.x and target.y then
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
            if p.willHit and target and target.x and target.y then
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

        -- Remove projectiles that are off screen
        if isOffscreen(p, world) then
            if p.body then
                p.body:destroy()
            end
            table.remove(projectile.list, i)
        end
    end
end

function projectile.draw(colors)
    for _, p in ipairs(projectile.list) do
        local beamLength = 20
        local beamWidth = 2
        local tailX = p.x - math.cos(p.angle) * beamLength
        local tailY = p.y - math.sin(p.angle) * beamLength

        -- Outer glow
        love.graphics.setColor(colors.projectile[1], colors.projectile[2], colors.projectile[3], 0.3)
        love.graphics.setLineWidth(beamWidth + 2)
        love.graphics.line(p.x, p.y, tailX, tailY)

        -- Core beam
        love.graphics.setColor(colors.projectile)
        love.graphics.setLineWidth(beamWidth)
        love.graphics.line(p.x, p.y, tailX, tailY)

        -- Bright tip
        love.graphics.setColor(colors.projectile)
        love.graphics.setLineWidth(beamWidth)
        love.graphics.line(p.x, p.y, p.x + math.cos(p.angle) * 3, p.y + math.sin(p.angle) * 3)
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
