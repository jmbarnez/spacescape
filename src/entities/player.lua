local player = {}

local physics = require("src.core.physics")
local weapons = require("src.core.weapons")

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
    size = 20,
    angle = 0,
    targetAngle = 0,
    approachAngle = nil,
    health = 100,
    maxHealth = 100,
    score = 0,
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

local function createBody()
    local p = player.state
    if p.body then
        p.body:destroy()
        p.body = nil
        p.shape = nil
        p.fixture = nil
    end
    local world = physics.getWorld()
    if not world then
        return
    end
    p.body = love.physics.newBody(world, p.x, p.y, "dynamic")
    p.body:setFixedRotation(true)
    p.shape = love.physics.newCircleShape(p.size)
    p.fixture = love.physics.newFixture(p.body, p.shape, 1)
end

function player.reset()
    local p = player.state
    player.centerInWindow()
    p.health = p.maxHealth
    p.score = 0
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
    local stopRadius = 10      -- Inside this, we consider we "reached" the point
    local slowRadius = 250     -- Start slowing down when within this distance

    p.isThrusting = false

    -- If we're very close and moving slowly, snap to the target and stop
    if distance < stopRadius and speed < 5 then
        p.x = p.targetX
        p.y = p.targetY
        p.vx = 0
        p.vy = 0
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
    local shipColor = colors.ship
    local outlineColor = colors.shipOutline
    local projectileColor = colors.projectile or shipColor
    local accentColor = colors.enemy or shipColor

    local coreRadius = p.size * 0.8

    -- Compact orb core
    love.graphics.setColor(shipColor)
    love.graphics.circle("fill", 0, 0, coreRadius)

    -- Inner energy core
    love.graphics.setColor(projectileColor[1], projectileColor[2], projectileColor[3], 0.75)
    love.graphics.circle("fill", 0, 0, coreRadius * 0.55)

    -- Side panels (symmetrical)
    love.graphics.setColor(shipColor[1] * 0.8, shipColor[2] * 0.8, shipColor[3] * 0.8)
    local armLength = p.size * 0.9
    local armWidth = p.size * 0.28

    -- Short lateral arms
    love.graphics.rectangle("fill", -armLength * 0.5, -armWidth * 0.5, armLength, armWidth)

    -- Short dorsal/ventral arms
    love.graphics.rectangle("fill", -armWidth * 0.5, -armLength * 0.5, armWidth, armLength)

    -- Nacelle pods at cardinal points
    local podRadius = p.size * 0.2
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.9)
    love.graphics.circle("fill", coreRadius * 0.95, 0, podRadius)
    love.graphics.circle("fill", -coreRadius * 0.95, 0, podRadius * 0.8)
    love.graphics.circle("fill", 0, -coreRadius * 0.95, podRadius * 0.8)
    love.graphics.circle("fill", 0, coreRadius * 0.95, podRadius * 0.8)

    -- Additional diagonal sensor pips
    local ringRadius = coreRadius * 0.8
    love.graphics.setColor(projectileColor[1], projectileColor[2], projectileColor[3], 0.8)
    for i = 0, 3 do
        local angle = math.pi * 0.25 + i * (math.pi * 0.5)
        local px = math.cos(angle) * ringRadius
        local py = math.sin(angle) * ringRadius
        love.graphics.circle("fill", px, py, podRadius * 0.45)
    end

    -- Central sensor
    love.graphics.setColor(projectileColor)
    love.graphics.circle("fill", coreRadius * 0.5, 0, p.size * 0.22)
    love.graphics.setColor(shipColor[1] * 0.2, shipColor[2] * 0.9, shipColor[3], 0.95)
    love.graphics.circle("fill", coreRadius * 0.5, 0, p.size * 0.12)

    -- Outline
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, coreRadius)
    love.graphics.circle("line", coreRadius * 0.95, 0, podRadius)
    love.graphics.circle("line", -coreRadius * 0.95, 0, podRadius * 0.8)
    love.graphics.circle("line", 0, -coreRadius * 0.95, podRadius * 0.8)
    love.graphics.circle("line", 0, coreRadius * 0.95, podRadius * 0.8)

    love.graphics.pop()
end

return player
