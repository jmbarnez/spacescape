--- Data structure that allows for fast removal at the cost of containing order.
local List = {}
List.__mt = {
    __index = List
}

function List.new()
    return setmetatable({
        size = 0,
    }, List.__mt)
end

function List:add(obj)
    local size = self.size + 1
    self[size] = obj
    self[obj]  = size
    self.size  = size
    if self.onAdded then self:onAdded(obj) end
    return self
end

function List:remove(obj)
    local index = self[obj]
    if not index then return end
    local size = self.size

    if index == size then
        self[size] = nil
    else
        local other = self[size]
        self[index] = other
        self[other] = index
        self[size] = nil
    end

    self[obj] = nil
    self.size = size - 1
    if self.onRemoved then self:onRemoved(obj) end
    return self
end

function List:clear()
    for i = 1, self.size do
        local o = self[i]
        self[o] = nil
        self[i] = nil
    end
    self.size = 0
    return self
end

function List:has(obj)
    return self[obj] and true or false
end

function List:get(i)
    return self[i]
end

function List:indexOf(obj)
    if (not self[obj]) then
        error("bad argument #1 to 'List:indexOf' (Object was not in List)", 2)
    end
    return self[obj]
end

function List:sort(order)
    table.sort(self, order)
    for key, obj in ipairs(self) do
        self[obj] = key
    end
    return self
end

function List:onAdded(obj) end

function List:onRemoved(obj) end

return setmetatable(List, {
    __call = function()
        return List.new()
    end,
})
