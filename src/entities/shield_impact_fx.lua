local colors = require("src.core.colors")
local camera = require("src.core.camera")

local shield_impact_fx = {}

shield_impact_fx.list = {}
shield_impact_fx.shader = nil

function shield_impact_fx.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/shield_impact.glsl")
    if ok then
        shield_impact_fx.shader = shader
    else
        shield_impact_fx.shader = nil
    end
end

function shield_impact_fx.spawn(centerX, centerY, impactX, impactY, radius, color)
    if not centerX or not centerY or not impactX or not impactY then
        return
    end

    radius = radius or 40
    if radius <= 0 then
        radius = 40
    end

    color = color or colors.shieldDamage or colors.projectile or {1, 1, 1}

    local hit = {
        cx = centerX,
        cy = centerY,
        ix = impactX,
        iy = impactY,
        radius = radius,
        color = { color[1] or 1, color[2] or 1, color[3] or 1 },
        startTime = love.timer.getTime(),
        duration = 0.35,
    }

    table.insert(shield_impact_fx.list, hit)
end

function shield_impact_fx.update(dt)
    if #shield_impact_fx.list == 0 then
        return
    end

    local now = love.timer.getTime()

    for i = #shield_impact_fx.list, 1, -1 do
        local hit = shield_impact_fx.list[i]
        local duration = hit.duration or 0.35
        local elapsed = now - (hit.startTime or now)

        if elapsed >= duration then
            table.remove(shield_impact_fx.list, i)
        end
    end
end

function shield_impact_fx.draw()
    if #shield_impact_fx.list == 0 then
        return
    end

    local shader = shield_impact_fx.shader
    if not shader then
        return
    end

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setShader(shader)

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local camScale = camera.scale or 1
    local camX = camera.x or 0
    local camY = camera.y or 0

    local now = love.timer.getTime()

    for i = #shield_impact_fx.list, 1, -1 do
        local hit = shield_impact_fx.list[i]
        local duration = hit.duration or 0.35
        local elapsed = now - (hit.startTime or now)
        local t = elapsed / duration

        if t >= 1.0 then
            table.remove(shield_impact_fx.list, i)
        else
            local screenCenterX = (hit.cx - camX) * camScale + width / 2
            local screenCenterY = (hit.cy - camY) * camScale + height / 2
            local screenImpactX = (hit.ix - camX) * camScale + width / 2
            local screenImpactY = (hit.iy - camY) * camScale + height / 2

            shader:send("center", { screenCenterX, screenCenterY })
            shader:send("impact", { screenImpactX, screenImpactY })
            shader:send("radius", hit.radius * camScale)
            shader:send("color", hit.color)
            shader:send("progress", t)

            love.graphics.setColor(1, 1, 1, 1)
            local r = hit.radius
            love.graphics.rectangle("fill", hit.cx - r, hit.cy - r, r * 2, r * 2)
        end
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
    love.graphics.setColor(1, 1, 1, 1)
end

function shield_impact_fx.clear()
    for i = #shield_impact_fx.list, 1, -1 do
        table.remove(shield_impact_fx.list, i)
    end
end

return shield_impact_fx
