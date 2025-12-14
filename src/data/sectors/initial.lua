local config = require("src.core.config")

local initial = {
    id = "initial",
    size = (config.world and config.world.width) or 6000,

    asteroids = {
        -- Lower overall density for the initial sector.
        countMin = 18,
        countMax = 32,

        -- Keep mithril present, but not common.
        variantWeights = {
            ice = 0.90,
            mithril_ore = 0.10,
        },

        pattern = "cluster",

        edgeMargin = 140,
        minSeparation = 22,
    },
}

return initial
