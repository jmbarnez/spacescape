local weapon = {
    name = "Enemy Pulse Laser",
    fireInterval = 1.4,
    projectileSpeed = 440,
    damage = 10,
    hitMax = 0.75,
    hitMin = 0.35,
    optimalRange = 350,
    maxRange = 700,
    projectile = {
        style = "beam",
        length = 18,
        width = 2,
        outerGlowAlpha = 0.25,
        tipLength = 2,
        color = {1.0, 0.4, 0.4}
    }
}

return weapon
