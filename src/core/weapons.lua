local weapons = {}

weapons.pulseLaser = require("src.data.weapons.pulse_laser")

local enemyPulseLaser = {}
for k, v in pairs(weapons.pulseLaser) do
    enemyPulseLaser[k] = v
end
enemyPulseLaser.damage = 1
weapons.enemyPulseLaser = enemyPulseLaser

return weapons
