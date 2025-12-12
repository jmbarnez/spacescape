-- Central item definitions registry
-- All items (resources, equipment, etc.) are defined here

local stone   = require("src.data.items.stone")
local ice     = require("src.data.items.ice")
local mithril = require("src.data.items.mithril")
local scrap   = require("src.data.items.scrap")

local items = {
    stone = stone,
    ice = ice,
    mithril = mithril,
    scrap = scrap,
}

items.default = items.stone

return items
