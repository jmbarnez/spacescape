--------------------------------------------------------------------------------
-- ASTEROID BEHAVIOR SYSTEM
-- Handles visual rotation and specific asteroid logic
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local AsteroidBehaviorSystem = Concord.system({
    rotators = { "rotation" }
})

function AsteroidBehaviorSystem:prePhysics(dt)
    for i = 1, self.rotators.size do
        local e = self.rotators[i]

        -- Passive rotation for objects with a rotationSpeed field
        local speed = e.rotationSpeed or 0

        if speed ~= 0 then
            e.rotation.angle = e.rotation.angle + speed * dt
        end
    end
end

return AsteroidBehaviorSystem
