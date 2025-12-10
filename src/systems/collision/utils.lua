--------------------------------------------------------------------------------
-- COLLISION UTILITIES
-- Shared helper functions used by collision handlers
--------------------------------------------------------------------------------

local projectileModule = require("src.entities.projectile")

local utils = {}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--- Calculate the contact point between two entities
--- Places the contact on the target's surface along the line toward the projectile.
--- @param x1 number Center X of first entity (projectile)
--- @param y1 number Center Y of first entity (projectile)
--- @param x2 number Center X of second entity (target)
--- @param y2 number Center Y of second entity (target)
--- @param boundingRadius number Approximate bounding radius of target (for visual offset)
--- @return number, number Contact point X and Y (approximated on target surface)
function utils.getContactPoint(x1, y1, x2, y2, boundingRadius)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 0 and boundingRadius and boundingRadius > 0 then
        local invDist = 1.0 / distance
        -- Point on the target's surface, facing the projectile's center
        return x2 + dx * invDist * boundingRadius,
            y2 + dy * invDist * boundingRadius
    end

    -- Fallback: just use the projectile position if something is degenerate
    return x1, y1
end

--- Get the bounding radius of an entity (for visual effects positioning)
--- Works for both circular and polygon colliders
--- @param entity table The entity to get bounding radius for
--- @return number The bounding radius
function utils.getBoundingRadius(entity)
    -- For polygon bodies, use stored collision radius or compute from vertices
    if entity.collisionRadius then
        return entity.collisionRadius
    end
    -- For ships with procedural data
    if entity.ship and entity.ship.boundingRadius then
        return entity.ship.boundingRadius
    end
    -- For asteroids with procedural data
    if entity.data and entity.data.shape and entity.data.shape.boundingRadius then
        return entity.data.shape.boundingRadius
    end
    -- Fallback to size
    return entity.size or 10
end

--- Remove an entity from a list and destroy its physics body
--- @param list table The entity list
--- @param entity table The entity to remove
function utils.removeEntity(list, entity)
    for i = #list, 1, -1 do
        if list[i] == entity then
            if entity.body then
                entity.body:destroy()
            end
            entity._removed = true
            table.remove(list, i)
            return true
        end
    end
    return false
end

--- Clean up all projectiles targeting a specific entity
--- @param bullets table The projectiles list
--- @param target table The target entity being removed
function utils.cleanupProjectilesForTarget(bullets, target)
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        if bullet.target == target then
            if bullet.body then
                bullet.body:destroy()
            end
            bullet._removed = true
            table.remove(bullets, i)
        end
    end
end

--- Roll hit chance based on weapon stats and distance traveled
--- @param projectile table The projectile entity
--- @return boolean True if the shot hits
function utils.rollHitChance(projectile)
    local weapon = projectile.weapon or (projectile.owner and projectile.owner.weapon) or {}
    local traveled = projectile.distanceTraveled or 0
    local hitChance = projectileModule.calculateHitChance(weapon, traveled)
    return math.random() <= hitChance
end

return utils
