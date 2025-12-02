local state_machine = {}

local states = {}
local current = nil

local function set_state(name)
    local new_state = states[name]
    if not new_state then
        return
    end
    current = new_state
end

function state_machine.load()
    states.game = require("src.states.game")
    set_state("game")
    if current and current.load then
        current.load()
    end
end

function state_machine.update(dt)
    if current and current.update then
        current.update(dt)
    end
end

function state_machine.draw()
    if current and current.draw then
        current.draw()
    end
end

function state_machine.mousepressed(x, y, button)
    if current and current.mousepressed then
        current.mousepressed(x, y, button)
    end
end
 
function state_machine.wheelmoved(x, y)
    if current and current.wheelmoved then
        current.wheelmoved(x, y)
    end
end

function state_machine.resize(w, h)
    if current and current.resize then
        current.resize(w, h)
    end
end

return state_machine
