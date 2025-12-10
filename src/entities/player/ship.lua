-- Player ship module
-- Handles ship blueprint management and physics body creation

local ship = {}

local physics = require("src.core.physics")
local config = require("src.core.config")
local core_ship = require("src.core.ship")
local player_drone = require("src.data.ships.player_drone")

--- Generate the collision polygon for the player drone.
-- Matches the visual shape from renderDrone(), using the same shared
-- core.ship layout so physics and visuals stay perfectly aligned.
-- @param size number The player size
-- @return table Flat vertex array for collision shape
local function generateDroneCollisionVertices(size)
    -- Build the same world-space layout used by rendering. If a dedicated
    -- collision hull is provided in the blueprint, core.ship will project
    -- that to world space; otherwise it falls back to the main hull.
    local layout = core_ship.buildInstanceFromBlueprint(player_drone, size)
    if not layout or not layout.collisionVertices or #layout.collisionVertices < 6 then
        return {}
    end

    return layout.collisionVertices
end

--- Build and cache the concrete ship layout owned by the player.
-- This keeps ship-specific geometry (hull, wings, collision vertices, radius)
-- on the ship object itself, while the player state handles input, movement
-- and progression (health, xp, abilities).
-- @param state table The player state table
function ship.buildLayoutForState(state)
    -- Use the configured player size as the base scale for the ship layout.
    local size = state.size or config.player.size

    -- Resolve which blueprint to use for this player. By default we fall back
    -- to the authored player_drone data, but higher-level systems can assign
    -- a different blueprint (e.g., for ship selection or unlocks).
    local blueprint = state.shipBlueprint or player_drone

    -- Build a concrete ship instance from the chosen blueprint.
    local layout = core_ship.buildInstanceFromBlueprint(blueprint, size)
    state.ship = layout

    -- Cache collision vertices and a representative collision radius so that
    -- physics and gameplay systems do not need to know about the blueprint.
    if layout and layout.collisionVertices and #layout.collisionVertices >= 6 then
        state.collisionVertices = layout.collisionVertices
    else
        -- Fallback: regenerate from the blueprint helper if something is
        -- missing on the layout (keeps physics and visuals in sync).
        state.collisionVertices = generateDroneCollisionVertices(size)
    end

    -- Prefer the ship's own bounding radius; otherwise, compute one from the
    -- flat vertex array or fall back to the configured player size.
    if layout and layout.boundingRadius then
        state.collisionRadius = layout.boundingRadius
    elseif state.collisionVertices and #state.collisionVertices >= 6 then
        state.collisionRadius = physics.computeBoundingRadius(state.collisionVertices)
    else
        state.collisionRadius = state.size or config.player.size
    end
end

--- Create the player's physics body with proper collision filtering.
-- @param state table The player state table
function ship.createBody(state)
    -- Clean up existing body if present so we never leak Box2D objects.
    if state.body then
        state.body:destroy()
        state.body = nil
        state.shapes = nil
        state.fixtures = nil
    end

    -- Ensure the player owns a concrete ship layout and collision data before
    -- creating the physics body. This keeps all geometry on the ship object.
    ship.buildLayoutForState(state)

    local verts = state.collisionVertices

    -- Prefer a polygon body that matches the ship silhouette.
    if verts and #verts >= 6 then
        state.body, state.shapes, state.fixtures = physics.createPolygonBody(
            state.x, state.y,
            verts,
            "PLAYER",
            state, -- Pass player state as the entity reference
            {}     -- No special options; empty table keeps lints happy
        )
    else
        -- Fallback: create a simple circle body using the cached collision
        -- radius (or player size) so gameplay still works even if data fails.
        local radius = state.collisionRadius or state.size or config.player.size
        local body, shape, fixture = physics.createCircleBody(
            state.x, state.y,
            radius,
            "PLAYER",
            state,
            {} -- No special options; empty table keeps lints happy
        )
        state.body = body
        state.shapes = shape and { shape } or nil
        state.fixtures = fixture and { fixture } or nil
    end
end

--- Change the player's ship blueprint at runtime.
--
-- This helper lets higher-level systems (menus, unlocks, debug tools) swap
-- which ship the player is currently piloting without needing to know the
-- details of ship layouts or physics. It rebuilds the ship layout and the
-- physics body in-place while preserving position, velocity, and XP.
--
-- @param state table The player state table
-- @param blueprint table|nil Ship blueprint table (e.g. require("src.data.ships.some_ship")).
--        If nil, the function falls back to the default player_drone blueprint.
function ship.setBlueprint(state, blueprint)
    -- Accept nil to mean "reset to default" so callers can easily revert.
    if blueprint == nil then
        state.shipBlueprint = player_drone
    else
        state.shipBlueprint = blueprint
    end

    -- Rebuild the ship layout + physics body now so everything (collision
    -- radius, hull shape, etc.) immediately matches the newly selected ship.
    ship.createBody(state)
end

--- Get the default ship blueprint.
-- @return table The player_drone blueprint
function ship.getDefaultBlueprint()
    return player_drone
end

return ship
