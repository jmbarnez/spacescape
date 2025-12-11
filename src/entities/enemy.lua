--------------------------------------------------------------------------------
-- ENEMY MODULE (ECS-BACKED)
-- Spawns enemies as ECS entities, provides legacy API compatibility
--------------------------------------------------------------------------------

local enemy = {}

local ecsWorld = require("src.ecs.world")
local assemblages = require("src.ecs.assemblages")
local Concord = require("lib.concord")
local physics = require("src.core.physics")
local config = require("src.core.config")
local weapons = require("src.core.weapons")
local ship_generator = require("src.utils.procedural_ship_generator")
local ship_renderer = require("src.render.ship_renderer")
local baseColors = require("src.core.colors")

--------------------------------------------------------------------------------
-- LEGACY LIST (computed from ECS world)
--------------------------------------------------------------------------------

function enemy.getList()
    local all = ecsWorld:query({ "ship", "faction", "position" }) or {}
    local enemies = {}
    for _, e in ipairs(all) do
        if e.faction and e.faction.name == "enemy" then
            table.insert(enemies, e)
        end
    end
    return enemies
end

-- Legacy .list property
setmetatable(enemy, {
    __index = function(t, k)
        if k == "list" then
            return enemy.getList()
        end
        return rawget(t, k)
    end
})

--------------------------------------------------------------------------------
-- SPAWN
--------------------------------------------------------------------------------

function enemy.spawn(world, safeRadius)
    local x, y

    if world then
        local margin = config.enemy.spawnMargin
        local centerX = world.centerX or (world.minX + world.maxX) / 2
        local centerY = world.centerY or (world.minY + world.maxY) / 2
        local minRadius = safeRadius or 0
        local halfWidth = (world.maxX - world.minX) / 2
        local halfHeight = (world.maxY - world.minY) / 2
        local maxRadius = math.min(halfWidth, halfHeight) - margin
        if maxRadius < 0 then maxRadius = 0 end

        if not safeRadius or minRadius <= 0 or minRadius >= maxRadius then
            x = math.random(world.minX + margin, world.maxX - margin)
            y = math.random(world.minY + margin, world.maxY - margin)
        else
            local t = math.random()
            local r = math.sqrt((maxRadius ^ 2 - minRadius ^ 2) * t + minRadius ^ 2)
            local angle = math.random() * math.pi * 2
            x = centerX + math.cos(angle) * r
            y = centerY + math.sin(angle) * r
        end
    else
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()
        local side = math.random(1, 4)

        if side == 1 then
            x, y = math.random(0, width), -30
        elseif side == 2 then
            x, y = width + 30, math.random(0, height)
        elseif side == 3 then
            x, y = math.random(0, width), height + 30
        else
            x, y = -30, math.random(0, height)
        end
    end

    local enemyConfig = config.enemy
    local size = enemyConfig.sizeMin + math.random() * (enemyConfig.sizeMax - enemyConfig.sizeMin)
    local ship = ship_generator.generate(size)
    local maxHealth = enemyConfig.maxHealth
    local collisionRadius = (ship and ship.boundingRadius) or size
    local consts = physics.constants

    local levelMin = enemyConfig.levelMin or 1
    local levelMax = enemyConfig.levelMax or levelMin
    local level = math.random(levelMin, levelMax)
    local levelStep = level - 1

    local healthPerLevel = enemyConfig.healthPerLevel or 0
    if levelStep > 0 and healthPerLevel ~= 0 then
        maxHealth = maxHealth * (1 + levelStep * healthPerLevel)
    end

    local detectionRange = enemyConfig.detectionRange
    local attackRange = enemyConfig.attackRange
    local detectionPerLevel = enemyConfig.detectionRangePerLevel or 0
    local attackPerLevel = enemyConfig.attackRangePerLevel or 0
    if levelStep > 0 then
        if detectionRange and detectionPerLevel ~= 0 then
            detectionRange = detectionRange * (1 + levelStep * detectionPerLevel)
        end
        if attackRange and attackPerLevel ~= 0 then
            attackRange = attackRange * (1 + levelStep * attackPerLevel)
        end
    end

    local baseWeapon = weapons.enemyPulseLaser
    local weaponData = {}
    if baseWeapon then
        for k, v in pairs(baseWeapon) do
            weaponData[k] = v
        end
        local damagePerLevel = enemyConfig.weaponDamagePerLevel or 0
        local baseDamage = weaponData.damage or 1
        if levelStep > 0 and damagePerLevel ~= 0 then
            weaponData.damage = baseDamage * (1 + levelStep * damagePerLevel)
        end
    end

    -- Create ECS entity
    local e = Concord.entity(ecsWorld)
    e:give("position", x, y)
        :give("velocity",
            (math.random() - 0.5) * enemyConfig.initialDriftSpeed,
            (math.random() - 0.5) * enemyConfig.initialDriftSpeed)
        :give("rotation", math.random() * math.pi * 2)
        :give("faction", "enemy")
        :give("ship")
        :give("damageable")
        :give("health", maxHealth, maxHealth)
        :give("size", size)
        :give("collisionRadius", collisionRadius)
        :give("thrust", consts.enemyThrust, consts.enemyMaxSpeed)
        :give("weapon", weaponData)
        :give("shipVisual", ship)
        :give("aiState", "idle", detectionRange, attackRange)
        :give("enemyLevel", level)
        :give("wanderBehavior", math.random() * math.pi * 2,
            enemyConfig.wanderIntervalBase + math.random() * enemyConfig.wanderIntervalRandom,
            enemyConfig.wanderRadius)
        :give("spawnPosition", x, y)
        :give("xpReward", config.player.xpPerEnemy or 0)
        :give("tokenReward", config.player.tokensPerEnemy or 0)
        :give("damping", 0.8)

    -- Create physics body
    local collisionVertices = nil
    if ship then
        if ship.collisionVertices and #ship.collisionVertices >= 6 then
            collisionVertices = ship.collisionVertices
        elseif ship.hull and ship.hull.points then
            collisionVertices = ship_generator.getBaseOutline(ship)
        end
    end

    local body, shapes, fixtures
    if collisionVertices and #collisionVertices >= 6 then
        body, shapes, fixtures = physics.createPolygonBody(x, y, collisionVertices, "ENEMY", e)
    else
        local b, s, f = physics.createCircleBody(x, y, collisionRadius, "ENEMY", e)
        body = b
        shapes = s and { s } or nil
        fixtures = f and { f } or nil
    end

    if body then
        e:give("physics", body, shapes, fixtures)
    end

    return e
end

--------------------------------------------------------------------------------
-- UPDATE (AI and movement now handled by ECS systems)
--------------------------------------------------------------------------------

function enemy.update(dt, playerState, world)
    -- Convert player state to ECS-compatible format for AI system
    local playerEntity = ecsWorld:getPlayer()

    -- If no ECS player yet, create a temporary wrapper for AI to use
    if not playerEntity and playerState then
        playerEntity = {
            position = { x = playerState.x, y = playerState.y }
        }
    end

    -- Run AI and movement via ECS world emit
    ecsWorld:emit("update", dt, playerEntity)

    -- Handle world boundaries
    local enemies = enemy.getList()
    for _, e in ipairs(enemies) do
        if world and e.position then
            local pos = e.position
            local radius = e.collisionRadius and e.collisionRadius.radius or 20
            local vel = e.velocity or { vx = 0, vy = 0 }

            if pos.x < world.minX + radius then
                pos.x = world.minX + radius
                vel.vx = math.abs(vel.vx) * 0.5
            elseif pos.x > world.maxX - radius then
                pos.x = world.maxX - radius
                vel.vx = -math.abs(vel.vx) * 0.5
            end
            if pos.y < world.minY + radius then
                pos.y = world.minY + radius
                vel.vy = math.abs(vel.vy) * 0.5
            elseif pos.y > world.maxY - radius then
                pos.y = world.maxY - radius
                vel.vy = -math.abs(vel.vy) * 0.5
            end

            -- Sync physics body
            if e.physics and e.physics.body then
                e.physics.body:setPosition(pos.x, pos.y)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function enemy.draw(colors)
    colors = colors or baseColors
    local enemies = enemy.getList()

    for _, e in ipairs(enemies) do
        local px = e.position.x
        local py = e.position.y
        local angle = e.rotation and e.rotation.angle or 0
        local ship = e.shipVisual and e.shipVisual.ship

        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(angle)

        if ship then
            ship_renderer.drawEnemy(ship, colors)
        end

        love.graphics.pop()

        -- Health bar (ECS component, always visible above the enemy)
        local healthComp = e.health
        local healthCurrent = healthComp and healthComp.current or 0
        local healthMax = healthComp and healthComp.max or 0

        -- Only skip if we truly have no valid health data
        if healthCurrent and healthMax and healthMax > 0 then
            -- Compute health bar placement relative to the enemy's collision radius
            local radius = (type(e.collisionRadius) == "table" and e.collisionRadius.radius) or e.collisionRadius or 10
            local barWidth = radius * 0.9
            local barHeight = 3
            local barX = px - barWidth
            local barY = py - radius - 10

            -- Background segment of the health bar
            love.graphics.setColor(colors.healthBg)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2, barHeight)

            -- Foreground segment shows current health ratio
            local ratio = math.max(0, math.min(1, healthCurrent / healthMax))
            love.graphics.setColor(colors.health)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, barHeight)

            -- Level label (e.g., "Lv 2") rendered just above the health bar
            local levelComp = e.enemyLevel
            local level = levelComp and levelComp.level
            if level then
                local label = "Lv " .. tostring(level)
                local font = love.graphics.getFont()
                local textWidth = font and font:getWidth(label) or 0
                local textHeight = font and font:getHeight() or 0
                local textX = px - textWidth / 2
                local textY = barY - textHeight - 2

                love.graphics.setColor(colors.uiText or colors.white or { 1, 1, 1, 1 })
                love.graphics.print(label, textX, textY)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- CLEAR
--------------------------------------------------------------------------------

function enemy.clear()
    local enemies = enemy.getList()

    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if e.physics and e.physics.body then
            e.physics.body:destroy()
        end
        e:destroy()
    end
end

return enemy
