--------------------------------------------------------------------------------
-- RENDER SYSTEM (ECS)
-- Handles drawing entities with visual components
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local ship_renderer = require("src.render.ship_renderer")
local baseColors = require("src.core.colors")

--------------------------------------------------------------------------------
-- SHIP RENDER SYSTEM
--------------------------------------------------------------------------------

local ShipRenderSystem = Concord.system({
    ships = { "position", "rotation", "shipVisual" },
})

function ShipRenderSystem:draw(colors)
    colors = colors or baseColors

    for i = 1, self.ships.size do
        local e = self.ships[i]
        local px = e.position.x
        local py = e.position.y
        local angle = e.rotation.angle
        local ship = e.shipVisual.ship

        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(angle)

        -- Determine color based on faction
        if e.faction and e.faction.name == "enemy" then
            ship_renderer.drawEnemy(ship, colors)
        else
            ship_renderer.draw(ship, colors)
        end

        love.graphics.pop()
    end
end

--------------------------------------------------------------------------------
-- HEALTH BAR RENDER SYSTEM
--------------------------------------------------------------------------------

local HealthBarSystem = Concord.system({
    damaged = { "position", "health", "collisionRadius" },
})

function HealthBarSystem:draw(colors)
    colors = colors or baseColors

    for i = 1, self.damaged.size do
        local e = self.damaged[i]
        local health = e.health

        -- Only show if damaged
        if health.current < health.max then
            local radius = e.collisionRadius.radius
            local barWidth = radius * 0.9
            local barHeight = 3
            local barX = e.position.x - barWidth
            local barY = e.position.y - radius - 10

            -- Background
            love.graphics.setColor(colors.healthBg)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2, barHeight)

            -- Health bar
            local ratio = math.max(0, math.min(1, health.current / health.max))
            love.graphics.setColor(colors.health)
            love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, barHeight)
        end
    end
end

--------------------------------------------------------------------------------
-- PROJECTILE RENDER SYSTEM
--------------------------------------------------------------------------------

local ProjectileRenderSystem = Concord.system({
    projectiles = { "projectile", "position", "rotation" },
})

function ProjectileRenderSystem:draw(colors)
    colors = colors or baseColors

    for i = 1, self.projectiles.size do
        local e = self.projectiles[i]
        local px = e.position.x
        local py = e.position.y
        local angle = e.rotation and e.rotation.angle or 0

        local config = e.projectileVisual and e.projectileVisual.config or {}
        local length = config.length or 20
        local width = config.width or 2
        local color = config.color or colors.projectile

        local tailX = px - math.cos(angle) * length
        local tailY = py - math.sin(angle) * length

        -- Outer glow
        love.graphics.setColor(color[1], color[2], color[3], 0.3)
        love.graphics.setLineWidth(width + 2)
        love.graphics.line(px, py, tailX, tailY)

        -- Core beam
        love.graphics.setColor(color)
        love.graphics.setLineWidth(width)
        love.graphics.line(px, py, tailX, tailY)
    end

    love.graphics.setLineWidth(1)
end

return {
    ShipRenderSystem = ShipRenderSystem,
    HealthBarSystem = HealthBarSystem,
    ProjectileRenderSystem = ProjectileRenderSystem,
}
