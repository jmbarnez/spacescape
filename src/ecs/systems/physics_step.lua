local Concord = require("lib.concord")
local physics = require("src.core.physics")

local PhysicsStepSystem = Concord.system({})

PhysicsStepSystem["physics.step"] = function(self, dt, playerEntity, worldData)
    self:stepPhysics(dt, playerEntity, worldData)
end

function PhysicsStepSystem:stepPhysics(dt, playerEntity, worldData)
    local world = self:getWorld()
    if not world then
        return
    end

    world:emit("physics.pre_step", dt, playerEntity, worldData)
    physics.update(dt)
    world:emit("physics.post_step", dt, playerEntity, worldData)
end

return PhysicsStepSystem
