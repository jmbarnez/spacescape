local physics = require("src.core.physics")

local projectile_shards = {}

projectile_shards.list = {}

local DEFAULT_COLOR = {1, 0.95, 0.8}

local function spawnShard(x, y, dirX, dirY, baseSpeed, lifeMin, lifeMax, color, sizeScale)
    local len = math.sqrt(dirX * dirX + dirY * dirY)
    if len == 0 then
        dirX, dirY = 1, 0
    else
        dirX = dirX / len
        dirY = dirY / len
    end

    local angleOffset = (math.random() - 0.5) * math.pi * 0.6
    local ca = math.cos(angleOffset)
    local sa = math.sin(angleOffset)
    local vxDirX = dirX * ca - dirY * sa
    local vxDirY = dirX * sa + dirY * ca

    local speed = baseSpeed * (0.35 + math.random() * 0.4)
    local vx = vxDirX * speed
    local vy = vxDirY * speed

    local life = (lifeMin or 0.35) + math.random() * ((lifeMax or 0.6) - (lifeMin or 0.35))
    local scale = sizeScale or 1.0
    local radius = 0.9 + 0.9 * scale

    local shard = {
        x = x,
        y = y,
        body = nil,
        shape = nil,
        fixture = nil,
        life = life,
        maxLife = life,
        color = color or DEFAULT_COLOR,
        lengthScale = scale,
    }

    shard.body, shard.shape, shard.fixture = physics.createCircleBody(
        x,
        y,
        radius,
        "DEBRIS",
        shard,
        { bodyType = "dynamic", isSensor = false, isBullet = false }
    )

    if shard.body then
        shard.body:setLinearVelocity(vx, vy)
        shard.body:setLinearDamping(3.0)
    end

    table.insert(projectile_shards.list, shard)
end

function projectile_shards.spawn(x, y, dirX, dirY, baseSpeed, count, color, length, width)
    baseSpeed = baseSpeed or (physics.constants and physics.constants.projectileSpeed) or 350
    count = count or 8

    local sizeScale = 1.0
    if length or width then
        local l = length or 20
        local w = width or 2
        sizeScale = ((l / 20) + (w / 2)) * 0.5
    end

    for i = 1, count do
        spawnShard(x, y, dirX, dirY, baseSpeed, 0.35, 0.7, color, sizeScale)
    end
end

function projectile_shards.update(dt)
    for i = #projectile_shards.list, 1, -1 do
        local s = projectile_shards.list[i]

        if s.body then
            s.x, s.y = s.body:getPosition()
        end

        s.life = s.life - dt
        if s.life <= 0 then
            if s.body then
                s.body:destroy()
            end
            table.remove(projectile_shards.list, i)
        end
    end
end

function projectile_shards.draw()
    if #projectile_shards.list == 0 then
        return
    end

    local prevLineWidth = love.graphics.getLineWidth()

    for _, s in ipairs(projectile_shards.list) do
        if s.body then
            local vx, vy = s.body:getLinearVelocity()
            local len = math.sqrt(vx * vx + vy * vy)
            if len > 0 then
                local nx = vx / len
                local ny = vy / len
                local scale = s.lengthScale or 1.0
                local tailLength = 2.5 + 3.5 * scale
                local headX = s.x + nx * (tailLength * 0.2)
                local headY = s.y + ny * (tailLength * 0.2)
                local tailX = s.x - nx * tailLength
                local tailY = s.y - ny * tailLength
                local t = math.max(0, s.life / (s.maxLife or 0.0001))

                local color = s.color or DEFAULT_COLOR
                love.graphics.setColor(color[1], color[2], color[3], 0.4 + 0.6 * t)
                love.graphics.setLineWidth(1.0 + scale)
                love.graphics.line(tailX, tailY, headX, headY)
            end
        end
    end

    love.graphics.setLineWidth(prevLineWidth)
end

function projectile_shards.clear()
    for i = #projectile_shards.list, 1, -1 do
        local s = projectile_shards.list[i]
        if s.body then
            s.body:destroy()
        end
        table.remove(projectile_shards.list, i)
    end
end

return projectile_shards
