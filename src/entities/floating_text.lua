local colors = require("src.core.colors")

local floating_text = {}

floating_text.list = {}
floating_text.font = nil

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

function floating_text.spawn(text, x, y, color, options)
    options = options or {}

    local life = options.duration or 1.2
    local riseSpeed = options.riseSpeed or 25
    local vx = options.vx or 0
    local vy = options.vy or -riseSpeed
    local scale = options.scale or 0.8
    local alphaStart = options.alpha or 1
    local bgColor = options.bgColor or colors.floatingBg
    local textColor = options.textColor or colors.floatingText

    -- Add random offset to prevent text stacking
    local offsetX = (math.random() - 0.5) * 80
    local offsetY = (math.random() - 0.5) * 60

    table.insert(floating_text.list, {
        text = tostring(text),
        x = x + offsetX,
        y = y + offsetY,
        vx = vx,
        vy = vy,
        t = 0,
        life = life,
        alphaStart = alphaStart,
        scale = scale,
        bgColor = bgColor,
        textColor = textColor
    })
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

function floating_text.update(dt)
    for i = #floating_text.list, 1, -1 do
        local f = floating_text.list[i]

        f.t = f.t + dt
        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt

        if f.t >= f.life then
            table.remove(floating_text.list, i)
        end
    end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function floating_text.draw()
    if #floating_text.list == 0 then
        return
    end

    if not floating_text.font then
        floating_text.font = love.graphics.newFont("assets/fonts/Orbitron-Bold.ttf", 16)
    end

    local prevFont = love.graphics.getFont()
    love.graphics.setFont(floating_text.font)

    local font = floating_text.font

    for _, f in ipairs(floating_text.list) do
        local progress = math.min(math.max(f.t / f.life, 0), 1)
        local alpha = (1 - progress) * f.alphaStart
        
        -- Measure text at desired scale so we can center it around (x, y)
        local text = f.text
        local scale = f.scale
        local w = font:getWidth(text) * scale
        local h = font:getHeight() * scale

        -- Colored text only (no background box behind it)
        local tc = f.textColor
        love.graphics.setColor(tc[1], tc[2], tc[3], alpha)
        love.graphics.print(text, f.x - w / 2, f.y - h / 2, 0, scale, scale)
    end

    love.graphics.setFont(prevFont)
    love.graphics.setColor(colors.white)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function floating_text.clear()
    floating_text.list = {}
end

return floating_text
