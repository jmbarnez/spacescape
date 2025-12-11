--------------------------------------------------------------------------------
-- PROJECTILE SPAWNER SYSTEM
-- Handles fireProjectile events and spawns actual projectiles
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local ProjectileSpawnerSystem = Concord.system({})

-- Handle fireProjectile event from FiringSystem
function ProjectileSpawnerSystem:fireProjectile(shooter, targetX, targetY, targetEntity)
    -- Lazy require to avoid circular dependency
    local projectileModule = require("src.entities.projectile")
    projectileModule.spawn(shooter, targetX, targetY, targetEntity)
end

return ProjectileSpawnerSystem
