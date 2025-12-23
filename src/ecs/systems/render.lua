--------------------------------------------------------------------------------
-- RENDER SYSTEM (ECS)
-- Handles drawing entities with visual components
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local ship_renderer = require("src.render.ship_renderer")
local icon_renderer = require("src.render.icon_renderer")
local baseColors = require("src.core.colors")
local asteroid_generator = require("src.utils.procedural_asteroid_generator")

local DEFAULT_WRECK_LIFETIME = 180
local ASTEROID_HEALTH_BAR_HEIGHT = 4
local ASTEROID_HEALTH_BAR_OFFSET_Y = 18

--------------------------------------------------------------------------------
-- SHIP RENDER SYSTEM
--------------------------------------------------------------------------------

local ShipRenderSystem = Concord.system({
    ships = { "position", "rotation", "shipVisual" },
})

ShipRenderSystem["render.draw"] = function(self, colors)
    self:draw(colors)
end

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
            ship_renderer.drawPlayer(ship, colors)
        end
        love.graphics.pop()
    end
end

--------------------------------------------------------------------------------
-- ASTEROID RENDER SYSTEM
--------------------------------------------------------------------------------

local AsteroidRenderSystem = Concord.system({
    asteroids = { "asteroid", "position", "rotation", "asteroidVisual", "health", "collisionRadius" },
})

AsteroidRenderSystem["render.draw"] = function(self, colors)
    self:draw(colors)
end

local function drawAsteroidHealthBar(colors, px, py, radius, healthCurrent, healthMax)
    if not (healthMax and healthMax > 0 and healthCurrent and healthCurrent >= 0) then
        return
    end

    if healthCurrent >= healthMax then
        return
    end

    local barWidth = radius * 0.9
    local barX = px - barWidth
    local barY = py - radius - ASTEROID_HEALTH_BAR_OFFSET_Y

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth * 2 + 2, ASTEROID_HEALTH_BAR_HEIGHT + 2)

    love.graphics.setColor(colors.asteroidHealthBg)
    love.graphics.rectangle("fill", barX, barY, barWidth * 2, ASTEROID_HEALTH_BAR_HEIGHT)

    local ratio = math.max(0, math.min(1, healthCurrent / healthMax))
    love.graphics.setColor(colors.asteroidHealth)
    love.graphics.rectangle("fill", barX, barY, barWidth * 2 * ratio, ASTEROID_HEALTH_BAR_HEIGHT)
end

function AsteroidRenderSystem:draw(colors)
    colors = colors or baseColors

    for i = 1, self.asteroids.size do
        local a = self.asteroids[i]

        local px = a.position.x
        local py = a.position.y
        local angle = a.rotation and a.rotation.angle or 0
        local data = (a.asteroidVisual and a.asteroidVisual.data) or a.data

        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(angle)
        if data then
            asteroid_generator.draw(data)
        end

        local surface = a.asteroidSurfaceDamage
        if surface and surface.marks then
            local marks = surface.marks
            for j = 1, #marks do
                local m = marks[j]
                local duration = tonumber(m.duration) or 0
                local age = tonumber(m.age) or 0

                local alpha = 0.0
                if duration > 0 then
                    alpha = 1.0 - math.max(0, math.min(1, age / duration))
                else
                    alpha = 0.85
                end

                local r = tonumber(m.r) or 4
                local mx = tonumber(m.x) or 0
                local my = tonumber(m.y) or 0

                love.graphics.setColor(0, 0, 0, 0.35 * alpha)
                love.graphics.circle("fill", mx, my, r)
            end
        end
        love.graphics.pop()

        local health = a.health
        if health and health.current and health.max then
            local radius = (a.collisionRadius and a.collisionRadius.radius) or 20
            drawAsteroidHealthBar(colors, px, py, radius, health.current, health.max)
        end
    end
end

--------------------------------------------------------------------------------
-- WRECK RENDER SYSTEM
--------------------------------------------------------------------------------

local WreckRenderSystem = Concord.system({
    wrecks = { "wreck", "position", "rotation" },
})

WreckRenderSystem["render.draw"] = function(self, colors)
    self:draw(colors)
end

function WreckRenderSystem:draw(colors)
    colors = colors or baseColors

    for i = 1, self.wrecks.size do
        local w = self.wrecks[i]

        local wx = w.position and w.position.x or w.x
        local wy = w.position and w.position.y or w.y
        if wx and wy then
            local angle = (w.rotation and w.rotation.angle) or w.angle or 0

            local size = 24
            if w.size then
                size = type(w.size) == "table" and w.size.value or w.size
            end

            local lifetimeTotal = w.lifetimeTotal or DEFAULT_WRECK_LIFETIME
            local age = w.age or 0
            if w.lifetime and w.lifetime.remaining and lifetimeTotal > 0 then
                age = lifetimeTotal - w.lifetime.remaining
                if age < 0 then
                    age = 0
                end
            end

            love.graphics.push()
            love.graphics.translate(wx, wy)
            love.graphics.rotate(angle)

            local fadeStart = lifetimeTotal * 0.8
            local alpha = 1.0
            if age > fadeStart and lifetimeTotal > fadeStart then
                alpha = 1.0 - ((age - fadeStart) / (lifetimeTotal - fadeStart))
            end

            local halfSize = size / 2

            love.graphics.setColor(0.45, 0.35, 0.25, alpha * 0.9)
            love.graphics.rectangle("fill", -halfSize, -halfSize, size, size, 3, 3)

            love.graphics.setColor(0.55, 0.45, 0.35, alpha * 0.8)
            local inset = 4
            love.graphics.rectangle("fill", -halfSize + inset, -halfSize + inset,
                size - inset * 2, size - inset * 2, 2, 2)

            love.graphics.setColor(0.35, 0.28, 0.18, alpha * 0.7)
            love.graphics.setLineWidth(2)
            love.graphics.line(-halfSize + 2, 0, halfSize - 2, 0)
            love.graphics.line(0, -halfSize + 2, 0, halfSize - 2)

            love.graphics.setColor(0.65, 0.55, 0.40, alpha * 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", -halfSize, -halfSize, size, size, 3, 3)

            love.graphics.pop()
        end
    end
end

--------------------------------------------------------------------------------
-- HEALTH BAR RENDER SYSTEM
--------------------------------------------------------------------------------

local HealthBarSystem = Concord.system({
    damaged = { "ship", "position", "health", "collisionRadius" },
})

HealthBarSystem["render.draw"] = function(self, colors)
    self:draw(colors)
end

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
-- ITEM RENDER SYSTEM
--------------------------------------------------------------------------------

local ItemRenderSystem = Concord.system({
    items = { "item", "position", "collisionRadius", "resourceYield" },
})

ItemRenderSystem["render.draw"] = function(self, colors)
    self:draw(colors)
end

local function getFirstResourceType(e)
    if not (e and e.resourceYield and e.resourceYield.resources) then
        return nil
    end

    for resourceType, amount in pairs(e.resourceYield.resources) do
        if (tonumber(amount) or 0) > 0 then
            return tostring(resourceType)
        end
    end

    return nil
end

function ItemRenderSystem:draw(colors)
    for i = 1, self.items.size do
        local e = self.items[i]
        local px = e.position.x
        local py = e.position.y

        local baseRadius = (e.collisionRadius and e.collisionRadius.radius) or 6

        local age = e.age or 0
        local pulse = (math.sin(age * 3.2) + 1) * 0.5

        local resourceType = getFirstResourceType(e)
        if resourceType then
            icon_renderer.draw(resourceType, {
                x = px,
                y = py,
                size = baseRadius,
                context = "inspace",
                age = age,
                pulse = pulse,
            })
        else
            icon_renderer.drawUnknown(px, py, baseRadius)
        end
    end
end

--------------------------------------------------------------------------------
-- PROJECTILE RENDER SYSTEM
--------------------------------------------------------------------------------

local ProjectileRenderSystem = Concord.system({
    projectiles = { "projectile", "position", "rotation" },
})

ProjectileRenderSystem["render.draw"] = function(self, colors)
    self:draw(colors)
end

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

--------------------------------------------------------------------------------
-- DEBRIS RENDER SYSTEM
--------------------------------------------------------------------------------

local DebrisRenderSystem = Concord.system({
    debris = { "debris", "position", "rotation", "debrisVisual" },
})

DebrisRenderSystem["render.draw"] = function(self, colors)
    self:draw(colors)
end

function DebrisRenderSystem:draw(colors)
    for i = 1, self.debris.size do
        local e = self.debris[i]
        local px = e.position.x
        local py = e.position.y
        local angle = (e.rotation and e.rotation.angle) or 0

        local lifetimeTotal = e.lifetimeTotal or 0
        local alpha = 1.0
        if lifetimeTotal > 0 and e.lifetime and e.lifetime.remaining then
            local age = lifetimeTotal - e.lifetime.remaining
            if age < 0 then age = 0 end
            local fadeStart = lifetimeTotal * 0.65
            if age > fadeStart and lifetimeTotal > fadeStart then
                alpha = 1.0 - ((age - fadeStart) / (lifetimeTotal - fadeStart))
            end
        end

        local dv = e.debrisVisual
        local color = dv.color or { 0.5, 0.5, 0.5, 1 }
        local r = color[1] or 0.5
        local g = color[2] or 0.5
        local b = color[3] or 0.5
        local a = (color[4] or 1) * alpha

        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(angle)

        love.graphics.setColor(r, g, b, a)
        love.graphics.polygon("fill", dv.flatPoints)

        love.graphics.setColor(r * 0.22, g * 0.22, b * 0.22, a * 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", dv.flatPoints)

        love.graphics.pop()
    end

    love.graphics.setLineWidth(1)
end

return {
    AsteroidRenderSystem = AsteroidRenderSystem,
    WreckRenderSystem = WreckRenderSystem,
    ShipRenderSystem = ShipRenderSystem,
    HealthBarSystem = HealthBarSystem,
    ItemRenderSystem = ItemRenderSystem,
    ProjectileRenderSystem = ProjectileRenderSystem,
    DebrisRenderSystem = DebrisRenderSystem,
}
