local _, ns = ...
local Util = ns.Util

local AchievementStorage = {}
ns.AchievementStorage = AchievementStorage

function AchievementStorage:GetCharDB()
    return ns.Storage:GetCharDB()
end

function AchievementStorage:EnsureAchievements()
    local charDB = self:GetCharDB()
    if not charDB then
        return nil
    end
    charDB.achievements = charDB.achievements or {}
    return charDB.achievements
end

function AchievementStorage:IsEarned(id)
    local achievements = self:EnsureAchievements()
    return achievements and achievements[id] ~= nil
end

function AchievementStorage:GetEarned(id)
    local achievements = self:EnsureAchievements()
    if achievements then
        return achievements[id]
    end
end

function AchievementStorage:RecordEarned(id, level, timestamp)
    local achievements = self:EnsureAchievements()
    if not achievements or not id or achievements[id] then
        return false
    end
    achievements[id] = {
        earnedAt = timestamp or Util:Now(),
        level = level or UnitLevel("player"),
    }
    return true
end

function AchievementStorage:GetAllEarned()
    local achievements = self:EnsureAchievements()
    if not achievements then
        return {}
    end
    local list = {}
    for id, data in pairs(achievements) do
        list[#list + 1] = {
            id = id,
            earnedAt = data.earnedAt,
            level = data.level,
        }
    end
    table.sort(list, function(a, b)
        return (tonumber(a.earnedAt) or 0) > (tonumber(b.earnedAt) or 0)
    end)
    return list
end
