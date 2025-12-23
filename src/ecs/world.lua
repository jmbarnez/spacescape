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
local playerProgression = require("src.ecs.systems.player_progression")
local reward = require("src.ecs.systems.reward")
local ai = require("src.ecs.systems.ai")
local projectileSpawner = require("src.ecs.systems.projectile_spawner")
local physicsStep = require("src.ecs.systems.physics_step")
local box2dCollisionProcessor = require("src.ecs.systems.box2d_collision_processor")
local respawner = require("src.ecs.systems.respawner")
local playerControl = require("src.ecs.systems.player_control")
local worldBounds = require("src.ecs.systems.world_bounds")
local asteroidBehavior = require("src.ecs.systems.asteroid_behavior")
local itemPickups = require("src.ecs.systems.item_pickups")
local projectileBounds = require("src.ecs.systems.projectile_bounds")
local miningProgression = require("src.ecs.systems.mining_progression")
local lifetime = require("src.ecs.systems.lifetime")
local asteroidSurfaceDamage = require("src.ecs.systems.asteroid_surface_damage")

-- Load assemblages
local assemblages = require("src.ecs.assemblages")

local world = Concord.world()

--------------------------------------------------------------------------------
-- SYSTEM REGISTRATION
--------------------------------------------------------------------------------

world:addSystems(
-- Movement and physics
    playerControl,
    asteroidBehavior,
    lifetime,
    physicsStep,
    movement.RotationSystem,
    movement.MovementSystem,
    worldBounds,
    movement.ProjectileSystem,

    -- Item and projectile lifecycle
    itemPickups,
    projectileBounds,

    -- AI and behavior
    ai.AISystem,
    ai.FiringSystem,

    -- Combat
    projectileSpawner,
    -- Process Box2D beginContact queue after the physics step.
    box2dCollisionProcessor,
    collision.CollisionSystem,
    playerProgression,
    miningProgression,
    asteroidSurfaceDamage,
    reward,
    respawner, -- Added respawner system
    collision.CleanupSystem,

    -- Rendering (order matters - drawn back to front)
    render.AsteroidRenderSystem,
    render.DebrisRenderSystem,
    render.WreckRenderSystem,
    render.ShipRenderSystem,
    render.HealthBarSystem,
    render.ItemRenderSystem,
    render.ProjectileRenderSystem
)

--------------------------------------------------------------------------------
-- ENTITY CREATION HELPERS
--------------------------------------------------------------------------------

-- spawnEnemy(x, y, spec)
--
-- spec is intentionally flexible so call sites can be explicit without
-- constantly reworking legacy code:
--   - { def = enemyDef }   -- pass a fully-loaded enemy definition table
--   - { id = "scout" }     -- select by enemy definition id
--   - { size = 20 }        -- force a size override (keeps random enemy type)
--
-- Backward compatible legacy forms:
--   - number -> size override
--   - string -> enemy id
--   - table  -> treated as a spec (or raw enemy def table)
function world:spawnEnemy(x, y, spec)
    return Concord.entity(self):assemble(assemblages.enemy, x, y, spec)
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
