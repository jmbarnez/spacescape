local colors = {
    ship = { 0.0, 1.0, 1.0 },
    projectile = { 1.0, 0.2, 0.8 },
    enemy = { 1.0, 0.1, 0.4 },
    enemyOutline = { 1.0, 0.4, 0.6 },
    health = { 0.0, 1.0, 0.8 },
    healthBg = { 0.15, 0.05, 0.2 },
    movementIndicator = { 0.0, 1.0, 0.8, 0.5 },
    star = { 1.0, 1.0, 1.0 },
    targetRing = { 1.0, 0.0, 0.5, 0.9 },
    targetRingLocking = { 1.0, 0.8, 0.0, 0.9 },
    targetRingLocked = { 1.0, 0.1, 0.3, 0.95 },

    white = { 1.0, 1.0, 1.0, 1.0 },

    -- UI colors (synthwave theme)
    uiPanelBorder = { 0.8, 0.8, 0.8, 0.7 },
    uiText = { 1.0, 1.0, 1.0, 1.0 },
    uiFps = { 1.0, 0.8, 0.0, 0.7 },
    uiInstruction = { 1.0, 1.0, 1.0, 0.6 },
    uiAbilitySlotBg = { 0.05, 0.05, 0.05, 0.8 },
    uiAbilityActive = { 0.0, 1.0, 1.0, 1.0 },
    uiAbilityInactive = { 0.6, 0.3, 0.8, 0.5 },
    uiCooldownBg = { 0.05, 0.05, 0.05, 0.7 },
    uiCooldownText = { 1.0, 1.0, 1.0, 1.0 },
    uiGameOverBg = { 0.0, 0.0, 0.0, 0.85 },
    uiGameOverText = { 1.0, 1.0, 1.0, 1.0 },
    uiGameOverSubText = { 1.0, 1.0, 1.0, 1.0 },

    -- Background / environment (deep purple synthwave)
    backgroundSpace = { 0.03, 0.0, 0.08, 1.0 },

    -- FX colors
    velocityVector = { 0.0, 1.0, 1.0, 0.4 },
    explosion = { 1.0, 0.4, 0.8 },
    particleImpact = { 1.0, 0.6, 0.9 },
    particleSpark = { 1.0, 0.9, 0.4 },
    engineTrailA = { 0.0, 1.0, 1.0 },
    engineTrailB = { 1.0, 0.2, 0.8 },
    enemyEngineTrailA = { 1.0, 0.2, 0.5 },
    enemyEngineTrailB = { 0.8, 0.0, 0.4 },
    -- Cyan outline color used when hovering entities with the mouse cursor
    hoverOutline = { 0.0, 1.0, 1.0, 0.95 },

    -- Damage / combat feedback
    damageEnemy = { 1.0, 0.8, 0.0 },
    damagePlayer = { 1.0, 0.2, 0.5 },
    shieldDamage = { 0.0, 1.0, 1.0 },
    missBg = { 0.5, 0.2, 0.8 },
    asteroidSpark = { 1.0, 0.6, 0.8 },

    -- Asteroid UI
    asteroidHealthBg = { 0.15, 0.05, 0.2, 0.9 },
    asteroidHealth = { 1.0, 0.8, 0.0, 1.0 },

    -- Floating text defaults
    floatingBg = { 1.0, 0.2, 0.8 },
    floatingText = { 1.0, 1.0, 1.0 },

    -- Item / pickup visuals (XP shards, resources, etc.)
    itemCore = { 1.0, 0.2, 0.8, 1.0 },
    itemGlow = { 0.5, 0.1, 0.6, 0.45 },
}

return colors
