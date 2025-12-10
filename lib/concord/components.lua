--- Container for registered ComponentClasses
local Components = {}

Components.__REJECT_PREFIX = "!"
Components.__REJECT_MATCH = "^(%" .. Components.__REJECT_PREFIX .. "?)(.+)"

function Components.has(name)
    return rawget(Components, name) and true or false
end

function Components.reject(name)
    local ok, err = Components.try(name)
    if not ok then error(err, 2) end
    return Components.__REJECT_PREFIX .. name
end

function Components.try(name, acceptRejected)
    if type(name) ~= "string" then
        return false, "ComponentsClass name is expected to be a string, got " .. type(name) .. ")"
    end

    local rejected = false
    if acceptRejected then
        local prefix
        prefix, name = string.match(name, Components.__REJECT_MATCH)
        rejected = prefix ~= "" and name
    end

    local value = rawget(Components, name)
    if not value then
        return false, "ComponentClass '" .. name .. "' does not exist / was not registered"
    end

    return true, value, rejected
end

function Components.get(name)
    local ok, value = Components.try(name)
    if not ok then error(value, 2) end
    return value
end

return setmetatable(Components, {
    __index = function(_, name)
        local ok, value = Components.try(name)
        if not ok then error(value, 2) end
        return value
    end
})
