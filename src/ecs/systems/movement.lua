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

        -- Projectiles with Box2D bodies are simulated by the physics step.
        -- If we also integrate position here, we'll effectively double-move
        -- them and/or desync the ECS transform from the physics transform.
        --
        -- We instead let the physics body be authoritative for projectile
        -- movement, then copy body position -> ECS position in the sync loop.
        if e.projectile and e.physics and e.physics.body then
            goto continue
        end

        e.position.x = e.position.x + e.velocity.vx * dt
        e.position.y = e.position.y + e.velocity.vy * dt

        ::continue::
    end

    -- Sync physics bodies with positions
    for i = 1, self.physicsBodies.size do
        local e = self.physicsBodies[i]
        if e.physics.body then
            if e.projectile then
                -- For projectiles, the physics body drives motion.
                -- Keep ECS position in lockstep with Box2D for consistent
                -- rendering + collision radius math.
                local bx, by = e.physics.body:getPosition()
                e.position.x = bx
                e.position.y = by
            else
                e.physics.body:setPosition(e.position.x, e.position.y)
            end
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

        -- Track distance traveled for hit-chance calculations and any
        -- range-based effects. We intentionally **do not** destroy
        -- projectiles purely because they exceeded weapon.maxRange here;
        -- that value is treated as an accuracy falloff range, while the
        -- actual lifetime/removal of projectiles is handled by:
        --   - collision resolution (on impact), and
        --   - the legacy projectileModule.update() offscreen cleanup
        --     which culls bullets once they leave the world bounds.
        --
        -- This ensures enemy basic shots can travel the full distance to
        -- the player even when fired from far away, instead of vanishing
        -- early once distanceTraveled >= maxRange.
        local dx = e.velocity.vx * dt
        local dy = e.velocity.vy * dt
        data.distanceTraveled = data.distanceTraveled + math.sqrt(dx * dx + dy * dy)

        -- Homing behavior: adjust velocity towards target while the
        -- projectile is alive. Lifetime is governed by collision/offscreen
        -- systems, not this movement pass.
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

                if e.physics and e.physics.body then
                    -- Critical: update Box2D linear velocity so homing is
                    -- reflected in the actual physics simulation.
                    -- Without this, projectiles keep traveling along their
                    -- original spawn heading and can appear to "freeze" at a
                    -- stale aim point when the target moves.
                    e.physics.body:setLinearVelocity(e.velocity.vx, e.velocity.vy)
                end

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
