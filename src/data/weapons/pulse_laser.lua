local weapon = {
    name = "Pulse Laser",
    fireInterval = 1,
    projectileSpeed = 1000,
    damage = 5,
    hitMax = 0.95,
    hitMin = 0.6,
    optimalRange = 350,
    maxRange = 550,
    projectile = {
        style = "beam",
        length = 22,
        width = 2,
        outerGlowAlpha = 0.3,
        tipLength = 3,
        color = {0.3, 0.7, 1.0}
    }
}

return weapon
