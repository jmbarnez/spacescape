local player = {}

local physics = require("src.core.physics")
local weapons = require("src.core.weapons")

-- Internal helper to draw the drone given a color palette and a base size
local function renderDrone(colors, size)
    local shipColor = colors.ship
    local outlineColor = colors.shipOutline or {0, 0, 0}
    local cockpitColor = colors.projectile or shipColor
    local engineColor = colors.enemy or shipColor

    -- Base dimensions (front points along +X)
    local hullLength = size * 2.4
    local hullHalfWidth = size * 0.35
    local noseX = hullLength * 0.5
    local backX = -hullLength * 0.4

    -- Main hull (long, narrow triangle)
    love.graphics.setColor(shipColor)
    love.graphics.polygon("fill",
        noseX, 0,
        backX, -hullHalfWidth,
        backX, hullHalfWidth
    )

    -- Wings (slimmer profile)
    local wingSpan = size * 0.9
    local wingFrontX = size * 0.2
    local wingBackX = backX * 0.5

    love.graphics.polygon("fill",
        wingFrontX, -hullHalfWidth * 0.7,
        wingBackX, -wingSpan,
        backX, -hullHalfWidth * 0.25
    )

    love.graphics.polygon("fill",
        wingFrontX, hullHalfWidth * 0.7,
        wingBackX, wingSpan,
        backX, hullHalfWidth * 0.25
    )

    -- Cockpit
    love.graphics.setColor(cockpitColor[1], cockpitColor[2], cockpitColor[3], 0.9)
    love.graphics.circle("fill", size * 0.25, 0, size * 0.25)

    -- Engine glow at the rear
    local engineRadius = size * 0.3
    local engineX = backX - size * 0.15
    love.graphics.setColor(engineColor[1], engineColor[2], engineColor[3], 0.9)
    love.graphics.circle("fill", engineX, 0, engineRadius)

    -- Outline
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line",
        noseX, 0,
        backX, -hullHalfWidth,
        backX, hullHalfWidth
    )
end

player.state = {
    x = 0,
    y = 0,
    -- Velocity components for zero-g physics
    vx = 0,
    vy = 0,
    -- Target position (where player clicked)
    targetX = 0,
    targetY = 0,
    -- Physics properties
    thrust = physics.constants.shipThrust,
    maxSpeed = physics.constants.shipMaxSpeed,
    size = 11,
    angle = 0,
    targetAngle = 0,
    approachAngle = nil,
    health = 100,
    maxHealth = 100,
    isThrusting = false,
    body = nil,
    shape = nil,
    fixture = nil,
    weapon = weapons.pulseLaser
}

function player.centerInWindow()
    local p = player.state
    p.x = love.graphics.getWidth() / 2
    p.y = love.graphics.getHeight() / 2
    p.targetX = p.x
    p.targetY = p.y
end

--------------------------------------------------------------------------------
-- PHYSICS BODY CREATION
-- Creates the player's physics body with proper collision filtering
--------------------------------------------------------------------------------
local function createBody()
    local p = player.state
    
    -- Clean up existing body if present
    if p.body then
        p.body:destroy()
        p.body = nil
        p.shape = nil
        p.fixture = nil
    end
    
    -- Create new body with collision filtering via physics helper
    p.body, p.shape, p.fixture = physics.createCircleBody(
        p.x, p.y,
        p.size,
        "PLAYER",
        p  -- Pass player state as the entity reference
    )
end

function player.reset()
    local p = player.state
    player.centerInWindow()
    p.health = p.maxHealth
    -- Reset velocity for zero-g
    p.vx = 0
    p.vy = 0
    p.isThrusting = false
    p.angle = 0
    p.targetAngle = 0
    p.approachAngle = nil
    createBody()
    p.weapon = weapons.pulseLaser
end

function player.update(dt, world)
    local p = player.state
    local consts = physics.constants
    
    local dx = p.targetX - p.x
    local dy = p.targetY - p.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local speed = physics.getSpeed(p.vx, p.vy)

    -- Arrival parameters
    local stopRadius = 5       -- Inside this, we consider we "reached" the point
    local slowRadius = 250     -- Start slowing down when within this distance

    p.isThrusting = false

    -- If we're very close and moving slowly, snap to the target and stop
    if distance < stopRadius and speed < 5 then
        p.vx = 0
        p.vy = 0
        p.targetX = p.x
        p.targetY = p.y
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
            desiredSpeed = p.maxSpeed
        else
            desiredSpeed = p.maxSpeed * (distance / slowRadius)
        end

        local desiredVx = dirX * desiredSpeed
        local desiredVy = dirY * desiredSpeed

        -- Velocity change we want: this handles both accelerating and braking
        local dvx = desiredVx - p.vx
        local dvy = desiredVy - p.vy
        local dvLen = math.sqrt(dvx * dvx + dvy * dvy)

        if dvLen > 1 then
            -- Use separate thrust direction so visuals stay stable
            local thrustAngle = math.atan2(dvy, dvx)

            -- Visual nose: keep facing along the original approach path
            if distance > stopRadius then
                local noseAngle = p.approachAngle or math.atan2(dy, dx)
                p.targetAngle = noseAngle
                p.angle = physics.rotateTowards(p.angle, p.targetAngle, consts.shipRotationSpeed, dt)
            end

            p.isThrusting = true
            p.vx, p.vy = physics.applyThrust(p.vx, p.vy, thrustAngle, p.thrust, dt, p.maxSpeed)
        else
            -- Close to desired velocity: just keep facing the approach direction
            if distance > stopRadius then
                local noseAngle = p.approachAngle or math.atan2(dy, dx)
                p.targetAngle = noseAngle
                p.angle = physics.rotateTowards(p.angle, p.targetAngle, consts.shipRotationSpeed, dt)
            end
        end
    end

    -- Apply very minimal damping (micro-thruster stabilization)
    p.vx, p.vy = physics.applyDamping(p.vx, p.vy, consts.linearDamping, dt)

    -- Update position based on velocity (momentum carries us)
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    
    -- World boundary handling - bounce off edges with velocity reversal
    if world then
        local margin = p.size
        if p.x < world.minX + margin then
            p.x = world.minX + margin
            p.vx = math.abs(p.vx) * 0.5  -- Bounce with energy loss
        elseif p.x > world.maxX - margin then
            p.x = world.maxX - margin
            p.vx = -math.abs(p.vx) * 0.5
        end
        if p.y < world.minY + margin then
            p.y = world.minY + margin
            p.vy = math.abs(p.vy) * 0.5
        elseif p.y > world.maxY - margin then
            p.y = world.maxY - margin
            p.vy = -math.abs(p.vy) * 0.5
        end
    else
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        if p.x < p.size then
            p.x = p.size
            p.vx = math.abs(p.vx) * 0.5
        elseif p.x > w - p.size then
            p.x = w - p.size
            p.vx = -math.abs(p.vx) * 0.5
        end
        if p.y < p.size then
            p.y = p.size
            p.vy = math.abs(p.vy) * 0.5
        elseif p.y > h - p.size then
            p.y = h - p.size
            p.vy = -math.abs(p.vy) * 0.5
        end
    end

    if p.body then
        p.body:setPosition(p.x, p.y)
    end
end

function player.setTarget(x, y)
    local p = player.state
    p.targetX = x
    p.targetY = y
    local dx = x - p.x
    local dy = y - p.y
    if dx ~= 0 or dy ~= 0 then
        p.approachAngle = math.atan2(dy, dx)
    end
end

function player.draw(colors)
    local p = player.state

    love.graphics.push()
    love.graphics.translate(p.x, p.y)
    love.graphics.rotate(p.angle)

    -- Main body (solid diamond/rhombus drone shape)
    renderDrone(colors, p.size)

    love.graphics.pop()
end

-- Expose renderDrone for preview use (e.g., skin selection)
player.renderDrone = renderDrone

return player
