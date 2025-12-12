--------------------------------------------------------------------------------
-- ENEMY MODULE (ECS-BACKED)
-- Spawns enemies as ECS entities, provides legacy API compatibility
--------------------------------------------------------------------------------

local enemy = {}

local ecsWorld = require("src.ecs.world")
local assemblages = require("src.ecs.assemblages")
local Concord = require("lib.concord")
local physics = require("src.core.physics")
local core_ship = require("src.core.ship")
local config = require("src.core.config")
local weapons = require("src.core.weapons")
local enemyDefs = require("src.data.enemies")
local ship_renderer = require("src.render.ship_renderer")
local baseColors = require("src.core.colors")

--------------------------------------------------------------------------------
-- LEGACY LIST (computed from ECS world)
--------------------------------------------------------------------------------

function enemy.getList()
    local all = ecsWorld:query({ "ship", "faction", "position" }) or {}
    local enemies = {}
    for _, e in ipairs(all) do
        -- Entities can be flagged for removal (or destroyed) during collision
        -- resolution, but still appear in queries until the ECS flush.
        -- Filtering them here prevents legacy callers from touching entities
        -- whose physics bodies were already destroyed.
        if e.faction and e.faction.name == "enemy" and not e._removed and not e.removed then
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

-- NOTE: Enemy spawning is now data-driven.
--
-- The spawn pipeline is:
--   spawnSystem -> enemy.spawn(...) -> pick enemy definition -> build ship
--
-- Enemy definitions live in:
--   src/data/enemies/*.lua
-- and reference ship blueprints in:
--   src/data/ships/*.lua
--
-- This replaces procedural ship generation so ship design, level range, stats,
-- and rewards can be authored explicitly.

local function randFloat(min, max)
    if min == nil and max == nil then
        return 0
    end
    if max == nil then
        return min
    end
    return min + math.random() * (max - min)
end

local function pickEnemyDef()
    if enemyDefs and enemyDefs.list and #enemyDefs.list > 0 then
        return enemyDefs.list[math.random(1, #enemyDefs.list)]
    end
    return enemyDefs and enemyDefs.default or nil
end

function enemy.spawn(world, safeRadius, specificDef, spawnX, spawnY)
    local x, y

    if spawnX and spawnY then
        x, y = spawnX, spawnY
    elseif world then
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
    local consts = physics.constants

    ------------------------------------------------------------------------
    -- Select which enemy type to spawn (data-driven)
    ------------------------------------------------------------------------
    local def = specificDef or pickEnemyDef()
    if not def then
        -- No enemy definitions available; bail safely.
        return nil
    end

    ------------------------------------------------------------------------
    -- Level + size
    ------------------------------------------------------------------------
    local levelMin = (def.levelRange and def.levelRange.min) or enemyConfig.levelMin or 1
    local levelMax = (def.levelRange and def.levelRange.max) or enemyConfig.levelMax or levelMin
    if levelMax < levelMin then
        levelMax = levelMin
    end

    local level = math.random(levelMin, levelMax)
    local levelStep = level - 1

    local sizeMin = (def.sizeRange and def.sizeRange.min) or enemyConfig.sizeMin
    local sizeMax = (def.sizeRange and def.sizeRange.max) or enemyConfig.sizeMax
    local size = randFloat(sizeMin, sizeMax)

    ------------------------------------------------------------------------
    -- Ship design (authored blueprint -> concrete instance)
    ------------------------------------------------------------------------
    local shipBlueprint = def.shipBlueprint
    local ship = core_ship.buildInstanceFromBlueprint(shipBlueprint, size)
    local collisionRadius = (ship and ship.boundingRadius) or size

    ------------------------------------------------------------------------
    -- Health scaling
    ------------------------------------------------------------------------
    local baseHealth = (def.health and def.health.base) or enemyConfig.maxHealth
    local healthPerLevel = (def.health and def.health.perLevel) or enemyConfig.healthPerLevel or 0
    local maxHealth = baseHealth
    if levelStep > 0 and healthPerLevel ~= 0 then
        maxHealth = maxHealth * (1 + levelStep * healthPerLevel)
    end

    ------------------------------------------------------------------------
    -- AI ranges
    --
    -- Detection scaling is disabled globally via config (and can be authored
    -- per enemy definition). Attack range may still scale if desired.
    ------------------------------------------------------------------------
    local detectionRange = (def.ai and def.ai.detectionRange) or enemyConfig.detectionRange
    local attackRange = (def.ai and def.ai.attackRange) or enemyConfig.attackRange
    local attackPerLevel = (def.ai and def.ai.attackRangePerLevel) or enemyConfig.attackRangePerLevel or 0
    if levelStep > 0 and attackPerLevel ~= 0 then
        attackRange = attackRange * (1 + levelStep * attackPerLevel)
    end

    ------------------------------------------------------------------------
    -- Weapon selection
    ------------------------------------------------------------------------
    local weaponId = (def.weapon and def.weapon.id) or "enemyPulseLaser"
    local baseWeapon = weapons[weaponId] or weapons.enemyPulseLaser
    local weaponData = {}
    if baseWeapon then
        for k, v in pairs(baseWeapon) do
            weaponData[k] = v
        end

        -- Optional per-enemy damage override.
        if def.weapon and def.weapon.damage ~= nil then
            weaponData.damage = def.weapon.damage
        end

        local damagePerLevel = (def.weapon and def.weapon.damagePerLevel) or enemyConfig.weaponDamagePerLevel or 0
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
        :give("xpReward", (def.rewards and def.rewards.xp) or config.player.xpPerEnemy or 0)
        :give("tokenReward", (def.rewards and def.rewards.tokens) or config.player.tokensPerEnemy or 0)
        :give("damping", 0.8)

    if def.respawn then
        e:give("respawnOnDeath", def.respawn.delay, def)
    end

    -- Optional loot definition (spawns a wreck via RewardSystem on death).
    if def.rewards and def.rewards.loot then
        local cargo = def.rewards.loot.cargo
        local coins = def.rewards.loot.coins
        e:give("loot", cargo, coins)
    end

    -- Create physics body
    local collisionVertices = nil
    if ship and ship.collisionVertices and #ship.collisionVertices >= 6 then
        collisionVertices = ship.collisionVertices
    end

    local body, shapes, fixtures
    if collisionVertices and #collisionVertices >= 6 then
        body, shapes, fixtures = physics.createPolygonBody(x, y, collisionVertices, "ENEMY", e, {})
    else
        local b, s, f = physics.createCircleBody(x, y, collisionRadius, "ENEMY", e, {})
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
    -- Handle world boundaries
    local enemies = enemy.getList()
    for _, e in ipairs(enemies) do
        if e._removed or e.removed then
            goto continue
        end

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
                -- Box2D bodies can be destroyed before the ECS entity is
                -- flushed/removed. Accessing a destroyed body throws.
                if e.physics.body.isDestroyed and e.physics.body:isDestroyed() then
                    e.physics.body = nil
                else
                    e.physics.body:setPosition(pos.x, pos.y)
                end
            end
        end

        ::continue::
    end
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function enemy.draw(colors, player)
    colors = colors or baseColors
    -- Cache player level once so we can compare enemy levels against it for coloring
    local playerLevel = player and player.level or nil
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

            -- Level indicator: rendered in a black box to the left of the health bar.
            -- The text color reflects how dangerous the enemy is relative to the player:
            -- green  = enemy level lower than player level
            -- yellow = enemy level equal to player level
            -- red    = enemy level higher than player level
            local levelComp = e.enemyLevel
            local level = levelComp and levelComp.level
            if level then
                local label = tostring(level)
                local font = love.graphics.getFont()
                local textWidth = font and font:getWidth(label) or 0
                local textHeight = font and font:getHeight() or 0

                -- Box sizing and placement: snug box just to the left of the bar
                local paddingX = 4
                local paddingY = 2
                local boxWidth = textWidth + paddingX * 2
                local boxHeight = barHeight + paddingY * 2
                local boxRight = barX - 4
                local boxX = boxRight - boxWidth
                local boxY = barY - (boxHeight - barHeight) / 2

                -- Black background box to anchor the level badge
                love.graphics.setColor(0, 0, 0, 0.9)
                love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight)

                -- Choose text color based on comparison with player level
                local r, g, b, a = 1, 1, 1, 1
                if playerLevel then
                    if level < playerLevel then
                        local c = colors.levelEasy or { 0.0, 1.0, 0.0, 1.0 }
                        r, g, b, a = c[1], c[2], c[3], c[4] or 1.0
                    elseif level == playerLevel then
                        local c = colors.levelEven or { 1.0, 1.0, 0.0, 1.0 }
                        r, g, b, a = c[1], c[2], c[3], c[4] or 1.0
                    else
                        local c = colors.levelHard or { 1.0, 0.1, 0.1, 1.0 }
                        r, g, b, a = c[1], c[2], c[3], c[4] or 1.0
                    end
                end

                love.graphics.setColor(r, g, b, a)
                local textX = boxX + (boxWidth - textWidth) / 2
                local textY = boxY + (boxHeight - textHeight) / 2
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
