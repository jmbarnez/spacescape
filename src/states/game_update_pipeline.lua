local systems = require("src.core.systems")
local ecsWorld = require("src.ecs.world")
local camera = require("src.core.camera")

local engineTrail = require("src.entities.engine_trail")
local starfield = require("src.render.starfield")
local projectileShards = require("src.entities.projectile_shards")
local particlesModule = require("src.entities.particles")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local floatingText = require("src.entities.floating_text")

local spawnSystem = require("src.systems.spawn")
local asteroidSectorSpawner = require("src.systems.asteroid_sector_spawner")
local combatSystem = require("src.systems.combat")
local abilitiesSystem = require("src.systems.abilities")

local gameQueries = require("src.states.game_queries")

local game_update_pipeline = {}

function game_update_pipeline.register()
	systems.clear()

	systems.registerUpdate("input", function(dt, ctx)
		ctx.inputSystem.update(dt, ctx.player, ctx.world, ctx.camera)
	end, 10)

	-- Update kinematic transforms BEFORE stepping Box2D so beginContact events
	-- are generated in the same frame (instead of one frame late).
	-- Update kinematic transforms BEFORE stepping Box2D so beginContact events
	-- are generated in the same frame (instead of one frame late).
	-- [DELETED] Legacy playerModule.update (Moved to PlayerControlSystem)


	-- ECS pre-physics: update AI/movement and sync ECS kinematic bodies into Box2D.
	systems.registerUpdate("asteroidSectors", function(dt, ctx)
		asteroidSectorSpawner.update(dt, ctx)
	end, 20)


	-- Asteroids still run through their legacy update loop, but are ECS-backed.
	-- They must update BEFORE physics so their bodies are in the correct place
	-- when Box2D evaluates contacts.
	-- Asteroids still run through their legacy update loop, but are ECS-backed.
	-- They must update BEFORE physics so their bodies are in the correct place
	-- when Box2D evaluates contacts.
	-- [DELETED] Legacy asteroidModule.update (Moved to ECS Systems)


	-- Wrecks have sensor bodies; keep their transforms in sync before physics.
	-- Wrecks have sensor bodies; keep their transforms in sync before physics.
	-- [DELETED] Legacy wreckModule.update (Moved to ECS Systems)



	systems.registerUpdate("physics", function(dt, ctx)
		if ecsWorld and ecsWorld.emit then
			ecsWorld:emit("stepPhysics", dt, ctx.player, ctx.world)
		end
	end, 40)


	systems.registerUpdate("engineTrail", function(dt, ctx)
		engineTrail.update(dt, ctx.player, gameQueries.getEnemyEntities())
	end, 40)

	systems.registerUpdate("camera", function(dt, ctx)
		camera.update(dt, ctx.player)
	end, 50)

	systems.registerUpdate("starfield", function(dt, ctx)
		starfield.update(dt, ctx.camera.x, ctx.camera.y)
	end, 60)

	systems.registerUpdate("projectiles", function(dt, ctx)
		-- Projectile lifetime/offscreen cleanup is handled by ECS systems.
	end, 80)

	systems.registerUpdate("projectileShards", function(dt, ctx)
		projectileShards.update(dt)
	end, 85)

	systems.registerUpdate("particles", function(dt, ctx)
		particlesModule.update(dt)
	end, 100)

	systems.registerUpdate("shieldImpactFx", function(dt, ctx)
		shieldImpactFx.update(dt)
	end, 105)

	systems.registerUpdate("floatingText", function(dt, ctx)
		floatingText.update(dt)
	end, 110)

	systems.registerUpdate("abilities", function(dt, ctx)
		abilitiesSystem.update(dt, ctx.player, ctx.world, ctx.camera)
	end, 120)

	systems.registerUpdate("spawn", function(dt, ctx)
		spawnSystem.update(dt)
	end, 130)

	systems.registerUpdate("combat", function(dt, ctx)
		combatSystem.updateAutoShoot(dt, ctx.player)
	end, 140)

	-- Items / pickups are updated after ships so that magnets use the latest
	-- player position, but before particles so they remain part of the core
	-- world simulation rather than just an effect layer.
	systems.registerUpdate("items", function(dt, ctx)
		-- Item magnet + pickup resolution is handled by ECS systems.
	end, 95)

	-- NOTE: wrecks are updated in the pre-physics phase now.
end

return game_update_pipeline
