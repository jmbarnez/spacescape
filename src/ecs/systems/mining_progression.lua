local Concord = require("lib.concord")

local MiningProgressionSystem = Concord.system({
    players = { "playerControlled", "miningSkill" },
})

MiningProgressionSystem["lifecycle.on_death"] = function(self, entity, killerFaction)
    self:onDeath(entity, killerFaction)
end

local function computeXpToNext(level)
    level = level or 1
    if level < 1 then
        level = 1
    end

    local base = 40
    local growth = 18

    local xpToNext = base + growth * (level - 1)
    if xpToNext <= 0 then
        xpToNext = 1
    end

    return xpToNext
end

local function recompute(skill)
    if not skill then
        return
    end

    skill.level = skill.level or 1
    skill.xp = skill.xp or 0

    local xpToNext = computeXpToNext(skill.level)
    skill.xpToNext = xpToNext
    skill.xpRatio = math.max(0, math.min(1, (skill.xp or 0) / xpToNext))
end

function MiningProgressionSystem:onDeath(entity, killerFaction)
    if killerFaction ~= "player" then
        return
    end

    if not entity or not entity.asteroid then
        return
    end

    local size = (entity.size and entity.size.value) or 20
    local miningXp = math.max(1, math.floor(size / 10))
    self:awardMiningXp(miningXp)
end

function MiningProgressionSystem:awardMiningXp(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return
    end

    for i = 1, self.players.size do
        local p = self.players[i]
        local skill = p.miningSkill
        if skill then
            skill.level = skill.level or 1
            skill.xp = (skill.xp or 0) + amount

            -- Level up as many times as needed.
            while true do
                local xpToNext = computeXpToNext(skill.level)
                if (skill.xp or 0) < xpToNext then
                    break
                end
                skill.xp = (skill.xp or 0) - xpToNext
                skill.level = (skill.level or 1) + 1
            end

            recompute(skill)
        end
    end
end

function MiningProgressionSystem:update(dt)
    -- No per-frame logic needed; progression is event-driven.
end

return MiningProgressionSystem
