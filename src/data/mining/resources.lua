local stone   = require("src.data.mining.resource_stone")
local ice     = require("src.data.mining.resource_ice")
local mithril = require("src.data.mining.resource_mithril")
local scrap   = require("src.data.mining.resource_scrap")

local resources = {
    stone = stone,
    ice = ice,
    mithril = mithril,
    scrap = scrap,
}

-- Optional default entry used as a fallback when an unknown resource id is
-- referenced. This prevents crashes if data and code drift temporarily.
resources.default = resources.stone

return resources
