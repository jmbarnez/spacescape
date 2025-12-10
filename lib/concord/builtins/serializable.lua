local PATH = (...):gsub('%.builtins%.[^%.]+$', '')

local Component = require(PATH .. ".component")

local Serializable = Component("serializable")

function Serializable:serialize()
    return nil
end

return Serializable
