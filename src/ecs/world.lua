--------------------------------------------------------------------------------
-- ECS WORLD
-- Central world instance and system registration
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

-- Load all components first (registers them with Concord)
require("src.ecs.components")

-- Load systems
local collision = require("src.ecs.systems.collision")
local movement = require("src.ecs.systems.movement")
local render = require("src.ecs.systems.render")
local reward = require("src.ecs.systems.reward")
local ai = require("src.ecs.systems.ai")
local projectileSpawner = require("src.ecs.systems.projectile_spawner")

-- Load assemblages
local assemblages = require("src.ecs.assemblages")

local world = Concord.world()

--------------------------------------------------------------------------------
-- SYSTEM REGISTRATION
--------------------------------------------------------------------------------

world:addSystems(
-- Movement and physics
    movement.MovementSystem,
    movement.RotationSystem,
    movement.ProjectileSystem,

    -- AI and behavior
    ai.AISystem,
    ai.FiringSystem,

    -- Combat
    projectileSpawner,
    collision.CollisionSystem,
    reward,
    collision.CleanupSystem,

    -- Rendering (order matters - drawn back to front)
    render.ShipRenderSystem,
    render.HealthBarSystem,
    render.ProjectileRenderSystem
)

--------------------------------------------------------------------------------
-- ENTITY CREATION HELPERS
--------------------------------------------------------------------------------

function world:spawnEnemy(x, y, size)
    return Concord.entity(self):assemble(assemblages.enemy, x, y, size)
end

function world:spawnProjectile(shooter, targetX, targetY, targetEntity)
    return Concord.entity(self):assemble(assemblages.projectile, shooter, targetX, targetY, targetEntity)
end

function world:spawnAsteroid(x, y, data, size)
    return Concord.entity(self):assemble(assemblages.asteroid, x, y, data, size)
end

function world:spawnPlayer(x, y, shipData)
    return Concord.entity(self):assemble(assemblages.player, x, y, shipData)
end

function world:spawnWreck(x, y, cargo, coins)
    return Concord.entity(self):assemble(assemblages.wreck, x, y, cargo, coins)
end

function world:spawnItem(x, y, resourceType, amount)
    return Concord.entity(self):assemble(assemblages.item, x, y, resourceType, amount)
end

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--- Clear all entities from the world
function world:clearAll()
    self:clear()
end

--- Get the player entity
function world:getPlayer()
    local players = self:query({ "playerControlled" })
    return players and players[1] or nil
end

return world
