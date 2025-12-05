local enemyModule = require("src.entities.enemy")
local projectileModule = require("src.entities.projectile")
local asteroidModule = require("src.entities.asteroid")
local explosionFx = require("src.entities.explosion_fx")
local floatingText = require("src.entities.floating_text")

local collision = {}

local enemies = enemyModule.list
local bullets = projectileModule.list
local asteroids = asteroidModule.list

local DAMAGE_COLOR_ENEMY = {1.0, 0.9, 0.4}
local DAMAGE_COLOR_PLAYER = {1.0, 0.4, 0.4}
local MISS_BG_COLOR = {0.3, 0.6, 1.0}

local function checkDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local function cleanupBulletsForTarget(target)
    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        if bullet.target == target then
            if bullet.body then
                bullet.body:destroy()
            end
            table.remove(bullets, bi)
        end
    end
end

local function handleBulletEnemyCollisions(player, particlesModule, colors, damagePerHit)
    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        if bullet.faction ~= "enemy" then
            for ei = #enemies, 1, -1 do
                local enemy = enemies[ei]
                if not (bullet.target and enemy ~= bullet.target) then
                    local distance = checkDistance(bullet.x, bullet.y, enemy.x, enemy.y)
                    local enemyRadius = enemy.collisionRadius or enemy.size or 0

                    if distance < enemyRadius then
                        local contactX, contactY = bullet.x, bullet.y
                        if distance > 0 then
                            local invDist = 1.0 / distance
                            contactX = enemy.x + (bullet.x - enemy.x) * invDist * enemyRadius
                            contactY = enemy.y + (bullet.y - enemy.y) * invDist * enemyRadius
                        end

                        local weapon = bullet.weapon or (bullet.owner and bullet.owner.weapon) or {}
                        local traveled = bullet.distanceTraveled or 0
                        local hitChance = projectileModule.calculateHitChance(weapon, traveled)
                        if math.random() > hitChance then
                            local textY = enemy.y - enemyRadius - 10
                            floatingText.spawn("0", enemy.x, textY, nil, { bgColor = MISS_BG_COLOR })
                            if bullet.body then
                                bullet.body:destroy()
                            end
                            table.remove(bullets, bi)
                            break
                        end

                        particlesModule.impact(contactX, contactY, colors.projectile, 6)

                        local damage = bullet.damage or damagePerHit
                        enemy.health = (enemy.health or 0) - damage
                        local amount = math.floor(damage + 0.5)
                        local textY = enemy.y - enemyRadius - 10
                        floatingText.spawn(tostring(amount), enemy.x, textY, DAMAGE_COLOR_ENEMY)
                        if bullet.body then
                            bullet.body:destroy()
                        end
                        table.remove(bullets, bi)

                        if enemy.health <= 0 then
                            local enemyRadius = enemy.collisionRadius or enemy.size or 20
                            explosionFx.spawn(enemy.x, enemy.y, colors.enemy, enemyRadius * 1.4)
                            if enemy.body then
                                enemy.body:destroy()
                            end
                            cleanupBulletsForTarget(enemy)
                            table.remove(enemies, ei)
                        end

                        break
                    end
                end
            end
        end
    end
end

local function handlePlayerEnemyCollisions(player, particlesModule, colors, damagePerHit)
    local playerDied = false

    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        local distance = checkDistance(player.x, player.y, enemy.x, enemy.y)
        local enemyRadius = enemy.collisionRadius or enemy.size or 0

        if distance < player.size + enemyRadius then
            explosionFx.spawn(enemy.x, enemy.y, colors.enemy, enemyRadius * 1.4)
            if enemy.body then
                enemy.body:destroy()
            end
            cleanupBulletsForTarget(enemy)
            table.remove(enemies, i)
            player.health = player.health - damagePerHit
            local amount = math.floor(damagePerHit + 0.5)
            local textY = player.y - player.size - 10
            floatingText.spawn(tostring(amount), player.x, textY, DAMAGE_COLOR_PLAYER)

            if player.health <= 0 then
                explosionFx.spawn(player.x, player.y, colors.ship, player.size * 2.2)
                playerDied = true
            end
        end
    end

    return playerDied
end

local function handleBulletAsteroidCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)
    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        for ai = #asteroids, 1, -1 do
            local asteroid = asteroids[ai]

            local distance = checkDistance(bullet.x, bullet.y, asteroid.x, asteroid.y)
            local asteroidRadius = asteroid.collisionRadius or asteroid.size or 0

            if distance < asteroidRadius then
                -- Any physical hit on an asteroid consumes the bullet and damages the rock,
                -- regardless of its owner / willHit RNG.
                local asteroidColor = (asteroid.data and asteroid.data.color) or colors.projectile
                particlesModule.impact(bullet.x, bullet.y, asteroidColor, 6)

                local damage = bullet.damage or damagePerHit
                asteroid.health = (asteroid.health or 0) - damage
                local amount = math.floor(damage + 0.5)
                local textY = asteroid.y - asteroidRadius - 10
                floatingText.spawn(tostring(amount), asteroid.x, textY, DAMAGE_COLOR_ENEMY)

                if bullet.body then
                    bullet.body:destroy()
                end
                table.remove(bullets, bi)

                if asteroid.health <= 0 then
                    local deathRadius = asteroid.collisionRadius or asteroid.size or 20
                    particlesModule.explosion(asteroid.x, asteroid.y, asteroidColor)
                    cleanupBulletsForTarget(asteroid)
                    table.remove(asteroids, ai)

                    -- Only award score when the player (non-enemy faction) destroys the asteroid.
                    if bullet.faction ~= "enemy" then
                        player.score = player.score + scorePerKill
                    end
                end

                break
            end
        end
    end
end

local function handleEnemyBulletPlayerCollisions(player, particlesModule, colors, damagePerHit)
    local playerDied = false

    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        if bullet.faction == "enemy" then
            local distance = checkDistance(bullet.x, bullet.y, player.x, player.y)

            if distance < player.size then
                local weapon = bullet.weapon or (bullet.owner and bullet.owner.weapon) or {}
                local traveled = bullet.distanceTraveled or 0
                local hitChance = projectileModule.calculateHitChance(weapon, traveled)
                if math.random() > hitChance then
                    local textY = player.y - player.size - 10
                    floatingText.spawn("0", player.x, textY, nil, { bgColor = MISS_BG_COLOR })
                    if bullet.body then
                        bullet.body:destroy()
                    end
                    table.remove(bullets, bi)
                else
                    particlesModule.impact(bullet.x, bullet.y, colors.projectile, 6)

                    local damage = bullet.damage or damagePerHit
                    player.health = player.health - damage
                    local amount = math.floor(damage + 0.5)
                    local textY = player.y - player.size - 10
                    floatingText.spawn(tostring(amount), player.x, textY, DAMAGE_COLOR_PLAYER)
                    if bullet.body then
                        bullet.body:destroy()
                    end
                    table.remove(bullets, bi)

                    if player.health <= 0 then
                        explosionFx.spawn(player.x, player.y, colors.ship, player.size * 2.2)
                        playerDied = true
                    end
                end
            end
        end
    end

    return playerDied
end

local function handlePlayerAsteroidCollisions(player, particlesModule, colors, damagePerHit)
    local playerDied = false

    for i = #asteroids, 1, -1 do
        local asteroid = asteroids[i]
        local dx = player.x - asteroid.x
        local dy = player.y - asteroid.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local asteroidRadius = asteroid.collisionRadius or asteroid.size or 0
        local minDistance = player.size + asteroidRadius

        if distance < minDistance and distance > 0 then
            local overlap = minDistance - distance
            local invDist = 1.0 / distance
            player.x = player.x + dx * invDist * overlap
            player.y = player.y + dy * invDist * overlap

            if player.body then
                player.body:setPosition(player.x, player.y)
            end

            -- Subtle spark effect instead of a large explosion
            local contactX = asteroid.x + dx * invDist * asteroidRadius
            local contactY = asteroid.y + dy * invDist * asteroidRadius
            particlesModule.spark(contactX, contactY, {0.9, 0.85, 0.7}, 4)
        end
    end

    return playerDied
end

function collision.update(player, particlesModule, colors, scorePerKill, damagePerHit)
    handleBulletEnemyCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)
    handleBulletAsteroidCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)

    local playerDiedEnemies = handlePlayerEnemyCollisions(player, particlesModule, colors, damagePerHit)
    local playerDiedAsteroids = handlePlayerAsteroidCollisions(player, particlesModule, colors, damagePerHit)

    local playerDiedEnemyBullets = handleEnemyBulletPlayerCollisions(player, particlesModule, colors, damagePerHit)

    return playerDiedEnemies or playerDiedAsteroids or playerDiedEnemyBullets
end

return collision
