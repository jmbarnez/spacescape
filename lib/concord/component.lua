--- Component - A pure data container contained by a single entity.
local PATH       = (...):gsub('%.[^%.]+$', '')

local Components = require(PATH .. ".components")
local Utils      = require(PATH .. ".utils")

local Component  = {}
Component.__mt   = {
    __index = Component,
}

function Component.new(name, populate)
    if (type(name) ~= "string") then
        Utils.error(2, "bad argument #1 to 'Component.new' (string expected, got %s)", type(name))
    end

    if (string.match(name, Components.__REJECT_MATCH) ~= "") then
        Utils.error(2, "bad argument #1 to 'Component.new' (Component names can't start with '%s', got %s)",
            Components.__REJECT_PREFIX, name)
    end

    if (rawget(Components, name)) then
        Utils.error(2, "bad argument #1 to 'Component.new' (ComponentClass with name '%s' was already registerd)", name)
    end

    if (type(populate) ~= "function" and type(populate) ~= "nil") then
        Utils.error(2, "bad argument #1 to 'Component.new' (function/nil expected, got %s)", type(populate))
    end

    local componentClass = setmetatable({
        __populate         = populate,
        __name             = name,
        __isComponentClass = true,
    }, Component.__mt)

    componentClass.__mt = {
        __index = componentClass
    }

    Components[name] = componentClass
    return componentClass
end

function Component:__populate() end

function Component:removed() end

function Component:serialize()
    local data              = Utils.shallowCopy(self, {})
    data.__componentClass   = nil
    data.__entity           = nil
    data.__isComponent      = nil
    data.__isComponentClass = nil
    return data
end

function Component:deserialize(data)
    Utils.shallowCopy(data, self)
end

function Component:__new(entity)
    local component = setmetatable({
        __componentClass   = self,
        __entity           = entity,
        __isComponent      = true,
        __isComponentClass = false,
    }, self.__mt)
    return component
end

function Component:__initialize(entity, ...)
    local component = self:__new(entity)
    self.__populate(component, ...)
    return component
end

function Component:hasName()
    return self.__name and true or false
end

function Component:getName()
    return self.__name
end

return setmetatable(Component, {
    __call = function(_, ...)
        return Component.new(...)
    end,
})
