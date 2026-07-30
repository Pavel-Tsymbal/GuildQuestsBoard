local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Scheduler = {}
ns.Scheduler = Scheduler

function Scheduler:Init()
    self.timer = nil
    ns.GQ:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Scheduler:OnWorldEnter()
    end)
end

function Scheduler:Start()
    self:Stop()
    self.timer = ns.GQ:ScheduleRepeatingTimer(function()
        Scheduler:OnTick()
    end, C.SCHEDULER_TICK)
end

function Scheduler:Stop()
    if self.timer then
        ns.GQ:CancelTimer(self.timer)
        self.timer = nil
    end
end

function Scheduler:OnWorldEnter()
    if Util:GetGuildKey() then
        self:OnTick()
    end
end

function Scheduler:OnTick()
    local store = ns.Storage:GetGuildStore()
    if not store then
        return
    end
    local now = Util:Now()
    for questId, quest in pairs(store.quests) do
        if ns.StateMachine:IsActive(quest) then
            if quest.timeMode == C.TIME_MODE.DEADLINE and quest.deadline then
                if now >= quest.deadline + C.EXPIRY_GRACE then
                    if ns.StateMachine:CanExpire(quest) then
                        ns.Actions:Expire(questId)
                    end
                end
            elseif quest.timeMode == C.TIME_MODE.SCHEDULED and quest.scheduledAt then
                if quest.status == C.STATUS.OPEN and now >= quest.scheduledAt then
                    ns.Actions:ScheduleStart(questId)
                end
            end
        end
    end
end
