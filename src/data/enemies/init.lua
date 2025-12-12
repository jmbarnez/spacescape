local scout = require("src.data.enemies.scout")

local enemies = {
    scout = scout,
}

-- Convenience list for random selection.
-- Keeping both a keyed map and a list makes it easy to reference an enemy by id
-- while also supporting weighted/random spawn logic.
enemies.list = {
    scout,
}

-- Optional fallback for invalid ids.
enemies.default = scout

return enemies
