-- Player module
-- Main entry point that ties together all player submodules

local player = {}

local physics = require("src.core.physics")
local weapons = require("src.core.weapons")
local config = require("src.core.config")
local worldRef = require("src.ecs.world_ref")

-- Load submodules
local cargo = require("src.entities.player.cargo")
local movement = require("src.entities.player.movement")
local shipModule = require("src.entities.player.ship")
local drawModule = require("src.entities.player.draw")

-- Player state: the central state table shared across all submodules
player.state = {
    x = 0,
    y = 0,
    -- Velocity components for zero-g physics
    vx = 0,
    vy = 0,
    -- Target position (where player clicked)
    targetX = 0,
    targetY = 0,
    -- Physics properties (movement for the player "pilot" driving a ship)
    thrust = physics.constants.shipThrust,
    maxSpeed = physics.constants.shipMaxSpeed,
    size = config.player.size, -- Base visual / spawn size used when building the ship
    angle = 0,
    targetAngle = 0,
    approachAngle = nil,
    health = config.player.maxHealth,
    maxHealth = config.player.maxHealth,
    shield = config.player.maxShield or 0,
    maxShield = config.player.maxShield or 0,
    -- Ship ownership: blueprint describes the chassis, ship is the concrete
    -- scaled layout instance used for rendering and collisions.
    shipBlueprint = shipModule.getDefaultBlueprint(), -- Current ship blueprint table the player is piloting
    ship = nil,                                       -- core.ship layout instance (built from shipBlueprint)
    -- Simple cargo component for storing mined / salvaged resources on the
    -- currently piloted ship. This is now backed by a fixed-size slot array so
    -- the HUD can render a 4x4 inventory grid that supports drag-and-drop and
    -- future per-slot behaviors.
    cargo = {
        maxSlots = 16,
        slots = {},
    },
    -- Magnet component: these radii are used by the item system to attract
    -- nearby pickups (XP shards, resources) toward the ship and decide when
    -- they are actually collected.
    magnetRadius = config.player.magnetRadius,
    magnetPickupRadius = config.player.magnetPickupRadius,
    isThrusting = false,
    body = nil,
    shapes = nil,            -- Table of shapes (polygon body may have multiple)
    fixtures = nil,          -- Table of fixtures
    collisionVertices = nil, -- Stored collision vertices (flat array) for physics
    collisionRadius = nil,   -- Cached radius derived from ship / collision vertices
    weapon = weapons.pulseLaser,
    -- Loot interaction state
    lootTarget = nil,  -- Reference to the wreck we're flying towards
    isLooting = false, -- Whether loot panel is open
}

--------------------------------------------------------------------------------
-- PUBLIC API: Wrappers around submodule functions that pass player.state
--------------------------------------------------------------------------------

--- Add a quantity of a specific resource type to the player's cargo.
-- @param resourceType string Resource identifier (e.g. "stone", "ice", "mithril")
-- @param amount number Amount to add (ignored if nil or <= 0)
-- @return number The amount that was actually added (for feedback)
function player.addCargoResource(resourceType, amount)
    return cargo.addResource(player.state, resourceType, amount)
end

--- Add experience points to the player, handling level-ups.
-- @param amount number XP to add
-- @return boolean True if the player leveled up
function player.addExperience(amount)
    if not amount or amount <= 0 then
        return false
    end

    local ecsWorld = worldRef.get()
    if not (ecsWorld and ecsWorld.emit) then
        return false
    end

    local e = worldRef.getPlayerProgressEntity and worldRef.getPlayerProgressEntity() or nil
    local prevLevel = (e and e.experience and e.experience.level) or 1
    ecsWorld:emit("awardXp", amount)

    local e2 = worldRef.getPlayerProgressEntity and worldRef.getPlayerProgressEntity() or nil
    local newLevel = (e2 and e2.experience and e2.experience.level) or prevLevel
    return newLevel > prevLevel
end

--- Add currency to the player.
-- @param amount number Amount to add
-- @return number The amount that was actually added
function player.addCurrency(amount)
    if not amount or amount <= 0 then
        return 0
    end

    local ecsWorld = worldRef.get()
    if not (ecsWorld and ecsWorld.emit) then
        return 0
    end

    ecsWorld:emit("awardTokens", amount)
    return amount
end

--- Reset all progression state to initial values.
function player.resetExperience()
    local ecsWorld = worldRef.get()
    if ecsWorld and ecsWorld.emit then
        ecsWorld:emit("resetPlayerProgress")
    end
end

--- Center the player in the window.
function player.centerInWindow()
    local p = player.state
    p.x = love.graphics.getWidth() / 2
    p.y = love.graphics.getHeight() / 2
    p.targetX = p.x
    p.targetY = p.y
end

--- Reset the player to initial state.
function player.reset()
    local p = player.state
    player.centerInWindow()
    player.resetExperience()
    p.health = p.maxHealth
    p.shield = p.maxShield
    -- Reset velocity for zero-g
    p.vx = 0
    p.vy = 0
    p.isThrusting = false
    p.angle = 0
    p.targetAngle = 0
    p.approachAngle = nil
    shipModule.createBody(p)
    p.weapon = weapons.pulseLaser
end

--- Change the player's ship blueprint at runtime.
-- @param blueprint table|nil Ship blueprint table. If nil, falls back to default.
function player.setShipBlueprint(blueprint)
    shipModule.setBlueprint(player.state, blueprint)
end

--- Update player each frame.
-- @param dt number Delta time
-- @param world table|nil World bounds table
function player.update(dt, world)
    movement.update(player.state, dt, world)
end

--- Set the player's movement target position.
-- @param x number Target X position
-- @param y number Target Y position
function player.setTarget(x, y)
    movement.setTarget(player.state, x, y)
    -- Clear loot target when player clicks somewhere else
    player.state.lootTarget = nil
    player.state.isLooting = false
end

--- Set a wreck as the loot target (player will fly to it)
--- @param wreck table The wreck entity to loot
function player.setLootTarget(wreck)
    if not wreck then return end
    local p = player.state
    p.lootTarget = wreck
    p.isLooting = false
    -- Set movement target to the wreck position (ECS position component)
    local wx = wreck.position and wreck.position.x or wreck.x
    local wy = wreck.position and wreck.position.y or wreck.y
    if wx and wy then
        movement.setTarget(p, wx, wy)
    end
end

--- Clear the current loot target
function player.clearLootTarget()
    local p = player.state
    p.lootTarget = nil
    p.isLooting = false
end

--- Get the current loot target
--- @return table|nil The loot target wreck
function player.getLootTarget()
    return player.state.lootTarget
end

--- Check if player is currently looting
--- @return boolean True if loot panel should be open
function player.isPlayerLooting()
    return player.state.isLooting
end

--- Set looting state
--- @param isLooting boolean Whether the player is looting
function player.setLooting(isLooting)
    player.state.isLooting = isLooting
end

--- Draw the player ship.
-- @param colors table Color palette to use
function player.draw(colors)
    drawModule.draw(player.state, colors, shipModule)
end

-- Expose renderDrone for preview use (e.g., skin selection)
player.renderDrone = drawModule.renderDrone

return player
