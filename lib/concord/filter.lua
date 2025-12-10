--- Filter - Used to filter Entities with specific Components
local PATH       = (...):gsub('%.[^%.]+$', '')

local List       = require(PATH .. ".list")
local Type       = require(PATH .. ".type")
local Utils      = require(PATH .. ".utils")
local Components = require(PATH .. ".components")

local Filter     = {}
Filter.__mt      = {
    __index = Filter,
}

function Filter.validate(errorLevel, name, def, onComponent)
    local filter = "World:query filter"
    if name then
        filter = ("filter '%s'"):format(name)
    end

    if type(def) ~= 'table' then
        Utils.error(3 + errorLevel, "invalid component list for %s (table expected, got %s)", filter, type(def))
    end

    if not onComponent and def.constructor and not Type.isCallable(def.constructor) then
        Utils.error(3 + errorLevel, "invalid pool constructor for %s (callable expected, got %s)", filter,
            type(def.constructor))
    end

    for n, component in ipairs(def) do
        local ok, err, reject = Components.try(component, true)
        if not ok then
            Utils.error(3 + errorLevel, "invalid component for %s at position #%d (%s)", filter, n, err)
        end
        if onComponent then
            onComponent(component, reject)
        end
    end
end

function Filter.parse(name, def)
    local filter = {}
    Filter.validate(1, name, def, function(component, reject)
        if reject then
            table.insert(filter, reject)
            table.insert(filter, false)
        else
            table.insert(filter, component)
            table.insert(filter, true)
        end
    end)
    return filter
end

function Filter.match(e, filter)
    for i = #filter, 2, -2 do
        local match = filter[i - 0]
        local name  = filter[i - 1]
        if (not e[name]) == match then return false end
    end
    return true
end

local REQUIRED_METHODS = { "add", "remove", "has", "clear" }
local VALID_POOL_TYPES = { table = true, userdata = true, lightuserdata = true, cdata = true }

function Filter.isValidPool(name, pool)
    local poolType = type(pool)
    if not VALID_POOL_TYPES[poolType] then
        Utils.error(3, "invalid value returned by pool '%s' constructor (table expected, got %s).", name, type(pool))
    end
    for _, method in ipairs(REQUIRED_METHODS) do
        if not Type.isCallable(pool[method]) then
            Utils.error(3, "invalid :%s method on pool '%s' (callable expected, got %s).", method, name,
                type(pool[method]))
        end
    end
end

function Filter.new(name, def)
    local pool
    if def.constructor then
        pool = def.constructor(def)
        Filter.isValidPool(name, pool)
    else
        pool = List()
    end

    local filterData = Filter.parse(name, def)

    local filter = setmetatable({
        pool       = pool,
        __filter   = filterData,
        __name     = name,
        __isFilter = true,
    }, Filter.__mt)

    return filter, pool
end

function Filter:eligible(e)
    return Filter.match(e, self.__filter)
end

function Filter:evaluate(e)
    local has = self.pool:has(e)
    local eligible = self:eligible(e)

    if not has and eligible then
        self.pool:add(e)
    elseif has and not eligible then
        self.pool:remove(e)
    end
    return self
end

function Filter:add(e, bypass)
    if not bypass and not self:eligible(e) then
        return self, false
    end
    self.pool:add(e)
    return self, true
end

function Filter:remove(e)
    self.pool:remove(e)
    return self
end

function Filter:clear(e)
    self.pool:clear(e)
    return self
end

function Filter:has(e)
    return self.pool:has(e)
end

function Filter:getName()
    return self.__name
end

return setmetatable(Filter, {
    __call = function(_, ...)
        return Filter.new(...)
    end,
})
