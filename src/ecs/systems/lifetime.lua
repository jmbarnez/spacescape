local Concord = require("lib.concord")

local LifetimeSystem = Concord.system({
    entities = { "lifetime" },
})

LifetimeSystem["physics.pre_step"] = function(self, dt)
    self:prePhysics(dt)
end

local function isNumber(n)
    return type(n) == "number" and n == n
end

function LifetimeSystem:prePhysics(dt)
    if not isNumber(dt) then
        return
    end

    for i = 1, self.entities.size do
        local e = self.entities[i]

        -- Items manage their lifetime in the item pickup system so they can
        -- fade/expire consistently with magnet handling.
        if e.item then
            goto continue
        end

        local lifetime = e.lifetime
        lifetime.remaining = (lifetime.remaining or 0) - dt
        if lifetime.remaining <= 0 then
            e:give("removed")
        end

        ::continue::
    end
end

function LifetimeSystem:update(dt)
    self:prePhysics(dt)
end

return LifetimeSystem
