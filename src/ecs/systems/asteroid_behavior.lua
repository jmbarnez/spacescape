--------------------------------------------------------------------------------
-- ASTEROID BEHAVIOR SYSTEM
-- Handles visual rotation and specific asteroid logic
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local AsteroidBehaviorSystem = Concord.system({
    rotators = { "rotation" }
})

AsteroidBehaviorSystem["physics.pre_step"] = function(self, dt)
    self:prePhysics(dt)
end

function AsteroidBehaviorSystem:prePhysics(dt)
    for i = 1, self.rotators.size do
        local e = self.rotators[i]

        -- Passive rotation for objects with a rotationSpeed field
        local speed = e.rotationSpeed or 0

        if speed ~= 0 then
            e.rotation.angle = e.rotation.angle + speed * dt
            -- RotationSystem steers rotation.angle toward rotation.targetAngle;
            -- keep them in sync for passive rotators so they actually spin.
            e.rotation.targetAngle = e.rotation.angle
        end
    end
end

return AsteroidBehaviorSystem
