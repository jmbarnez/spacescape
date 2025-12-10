--------------------------------------------------------------------------------
-- ECS MODULE
-- Main entry point for the ECS system
--------------------------------------------------------------------------------

-- Initialize components first
require("src.ecs.components")

-- Export world and assemblages
local M = {
    world = require("src.ecs.world"),
    assemblages = require("src.ecs.assemblages"),
}

return M
