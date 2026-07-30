local _, ns = ...
local Util = ns.Util

local Queue = {}
ns.Queue = Queue

Queue.pending = {}
Queue.shown = {}

function Queue:Init()
    ns.GQ:RegisterCallback("QuestCreated", function(_, questId)
        self:Enqueue(questId)
    end)
end

function Queue:Enqueue(questId)
    if ns.PersonalSettings:IsNotificationDismissed(questId) then
        return
    end
    if self.shown[questId] then
        return
    end
    for _, id in ipairs(self.pending) do
        if id == questId then
            return
        end
    end
    table.insert(self.pending, questId)
    self:Process()
end

function Queue:Process()
    if not ns.PersonalSettings:ShouldShowNotification() then
        return
    end
    if ns.Toast:IsVisible() then
        return
    end
    local questId = table.remove(self.pending, 1)
    if not questId then
        return
    end
    local quest = ns.Storage:GetQuest(questId)
    if quest then
        self.shown[questId] = true
        ns.Toast:ShowQuest(quest, function()
            self.shown[questId] = nil
            self:Process()
        end)
    else
        self:Process()
    end
end

function Queue:Dismiss(questId)
    ns.PersonalSettings:DismissNotification(questId)
    self.shown[questId] = nil
end
