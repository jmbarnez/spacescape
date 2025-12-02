local enemyModule = require("src.entities.enemy")
local projectileModule = require("src.entities.projectile")
local asteroidModule = require("src.entities.asteroid")

local collision = {}

local enemies = enemyModule.list
local bullets = projectileModule.list
local asteroids = asteroidModule.list

local function checkDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local function handleBulletEnemyCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)
    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        if bullet.faction ~= "enemy" then
            for ei = #enemies, 1, -1 do
                local enemy = enemies[ei]
                local distance = checkDistance(bullet.x, bullet.y, enemy.x, enemy.y)
                local enemyRadius = enemy.collisionRadius or enemy.size or 0

                if distance < enemyRadius then
                    particlesModule.explosion(bullet.x, bullet.y, colors.projectile)

                    local damage = bullet.damage or damagePerHit
                    enemy.health = (enemy.health or 0) - damage
                    if bullet.body then
                        bullet.body:destroy()
                    end
                    table.remove(bullets, bi)

                    if enemy.health <= 0 then
                        particlesModule.explosion(enemy.x, enemy.y, colors.enemy)
                        if enemy.body then
                            enemy.body:destroy()
                        end
                        table.remove(enemies, ei)
                        player.score = player.score + scorePerKill
                    end

                    break
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
            particlesModule.explosion(enemy.x, enemy.y, colors.enemy)
            if enemy.body then
                enemy.body:destroy()
            end
            table.remove(enemies, i)
            player.health = player.health - damagePerHit

            if player.health <= 0 then
                particlesModule.explosion(player.x, player.y, colors.ship)
                playerDied = true
            end
        end
    end

    return playerDied
end

local function handleBulletAsteroidCollisions(player, particlesModule, colors, scorePerKill)
    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        if bullet.faction ~= "enemy" then
            for ai = #asteroids, 1, -1 do
                local asteroid = asteroids[ai]
                local distance = checkDistance(bullet.x, bullet.y, asteroid.x, asteroid.y)
                local asteroidRadius = asteroid.collisionRadius or asteroid.size or 0

                if distance < asteroidRadius then
                    particlesModule.explosion(bullet.x, bullet.y, colors.projectile)

                    if bullet.body then
                        bullet.body:destroy()
                    end
                    table.remove(bullets, bi)

                    particlesModule.explosion(asteroid.x, asteroid.y, colors.enemy)
                    table.remove(asteroids, ai)
                    player.score = player.score + scorePerKill

                    break
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
                particlesModule.explosion(bullet.x, bullet.y, colors.projectile)

                local damage = bullet.damage or damagePerHit
                player.health = player.health - damage
                if bullet.body then
                    bullet.body:destroy()
                end
                table.remove(bullets, bi)

                if player.health <= 0 then
                    particlesModule.explosion(player.x, player.y, colors.ship)
                    playerDied = true
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

            if player.health <= 0 then
                particlesModule.explosion(player.x, player.y, colors.ship)
                playerDied = true
            end
        end
    end

    return playerDied
end

function collision.update(player, particlesModule, colors, scorePerKill, damagePerHit)
    handleBulletEnemyCollisions(player, particlesModule, colors, scorePerKill, damagePerHit)
    handleBulletAsteroidCollisions(player, particlesModule, colors, scorePerKill)

    local playerDiedEnemies = handlePlayerEnemyCollisions(player, particlesModule, colors, damagePerHit)
    local playerDiedAsteroids = handlePlayerAsteroidCollisions(player, particlesModule, colors, damagePerHit)

    local playerDiedEnemyBullets = handleEnemyBulletPlayerCollisions(player, particlesModule, colors, damagePerHit)

    return playerDiedEnemies or playerDiedAsteroids or playerDiedEnemyBullets
end

return collision
