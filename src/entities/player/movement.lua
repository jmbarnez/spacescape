-- Player movement module
-- Handles movement physics, targeting, and boundary handling

local movement = {}

local physics = require("src.core.physics")
local config = require("src.core.config")
local colors = require("src.core.colors")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local wreckModule = require("src.entities.wreck")

--- Set the player's movement target position.
-- @param state table The player state table
-- @param x number Target X position
-- @param y number Target Y position
function movement.setTarget(state, x, y)
    state.targetX = x
    state.targetY = y
    local dx = x - state.x
    local dy = y - state.y
    if dx ~= 0 or dy ~= 0 then
        state.approachAngle = math.atan2(dy, dx)
    end
end

--- Handle boundary bounce and spawn shield impact FX if shields are up.
-- @param state table The player state table
-- @param boundX number|nil Impact X position
-- @param boundY number|nil Impact Y position
local function handleBoundaryBounce(state, boundX, boundY)
    -- Only spawn FX when we actually have an active shield; the hull
    -- alone just quietly bounces.
    if not (state.shield and state.shield > 0) then
        return
    end

    if not shieldImpactFx or not shieldImpactFx.spawn then
        return
    end

    local radius = state.collisionRadius or state.size or config.player.size
    if not radius or radius <= 0 then
        return
    end

    local cx = state.x
    local cy = state.y
    local ix = boundX or cx
    local iy = boundY or cy

    if not ix or not iy then
        return
    end

    local color = colors.shieldDamage

    ----------------------------------------------------------------------
    -- Attach the shield FX to the player state so the ring continues to
    -- wrap the ship as it slides along the world boundary instead of
    -- being left behind at the initial contact point.
    ----------------------------------------------------------------------
    shieldImpactFx.spawn(cx, cy, ix, iy, radius * 1.15, color, state)
end

--- Update player movement each frame.
-- @param state table The player state table
-- @param dt number Delta time
-- @param world table|nil World bounds table
function movement.update(state, dt, world)
    local consts = physics.constants

    local dx = state.targetX - state.x
    local dy = state.targetY - state.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local speed = physics.getSpeed(state.vx, state.vy)

    -- Arrival parameters
    local stopRadius = config.player.stopRadius -- Inside this, we consider we "reached" the point
    local slowRadius = config.player.slowRadius -- Start slowing down when within this distance

    state.isThrusting = false

    -- If we're very close and moving slowly, snap to the target and stop
    if distance < stopRadius and speed < config.player.arrivalSpeedThreshold then
        state.vx = 0
        state.vy = 0
        state.targetX = state.x
        state.targetY = state.y
    else
        -- Desired direction toward the target (for movement)
        local dirX, dirY = 0, 0
        if distance > 0 then
            dirX = dx / distance
            dirY = dy / distance
        end

        -- Desired speed: full speed far away, slower as we approach
        local desiredSpeed
        if distance > slowRadius then
            desiredSpeed = state.maxSpeed
        else
            desiredSpeed = state.maxSpeed * (distance / slowRadius)
        end

        local desiredVx = dirX * desiredSpeed
        local desiredVy = dirY * desiredSpeed

        -- Velocity change we want: this handles both accelerating and braking
        local dvx = desiredVx - state.vx
        local dvy = desiredVy - state.vy
        local dvLen = math.sqrt(dvx * dvx + dvy * dvy)

        if dvLen > 1 then
            -- Use separate thrust direction so visuals stay stable
            local thrustAngle = math.atan2(dvy, dvx)

            -- Visual nose: keep facing along the original approach path
            if distance > stopRadius then
                local noseAngle = state.approachAngle or math.atan2(dy, dx)
                state.targetAngle = noseAngle
                state.angle = physics.rotateTowards(state.angle, state.targetAngle, consts.shipRotationSpeed, dt)
            end

            state.isThrusting = true
            state.vx, state.vy = physics.applyThrust(state.vx, state.vy, thrustAngle, state.thrust, dt, state.maxSpeed)
        else
            -- Close to desired velocity: just keep facing the approach direction
            if distance > stopRadius then
                local noseAngle = state.approachAngle or math.atan2(dy, dx)
                state.targetAngle = noseAngle
                state.angle = physics.rotateTowards(state.angle, state.targetAngle, consts.shipRotationSpeed, dt)
            end
        end
    end

    -- Apply very minimal damping (micro-thruster stabilization)
    state.vx, state.vy = physics.applyDamping(state.vx, state.vy, consts.linearDamping, dt)

    -- Update position based on velocity (momentum carries us)
    state.x = state.x + state.vx * dt
    state.y = state.y + state.vy * dt

    --------------------------------------------------------------------------
    -- Loot target range check: when player reaches a wreck, trigger looting
    --------------------------------------------------------------------------
    if state.lootTarget and not state.isLooting then
        local lw = state.lootTarget
        local ldx = lw.x - state.x
        local ldy = lw.y - state.y
        local lootDist = math.sqrt(ldx * ldx + ldy * ldy)
        local lootRange = wreckModule.getLootRange()
        if lootDist <= lootRange then
            state.isLooting = true
            -- Stop movement when reaching the wreck
            state.targetX = state.x
            state.targetY = state.y
        end
    end

    -- Validate loot target still exists
    if state.lootTarget then
        local found = false
        for _, w in ipairs(wreckModule.list) do
            if w == state.lootTarget then
                found = true
                break
            end
        end
        if not found then
            state.lootTarget = nil
            state.isLooting = false
        end
    end

    ----------------------------------------------------------------------
    -- World / screen boundary handling
    --
    -- The player should bounce off the invisible world edges so that the
    -- ship never leaves the playable area. When shields are up, we also
    -- trigger a shield impact FX on the side that was hit so the player
    -- gets a clear, stylish cue that they smacked the field boundary.
    ----------------------------------------------------------------------

    if world then
        ------------------------------------------------------------------
        -- World-space bounds (large playfield defined by core.world)
        ------------------------------------------------------------------
        local margin = state.collisionRadius or state.size

        if state.x < world.minX + margin then
            state.x = world.minX + margin
            state.vx = math.abs(state.vx) * config.player.bounceFactor
            handleBoundaryBounce(state, world.minX + margin, state.y)
        elseif state.x > world.maxX - margin then
            state.x = world.maxX - margin
            state.vx = -math.abs(state.vx) * config.player.bounceFactor
            handleBoundaryBounce(state, world.maxX - margin, state.y)
        end

        if state.y < world.minY + margin then
            state.y = world.minY + margin
            state.vy = math.abs(state.vy) * config.player.bounceFactor
            handleBoundaryBounce(state, state.x, world.minY + margin)
        elseif state.y > world.maxY - margin then
            state.y = world.maxY - margin
            state.vy = -math.abs(state.vy) * config.player.bounceFactor
            handleBoundaryBounce(state, state.x, world.maxY - margin)
        end
    else
        ------------------------------------------------------------------
        -- Fallback to screen bounds if the world table is not provided.
        ------------------------------------------------------------------
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local margin = state.collisionRadius or state.size

        if state.x < margin then
            state.x = margin
            state.vx = math.abs(state.vx) * config.player.bounceFactor
            handleBoundaryBounce(state, margin, state.y)
        elseif state.x > w - margin then
            state.x = w - margin
            state.vx = -math.abs(state.vx) * config.player.bounceFactor
            handleBoundaryBounce(state, w - margin, state.y)
        end

        if state.y < margin then
            state.y = margin
            state.vy = math.abs(state.vy) * config.player.bounceFactor
            handleBoundaryBounce(state, state.x, margin)
        elseif state.y > h - margin then
            state.y = h - margin
            state.vy = -math.abs(state.vy) * config.player.bounceFactor
            handleBoundaryBounce(state, state.x, h - margin)
        end
    end

    if state.body then
        state.body:setPosition(state.x, state.y)
    end
end

return movement
