-- Player cargo management module
-- Handles slot-based inventory for mined/salvaged resources

local cargo = {}

local config = require("src.core.config")

--- Add a quantity of a specific resource type to the player's cargo.
--
-- This helper is used by the item / pickup system when resource chunks are
-- collected. It keeps all cargo bookkeeping behind the player module so that
-- future changes to cargo structure (capacity limits, per-ship bays, etc.)
-- do not leak into other systems.
--
-- @param state table The player state table
-- @param resourceType string Resource identifier (e.g. "stone", "ice", "mithril")
-- @param amount number Amount to add (ignored if nil or <= 0)
-- @return number The amount that was actually added (for feedback)
function cargo.addResource(state, resourceType, amount)
    if not resourceType or not amount or amount <= 0 then
        return 0
    end

    --------------------------------------------------------------------------
    -- Ensure the cargo structure exists and is in the expected slot-based
    -- format. This keeps the function resilient if older code ever overwrites
    -- p.cargo with a plain table.
    --------------------------------------------------------------------------
    if not state.cargo or type(state.cargo) ~= "table" then
        state.cargo = {
            maxSlots = 16,
            slots = {},
        }
    end

    local cargoData = state.cargo
    cargoData.maxSlots = cargoData.maxSlots or 16
    cargoData.slots = cargoData.slots or {}

    local slots = cargoData.slots
    local maxSlots = cargoData.maxSlots

    -- Normalise key to a simple string so we can safely store it in slots.
    local key = tostring(resourceType)

    --------------------------------------------------------------------------
    -- First, try to find an existing stack for this resource type so we can
    -- simply increase its quantity instead of occupying a new slot.
    --------------------------------------------------------------------------
    local targetIndex = nil
    for i = 1, maxSlots do
        local slot = slots[i]
        if slot and slot.id == key then
            targetIndex = i
            break
        end
    end

    --------------------------------------------------------------------------
    -- If no existing stack was found, look for the first empty slot.
    --------------------------------------------------------------------------
    if not targetIndex then
        for i = 1, maxSlots do
            local slot = slots[i]
            if not slot or slot.id == nil then
                slots[i] = {
                    id = key,
                    quantity = 0,
                }
                targetIndex = i
                break
            end
        end
    end

    --------------------------------------------------------------------------
    -- If we still do not have a target slot, the inventory is full. For now
    -- we simply reject the pickup (return 0) so callers can decide what to do
    -- (e.g. spawn overflow into space) without crashing.
    --------------------------------------------------------------------------
    if not targetIndex then
        return 0
    end

    local slot = slots[targetIndex]
    slot.quantity = (slot.quantity or 0) + amount

    -- No capacity limit yet: everything fits into the chosen stack. If you
    -- later add max stack sizes, clamp here and return the actual delta.
    return amount
end

--- Initialize the cargo structure on a player state table.
-- @param state table The player state table
function cargo.init(state)
    state.cargo = {
        maxSlots = 16,
        slots = {},
    }
end

return cargo
