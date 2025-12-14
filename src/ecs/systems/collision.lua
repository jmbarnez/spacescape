--------------------------------------------------------------------------------
-- COLLISION SYSTEM (ECS)
-- Generic faction-based collision handling
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local baseColors = require("src.core.colors")
local config = require("src.core.config")

local CollisionSystem = Concord.system({
    -- Projectiles that can deal damage
    projectiles = { "projectile", "position", "damage", "faction" },
    -- Entities that can take damage
    damageables = { "damageable", "position", "health" },
    -- Ships for ramming
    ships = { "ship", "position", "faction", "health" },
})

--------------------------------------------------------------------------------
-- DAMAGE APPLICATION
--------------------------------------------------------------------------------

local function getCollisionRadius(e)
    if not e then
        return 0
    end

    if e.collisionRadius then
        return e.collisionRadius.radius or 0
    end

    if e.size then
        return e.size.value or 0
    end

    return 0
end

local function isPlayerShip(e)
    return e and (e.playerControlled == true or e.playerControlled ~= nil or (e.faction and e.faction.name == "player"))
end

--- Apply damage to an entity, shields first then hull
--- @param entity table The entity to damage
--- @param amount number The damage amount
--- @return boolean died, number shieldDamage, number hullDamage
local function applyDamage(entity, amount)
    if not entity or amount <= 0 then
        return false, 0, 0
    end

    local shieldDamage = 0
    local hullDamage = 0

    -- Shield absorbs first
    if entity.shield and entity.shield.current > 0 then
        if amount <= entity.shield.current then
            entity.shield.current = entity.shield.current - amount
            shieldDamage = amount
            return false, shieldDamage, hullDamage
        else
            shieldDamage = entity.shield.current
            amount = amount - entity.shield.current
            entity.shield.current = 0
        end
    end

    -- Remaining goes to hull
    entity.health.current = entity.health.current - amount
    hullDamage = amount

    return entity.health.current <= 0, shieldDamage, hullDamage
end

--------------------------------------------------------------------------------
-- COLLISION RESOLUTION
--------------------------------------------------------------------------------

--- Handle projectile hitting a damageable target
--- @param self table The system instance
--- @param projectile table The projectile entity
--- @param target table The target entity
--- @param contactX number Contact point X
--- @param contactY number Contact point Y
function CollisionSystem:handleProjectileHit(projectile, target, contactX, contactY)
    -- Faction check: ignore friendly fire
    local projectileFaction = (projectile.faction and projectile.faction.name) or "neutral"
    local targetFaction = (target.faction and target.faction.name) or "neutral"

    if projectileFaction == targetFaction then
        return -- Same faction, ignore
    end

    -- Get damage amount
    local damage = projectile.damage.amount

    -- Apply damage
    local died, shieldDamage, hullDamage = applyDamage(target, damage)

    -- Emit damage event for VFX systems to react
    local world = self:getWorld()
    world:emit("onDamage", target, damage, shieldDamage, hullDamage, contactX, contactY)

    -- Handle death
    if died then
        world:emit("onDeath", target, projectileFaction)
    end

    -- Mark projectile for removal
    projectile:give("removed")
end

--- Handle ship ramming another ship
--- @param self table The system instance
--- @param attacker table The attacking ship
--- @param defender table The defending ship
--- @param contactX number Contact point X
--- @param contactY number Contact point Y
function CollisionSystem:handleShipRam(attacker, defender, contactX, contactY)
    -- Faction check: ignore same faction
    local attackerFaction = attacker.faction.name
    local defenderFaction = defender.faction.name

    if attackerFaction == defenderFaction then
        return
    end

    -- Get damage (configurable)
    local damage = config.combat.ramDamage or config.combat.damagePerHit or 20
    local world = self:getWorld()

    -- Apply damage to defender
    local defenderDied, defShieldDmg, defHullDmg = applyDamage(defender, damage)
    world:emit("onDamage", defender, damage, defShieldDmg, defHullDmg, contactX, contactY)

    if defenderDied then
        world:emit("onDeath", defender, attackerFaction)
    end

    -- Optionally apply damage to attacker too (ramming costs)
    local attackerDied, atkShieldDmg, atkHullDmg = applyDamage(attacker, damage)
    world:emit("onDamage", attacker, damage, atkShieldDmg, atkHullDmg, contactX, contactY)

    if attackerDied then
        world:emit("onDeath", attacker, defenderFaction)
    end
end

function CollisionSystem:handleShipVsAsteroid(ship, asteroid, contactX, contactY)
    if not (ship and ship.position and ship.velocity and asteroid and asteroid.position) then
        return
    end

    local shipRadius = getCollisionRadius(ship)
    local asteroidRadius = getCollisionRadius(asteroid)
    if shipRadius <= 0 or asteroidRadius <= 0 then
        return
    end

    local shipX = ship.position.x
    local shipY = ship.position.y
    local astX = asteroid.position.x
    local astY = asteroid.position.y

    local dx = shipX - astX
    local dy = shipY - astY
    local distSq = dx * dx + dy * dy
    if distSq <= 0 then
        return
    end

    local distance = math.sqrt(distSq)
    local minDist = shipRadius + asteroidRadius
    if distance >= minDist then
        return
    end

    local invDist = 1.0 / distance
    local nx = dx * invDist
    local ny = dy * invDist
    local overlap = minDist - distance

    -- Push ship out of the asteroid.
    local newX = shipX + nx * overlap
    local newY = shipY + ny * overlap
    ship.position.x = newX
    ship.position.y = newY

    if ship.physics and ship.physics.body then
        ship.physics.body:setPosition(newX, newY)
    end

    local shield = ship.shield and ship.shield.current or 0
    if isPlayerShip(ship) and shield > 0 then
        -- Reflect velocity along contact normal so the player "bounces".
        local vx = ship.velocity.vx or 0
        local vy = ship.velocity.vy or 0
        local dot = vx * nx + vy * ny
        if dot < 0 then
            local bounce = (config.player and config.player.bounceFactor) or 0.5
            local rvx = vx - 2 * dot * nx
            local rvy = vy - 2 * dot * ny
            ship.velocity.vx = rvx * bounce
            ship.velocity.vy = rvy * bounce
        end

        local ix = contactX
        local iy = contactY
        if not ix or not iy then
            ix = astX + nx * asteroidRadius
            iy = astY + ny * asteroidRadius
        end

        local world = self:getWorld()
        if world and world.emit then
            world:emit("onAsteroidBump", ship, ix, iy)
        end
    end
end

--------------------------------------------------------------------------------
-- BOX2D INTEGRATION
--------------------------------------------------------------------------------

--- Process a collision between two entities
--- Called from the physics callback system
function CollisionSystem:processCollision(entityA, entityB, contactX, contactY)
    if not entityA or not entityB then return end

    -- Check for removed entities
    if entityA.removed or entityB.removed then return end

    -- Projectile vs Damageable
    local projectile = entityA.projectile and entityA or (entityB.projectile and entityB)
    local target = nil

    if projectile then
        -- Find the other entity as target
        target = (projectile == entityA) and entityB or entityA

        if target and target.damageable then
            local cx = contactX or target.position.x
            local cy = contactY or target.position.y
            self:handleProjectileHit(projectile, target, cx, cy)
            return
        end
    end

    -- Ship vs Ship (ram)
    if entityA.ship and entityB.ship then
        local cx = contactX or (entityA.position.x + entityB.position.x) / 2
        local cy = contactY or (entityA.position.y + entityB.position.y) / 2
        self:handleShipRam(entityA, entityB, cx, cy)
        return
    end

    -- Ship vs Asteroid (bump/resolve)
    local ship = (entityA.ship and entityA) or (entityB.ship and entityB)
    local asteroid = (entityA.asteroid and entityA) or (entityB.asteroid and entityB)
    if ship and asteroid then
        self:handleShipVsAsteroid(ship, asteroid, contactX, contactY)
        return
    end
end

--------------------------------------------------------------------------------
-- CLEANUP SYSTEM
-- Removes entities marked with 'removed' component
--------------------------------------------------------------------------------

local CleanupSystem = Concord.system({
    toRemove = { "removed" },
})

function CleanupSystem:postPhysics(dt)
    for i = self.toRemove.size, 1, -1 do
        local e = self.toRemove[i]
        if e.physics and e.physics.body then
            e.physics.body:destroy()
        end
        e:destroy()
    end
end

function CleanupSystem:update(dt)
    self:postPhysics(dt)
end

return {
    CollisionSystem = CollisionSystem,
    CleanupSystem = CleanupSystem,
    applyDamage = applyDamage,
}
