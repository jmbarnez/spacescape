--- System - Iterates over Entities and modifies their Components.
local PATH   = (...):gsub('%.[^%.]+$', '')

local Filter = require(PATH .. ".filter")
local Utils  = require(PATH .. ".utils")

local System = {
    ENABLE_OPTIMIZATION = true,
}

System.mt    = {
    __index = System,
    __call  = function(systemClass, world)
        local system = setmetatable({
            __enabled = true,
            __filters = {},
            __world = world,
            __isSystem = true,
            __isSystemClass = false,
        }, systemClass)

        if (System.ENABLE_OPTIMIZATION) then
            Utils.shallowCopy(systemClass, system)
        end

        for name, def in pairs(systemClass.__definition) do
            local filter, pool = Filter(name, Utils.shallowCopy(def, {}))
            system[name] = pool
            table.insert(system.__filters, filter)
        end

        system:init(world)

        return system
    end,
}

function System.new(definition)
    definition = definition or {}

    for name, def in pairs(definition) do
        if type(name) ~= 'string' then
            Utils.error(2, "invalid name for filter (string key expected, got %s)", type(name))
        end
        Filter.validate(0, name, def)
    end

    local systemClass = setmetatable({
        __definition = definition,
        __isSystemClass = true,
    }, System.mt)
    systemClass.__index = systemClass

    if (System.ENABLE_OPTIMIZATION) then
        Utils.shallowCopy(System, systemClass)
    end

    return systemClass
end

function System:__evaluate(e)
    for _, filter in ipairs(self.__filters) do
        filter:evaluate(e)
    end
    return self
end

function System:__remove(e)
    for _, filter in ipairs(self.__filters) do
        if filter:has(e) then
            filter:remove(e)
        end
    end
    return self
end

function System:__clear()
    for _, filter in ipairs(self.__filters) do
        filter:clear()
    end
    return self
end

function System:setEnabled(enable)
    if (not self.__enabled and enable) then
        self.__enabled = true
        self:onEnabled()
    elseif (self.__enabled and not enable) then
        self.__enabled = false
        self:onDisabled()
    end
    return self
end

function System:isEnabled()
    return self.__enabled
end

function System:getWorld()
    return self.__world
end

function System:init(world) end

function System:onEnabled() end

function System:onDisabled() end

return setmetatable(System, {
    __call = function(_, ...)
        return System.new(...)
    end,
})
