local state_machine = require("src.core.state_machine")

function love.load()
    state_machine.load()
end

function love.update(dt)
    state_machine.update(dt)
end

function love.draw()
    state_machine.draw()
end

function love.mousepressed(x, y, button)
    state_machine.mousepressed(x, y, button)
end

function love.resize(w, h)
    state_machine.resize(w, h)
end

