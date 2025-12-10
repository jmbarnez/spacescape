-- Player draw module
-- Handles player rendering

local draw = {}

local core_ship = require("src.core.ship")
local ship_renderer = require("src.render.ship_renderer")
local player_drone = require("src.data.ships.player_drone")

--- Render a drone for preview purposes (e.g., skin selection).
-- @param colors table Color palette to use
-- @param size number Size of the drone
function draw.renderDrone(colors, size)
    -- Build a concrete world-space layout for the current player blueprint
    -- and delegate all actual drawing to the shared ship renderer so that
    -- player ships use the same flexible template-driven pipeline as other
    -- ships.
    local layout = core_ship.buildInstanceFromBlueprint(player_drone, size)
    ship_renderer.drawPlayer(layout, colors)
end

--- Draw the player ship.
-- @param state table The player state table
-- @param colors table Color palette to use
-- @param shipModule table The player ship module (for building layout if needed)
function draw.draw(state, colors, shipModule)
    love.graphics.push()
    love.graphics.translate(state.x, state.y)
    love.graphics.rotate(state.angle)

    -- Ensure the player owns a concrete ship layout before drawing so that we
    -- always render the same instance that the physics body and collisions use.
    if not state.ship then
        shipModule.buildLayoutForState(state)
    end

    -- Main body: draw the owned ship layout using the shared ship renderer so
    -- the player visuals stay consistent with enemies and other ship users.
    if state.ship then
        ship_renderer.drawPlayer(state.ship, colors)
    end

    love.graphics.pop()
end

return draw
