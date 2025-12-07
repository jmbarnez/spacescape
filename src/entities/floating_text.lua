local colors = require("src.core.colors")

local floating_text = {}

floating_text.list = {}
floating_text.font = nil

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

    table.insert(floating_text.list, {
        text = tostring(text),
        x = x,
        y = y,
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
        local progress = f.life > 0 and (f.t / f.life) or 1
        if progress < 0 then progress = 0 end
        if progress > 1 then progress = 1 end

        local alpha = (1 - progress) * (f.alphaStart or 1)
        local text = f.text
        local w = font:getWidth(text)
        local h = font:getHeight()

        local scale = f.scale or 1
        local padX = 2 * scale
        local padY = 1 * scale

        local boxW = w * scale + padX * 2
        local boxH = h * scale + padY * 2
        local boxX = f.x - boxW / 2
        local boxY = f.y - boxH / 2

        local bg = f.bgColor or colors.floatingBg
        local tc = f.textColor or colors.floatingText

        -- Background rectangle
        love.graphics.setColor(bg[1], bg[2], bg[3], alpha * 0.9)
        love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 3, 3)

        -- Text
        love.graphics.setColor(tc[1], tc[2], tc[3], alpha)
        love.graphics.print(text, f.x - (w * scale) / 2, f.y - (h * scale) / 2, 0, scale, scale)
    end

    love.graphics.setFont(prevFont)
    love.graphics.setColor(colors.white)
end

function floating_text.clear()
    for i = #floating_text.list, 1, -1 do
        table.remove(floating_text.list, i)
    end
end

return floating_text
