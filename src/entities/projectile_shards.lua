local physics = require("src.core.physics")

local projectile_shards = {}

projectile_shards.list = {}

local DEFAULT_COLOR = {1, 0.95, 0.8}

local function spawnShard(x, y, dirX, dirY, baseSpeed, lifeMin, lifeMax, color)
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
    local radius = 1.2

    local shard = {
        x = x,
        y = y,
        body = nil,
        shape = nil,
        fixture = nil,
        life = life,
        maxLife = life,
        color = color or DEFAULT_COLOR,
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

function projectile_shards.spawn(x, y, dirX, dirY, baseSpeed, count, color)
    baseSpeed = baseSpeed or (physics.constants and physics.constants.projectileSpeed) or 350
    count = count or 8

    for i = 1, count do
        spawnShard(x, y, dirX, dirY, baseSpeed, 0.35, 0.7, color)
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
                local tailLength = 3.5
                local tailX = s.x - nx * tailLength
                local tailY = s.y - ny * tailLength
                local t = math.max(0, s.life / (s.maxLife or 0.0001))

                local color = s.color or DEFAULT_COLOR
                love.graphics.setColor(color[1], color[2], color[3], 0.4 + 0.6 * t)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(tailX, tailY, s.x, s.y)
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
