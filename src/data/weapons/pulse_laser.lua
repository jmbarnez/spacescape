local weapon = {
    name = "Pulse Laser",
    fireInterval = 1.2,           -- Slightly slower fire rate for deliberate combat
    projectileSpeed = 350,        -- Slower projectiles for space feel
    damage = 5,
    hitMax = 0.95,
    hitMin = 0.6,
    optimalRange = 300,           -- Slightly reduced optimal range
    maxRange = 500,
    projectile = {
        style = "beam",
        length = 12,              -- Longer beam trail
        width = 2,
        outerGlowAlpha = 0.4,
        tipLength = 4,
        color = {0.3, 0.7, 1.0}
    }
}

return weapon
