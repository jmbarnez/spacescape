--------------------------------------------------------------------------------
-- COLLISION UTILITIES (ECS-AWARE)
-- Helper functions for accessing entity properties regardless of format
--------------------------------------------------------------------------------

local projectileModule = require("src.entities.projectile")

local utils = {}

--------------------------------------------------------------------------------
-- ECS-AWARE PROPERTY ACCESSORS
--------------------------------------------------------------------------------

--- Get X position from entity (handles ECS and legacy)
function utils.getX(entity)
    if entity.position then return entity.position.x end
    return entity.x or 0
end

--- Get Y position from entity (handles ECS and legacy)
function utils.getY(entity)
    if entity.position then return entity.position.y end
    return entity.y or 0
end

--- Get velocity X from entity
function utils.getVX(entity)
    if entity.velocity then return entity.velocity.vx end
    return entity.vx or 0
end

--- Get velocity Y from entity
function utils.getVY(entity)
    if entity.velocity then return entity.velocity.vy end
    return entity.vy or 0
end

--- Get current health from entity
function utils.getHealth(entity)
    if entity.health then
        if type(entity.health) == "table" then
            return entity.health.current
        end
        return entity.health
    end
    return 0
end

--- Get max health from entity
function utils.getMaxHealth(entity)
    if entity.health then
        if type(entity.health) == "table" then
            return entity.health.max
        end
        return entity.maxHealth or entity.health
    end
    return entity.maxHealth or 0
end

--- Set health on entity
function utils.setHealth(entity, value)
    if entity.health and type(entity.health) == "table" then
        entity.health.current = value
    else
        entity.health = value
    end
end

--- Get current shield from entity
function utils.getShield(entity)
    if entity.shield then
        if type(entity.shield) == "table" then
            return entity.shield.current
        end
        return entity.shield
    end
    return 0
end

--- Get max shield from entity
function utils.getMaxShield(entity)
    if entity.shield then
        if type(entity.shield) == "table" then
            return entity.shield.max
        end
        return entity.maxShield or entity.shield
    end
    return entity.maxShield or 0
end

--- Set shield on entity
function utils.setShield(entity, value)
    if entity.shield and type(entity.shield) == "table" then
        entity.shield.current = value
    else
        entity.shield = value
    end
end

--- Get size from entity
function utils.getSize(entity)
    if entity.size then
        if type(entity.size) == "table" then
            return entity.size.value
        end
        return entity.size
    end
    return 10
end

--- Get damage amount from entity (projectile)
function utils.getDamage(entity)
    if entity.damage then
        if type(entity.damage) == "table" then
            return entity.damage.amount
        end
        return entity.damage
    end
    return 10
end

--- Get faction from entity
function utils.getFaction(entity)
    if entity.faction then
        if type(entity.faction) == "table" then
            return entity.faction.name
        end
        return entity.faction
    end
    return "neutral"
end

--- Get physics body from entity
function utils.getBody(entity)
    if entity.physics and entity.physics.body then
        return entity.physics.body
    end
    return entity.body
end

--------------------------------------------------------------------------------
-- CONTACT AND RADIUS FUNCTIONS
--------------------------------------------------------------------------------

function utils.getContactPoint(x1, y1, x2, y2, boundingRadius)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 0 and boundingRadius and boundingRadius > 0 then
        local invDist = 1.0 / distance
        return x2 + dx * invDist * boundingRadius,
            y2 + dy * invDist * boundingRadius
    end

    return x1, y1
end

function utils.getBoundingRadius(entity)
    -- ECS collisionRadius component
    if entity.collisionRadius then
        if type(entity.collisionRadius) == "table" then
            return entity.collisionRadius.radius
        end
        return entity.collisionRadius
    end
    -- Ships with procedural data
    if entity.ship and entity.ship.boundingRadius then
        return entity.ship.boundingRadius
    end
    if entity.shipVisual and entity.shipVisual.ship and entity.shipVisual.ship.boundingRadius then
        return entity.shipVisual.ship.boundingRadius
    end
    -- Asteroids with procedural data
    if entity.data and entity.data.shape and entity.data.shape.boundingRadius then
        return entity.data.shape.boundingRadius
    end
    if entity.asteroidVisual and entity.asteroidVisual.data and entity.asteroidVisual.data.shape then
        return entity.asteroidVisual.data.shape.boundingRadius
    end
    -- Fallback to size
    return utils.getSize(entity)
end

--------------------------------------------------------------------------------
-- ENTITY REMOVAL
--------------------------------------------------------------------------------

function utils.removeEntity(list, entity)
    -- For ECS entities, use destroy()
    if entity.destroy and type(entity.destroy) == "function" then
        entity._removed = true

        local body = utils.getBody(entity)
        if body and body.destroy and not body:isDestroyed() then
            body:destroy()
        end
        entity:destroy()
        return true
    end

    -- Legacy list removal
    for i = #list, 1, -1 do
        if list[i] == entity then
            local body = utils.getBody(entity)
            if body and body.destroy and not body:isDestroyed() then
                body:destroy()
            end
            entity._removed = true
            table.remove(list, i)
            return true
        end
    end
    return false
end

function utils.cleanupProjectilesForTarget(bullets, target)
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        local bulletTarget = bullet.target or (bullet.projectileData and bullet.projectileData.target)
        if bulletTarget == target then
            local body = utils.getBody(bullet)
            if body and body.destroy and not body:isDestroyed() then
                body:destroy()
            end
            if bullet.destroy then
                bullet._removed = true
                bullet:destroy()
            else
                bullet._removed = true
                table.remove(bullets, i)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- HIT CHANCE
--------------------------------------------------------------------------------

function utils.rollHitChance(projectile)
    local weapon = projectile.weapon
    if type(weapon) == "table" and weapon.data then
        weapon = weapon.data
    end
    if not weapon then
        weapon = projectile.owner and projectile.owner.weapon or {}
        if type(weapon) == "table" and weapon.data then
            weapon = weapon.data
        end
    end
    local traveled = projectile.distanceTraveled
    if projectile.projectileData then
        traveled = projectile.projectileData.distanceTraveled
    end
    traveled = traveled or 0
    local hitChance = projectileModule.calculateHitChance(weapon, traveled)
    return math.random() <= hitChance
end

return utils
