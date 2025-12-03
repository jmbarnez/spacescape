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

local function handleBulletEnemyCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)
    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        if bullet.faction ~= "enemy" then
            for ei = #enemies, 1, -1 do
                local enemy = enemies[ei]
                if not (bullet.target and bullet.willHit and enemy ~= bullet.target) then
                    local distance = checkDistance(bullet.x, bullet.y, enemy.x, enemy.y)
                    local enemyRadius = enemy.collisionRadius or enemy.size or 0

                    if distance < enemyRadius then
                        if bullet.willHit == false then
                            local textY = enemy.y - enemyRadius - 10
                            floatingText.spawn("0", enemy.x, textY, nil, { bgColor = MISS_BG_COLOR })
                            if bullet.body then
                                bullet.body:destroy()
                            end
                            table.remove(bullets, bi)
                            break
                        end

                        particlesModule.explosion(bullet.x, bullet.y, colors.projectile)

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
                            player.score = player.score + scorePerKill
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
        if bullet.faction ~= "enemy" then
            for ai = #asteroids, 1, -1 do
                local asteroid = asteroids[ai]

                if not (bullet.target and bullet.willHit and asteroid ~= bullet.target) then
                    local distance = checkDistance(bullet.x, bullet.y, asteroid.x, asteroid.y)
                    local asteroidRadius = asteroid.collisionRadius or asteroid.size or 0

                    if distance < asteroidRadius then
                        if bullet.willHit == false then
                            local textY = asteroid.y - asteroidRadius - 10
                            floatingText.spawn("0", asteroid.x, textY, nil, { bgColor = MISS_BG_COLOR })
                            if bullet.body then
                                bullet.body:destroy()
                            end
                            table.remove(bullets, bi)
                            break
                        end

                        particlesModule.explosion(bullet.x, bullet.y, colors.projectile)

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
                            particlesModule.explosion(asteroid.x, asteroid.y, colors.enemy)
                            cleanupBulletsForTarget(asteroid)
                            table.remove(asteroids, ai)
                            player.score = player.score + scorePerKill
                        end

                        break
                    end
                end
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
                if bullet.willHit == false then
                    local textY = player.y - player.size - 10
                    floatingText.spawn("0", player.x, textY, nil, { bgColor = MISS_BG_COLOR })
                    if bullet.body then
                        bullet.body:destroy()
                    end
                    table.remove(bullets, bi)
                else
                    particlesModule.explosion(bullet.x, bullet.y, colors.projectile)

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
        local distance = checkDistance(player.x, player.y, asteroid.x, asteroid.y)
        local asteroidRadius = asteroid.collisionRadius or asteroid.size or 0

        if distance < player.size + asteroidRadius then
            particlesModule.explosion(asteroid.x, asteroid.y, colors.enemy)
            table.remove(asteroids, i)
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

function collision.update(player, particlesModule, colors, scorePerKill, damagePerHit)
    handleBulletEnemyCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)
    handleBulletAsteroidCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)

    local playerDiedEnemies = handlePlayerEnemyCollisions(player, particlesModule, colors, damagePerHit)
    local playerDiedAsteroids = handlePlayerAsteroidCollisions(player, particlesModule, colors, damagePerHit)

    local playerDiedEnemyBullets = handleEnemyBulletPlayerCollisions(player, particlesModule, colors, damagePerHit)

    return playerDiedEnemies or playerDiedAsteroids or playerDiedEnemyBullets
end

return collision
