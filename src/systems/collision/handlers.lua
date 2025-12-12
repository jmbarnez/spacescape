--------------------------------------------------------------------------------
-- COLLISION HANDLERS
-- Entity-vs-entity collision resolution logic
--------------------------------------------------------------------------------

local baseColors = require("src.core.colors")
local config = require("src.core.config")
local explosionFx = require("src.entities.explosion_fx")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local playerModule = require("src.entities.player")
local utils = require("src.systems.collision.utils")
local damageModule = require("src.systems.collision.damage")

local handlers = {}

--------------------------------------------------------------------------------
-- COLOR CONSTANTS
--------------------------------------------------------------------------------
local DAMAGE_COLOR_ENEMY = baseColors.damageEnemy   -- Yellow-ish for damage to enemies
local DAMAGE_COLOR_PLAYER = baseColors.damagePlayer -- Red-ish for damage to player
local MISS_BG_COLOR = baseColors.missBg             -- Blue background for miss text

--------------------------------------------------------------------------------
-- GENERIC PROJECTILE HIT RESOLVER
--------------------------------------------------------------------------------

--- Generic helper for handling a projectile hitting a target
--- This centralizes miss logic, particles, damage, and death effects.
--- @param projectile table The projectile entity
--- @param target table The target entity (enemy, player, asteroid)
--- @param contactX number|nil Optional contact X from Box2D
--- @param contactY number|nil Optional contact Y from Box2D
--- @param radius number|nil Optional precomputed target radius
--- @param cfg table Behavior config:
---   canMiss: boolean (if true, rollHitChance is used)
---   missOptions: table (options for miss floating text)
---   damageTextColor: table (RGB for damage text)
---   impactColor: table (RGB for impact particles)
---   impactCount: integer (particle count, default 6)
---   onKill: function(target, radius, damage) called if target dies
---   explosionOnHit: boolean (if true, spawn a small explosion at impact)
--- @param context table Runtime context { bullets, currentColors, currentDamagePerHit }
function handlers.resolveProjectileHit(projectile, target, contactX, contactY, radius, cfg, context)
    if not projectile or not target then
        return
    end

    cfg = cfg or {}
    radius = radius or utils.getBoundingRadius(target)
    local currentColors = context.currentColors
    local currentDamagePerHit = context.currentDamagePerHit
    local bullets = context.bullets

    -- Derive contact point if not provided
    local projX, projY = utils.getX(projectile), utils.getY(projectile)
    local targX, targY = utils.getX(target), utils.getY(target)
    if (not contactX or not contactY) and projX and projY and targX and targY then
        contactX, contactY = utils.getContactPoint(
            projX, projY,
            targX, targY,
            radius
        )
    end

    -- Handle miss logic (for shots that can miss)
    if cfg.canMiss and not utils.rollHitChance(projectile) then
        damageModule.spawnProjectileShards(projectile, target, contactX, contactY, radius, 0.6, currentColors)

        if context.currentParticles then
            local impactColor = cfg.impactColor
            if not impactColor then
                local projectileConfig = nil
                if projectile.projectileVisual and projectile.projectileVisual.config then
                    projectileConfig = projectile.projectileVisual.config
                elseif projectile.projectileData and projectile.projectileData.weapon and projectile.projectileData.weapon.projectile then
                    projectileConfig = projectile.projectileData.weapon.projectile
                else
                    if projectile.weapon then
                        local weaponData = projectile.weapon
                        if type(weaponData) == "table" and weaponData.data then
                            weaponData = weaponData.data
                        end
                        if weaponData and weaponData.projectile then
                            projectileConfig = weaponData.projectile
                        end
                    end
                end

                if projectileConfig and projectileConfig.color then
                    impactColor = projectileConfig.color
                elseif currentColors and currentColors.projectile then
                    impactColor = currentColors.projectile
                else
                    impactColor = baseColors.projectile or baseColors.white
                end
            end

            local impactCount = cfg.impactCount or 10
            local ix = contactX or targX or projX
            local iy = contactY or targY or projY
            if ix and iy then
                local nx, ny = 0, 0

                local pvx = utils.getVX(projectile)
                local pvy = utils.getVY(projectile)
                local vLen = math.sqrt(pvx * pvx + pvy * pvy)
                if vLen and vLen > 0 then
                    nx = -pvx / vLen
                    ny = -pvy / vLen
                elseif targX and targY then
                    local dx = ix - targX
                    local dy = iy - targY
                    local dLen = math.sqrt(dx * dx + dy * dy)
                    if dLen and dLen > 0 then
                        nx = dx / dLen
                        ny = dy / dLen
                    end
                end

                local spawnX, spawnY = ix, iy
                if nx ~= 0 or ny ~= 0 then
                    local outward = math.min((radius or 0) * 0.2, 10)
                    spawnX = ix + nx * outward
                    spawnY = iy + ny * outward
                end

                context.currentParticles.impact(spawnX, spawnY, impactColor, impactCount, nx, ny)
            end
        end

        if target and utils.getShield(target) > 0 then
            damageModule.spawnShieldImpactVisual(target, projectile, contactX, contactY, radius)
        end

        utils.removeEntity(bullets, projectile)
        return
    end

    damageModule.spawnProjectileShards(projectile, target, contactX, contactY, radius, 1.0, currentColors)

    if context.currentParticles then
        local impactColor = cfg.impactColor
        if not impactColor then
            local projectileConfig = nil
            if projectile.projectileVisual and projectile.projectileVisual.config then
                projectileConfig = projectile.projectileVisual.config
            elseif projectile.projectileData and projectile.projectileData.weapon and projectile.projectileData.weapon.projectile then
                projectileConfig = projectile.projectileData.weapon.projectile
            else
                if projectile.weapon then
                    local weaponData = projectile.weapon
                    if type(weaponData) == "table" and weaponData.data then
                        weaponData = weaponData.data
                    end
                    if weaponData and weaponData.projectile then
                        projectileConfig = weaponData.projectile
                    end
                end
            end

            if projectileConfig and projectileConfig.color then
                impactColor = projectileConfig.color
            elseif currentColors and currentColors.projectile then
                impactColor = currentColors.projectile
            else
                impactColor = baseColors.projectile or baseColors.white
            end
        end

        local impactCount = cfg.impactCount or 10
        local ix = contactX or targX or projX
        local iy = contactY or targY or projY
        if ix and iy then
            local nx, ny = 0, 0

            local pvx = utils.getVX(projectile)
            local pvy = utils.getVY(projectile)
            local vLen = math.sqrt(pvx * pvx + pvy * pvy)
            if vLen and vLen > 0 then
                nx = -pvx / vLen
                ny = -pvy / vLen
            elseif targX and targY then
                local dx = ix - targX
                local dy = iy - targY
                local dLen = math.sqrt(dx * dx + dy * dy)
                if dLen and dLen > 0 then
                    nx = dx / dLen
                    ny = dy / dLen
                end
            end

            local spawnX, spawnY = ix, iy
            if nx ~= 0 or ny ~= 0 then
                local outward = math.min((radius or 0) * 0.2, 10)
                spawnX = ix + nx * outward
                spawnY = iy + ny * outward
            end

            context.currentParticles.impact(spawnX, spawnY, impactColor, impactCount, nx, ny)
        end
    end

    -- Apply damage and spawn floating numbers for shield vs hull
    local damageAmt = utils.getDamage(projectile) or currentDamagePerHit

    local died, shieldDamage, hullDamage = damageModule.applyDamage(target, damageAmt)

    -- Shield damage (bright blue)
    if shieldDamage and shieldDamage > 0 then
        local shieldColor = baseColors.shieldDamage
        damageModule.spawnDamageText(shieldDamage, targX, targY, radius, shieldColor, nil)
        damageModule.spawnShieldImpactVisual(target, projectile, contactX, contactY, radius)
    end

    -- Hull damage (use configured damage text color)
    if hullDamage and hullDamage > 0 then
        local hullColor = cfg.damageTextColor or DAMAGE_COLOR_ENEMY
        damageModule.spawnDamageText(hullDamage, targX, targY, radius, hullColor, nil)
    end

    -- Remove the projectile on any resolved hit
    utils.removeEntity(bullets, projectile)

    -- Death handling
    if died and cfg.onKill then
        cfg.onKill(target, radius, damageAmt)
    end
end

--------------------------------------------------------------------------------
-- PLAYER PROJECTILE VS ENEMY
--------------------------------------------------------------------------------

--- Handle player projectile hitting an enemy
--- @param projectile table The projectile entity
--- @param enemy table The enemy entity
--- @param contactX number Contact point X (optional)
--- @param contactY number Contact point Y (optional)
--- @param context table Runtime context
function handlers.handlePlayerProjectileVsEnemy(projectile, enemy, contactX, contactY, context)
    -- Skip if projectile is targeting a different enemy
    if projectile.target and projectile.target ~= enemy then
        return
    end

    local enemyRadius = utils.getBoundingRadius(enemy)

    handlers.resolveProjectileHit(projectile, enemy, contactX, contactY, enemyRadius, {
        canMiss = true,
        missOptions = { bgColor = MISS_BG_COLOR },
        -- Use red for hull damage numbers (matches player hull color)
        damageTextColor = DAMAGE_COLOR_PLAYER,
        impactColor = context.currentColors and context.currentColors.projectile or nil,
        impactCount = 10,
        onKill = function(target, radius)
            local tx, ty = utils.getX(target), utils.getY(target)
            explosionFx.spawn(tx, ty, context.currentColors.enemy, radius * 1.4)
            utils.cleanupProjectilesForTarget(context.bullets, target)
            utils.removeEntity(context.enemies, target)
            local owner = projectile.owner or (projectile.projectileData and projectile.projectileData.owner)
            local ownerFaction = owner and utils.getFaction(owner) or "player"
            if ownerFaction ~= "enemy" then
                local xp = config.player.xpPerEnemy or 0
                local tokens = config.player.tokensPerEnemy or 0
                damageModule.awardXpAndTokensOnKill(xp, tokens)
                -- Spawn cargo wreck for looting
                damageModule.spawnEnemyWreck(tx, ty, target, radius)
            end
        end,
    }, context)
end

--------------------------------------------------------------------------------
-- ENEMY PROJECTILE VS PLAYER
--------------------------------------------------------------------------------

--- Handle enemy projectile hitting the player
--- @param projectile table The projectile entity
--- @param player table The player entity
--- @param contactX number Contact point X (optional)
--- @param contactY number Contact point Y (optional)
--- @param context table Runtime context
function handlers.handleEnemyProjectileVsPlayer(projectile, player, contactX, contactY, context)
    -- Prefer the computed bounding/collision radius over player.size.
    --
    -- player.size is the base ship size, but the actual collision silhouette
    -- (and therefore the shield ring size) is derived from the built ship
    -- geometry. Using the bounding radius keeps enemy hits visually consistent
    -- with player projectile impacts.
    local playerRadius = utils.getBoundingRadius(player) or player.size

    handlers.resolveProjectileHit(projectile, player, contactX, contactY, playerRadius, {
        canMiss = false,
        missOptions = { bgColor = MISS_BG_COLOR },
        damageTextColor = DAMAGE_COLOR_PLAYER,
        impactColor = context.currentColors and context.currentColors.projectile or nil,
        impactCount = 10,
        onKill = function(target, radius)
            local tx, ty = utils.getX(target), utils.getY(target)
            explosionFx.spawn(tx, ty, context.currentColors.ship, radius * 2.2)
            context.playerDiedThisFrame = true
        end,
    }, context)
end

--------------------------------------------------------------------------------
-- PROJECTILE VS ASTEROID
--------------------------------------------------------------------------------

--- Handle any projectile hitting an asteroid
--- @param projectile table The projectile entity
--- @param asteroid table The asteroid entity
--- @param contactX number Contact point X (optional)
--- @param contactY number Contact point Y (optional)
--- @param context table Runtime context
function handlers.handleProjectileVsAsteroid(projectile, asteroid, contactX, contactY, context)
    local asteroidRadius = utils.getBoundingRadius(asteroid)
    local asteroidColor = (asteroid.data and asteroid.data.color) or
        (context.currentColors and context.currentColors.enemy) or
        baseColors.enemy

    -- Asteroids always get hit (no miss chance)
    handlers.resolveProjectileHit(projectile, asteroid, contactX, contactY, asteroidRadius, {
        canMiss = false,
        damageTextColor = DAMAGE_COLOR_ENEMY,
        -- Use projectile color for impact particles, asteroid color only for big death explosions
        impactColor = context.currentColors and context.currentColors.projectile or nil,
        impactCount = 14,
        onKill = function(target, radius)
            local tx, ty = utils.getX(target), utils.getY(target)
            if context.currentParticles then
                context.currentParticles.explosion(tx, ty, asteroidColor)
            end
            utils.cleanupProjectilesForTarget(context.bullets, target)
            utils.removeEntity(context.asteroids, target)
            local owner = projectile.owner or (projectile.projectileData and projectile.projectileData.owner)
            local ownerFaction = owner and utils.getFaction(owner) or "player"
            if ownerFaction ~= "enemy" then
                local xp = config.player.xpPerAsteroid or 0
                -- Asteroids should not award tokens/currency; only XP + item/resources.
                damageModule.awardXpAndTokensOnKill(xp, 0)
                local resources = damageModule.computeAsteroidResourceYield(target, radius)
                damageModule.spawnResourceChunksAt(tx, ty, resources)
            end
        end,
    }, context)
end

--------------------------------------------------------------------------------
-- PLAYER VS ENEMY (RAM)
--------------------------------------------------------------------------------

--- Handle player colliding with an enemy (ram damage)
--- @param player table The player entity
--- @param enemy table The enemy entity
--- @param contactX number|nil Contact point X (optional)
--- @param contactY number|nil Contact point Y (optional)
--- @param context table Runtime context
function handlers.handlePlayerVsEnemy(player, enemy, contactX, contactY, context)
    local enemyRadius = utils.getBoundingRadius(enemy)
    local ex, ey = utils.getX(enemy), utils.getY(enemy)
    local px, py = utils.getX(player), utils.getY(player)
    local playerSize = utils.getSize(player)

    -- Destroy the enemy on contact
    explosionFx.spawn(ex, ey, context.currentColors.enemy, enemyRadius * 1.4)
    utils.cleanupProjectilesForTarget(context.bullets, enemy)
    utils.removeEntity(context.enemies, enemy)
    local xp = config.player.xpPerEnemy or 0
    local tokens = config.player.tokensPerEnemy or 0
    damageModule.awardXpAndTokensOnKill(xp, tokens)
    -- Spawn cargo wreck for looting
    damageModule.spawnEnemyWreck(ex, ey, enemy, enemyRadius)

    -- Damage the player; shields absorb before hull
    local damageAmt = context.currentDamagePerHit
    local died, shieldDamage, hullDamage = damageModule.applyDamage(player, damageAmt)

    -- Shield damage text (bright blue)
    if shieldDamage and shieldDamage > 0 then
        local shieldColor = baseColors.shieldDamage
        damageModule.spawnDamageText(shieldDamage, px, py, playerSize, shieldColor, nil)
    end

    if shieldDamage and shieldDamage > 0 and shieldImpactFx and shieldImpactFx.spawn then
        local ix = contactX or ex or px
        local iy = contactY or ey or py
        local radius = utils.getBoundingRadius(player)
        if radius and radius > 0 and px and py and ix and iy then
            ------------------------------------------------------------------
            -- Attach the FX to the player state so the ring visually follows
            -- the ship if it continues to move after the ram impact.
            ------------------------------------------------------------------
            shieldImpactFx.spawn(px, py, ix, iy, radius * 1.15,
                baseColors.shieldDamage,
                player)
        end
    end

    -- Hull damage text (red for player)
    if hullDamage and hullDamage > 0 then
        damageModule.spawnDamageText(hullDamage, player.x, player.y, player.size, DAMAGE_COLOR_PLAYER, nil)
    end

    if died then
        explosionFx.spawn(player.x, player.y, context.currentColors.ship, player.size * 2.2)
        context.playerDiedThisFrame = true
    end
end

--------------------------------------------------------------------------------
-- SHIP VS ASTEROID
--------------------------------------------------------------------------------

--- Resolve a generic ship colliding with an asteroid (push ship away, no damage)
--- @param ship table The ship entity (player or enemy)
--- @param asteroid table The asteroid entity
--- @param contactX number|nil Contact point X from Box2D (optional)
--- @param contactY number|nil Contact point Y from Box2D (optional)
--- @param context table Runtime context
function handlers.resolveShipVsAsteroid(ship, asteroid, contactX, contactY, context)
    if not ship or not asteroid then
        return
    end

    local shipX, shipY = utils.getX(ship), utils.getY(ship)
    local astX, astY = utils.getX(asteroid), utils.getY(asteroid)

    local dx = shipX - astX
    local dy = shipY - astY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance <= 0 then
        return
    end

    local shipRadius
    local asteroidRadius

    if contactX and contactY then
        local sx = contactX - shipX
        local sy = contactY - shipY
        shipRadius = math.sqrt(sx * sx + sy * sy)

        local ax = contactX - astX
        local ay = contactY - astY
        asteroidRadius = math.sqrt(ax * ax + ay * ay)
    else
        shipRadius = utils.getBoundingRadius(ship)
        asteroidRadius = utils.getBoundingRadius(asteroid)
    end

    if not shipRadius or not asteroidRadius or shipRadius <= 0 or asteroidRadius <= 0 then
        return
    end

    local minDistance = shipRadius + asteroidRadius

    -- Push ship away from asteroid
    if distance < minDistance then
        local overlap = minDistance - distance
        local invDist = 1.0 / distance

        ------------------------------------------------------------------
        -- Positional resolve: push the ship out of the asteroid
        ------------------------------------------------------------------
        local newX = shipX + dx * invDist * overlap
        local newY = shipY + dy * invDist * overlap

        -- Update ECS position component
        if ship.position then
            ship.position.x = newX
            ship.position.y = newY
        else
            ship.x = newX
            ship.y = newY
        end

        -- Sync physics body position
        local body = utils.getBody(ship)
        if body then
            body:setPosition(newX, newY)
        end

        ------------------------------------------------------------------
        -- Visual sparks at the contact point
        ------------------------------------------------------------------
        local sparkX, sparkY = contactX, contactY
        if not sparkX or not sparkY then
            sparkX = astX + dx * invDist * asteroidRadius
            sparkY = astY + dy * invDist * asteroidRadius
        end

        if sparkX and sparkY and context.currentParticles then
            context.currentParticles.spark(sparkX, sparkY, baseColors.asteroidSpark, 2)
        end

        ------------------------------------------------------------------
        -- Shield impact FX + bounce for the player ship when shields are up.
        -- Enemies keep their existing sliding behavior so they do not jitter
        -- around asteroids as aggressively.
        ------------------------------------------------------------------
        if ship == playerModule.state and ship.shield and ship.shield > 0 then
            if shieldImpactFx and shieldImpactFx.spawn then
                local sx = ship.x
                local sy = ship.y
                local ix = sparkX
                local iy = sparkY
                local shieldRadius = utils.getBoundingRadius(ship)

                if shieldRadius and shieldRadius > 0 and sx and sy and ix and iy then
                    ------------------------------------------------------------------
                    -- Attach the asteroid bump FX to the player ship so the
                    -- ring remains centered on the hull while the short
                    -- bounce animation plays out.
                    ------------------------------------------------------------------
                    shieldImpactFx.spawn(sx, sy, ix, iy, shieldRadius * 1.15,
                        baseColors.shieldDamage,
                        ship)
                end
            end

            -- Reflect the player's velocity around the contact normal so that
            -- the ship "bounces" off the asteroid surface while losing a bit
            -- of speed according to the configured bounceFactor.
            local vx = ship.vx or 0
            local vy = ship.vy or 0
            local speedSq = vx * vx + vy * vy
            if speedSq > 0 then
                local nx = dx * invDist
                local ny = dy * invDist
                local dot = vx * nx + vy * ny

                -- Only reflect if we are actually moving into the surface.
                if dot < 0 then
                    local bounce = config.player.bounceFactor or 0.5
                    local rvx = vx - 2 * dot * nx
                    local rvy = vy - 2 * dot * ny
                    ship.vx = rvx * bounce
                    ship.vy = rvy * bounce
                end
            end
        end
    end
end

--- Handle player colliding with an asteroid (Box2D event wrapper)
--- @param player table The player entity
--- @param asteroid table The asteroid entity
--- @param contactX number|nil Contact point X (optional)
--- @param contactY number|nil Contact point Y (optional)
--- @param context table Runtime context
function handlers.handlePlayerVsAsteroid(player, asteroid, contactX, contactY, context)
    handlers.resolveShipVsAsteroid(player, asteroid, contactX, contactY, context)
end

--- Handle enemy colliding with an asteroid
--- @param enemy table The enemy entity
--- @param asteroid table The asteroid entity
--- @param contactX number|nil Contact point X (optional)
--- @param contactY number|nil Contact point Y (optional)
--- @param context table Runtime context
function handlers.handleEnemyVsAsteroid(enemy, asteroid, contactX, contactY, context)
    handlers.resolveShipVsAsteroid(enemy, asteroid, contactX, contactY, context)
end

return handlers
