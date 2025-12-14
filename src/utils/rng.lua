local bit = require("bit")

local rng = {}

local function toUint32(n)
    return bit.tobit(n)
end

local function mix32(a)
    a = toUint32(a)
    a = bit.bxor(a, bit.rshift(a, 16))
    a = toUint32(a * 0x7feb352d)
    a = bit.bxor(a, bit.rshift(a, 15))
    a = toUint32(a * 0x846ca68b)
    a = bit.bxor(a, bit.rshift(a, 16))
    return a
end

function rng.hash2u32(seed, x, y)
    seed = toUint32(seed or 0)
    x = toUint32(x or 0)
    y = toUint32(y or 0)

    local h = seed
    h = bit.bxor(h, mix32(x + 0x9e3779b9))
    h = bit.bxor(h, mix32(y + 0x85ebca6b))
    return toUint32(h)
end

function rng.hash01(seed, x, y)
    local h = rng.hash2u32(seed, x, y)
    local u = bit.band(h, 0x7fffffff)
    return u / 0x80000000
end

function rng.new(seed)
    local state = toUint32(seed or 0x12345678)

    return {
        nextU32 = function(self)
            state = toUint32(state + 0x6d2b79f5)
            return mix32(state)
        end,
        next = function(self)
            local u = bit.band(mix32(state), 0x7fffffff)
            state = toUint32(state + 0x6d2b79f5)
            return u / 0x80000000
        end,
        range = function(self, min, max)
            if min == nil or max == nil then
                return 0
            end
            local u = bit.band(mix32(state), 0x7fffffff)
            state = toUint32(state + 0x6d2b79f5)
            return min + (max - min) * (u / 0x80000000)
        end,
        int = function(self, min, max)
            if min == nil or max == nil then
                return 0
            end
            if max < min then
                min, max = max, min
            end
            local span = max - min + 1
            local u = bit.band(mix32(state), 0x7fffffff)
            state = toUint32(state + 0x6d2b79f5)
            return min + (u % span)
        end,
    }
end

return rng
