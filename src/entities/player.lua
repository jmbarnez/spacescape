local player = {}

local physics = require("src.core.physics")
local weapons = require("src.core.weapons")

player.state = {
    x = 0,
    y = 0,
    targetX = 0,
    targetY = 0,
    speed = 150,
    size = 20,
    angle = 0,
    health = 100,
    maxHealth = 100,
    score = 0,
    isMoving = false,
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
    p.isMoving = false
    createBody()
    p.weapon = weapons.pulseLaser
end

function player.update(dt, world)
    local p = player.state
    local dx = p.targetX - p.x
    local dy = p.targetY - p.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 5 then
        p.isMoving = true
        local moveX = (dx / distance) * p.speed * dt
        local moveY = (dy / distance) * p.speed * dt

        if math.abs(moveX) > math.abs(dx) then moveX = dx end
        if math.abs(moveY) > math.abs(dy) then moveY = dy end

        p.x = p.x + moveX
        p.y = p.y + moveY

        p.angle = math.atan2(dy, dx)
    else
        p.isMoving = false
    end

    if world then
        local margin = p.size
        p.x = math.max(world.minX + margin, math.min(world.maxX - margin, p.x))
        p.y = math.max(world.minY + margin, math.min(world.maxY - margin, p.y))
    else
        p.x = math.max(p.size, math.min(love.graphics.getWidth() - p.size, p.x))
        p.y = math.max(p.size, math.min(love.graphics.getHeight() - p.size, p.y))
    end

    if p.body then
        p.body:setPosition(p.x, p.y)
    end
end

function player.setTarget(x, y)
    local p = player.state
    p.targetX = x
    p.targetY = y
end

function player.draw(colors)
    local p = player.state

    love.graphics.push()
    love.graphics.translate(p.x, p.y)
    love.graphics.rotate(p.angle)

    -- Main body (solid diamond/rhombus drone shape)
    love.graphics.setColor(colors.ship)
    local coreRadius = p.size * 0.55
    love.graphics.circle("fill", 0, 0, coreRadius)

    -- Side panels (symmetrical)
    love.graphics.setColor(colors.ship[1] * 0.8, colors.ship[2] * 0.8, colors.ship[3] * 0.8)
    local armLength = p.size * 0.9
    local armWidth = p.size * 0.25
    love.graphics.rectangle("fill", -armLength * 0.4, -armWidth * 0.5, armLength * 0.8, armWidth)
    love.graphics.rectangle("fill", -armWidth * 0.5, -armLength * 0.4, armWidth, armLength * 0.8)

    local podRadius = p.size * 0.22
    love.graphics.circle("fill", p.size * 0.7, 0, podRadius)
    love.graphics.circle("fill", -p.size * 0.3, -p.size * 0.7, podRadius * 0.9)
    love.graphics.circle("fill", -p.size * 0.3, p.size * 0.7, podRadius * 0.9)

    -- Central sensor
    love.graphics.setColor(colors.ship[1] * 0.6, colors.ship[2] * 0.6, colors.ship[3] * 0.6)
    love.graphics.circle("fill", p.size * 0.4, 0, p.size * 0.18)

    -- Outline
    love.graphics.setColor(colors.shipOutline)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, coreRadius)
    love.graphics.circle("line", p.size * 0.7, 0, podRadius)
    love.graphics.circle("line", -p.size * 0.3, -p.size * 0.7, podRadius * 0.9)
    love.graphics.circle("line", -p.size * 0.3, p.size * 0.7, podRadius * 0.9)

    -- Engine indicator
    if p.isMoving then
        love.graphics.setColor(colors.shipOutline[1], colors.shipOutline[2], colors.shipOutline[3], 0.8)
        love.graphics.circle("fill", -p.size * 0.5, 0, 4)
    else
        love.graphics.setColor(colors.shipOutline[1], colors.shipOutline[2], colors.shipOutline[3], 0.4)
        love.graphics.circle("fill", -p.size * 0.5, 0, 3)
    end

    love.graphics.pop()
end

return player
