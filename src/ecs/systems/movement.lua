--------------------------------------------------------------------------------
-- MOVEMENT SYSTEM (ECS)
-- Handles velocity, thrust, and physics body sync
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local physics = require("src.core.physics")

local MovementSystem = Concord.system({
    -- All entities with position and velocity
    movers = { "position", "velocity" },
    -- Entities with thrust capability
    thrusters = { "position", "velocity", "thrust", "rotation" },
    -- Entities with physics bodies
    physicsBodies = { "position", "physics" },
})

--- Update all moving entities
function MovementSystem:update(dt)
    local consts = physics.constants

    -- Update thrusters (apply thrust to velocity)
    for i = 1, self.thrusters.size do
        local e = self.thrusters[i]
        local thrust = e.thrust

        if thrust.isThrusting then
            local angle = e.rotation.angle
            e.velocity.vx, e.velocity.vy = physics.applyThrust(
                e.velocity.vx, e.velocity.vy,
                angle,
                thrust.power,
                dt,
                thrust.maxSpeed
            )
        end

        -- Apply damping (use entity-specific damping if available, else global default)
        local damping = e.damping and e.damping.value or consts.linearDamping
        e.velocity.vx, e.velocity.vy = physics.applyDamping(
            e.velocity.vx, e.velocity.vy,
            damping,
            dt
        )
    end

    -- Update positions from velocity
    for i = 1, self.movers.size do
        local e = self.movers[i]
        e.position.x = e.position.x + e.velocity.vx * dt
        e.position.y = e.position.y + e.velocity.vy * dt
    end

    -- Sync physics bodies with positions
    for i = 1, self.physicsBodies.size do
        local e = self.physicsBodies[i]
        if e.physics.body then
            e.physics.body:setPosition(e.position.x, e.position.y)
        end
    end
end

--------------------------------------------------------------------------------
-- ROTATION SYSTEM
--------------------------------------------------------------------------------

local RotationSystem = Concord.system({
    rotators = { "rotation" },
})

function RotationSystem:update(dt)
    local consts = physics.constants

    for i = 1, self.rotators.size do
        local e = self.rotators[i]
        local rot = e.rotation

        -- Smoothly rotate towards target angle
        rot.angle = physics.rotateTowards(
            rot.angle,
            rot.targetAngle,
            consts.shipRotationSpeed,
            dt
        )
    end
end

--------------------------------------------------------------------------------
-- PROJECTILE MOVEMENT SYSTEM
-- Handles homing projectiles and distance tracking
--------------------------------------------------------------------------------

local ProjectileSystem = Concord.system({
    projectiles = { "projectile", "position", "velocity", "projectileData" },
})

function ProjectileSystem:update(dt)
    for i = 1, self.projectiles.size do
        local e = self.projectiles[i]
        local data = e.projectileData

        -- Track distance traveled
        local dx = e.velocity.vx * dt
        local dy = e.velocity.vy * dt
        data.distanceTraveled = data.distanceTraveled + math.sqrt(dx * dx + dy * dy)

        -- Homing behavior: adjust velocity towards target
        if data.target and data.target.position then
            local tx = data.target.position.x
            local ty = data.target.position.y
            local px = e.position.x
            local py = e.position.y

            local dirX = tx - px
            local dirY = ty - py
            local distSq = dirX * dirX + dirY * dirY

            if distSq > 0 then
                local angle = math.atan2(dirY, dirX)
                local speed = math.sqrt(e.velocity.vx ^ 2 + e.velocity.vy ^ 2)
                e.velocity.vx = math.cos(angle) * speed
                e.velocity.vy = math.sin(angle) * speed

                if e.rotation then
                    e.rotation.angle = angle
                end
            end
        end
    end
end

return {
    MovementSystem = MovementSystem,
    RotationSystem = RotationSystem,
    ProjectileSystem = ProjectileSystem,
}
