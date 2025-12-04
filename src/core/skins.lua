local skins = {}

skins.list = {
    {
        id = "ion_blue",
        name = "Ion Blue",
        colors = {
            ship = {0.2, 0.6, 1.0},
            shipOutline = {0.4, 0.8, 1.0},
            projectile = {0.3, 0.7, 1.0},
            enemy = {1.0, 0.3, 0.3},
            enemyOutline = {1.0, 0.5, 0.5},
            health = {0.3, 1.0, 0.3},
            healthBg = {0.3, 0.3, 0.3},
            movementIndicator = {0.3, 1.0, 0.3, 0.5},
            star = {1.0, 1.0, 1.0},
            targetRing = {1.0, 0.0, 0.0, 0.9},
            targetRingLocking = {1.0, 1.0, 0.0, 0.9},
            targetRingLocked = {0.9, 0.1, 0.1, 0.95}
        }
    },
    {
        id = "ember_orange",
        name = "Ember Orange",
        colors = {
            ship = {1.0, 0.55, 0.15},
            shipOutline = {1.0, 0.8, 0.4},
            projectile = {1.0, 0.9, 0.6},
            enemy = {0.95, 0.25, 0.25},
            enemyOutline = {1.0, 0.45, 0.45},
            health = {0.45, 1.0, 0.45},
            healthBg = {0.25, 0.2, 0.2},
            movementIndicator = {1.0, 0.8, 0.3, 0.55},
            star = {1.0, 0.95, 0.85},
            targetRing = {1.0, 0.7, 0.2, 0.95},
            targetRingLocking = {1.0, 0.9, 0.4, 0.95},
            targetRingLocked = {1.0, 0.4, 0.1, 0.98}
        }
    },
    {
        id = "void_violet",
        name = "Void Violet",
        colors = {
            ship = {0.6, 0.3, 1.0},
            shipOutline = {0.9, 0.7, 1.0},
            projectile = {0.8, 0.6, 1.0},
            enemy = {1.0, 0.35, 0.7},
            enemyOutline = {1.0, 0.6, 0.9},
            health = {0.5, 1.0, 0.8},
            healthBg = {0.25, 0.2, 0.3},
            movementIndicator = {0.7, 0.9, 1.0, 0.55},
            star = {0.95, 0.95, 1.0},
            targetRing = {0.9, 0.3, 1.0, 0.95},
            targetRingLocking = {0.8, 0.8, 1.0, 0.95},
            targetRingLocked = {0.6, 0.2, 1.0, 0.98}
        }
    }
}

skins.byId = {}
for _, skin in ipairs(skins.list) do
    skins.byId[skin.id] = skin
end

skins.currentId = skins.list[1].id

function skins.getList()
    return skins.list
end

function skins.setCurrent(id)
    if skins.byId[id] then
        skins.currentId = id
    end
end

function skins.getCurrent()
    return skins.byId[skins.currentId] or skins.list[1]
end

return skins
