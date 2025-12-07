-- Shield impact effect system
-- Adds a short-lived shader-based flash around shielded entities when they are struck.
-- The effect is screen-space so we can use crisp pixel distances for radius and ripples.

local camera = require("src.core.camera")
local colors = require("src.core.colors")

local shield_fx = {}

-- Active shield impact instances; each entry carries position, radius, color, and impact direction.
shield_fx.list = {}
shield_fx.shader = nil

-- Load the shield shader once; failures are tolerated gracefully so the game keeps running.
function shield_fx.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/shield.glsl")
    if ok then
        shield_fx.shader = shader
    end
end

-- Nuke all active shield flashes; handy for restart/reset.
function shield_fx.clear()
    for i = #shield_fx.list, 1, -1 do
        table.remove(shield_fx.list, i)
    end
end

-- Spawn a new shield flash.
-- @param x, y     world-space center
-- @param radius   shield radius (world units)
-- @param color    rgb table for tint
-- @param dir      impact direction vector (normalized or close enough)
function shield_fx.spawn(x, y, radius, color, dir)
    if not x or not y then
        return
    end
    radius = radius or 24
    color = color or colors.projectile or {0.3, 0.7, 1.0}
    dir = dir or {0.0, 1.0}

    table.insert(shield_fx.list, {
        x = x,
        y = y,
        radius = radius,
        color = {color[1] or 0.3, color[2] or 0.7, color[3] or 1.0},
        dir = {dir[1] or 0.0, dir[2] or 1.0},
        startTime = love.timer.getTime(),
        duration = 0.45, -- quick flash so hits feel snappy
    })
end

-- Draw all active shield flashes in screen space with additive blending for a bright pop.
function shield_fx.draw()
    if #shield_fx.list == 0 then
        return
    end

    local shader = shield_fx.shader
    local now = love.timer.getTime()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local camScale = camera.scale or 1
    local camX = camera.x or 0
    local camY = camera.y or 0

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    if shader then
        love.graphics.setShader(shader)
    end
    love.graphics.setBlendMode("add", "alphamultiply")

    for i = #shield_fx.list, 1, -1 do
        local fx = shield_fx.list[i]
        local elapsed = now - (fx.startTime or now)
        local duration = fx.duration or 0.4
        local t = elapsed / duration

        if t >= 1.0 then
            -- Kill expired flashes first so the list stays small.
            table.remove(shield_fx.list, i)
        else
            -- Convert world position to screen so the shader can draw in pixel space.
            local screenX = (fx.x - camX) * camScale + width / 2
            local screenY = (fx.y - camY) * camScale + height / 2
            local r = (fx.radius or 24) * camScale

            if shader then
                shader:send("time", now)
                shader:send("center", {screenX, screenY})
                shader:send("radius", r)
                shader:send("color", fx.color or colors.projectile)
                shader:send("contactDir", fx.dir or {0.0, 1.0})
                shader:send("progress", t)
                love.graphics.setColor(colors.white)
                love.graphics.rectangle("fill", screenX - r, screenY - r, r * 2, r * 2)
            else
                -- Fallback: simple expanding circle if shader failed to load.
                local alpha = (1.0 - t) * 0.8
                local size = r * (0.8 + 0.4 * t)
                love.graphics.setColor(fx.color[1], fx.color[2], fx.color[3], alpha)
                love.graphics.circle("line", screenX, screenY, size)
            end
        end
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
    love.graphics.setColor(1, 1, 1, 1)
end

return shield_fx
