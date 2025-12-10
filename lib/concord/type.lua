--- Type - Helper module for type checking Concord types
local Type = {}

function Type.isCallable(t)
    if type(t) == "function" then return true end
    local meta = getmetatable(t)
    if meta and type(meta.__call) == "function" then return true end
    return false
end

function Type.isEntity(t)
    return type(t) == "table" and t.__isEntity or false
end

function Type.isComponentClass(t)
    return type(t) == "table" and t.__isComponentClass or false
end

function Type.isComponent(t)
    return type(t) == "table" and t.__isComponent or false
end

function Type.isSystemClass(t)
    return type(t) == "table" and t.__isSystemClass or false
end

function Type.isSystem(t)
    return type(t) == "table" and t.__isSystem or false
end

function Type.isWorld(t)
    return type(t) == "table" and t.__isWorld or false
end

function Type.isFilter(t)
    return type(t) == "table" and t.__isFilter or false
end

return Type
