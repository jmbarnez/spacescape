local state_machine = require("src.core.state_machine")

function love.load()
	state_machine.load()
end

function love.update(dt)
	state_machine.call("update", dt)
end

function love.draw()
	state_machine.call("draw")
end

function love.keypressed(key)
	state_machine.call("keypressed", key)
end

function love.mousepressed(x, y, button)
	state_machine.call("mousepressed", x, y, button)
end

function love.wheelmoved(x, y)
	state_machine.call("wheelmoved", x, y)
end

function love.resize(w, h)
	state_machine.call("resize", w, h)
end

function love.mousereleased(x, y, button)
	state_machine.call("mousereleased", x, y, button)
end

function love.mousemoved(x, y, dx, dy)
	state_machine.call("mousemoved", x, y, dx, dy)
end
