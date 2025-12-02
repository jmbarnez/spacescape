local projectile = {}

projectile.list = {}

local physics = require("src.core.physics")

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

function projectile.spawn(player, targetX, targetY)
    local angle = math.atan2(targetY - player.y, targetX - player.x)

    local weapon = player.weapon or {}
    local speed = weapon.projectileSpeed or 600
    local damage = weapon.damage or 20

    local x = player.x + math.cos(angle) * player.size
    local y = player.y + math.sin(angle) * player.size

    local physicsWorld = physics.getWorld()
    local body, shape, fixture
    if physicsWorld then
        body = love.physics.newBody(physicsWorld, x, y, "dynamic")
        shape = love.physics.newCircleShape(4)
        fixture = love.physics.newFixture(body, shape, 1)
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
        body = body,
        shape = shape,
        fixture = fixture
    })

    player.angle = angle
end

function projectile.update(dt, world)
    for i = #projectile.list, 1, -1 do
        local p = projectile.list[i]
        if p.body then
            p.x, p.y = p.body:getPosition()
        else
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
    love.graphics.setColor(colors.projectile)
    for _, p in ipairs(projectile.list) do
        love.graphics.circle("fill", p.x, p.y, 4)

        -- Projectile trail
        love.graphics.setColor(colors.projectile[1], colors.projectile[2], colors.projectile[3], 0.3)
        local trailX = p.x - math.cos(p.angle) * 15
        local trailY = p.y - math.sin(p.angle) * 15
        love.graphics.line(p.x, p.y, trailX, trailY)
        love.graphics.setColor(colors.projectile)
    end
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
