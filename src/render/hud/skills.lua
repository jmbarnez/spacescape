local hud_skills = {}

local window_frame = require("src.render.hud.window_frame")
local ui_theme = require("src.core.ui_theme")

--------------------------------------------------------------------------------
-- WINDOW STATE / LAYOUT
--------------------------------------------------------------------------------

local windowState = {
    x = nil,
    y = nil,
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
}

local PANEL_WIDTH = 420
local PANEL_HEIGHT = 260
local PANEL_PADDING = 18

local function getLayoutOpts()
    return {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    }
end

local function clamp01(t)
    if t < 0 then return 0 end
    if t > 1 then return 1 end
    return t
end

local function drawProgressBar(x, y, w, h, ratio)
    ratio = clamp01(ratio or 0)

    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(0.35, 0.75, 1.0, 0.75)
    love.graphics.rectangle("fill", x, y, w * ratio, h)

    love.graphics.setColor(1, 1, 1, 0.20)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
end

local function formatXpText(font, maxWidth, xp, xpToNext, ratio)
    local xpInt = math.floor((xp or 0) + 0.5)
    local toNextInt = math.floor((xpToNext or 0) + 0.5)

    local candidates = {}
    if toNextInt > 0 then
        candidates[#candidates + 1] = string.format("%d / %d", xpInt, toNextInt)
        candidates[#candidates + 1] = string.format("%d/%d", xpInt, toNextInt)
    else
        candidates[#candidates + 1] = tostring(xpInt)
    end

    local pct = math.floor(clamp01(ratio or 0) * 100 + 0.5)
    candidates[#candidates + 1] = tostring(pct) .. "%"

    for _, txt in ipairs(candidates) do
        if font:getWidth(txt) <= maxWidth then
            return txt
        end
    end

    return candidates[#candidates]
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function hud_skills.draw(player, colors)
    if not player then
        return
    end

    local font = love.graphics.getFont()
    local hudPanelStyle = ui_theme.hudPanel

    local layout = window_frame.draw(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
        title = "SKILLS",
    }, colors)

    local contentX = layout.contentX + PANEL_PADDING
    local contentY = layout.contentY + PANEL_PADDING
    local contentW = layout.contentWidth - PANEL_PADDING * 2

    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
    love.graphics.print("Skill", contentX, contentY)

    local levelLabel = "Level"
    local levelWidth = font:getWidth(levelLabel)
    love.graphics.print(levelLabel, contentX + contentW - levelWidth, contentY)

    local rowY = contentY + font:getHeight() + 10
    local rowMinH = 64

    -- For now we only show Mining, but we layout as a grid row so it scales to more skills later.
    local mining = player.miningSkill
    local miningLevel = mining and mining.level or 1
    local miningXp = mining and mining.xp or 0
    local miningToNext = mining and mining.xpToNext or 0
    local ratio = mining and mining.xpRatio
    if ratio == nil and miningToNext > 0 then
        ratio = miningXp / miningToNext
    end

    local rowPad = 10
    local headerY = rowY + rowPad
    local barGap = 12

    local barX = contentX + 10
    local barW = math.max(40, contentW - 20)
    local barH = math.max(18, font:getHeight() + 6)
    local barY = headerY + font:getHeight() + barGap

    local rowH = (barY + barH + rowPad) - rowY
    if rowH < rowMinH then
        rowH = rowMinH
    end

    love.graphics.setColor(1, 1, 1, 0.06)
    love.graphics.rectangle("fill", contentX, rowY, contentW, rowH)
    love.graphics.setColor(hudPanelStyle.border[1], hudPanelStyle.border[2], hudPanelStyle.border[3], 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", contentX, rowY, contentW, rowH)

    local labelY = headerY
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.95)
    love.graphics.print("Mining", contentX + 10, labelY)

    local levelText = tostring(miningLevel or 1)
    local lvlW = font:getWidth(levelText)
    love.graphics.print(levelText, contentX + contentW - lvlW - 10, labelY)

    drawProgressBar(barX, barY, barW, barH, ratio or 0)

    local xpText = formatXpText(font, barW - 10, miningXp, miningToNext, ratio)
    local xpW = font:getWidth(xpText)
    local xpX = barX + (barW - xpW) / 2
    local xpY = barY + (barH - font:getHeight()) / 2

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.print(xpText, xpX + 1, xpY + 1)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(xpText, xpX, xpY)
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function hud_skills.mousepressed(x, y, button)
    return window_frame.mousepressed(windowState, getLayoutOpts(), x, y, button)
end

function hud_skills.mousereleased(x, y, button)
    window_frame.mousereleased(windowState, getLayoutOpts(), x, y, button)
end

function hud_skills.mousemoved(x, y)
    window_frame.mousemoved(windowState, getLayoutOpts(), x, y)
end

function hud_skills.reset()
    window_frame.reset(windowState)
end

return hud_skills
