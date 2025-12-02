local enemy = {}

enemy.list = {}

local ship_generator = require("src.utils.procedural_ship_generator")
local physics = require("src.core.physics")
local weapons = require("src.core.weapons")
local projectileModule = require("src.entities.projectile")

function enemy.spawn(world)
    local side = math.random(1, 4)
    local x, y

    if world then
        local margin = 50
        x = math.random(world.minX + margin, world.maxX - margin)
        y = math.random(world.minY + margin, world.maxY - margin)
    else
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()

        if side == 1 then
            x = math.random(0, width)
            y = -30
        elseif side == 2 then
            x = width + 30
            y = math.random(0, height)
        elseif side == 3 then
            x = math.random(0, width)
            y = height + 30
        else
            x = -30
            y = math.random(0, height)
        end
    end

    local size = 15 + math.random() * 10
    local ship = ship_generator.generate(size)
    local maxHealth = (ship and ship.hull and ship.hull.maxHealth) or 1

    local collisionRadius = (ship and ship.boundingRadius) or size

    local physicsWorld = physics.getWorld()
    local body, shape, fixture
    if physicsWorld then
        body = love.physics.newBody(physicsWorld, x, y, "dynamic")
        shape = love.physics.newCircleShape(collisionRadius)
        fixture = love.physics.newFixture(body, shape, 1)
        body:setFixedRotation(true)
    end

    table.insert(enemy.list, {
        x = x,
        y = y,
        size = size,
        speed = 80 + math.random() * 60,
        health = maxHealth,
        maxHealth = maxHealth,
        angle = 0,
        ship = ship,
        collisionRadius = collisionRadius,
        body = body,
        shape = shape,
        fixture = fixture,
        faction = "enemy",
        weapon = weapons.enemyPulseLaser,
        state = "idle",
        detectionRange = 600,
        attackRange = 350,
        fireTimer = 0
    })
end

function enemy.update(dt, playerState, world)
    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]

        local dx = playerState.x - e.x
        local dy = playerState.y - e.y
        local distance = math.sqrt(dx * dx + dy * dy)

        local detectionRange = e.detectionRange or 600
        local attackRange = e.attackRange or 350

        if distance > detectionRange then
            e.state = "idle"
        elseif distance > attackRange then
            e.state = "chase"
        else
            e.state = "attack"
        end

        if e.state == "chase" then
            if distance > 0 then
                e.x = e.x + (dx / distance) * e.speed * dt
                e.y = e.y + (dy / distance) * e.speed * dt
            end
        elseif e.state == "attack" then
            if distance > attackRange * 1.1 and distance > 0 then
                e.x = e.x + (dx / distance) * e.speed * dt
                e.y = e.y + (dy / distance) * e.speed * dt
            elseif distance < attackRange * 0.8 and distance > 0 then
                e.x = e.x - (dx / distance) * e.speed * dt * 0.5
                e.y = e.y - (dy / distance) * e.speed * dt * 0.5
            end

            local weapon = e.weapon or {}
            local interval = weapon.fireInterval or 1.0
            e.fireTimer = (e.fireTimer or 0) + dt
            if e.fireTimer >= interval then
                e.fireTimer = 0
                projectileModule.spawn(e, playerState.x, playerState.y, playerState)
            end
        end

        if distance > 0 then
            e.angle = math.atan2(dy, dx)
        end

        if world then
            local margin = e.collisionRadius or e.size
            e.x = math.max(world.minX + margin, math.min(world.maxX - margin, e.x))
            e.y = math.max(world.minY + margin, math.min(world.maxY - margin, e.y))
        end

        if e.body then
            e.body:setPosition(e.x, e.y)
        end
    end
end

function enemy.draw(colors)
    for _, e in ipairs(enemy.list) do
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.rotate(e.angle)

        ship_generator.draw(e.ship, colors)

        love.graphics.pop()

        if e.maxHealth and e.health and e.health < e.maxHealth then
            local radius = (e.ship and e.ship.boundingRadius) or e.size or 10
            local barWidth = radius * 0.9
            local barHeight = 3
            local barX = e.x - barWidth
            local barY = e.y - radius - 10

            love.graphics.setColor(colors.healthBg)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2, barHeight)

            local ratio = math.max(0, math.min(1, e.health / e.maxHealth))
            love.graphics.setColor(colors.health)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, barHeight)
        end
    end
end

function enemy.clear()
    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]
        if e.body then
            e.body:destroy()
        end
        table.remove(enemy.list, i)
    end
end

return enemy
