--- World - A collection of Systems and Entities.
local PATH             = (...):gsub('%.[^%.]+$', '')

local Filter           = require(PATH .. ".filter")
local Entity           = require(PATH .. ".entity")
local Components       = require(PATH .. ".components")
local Type             = require(PATH .. ".type")
local List             = require(PATH .. ".list")
local Utils            = require(PATH .. ".utils")

local World            = {
    ENABLE_OPTIMIZATION = true,
}
World.__mt             = {
    __index = World,
}

local defaultGenerator = function(state)
    local current = state
    state = state + 1
    return string.format("%d", current), state
end

function World.new()
    local world = setmetatable({
        __entities = List(),
        __systems = List(),

        __events = {},
        __emitSDepth = 0,

        __resources = {},

        __hash = {
            state = -2 ^ 53,
            generator = defaultGenerator,
            keys = {},
            entities = {}
        },

        __added = List(),
        __backAdded = List(),
        __removed = List(),
        __backRemoved = List(),
        __dirty = List(),
        __backDirty = List(),

        __systemLookup = {},

        __isWorld = true,

        __ignoreEmits = false
    }, World.__mt)

    if (World.ENABLE_OPTIMIZATION) then
        Utils.shallowCopy(World, world)
    end

    return world
end

function World:addEntity(e)
    if not Type.isEntity(e) then
        Utils.error(2, "bad argument #1 to 'World:addEntity' (Entity expected, got %s)", type(e))
    end

    if e.__world then
        error("bad argument #1 to 'World:addEntity' (Entity was already added to a world)", 2)
    end

    e.__world = self
    self.__added:add(e)

    return self
end

function World:newEntity()
    return Entity(self)
end

function World:query(def, onMatch)
    local filter = Filter.parse(nil, def)

    local list = nil
    if not Type.isCallable(onMatch) then
        list = type(onMatch) == "table" and onMatch or {}
    end

    for _, e in ipairs(self.__entities) do
        if Filter.match(e, filter) then
            if list then
                table.insert(list, e)
            else
                onMatch(e)
            end
        end
    end

    return list
end

function World:removeEntity(e)
    if not Type.isEntity(e) then
        Utils.error(2, "bad argument #1 to 'World:removeEntity' (Entity expected, got %s)", type(e))
    end

    if e.__world ~= self then
        error("trying to remove an Entity from a World it doesn't belong to", 2)
    end

    if e:has("key") then
        e:remove("key")
    end

    self.__removed:add(e)

    return self
end

function World:__dirtyEntity(e)
    if not self.__dirty:has(e) then
        self.__dirty:add(e)
    end
end

function World:__flush()
    if (self.__added.size == 0 and self.__removed.size == 0 and self.__dirty.size == 0) then
        return self
    end

    self.__added, self.__backAdded     = self.__backAdded, self.__added
    self.__removed, self.__backRemoved = self.__backRemoved, self.__removed
    self.__dirty, self.__backDirty     = self.__backDirty, self.__dirty

    local e

    for i = 1, self.__backAdded.size do
        e = self.__backAdded[i]
        if e.__world == self then
            self.__entities:add(e)
            for j = 1, self.__systems.size do
                self.__systems[j]:__evaluate(e)
            end
            self:onEntityAdded(e)
        end
    end
    self.__backAdded:clear()

    for i = 1, self.__backRemoved.size do
        e = self.__backRemoved[i]
        if e.__world == self then
            e.__world = nil
            self.__entities:remove(e)
            for j = 1, self.__systems.size do
                self.__systems[j]:__remove(e)
            end
            self:onEntityRemoved(e)
        end
    end
    self.__backRemoved:clear()

    for i = 1, self.__backDirty.size do
        e = self.__backDirty[i]
        if e.__world == self then
            for j = 1, self.__systems.size do
                self.__systems[j]:__evaluate(e)
            end
        end
    end
    self.__backDirty:clear()

    return self
end

local blacklistedSystemFunctions = {
    "init",
    "onEnabled",
    "onDisabled",
}

local tryAddSystem = function(world, systemClass)
    if (not Type.isSystemClass(systemClass)) then
        return false, "SystemClass expected, got " .. type(systemClass)
    end

    if (world.__systemLookup[systemClass]) then
        return false, "SystemClass was already added to World"
    end

    local system = systemClass(world)

    world.__systemLookup[systemClass] = system
    world.__systems:add(system)

    for callbackName, callback in pairs(systemClass) do
        if (not blacklistedSystemFunctions[callbackName]) then
            if (not world.__events[callbackName]) then
                world.__events[callbackName] = {}
            end

            local listeners = world.__events[callbackName]
            listeners[#listeners + 1] = {
                system   = system,
                callback = callback,
            }
        end
    end

    for j = 1, world.__entities.size do
        system:__evaluate(world.__entities[j])
    end

    return true
end

function World:addSystem(systemClass)
    local ok, err = tryAddSystem(self, systemClass)
    if not ok then
        Utils.error(2, "bad argument #1 to 'World:addSystem' (%s)", err)
    end
    return self
end

function World:addSystems(...)
    for i = 1, select("#", ...) do
        local systemClass = select(i, ...)
        local ok, err = tryAddSystem(self, systemClass)
        if not ok then
            Utils.error(2, "bad argument #%d to 'World:addSystems' (%s)", i, err)
        end
    end
    return self
end

function World:hasSystem(systemClass)
    if not Type.isSystemClass(systemClass) then
        Utils.error(2, "bad argument #1 to 'World:hasSystem' (SystemClass expected, got %s)", type(systemClass))
    end
    return self.__systemLookup[systemClass] and true or false
end

function World:getSystem(systemClass)
    if not Type.isSystemClass(systemClass) then
        Utils.error(2, "bad argument #1 to 'World:getSystem' (SystemClass expected, got %s)", type(systemClass))
    end
    return self.__systemLookup[systemClass]
end

function World:emit(functionName, ...)
    if not functionName or type(functionName) ~= "string" then
        Utils.error(2, "bad argument #1 to 'World:emit' (String expected, got %s)", type(functionName))
    end

    local shouldFlush = self.__emitSDepth == 0

    self.__emitSDepth = self.__emitSDepth + 1

    local listeners = self.__events[functionName]

    if not self.__ignoreEmits and Type.isCallable(self.beforeEmit) then
        self.__ignoreEmits = true
        local preventDefaults = self:beforeEmit(functionName, listeners, ...)
        self.__ignoreEmits = false
        if preventDefaults then return end
    end

    if listeners then
        for i = 1, #listeners do
            local listener = listeners[i]
            if (listener.system.__enabled) then
                if (shouldFlush) then
                    self:__flush()
                end
                listener.callback(listener.system, ...)
            end
        end
    end

    if not self.__ignoreEmits and Type.isCallable(self.afterEmit) then
        self.__ignoreEmits = true
        self:afterEmit(functionName, listeners, ...)
        self.__ignoreEmits = false
    end

    self.__emitSDepth = self.__emitSDepth - 1

    return self
end

function World:clear()
    for i = 1, self.__entities.size do
        self:removeEntity(self.__entities[i])
    end

    for i = 1, self.__added.size do
        local e = self.__added[i]
        e.__world = nil
    end
    self.__added:clear()

    self:__flush()

    return self
end

function World:getEntities()
    return self.__entities
end

function World:getSystems()
    return self.__systems
end

function World:serialize(ignoreKeys)
    self:__flush()
    local data = { generator = self.__hash.state }
    for i = 1, self.__entities.size do
        local entity = self.__entities[i]
        if entity.serializable then
            local entityData = entity:serialize(ignoreKeys)
            table.insert(data, entityData)
        end
    end
    return data
end

function World:deserialize(data, startClean, ignoreGenerator)
    if startClean then
        self:clear()
    end

    if (not ignoreGenerator) then
        self.__hash.state = data.generator
    end

    local entities = {}

    for i = 1, #data do
        local entity = Entity(self)

        if data[i].key then
            local component = Components.key:__new(entity)
            component:deserialize(data[i].key)
            entity.key = component
            entity:__dirty()
        end

        entities[i] = entity
    end

    for i = 1, #data do
        entities[i]:deserialize(data[i])
    end

    self:__flush()

    return self
end

function World:setKeyGenerator(generator, initialState)
    if not Type.isCallable(generator) then
        Utils.error(2, "bad argument #1 to 'World:setKeyGenerator' (function expected, got %s)", type(generator))
    end
    self.__hash.generator = generator
    self.__hash.state = initialState
    return self
end

function World:__clearKey(e)
    local key = self.__hash.keys[e]
    if key then
        self.__hash.keys[e] = nil
        self.__hash.entities[key] = nil
    end
    return self
end

function World:__assignKey(e, key)
    local hash = self.__hash

    if not key then
        key = hash.keys[e]
        if key then return key end
        key, hash.state = hash.generator(hash.state)
    end

    if hash.entities[key] and hash.entities[key] ~= e then
        Utils.error(4, "Trying to assign a key that is already taken (key: '%s').", key)
    elseif hash.keys[e] and hash.keys[e] ~= key then
        Utils.error(4, "Trying to assign more than one key to an Entity. (old: '%s', new: '%s')", hash.keys[e], key)
    end

    hash.keys[e] = key
    hash.entities[key] = e

    return key
end

function World:getEntityByKey(key)
    return self.__hash.entities[key]
end

function World:onEntityAdded(e) end

function World:onEntityRemoved(e) end

function World:setResource(name, resource)
    self.__resources[name] = resource
    return self
end

function World:getResource(name)
    return self.__resources[name]
end

return setmetatable(World, {
    __call = function(_, ...)
        return World.new(...)
    end,
})
