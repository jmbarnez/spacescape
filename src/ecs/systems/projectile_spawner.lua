--------------------------------------------------------------------------------
-- PROJECTILE SPAWNER SYSTEM
-- Handles fireProjectile events and spawns actual projectiles
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local ProjectileSpawnerSystem = Concord.system({})

ProjectileSpawnerSystem["combat.fire_projectile"] = function(self, shooter, targetX, targetY, targetEntity)
    self:fireProjectile(shooter, targetX, targetY, targetEntity)
end

-- Handle fireProjectile event from FiringSystem
function ProjectileSpawnerSystem:fireProjectile(shooter, targetX, targetY, targetEntity)
    -- ECS-first: projectiles are authoritative ECS entities.
    -- This removes the last dependency on the legacy projectile module wrapper.
    local world = self:getWorld()
    if world and world.spawnProjectile then
        world:spawnProjectile(shooter, targetX, targetY, targetEntity)
    end
end

return ProjectileSpawnerSystem
