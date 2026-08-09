local _, ns = ...

local Tracker = {}
ns.AchievementTracker = Tracker

Tracker.recentLevelUp = false
Tracker.levelUpTimer = nil
Tracker.pendingSpeedrunLevel = nil

function Tracker:Init()
    ns.GQ:RegisterEvent("QUEST_TURNED_IN", function(_, questId)
        self:OnQuestTurnedIn(questId)
    end)
    ns.GQ:RegisterEvent("PLAYER_LEVEL_UP", function(_, newLevel)
        self:OnPlayerLevelUp(newLevel)
    end)
    ns.GQ:RegisterEvent("TIME_PLAYED_MSG", function(_, totalTimePlayed)
        self:OnTimePlayedMsg(totalTimePlayed)
    end)
end

function Tracker:OnPlayerLevelUp(newLevel)
    self.recentLevelUp = true
    if self.levelUpTimer then
        ns.GQ:CancelTimer(self.levelUpTimer)
    end
    self.levelUpTimer = ns.GQ:ScheduleTimer(function()
        Tracker.recentLevelUp = false
        Tracker.levelUpTimer = nil
    end, 1)

    newLevel = tonumber(newLevel) or UnitLevel("player")
    if ns.AchievementCatalog:GetSpeedrunByTargetLevel(newLevel) then
        self.pendingSpeedrunLevel = newLevel
        RequestTimePlayed()
    end
end

function Tracker:OnTimePlayedMsg(totalTimePlayed)
    if not self.pendingSpeedrunLevel then
        return
    end
    local level = self.pendingSpeedrunLevel
    self.pendingSpeedrunLevel = nil

    local entry = ns.AchievementCatalog:GetSpeedrunByTargetLevel(level)
    if not entry then
        return
    end
    if ns.AchievementStorage:IsEarned(entry.id) then
        return
    end
    if tonumber(totalTimePlayed) > entry.playedTimeThreshold then
        return
    end
    self:AwardEntry(entry)
end

function Tracker:LevelAllowed(levelCap)
    local level = UnitLevel("player")
    if level <= levelCap then
        return true
    end
    if self.recentLevelUp and level <= levelCap + 1 then
        return true
    end
    return false
end

function Tracker:AwardEntry(entry)
    if not entry or ns.AchievementStorage:IsEarned(entry.id) then
        return
    end
    if not ns.AchievementCatalog:CanPlayerEarn(entry) then
        return
    end
    if not ns.AchievementStorage:RecordEarned(entry.id, UnitLevel("player")) then
        return
    end
    local title = ns.AchievementCatalog:GetTitle(entry)
    ns.GQ:Print(string.format(ns.L["ACHIEV_EARNED_NOTIFY"], title))
    ns.AchievementNotifier:Show(entry)
    ns.GQ:Fire("AchievementEarned", entry.id)
    if ns.MainUI and ns.MainUI:IsAchievementsView() then
        ns.AchievementsPanel:Refresh()
    end
end

function Tracker:OnQuestTurnedIn(questId)
    if not questId then
        return
    end
    local entry = ns.AchievementCatalog:GetByQuestId(questId)
    if not entry then
        return
    end
    if not ns.AchievementCatalog:CanPlayerEarn(entry) then
        return
    end
    if ns.AchievementStorage:IsEarned(entry.id) then
        return
    end
    if not self:LevelAllowed(entry.levelCap) then
        return
    end
    self:AwardEntry(entry)
end
