-- Player progression module
-- Handles XP, leveling, and currency

local progression = {}

local config = require("src.core.config")

--- Recalculate XP progress ratio for the current level.
-- @param state table The player state table
local function recalcXpProgress(state)
    local base = config.player.xpBase or 100
    local growth = config.player.xpGrowth or 0
    local level = state.level or 1
    local xp = state.xp or 0

    local xpToNext = base + growth * (level - 1)
    if xpToNext <= 0 then
        xpToNext = 1
    end

    state.xpToNext = xpToNext
    state.xpRatio = math.max(0, math.min(1, xp / xpToNext))
end

--- Add experience points to the player, handling level-ups.
-- @param state table The player state table
-- @param amount number XP to add
-- @return boolean True if the player leveled up
function progression.addExperience(state, amount)
    if not amount or amount <= 0 then
        return false
    end

    -- Lifetime XP: always increase, never reduced by level-ups. This is where
    -- you can later hook in stats, unlocks, etc.
    state.totalXp = (state.totalXp or 0) + amount

    -- Per-level XP: only used for the current level's progress ring.
    state.xp = (state.xp or 0) + amount
    local leveledUp = false

    -- Process level-ups; any overflow XP will be discarded so the ring resets to empty.
    -- This matches the UX request: fill the ring to 100%, then drop to 0 on level-up.
    while true do
        local base = config.player.xpBase or 100
        local growth = config.player.xpGrowth or 0
        local level = state.level or 1
        local xpToNext = base + growth * (level - 1)
        if xpToNext <= 0 then
            xpToNext = 1
        end

        if state.xp >= xpToNext then
            -- Level up and intentionally **do not** carry leftover XP.
            -- Discarding the remainder ensures the XP ring fully empties after leveling.
            state.xp = 0
            state.level = level + 1
            leveledUp = true
        else
            break
        end
    end

    -- Recalculate ratio after leveling and possible XP reset.
    recalcXpProgress(state)
    return leveledUp
end

--- Add currency to the player.
-- @param state table The player state table
-- @param amount number Amount to add
-- @return number The amount that was actually added
function progression.addCurrency(state, amount)
    if not amount or amount <= 0 then
        return 0
    end
    state.currency = (state.currency or 0) + amount
    return amount
end

--- Reset all progression state to initial values.
-- @param state table The player state table
function progression.reset(state)
    state.level = 1
    state.xp = 0
    state.totalXp = 0
    recalcXpProgress(state)
end

--- Initialize progression fields on a player state table.
-- @param state table The player state table
function progression.init(state)
    state.level = 1
    state.xp = 0
    state.totalXp = 0
    state.xpToNext = config.player.xpBase
    state.xpRatio = 0
    state.currency = 0
end

-- Expose recalc for external use if needed
progression.recalcXpProgress = recalcXpProgress

return progression
