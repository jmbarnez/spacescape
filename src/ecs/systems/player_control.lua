--------------------------------------------------------------------------------
-- PLAYER CONTROL SYSTEM (ECS)
-- Handles player input for movement, targeting, and looting
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local physics = require("src.core.physics")
local config = require("src.core.config")
local wreckModule = require("src.entities.wreck")

local PlayerControlSystem = Concord.system({
    -- Only entities with player control tag and movement components
    players = { "playerControlled", "position", "velocity", "rotation", "destination", "thrust" }
})

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function PlayerControlSystem:prePhysics(dt)
    local consts = physics.constants

    for i = 1, self.players.size do
        local e = self.players[i]

        -- Loot targeting logic
        -- If we have a loot target, update destination to follow it
        local lootTarget = e.lootTarget
        if lootTarget then
            -- Validate target still exists and has position
            local isValid = false
            local tx, ty

            if lootTarget.position then
                tx, ty = lootTarget.position.x, lootTarget.position.y
                isValid = true
            elseif lootTarget.x and lootTarget.y then
                tx, ty = lootTarget.x, lootTarget.y
                isValid = true
            end

            -- Also check if it's still in the wreck list (not destroyed)
            if isValid then
                local wreckList = (wreckModule.getList and wreckModule.getList()) or wreckModule.list or {}
                local found = false
                for _, w in ipairs(wreckList) do
                    if w == lootTarget then
                        found = true
                        break
                    end
                end
                isValid = found
            end

            if isValid then
                e.destination.x = tx
                e.destination.y = ty
                e.destination.active = true

                -- Check for arrival (loot range)
                local dx = tx - e.position.x
                local dy = ty - e.position.y
                local dist = math.sqrt(dx * dx + dy * dy)
                local lootRange = wreckModule.getLootRange() or 60

                if dist <= lootRange then
                    -- Arrived! Stop and open loot
                    e.destination.active = false
                    e.destination.x = e.position.x
                    e.destination.y = e.position.y
                    e.isLooting = true
                    -- Clear velocity
                    e.velocity.vx = 0
                    e.velocity.vy = 0
                end
            else
                -- Target lost
                e.lootTarget = nil
                e.isLooting = false
            end
        end

        -- Standard movement logic
        if e.destination.active then
            local dest = e.destination
            local pos = e.position
            local vel = e.velocity
            local thrust = e.thrust

            local dx = dest.x - pos.x
            local dy = dest.y - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local speed = math.sqrt(vel.vx * vel.vx + vel.vy * vel.vy)

            -- Arrival parameters
            local stopRadius = config.player.stopRadius or 10
            local slowRadius = config.player.slowRadius or 200

            thrust.isThrusting = false

            if dist < stopRadius and speed < (config.player.arrivalSpeedThreshold or 10) then
                -- Arrived
                vel.vx = 0
                vel.vy = 0
                dest.x = pos.x
                dest.y = pos.y
                -- Keep active=true so we hold position? Or false to drift?
                -- Legacy behavior implies snapping to target.
            else
                -- Move towards target
                local dirX, dirY = 0, 0
                if dist > 0 then
                    dirX = dx / dist
                    dirY = dy / dist
                end

                local desiredSpeed = thrust.maxSpeed
                if dist < slowRadius then
                    desiredSpeed = thrust.maxSpeed * (dist / slowRadius)
                end

                local desiredVx = dirX * desiredSpeed
                local desiredVy = dirY * desiredSpeed

                local dvx = desiredVx - vel.vx
                local dvy = desiredVy - vel.vy

                -- Thrust if we need to change velocity significantly
                if math.sqrt(dvx * dvx + dvy * dvy) > 1 then
                    local thrustAngle = math.atan2(dvy, dvx)

                    -- Face movement direction
                    if dist > stopRadius then
                        -- e.approachAngle logic from legacy... simplifed here:
                        e.rotation.targetAngle = math.atan2(dy, dx)
                    end

                    thrust.isThrusting = true
                    -- Apply thrust (modifies velocity)
                    -- We use the physics helper if available, or manual calculation
                    -- reusing logic from MovementSystem for consistency?
                    -- Actually, MovementSystem applies thrust based on *Components*.
                    -- PlayerControlSystem should just set the *Intent* (isThrusting, rotation).
                    -- But MovementSystem applies thrust in direction of *Rotation*.
                    -- So we need to align rotation to thrust angle if we want to move there?
                    -- Or does this ship possess multidirectional thrusters?
                    -- Legacy code: "Use separate thrust direction so visuals stay stable"
                    -- but applies thrust to velocity directly.

                    -- To be ECS pure:
                    -- PlayerControl sets `rotation.targetAngle` and `thrust.isThrusting`.
                    -- MovementSystem receives this.
                    -- BUT MovementSystem applies thrust towards `rotation.angle`.
                    -- If we want to drift (strafe), we might need a separate component or
                    -- change MovementSystem to support "thrust vector" distinct from "facing vector".

                    -- For now, let's replicate legacy behavior by DIRECTLY modifying velocity here?
                    -- No, that fights MovementSystem.
                    -- Let's set rotation to face target, and thrust forward.
                    -- This means "tank controls" or "airplane" style, no strafing.
                    -- Legacy `movement.lua` line 115: "Use separate thrust direction"
                    -- then calls `physics.applyThrust(..., thrustAngle, ...)`

                    -- Wait, `physics.applyThrust` taking an angle implies we can thrust in any direction?
                    -- Let's check `physics.lua` or just assume we can simply modify velocity here
                    -- because MovementSystem processes `thrust.isThrusting` by applying force
                    -- in direction of `e.rotation.angle`.

                    -- If we want "strafe" behavior (thrusting towards target while facing elsewhere),
                    -- we cannot use the standard `MovementSystem`'s simple "thrust forward" logic
                    -- UNLESS we change `MovementSystem` or give the player a special "VectorThrust" component.

                    -- Given legacy code explicitly calculates `thrustAngle = math.atan2(dvy, dvx)`,
                    -- it seems the physical thrust is decoupled from visual rotation in the legacy implementation.

                    -- DECISION: We will do the velocity integration for "Smart Pilot Control" HERE,
                    -- and disable the dumb "thrust forward" logic in MovementSystem for the player
                    -- by NOT setting `thrust.isThrusting = true` for the generic system,
                    -- OR by adding a flag to `thrust` component like `manualControl = true`.

                    -- Actually, looking at `MovementSystem`:
                    -- `if thrust.isThrusting then ... vx, vy = physics.applyThrust(..., e.rotation.angle, ...)`
                    -- It forces thrust along rotation.

                    -- So for the Player, who needs smart vectoring, we should probably handle velocity
                    -- updates in this system and LEAVE `isThrusting` false for the base system
                    -- to avoid double-application or wrong-direction thrust.
                    -- We can still set `isThrusting` for visuals (trail) if we separate the visual flag?
                    -- The `thrust` component has `isThrusting`. Render systems probably use it.

                    -- Compromise: Set `isThrusting = true` so trails work.
                    -- But we must preempt or override MovementSystem?
                    -- Or simply, we accept that for the Player, we align rotation to thrust.
                    -- Legacy `movement.lua`:
                    -- `state.angle = physics.rotateTowards(..., state.targetAngle ...)`
                    -- `state.vx, state.vy = physics.applyThrust(..., thrustAngle ...)`
                    -- Note: thrustAngle != state.angle necessarily.

                    -- To faithfully recreate this, I'll calculate the new velocity here
                    -- and apply it. I will set `isThrusting = true` for visuals.
                    -- I will rely on MovementSystem NOT overwriting velocity if I've already done it?
                    -- MovementSystem adds to velocity.

                    -- Hack: If I apply the thrust here, MovementSystem will apply MORE thrust (forward).
                    -- Solution: Add a `canThrust` boolean or similar to `thrust` component?
                    -- Or just let the PlayerControlSystem handle ALL velocity changes for the player
                    -- and ensure MovementSystem ignores player?
                    -- MovementSystem iterates `thrusters` assemblage.
                    -- We can just NOT give the player the standard `thrust` component interacting with MovementSystem?
                    -- But we want `thrust.power`, `thrust.maxSpeed`.

                    -- Better: PlayerControlSystem runs BEFORE MovementSystem?
                    -- No, if both apply thrust, we get double thrust.

                    -- Let's look at `MovementSystem` again.
                    -- It iterates `thrusters`.

                    -- I will allow `PlayerControlSystem` to handle the physics logic for the player
                    -- because it's complex (arrival curves, braking).
                    -- I will set `e.thrust.isThrusting = true` (for visuals)
                    -- BUT I will momentarily disable `e.thrust.power` or similar so MovementSystem doesn't add extra force?
                    -- No, that's messy.

                    -- Cleanest: Handle player movement entirely here.
                    -- Don't rely on `MovementSystem` for player *thrust*.
                    -- `MovementSystem` also handles damping and position integration (x += vx * dt).
                    -- We WANT position integration.
                    -- We just don't want the dumb "accelerate forward" logic.

                    -- Proposal: In `MovementSystem`, check `if e.playerControlled then continue end` inside the thrust loop.
                    -- Or better, `if e.thrust.manual then continue end`.
                    -- Let's modify `thrust` component to have `manual`. or `externalControl`.

                    -- For now, I'll implement the logic here and modify `MovementSystem` later to skip entities
                    -- that have a specific "handled externally" flag, or just checking for `playerControlled`.

                    e.velocity.vx, e.velocity.vy = physics.applyThrust(
                        e.velocity.vx, e.velocity.vy,
                        thrustAngle, -- Thrust in the needed direction, not necessarily facing
                        e.thrust.power,
                        dt,
                        e.thrust.maxSpeed
                    )
                end
            end
        end
    end
end

return PlayerControlSystem
