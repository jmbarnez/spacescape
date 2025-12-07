local state_machine = {}

local states = {}
local current = nil
local currentName = nil

local function set_state(name)
    local new_state = states[name]
    if not new_state or new_state == current then
        return
    end

    local previous = current
    local previousName = currentName

    if previous and previous.exit then
        previous.exit(name)
    end

    current = new_state
    currentName = name

    if current and current.enter then
        current.enter(previousName)
    end
end

function state_machine.register(name, module)
    states[name] = module
end

function state_machine.switch(name)
    set_state(name)
end

function state_machine.get_current()
    return current, currentName
end

function state_machine.call(method, ...)
    if current and current[method] then
        return current[method](...)
    end
end

function state_machine.load()
    if not states.game then
        states.game = require("src.states.game")
    end
    set_state("game")
    if current and current.load then
        current.load()
    end
end

function state_machine.update(dt)
    return state_machine.call("update", dt)
end

function state_machine.draw()
    return state_machine.call("draw")
end

function state_machine.keypressed(key)
    return state_machine.call("keypressed", key)
end

function state_machine.mousepressed(x, y, button)
    return state_machine.call("mousepressed", x, y, button)
end
 
function state_machine.wheelmoved(x, y)
    return state_machine.call("wheelmoved", x, y)
end

function state_machine.resize(w, h)
    return state_machine.call("resize", w, h)
end

return state_machine
