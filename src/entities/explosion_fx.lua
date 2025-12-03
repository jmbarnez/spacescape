local explosion_fx = {}

local camera = require("src.core.camera")

explosion_fx.list = {}
explosion_fx.shader = nil

function explosion_fx.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/explosion.glsl")
    if ok then
        explosion_fx.shader = shader
    end
end

function explosion_fx.spawn(x, y, color, radius)
    if not x or not y then
        return
    end
    color = color or {1, 0.8, 0.4}
    radius = radius or 60
    table.insert(explosion_fx.list, {
        x = x,
        y = y,
        radius = radius,
        color = {color[1] or 1, color[2] or 1, color[3] or 1},
        startTime = love.timer.getTime(),
        duration = 0.4
    })
end

function explosion_fx.update(dt)
end

function explosion_fx.draw()
    if #explosion_fx.list == 0 then
        return
    end

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    local shader = explosion_fx.shader
    local now = love.timer.getTime()

    if shader then
        love.graphics.setShader(shader)
        shader:send("time", now)
    end

    love.graphics.setBlendMode("add", "alphamultiply")

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local camScale = camera.scale or 1
    local camX = camera.x or 0
    local camY = camera.y or 0

    for i = #explosion_fx.list, 1, -1 do
        local e = explosion_fx.list[i]
        local elapsed = now - (e.startTime or now)
        local duration = e.duration or 0.7
        local t = elapsed / duration

        if t >= 1.0 then
            table.remove(explosion_fx.list, i)
        else
            if shader then
                local screenX = (e.x - camX) * camScale + width / 2
                local screenY = (e.y - camY) * camScale + height / 2

                shader:send("center", {screenX, screenY})
                shader:send("radius", e.radius * camScale)
                shader:send("color", e.color)
                shader:send("progress", t)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", e.x - e.radius, e.y - e.radius, e.radius * 2, e.radius * 2)
            else
                local alpha = 1.0 - t
                local size = e.radius * (0.4 + 0.8 * t)
                love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha)
                love.graphics.circle("fill", e.x, e.y, size)
            end
        end
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
    love.graphics.setColor(1, 1, 1, 1)
end

function explosion_fx.clear()
    for i = #explosion_fx.list, 1, -1 do
        table.remove(explosion_fx.list, i)
    end
end

return explosion_fx
