local enemy = {}

enemy.list = {}

local ship_generator = require("src.utils.procedural_ship_generator")
local physics = require("src.core.physics")
local weapons = require("src.core.weapons")
local projectileModule = require("src.entities.projectile")
local config = require("src.core.config")

function enemy.spawn(world, safeRadius)
    local side = math.random(1, 4)
    local x, y

    if world then
        local margin = config.enemy.spawnMargin
        local centerX = world.centerX or (world.minX + world.maxX) / 2
        local centerY = world.centerY or (world.minY + world.maxY) / 2
        local minRadius = safeRadius or 0
        local halfWidth = (world.maxX - world.minX) / 2
        local halfHeight = (world.maxY - world.minY) / 2
        local maxRadius = math.min(halfWidth, halfHeight) - margin
        if maxRadius < 0 then
            maxRadius = 0
        end
        if not safeRadius or minRadius <= 0 or minRadius >= maxRadius then
            x = math.random(world.minX + margin, world.maxX - margin)
            y = math.random(world.minY + margin, world.maxY - margin)
        else
            local rMin = minRadius
            local rMax = maxRadius
            local t = math.random()
            local r = math.sqrt((rMax * rMax - rMin * rMin) * t + rMin * rMin)
            local angle = math.random() * math.pi * 2
            x = centerX + math.cos(angle) * r
            y = centerY + math.sin(angle) * r
        end
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

    local size = config.enemy.sizeMin + math.random() * (config.enemy.sizeMax - config.enemy.sizeMin)
    local ship = ship_generator.generate(size)
    local maxHealth = config.enemy.maxHealth

    local collisionRadius = (ship and ship.boundingRadius) or size
    local consts = physics.constants
    
    -- Get collision vertices from the ship's hull
    local collisionVertices = nil
    if ship and ship.hull and ship.hull.points then
        collisionVertices = ship_generator.getBaseOutline(ship)
    end
    
    -- Create the enemy entity first (so we can pass it to physics)
    local newEnemy = {
        x = x,
        y = y,
        -- Zero-g velocity
        vx = (math.random() - 0.5) * config.enemy.initialDriftSpeed,  -- Small initial drift
        vy = (math.random() - 0.5) * config.enemy.initialDriftSpeed,
        size = size,
        thrust = consts.enemyThrust,
        maxSpeed = consts.enemyMaxSpeed,
        health = maxHealth,
        maxHealth = maxHealth,
        angle = math.random() * math.pi * 2,
        targetAngle = 0,
        ship = ship,
        collisionRadius = collisionRadius,
        collisionVertices = collisionVertices,
        body = nil,
        shapes = nil,   -- Table of shapes (polygon body may have multiple)
        fixtures = nil, -- Table of fixtures
        faction = "enemy",
        weapon = weapons.enemyPulseLaser,
        state = "idle",
        detectionRange = config.enemy.detectionRange,
        attackRange = config.enemy.attackRange,
        fireTimer = 0,
        wanderAngle = math.random() * math.pi * 2,
        wanderTimer = config.enemy.wanderIntervalBase + math.random() * config.enemy.wanderIntervalRandom,
        isThrusting = false
    }
    
    -- Create physics body with polygon collision from ship hull
    if collisionVertices and #collisionVertices >= 6 then
        newEnemy.body, newEnemy.shapes, newEnemy.fixtures = physics.createPolygonBody(
            x, y,
            collisionVertices,
            "ENEMY",
            newEnemy
        )
    else
        -- Fallback to circle if no valid hull vertices
        local body, shape, fixture = physics.createCircleBody(
            x, y,
            collisionRadius,
            "ENEMY",
            newEnemy
        )
        newEnemy.body = body
        newEnemy.shapes = shape and {shape} or nil
        newEnemy.fixtures = fixture and {fixture} or nil
    end
    
    table.insert(enemy.list, newEnemy)
end

function enemy.update(dt, playerState, world)
    local consts = physics.constants
    local activeEnemyIndex = nil
    local closestDistSq = math.huge

    for i = 1, #enemy.list do
        local e = enemy.list[i]
        local dx = playerState.x - e.x
        local dy = playerState.y - e.y
        local distSq = dx * dx + dy * dy
        local detectionRange = e.detectionRange or config.enemy.detectionRange

        if distSq <= detectionRange * detectionRange and distSq < closestDistSq then
            closestDistSq = distSq
            activeEnemyIndex = i
        end
    end

    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]

        local dx = playerState.x - e.x
        local dy = playerState.y - e.y
        local distance = math.sqrt(dx * dx + dy * dy)

        local weapon = e.weapon or {}
        local optimalRange = weapon.optimalRange or e.attackRange or config.enemy.attackRange
        local detectionRange = e.detectionRange or config.enemy.detectionRange
        local attackRange = optimalRange

        -- Determine AI state
        if i == activeEnemyIndex then
            if distance > detectionRange then
                e.state = "idle"
            elseif distance > attackRange then
                e.state = "chase"
            else
                e.state = "attack"
            end
        else
            e.state = "idle"
        end

        -- Calculate target angle based on state
        local thrustAngle = e.angle
        e.isThrusting = false
        
        if e.state == "chase" then
            -- Chase: thrust towards player
            if distance > 0 then
                e.targetAngle = math.atan2(dy, dx)
                local angleDiff = math.abs(physics.normalizeAngle(e.targetAngle - e.angle))
                if angleDiff < math.pi / 2 then
                    e.isThrusting = true
                    thrustAngle = e.angle
                end
            end
        elseif e.state == "attack" then
            -- Attack: maintain optimal range
            e.targetAngle = math.atan2(dy, dx)
            if distance > attackRange * config.enemy.attackTooFarFactor and distance > 0 then
                -- Too far, thrust towards
                local angleDiff = math.abs(physics.normalizeAngle(e.targetAngle - e.angle))
                if angleDiff < math.pi / 2 then
                    e.isThrusting = true
                    thrustAngle = e.angle
                end
            elseif distance < attackRange * config.enemy.attackTooCloseFactor and distance > 0 then
                -- Too close, thrust away (reverse thrust)
                local awayAngle = math.atan2(-dy, -dx)
                local angleDiff = math.abs(physics.normalizeAngle(awayAngle - e.angle))
                if angleDiff < math.pi / 2 then
                    e.isThrusting = true
                    thrustAngle = awayAngle
                end
            end
        elseif e.state == "idle" then
            -- Idle: gentle wandering with occasional thrust
            e.wanderTimer = (e.wanderTimer or 0) - dt
            if not e.wanderAngle then
                e.wanderAngle = math.random() * math.pi * 2
            end
            if e.wanderTimer <= 0 then
                e.wanderAngle = math.random() * math.pi * 2
                e.wanderTimer = config.enemy.wanderIntervalBase + math.random() * config.enemy.wanderIntervalRandom  -- Longer intervals for space feel
            end
            e.targetAngle = e.wanderAngle
            -- Only thrust occasionally when idle (drifting mostly)
            if e.wanderTimer > config.enemy.wanderThrustThreshold then
                local angleDiff = math.abs(physics.normalizeAngle(e.targetAngle - e.angle))
                if angleDiff < math.pi / 4 then
                    e.isThrusting = true
                    thrustAngle = e.angle
                end
            end
        end

        -- Smoothly rotate towards target angle
        e.angle = physics.rotateTowards(e.angle, e.targetAngle, consts.shipRotationSpeed * 0.8, dt)

        -- Apply thrust if thrusting
        if e.isThrusting then
            e.vx, e.vy = physics.applyThrust(e.vx, e.vy, thrustAngle, e.thrust, dt, e.maxSpeed)
        end

        -- Apply minimal damping
        e.vx, e.vy = physics.applyDamping(e.vx, e.vy, consts.linearDamping, dt)

        -- Update position based on velocity
        e.x = e.x + e.vx * dt
        e.y = e.y + e.vy * dt

        -- Firing logic
        local interval = weapon.fireInterval or 1.0
        e.fireTimer = (e.fireTimer or 0) + dt
        if i == activeEnemyIndex and distance <= detectionRange and e.fireTimer >= interval then
            e.fireTimer = 0
            projectileModule.spawn(e, playerState.x, playerState.y, playerState)
        end

        -- World boundary handling with bounce
        if world then
            local margin = e.collisionRadius or e.size
            if e.x < world.minX + margin then
                e.x = world.minX + margin
                e.vx = math.abs(e.vx) * 0.5
            elseif e.x > world.maxX - margin then
                e.x = world.maxX - margin
                e.vx = -math.abs(e.vx) * 0.5
            end
            if e.y < world.minY + margin then
                e.y = world.minY + margin
                e.vy = math.abs(e.vy) * 0.5
            elseif e.y > world.maxY - margin then
                e.y = world.maxY - margin
                e.vy = -math.abs(e.vy) * 0.5
            end
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
