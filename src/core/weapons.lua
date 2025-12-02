local weapons = {}

weapons.playerPulseLaser = {
    name = "Pulse Laser",
    fireInterval = 0.3,
    projectileSpeed = 600,
    damage = 20,
    hitMax = 0.95,
    hitMin = 0.6,
    optimalRange = 450,
    maxRange = 900
}

weapons.enemyPulseLaser = {
    name = "Enemy Pulse Laser",
    fireInterval = 1.4,
    projectileSpeed = 440,
    damage = 10,
    hitMax = 0.75,
    hitMin = 0.35,
    optimalRange = 350,
    maxRange = 700
}

return weapons
