local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Actions = {}
ns.Actions = Actions

function Actions:Init()
end

function Actions:Emit(eventType, payload, actor)
    actor = actor or Util:GetPlayerName()
    local event = ns.Schema:NewEvent(eventType, actor, payload)
    event.lamport = ns.Storage:NextLamport()
    event.guildKey = Util:GetGuildKey()
    return ns.Replicator:ProcessLocalEvent(event)
end

function Actions:Create(data)
    local ok, err = ns.Validator:ValidateCreate(data)
    if not ok then
        return false, err
    end
    local can, permErr = ns.Rules:CanCreateQuest()
    if not can then
        return false, permErr
    end
    local payload = ns.Validator:SanitizeCreate(data)
    return self:Emit(C.EVENT.QUEST_CREATED, payload)
end

function Actions:Claim(questId)
    local quest = ns.Storage:GetQuest(questId)
    local can, err = ns.Rules:CanAcceptQuest(nil, quest)
    if not can then
        return false, err
    end
    if not ns.StateMachine:CanTransition(quest, C.EVENT.QUEST_CLAIMED) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_CLAIMED, {
        questId = questId,
        participant = Util:GetPlayerName(),
    })
end

function Actions:Start(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanStart(nil, quest) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_STARTED, {
        questId = questId,
        participant = Util:GetPlayerName(),
    })
end

function Actions:Submit(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanSubmit(nil, quest) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_SUBMITTED, {
        questId = questId,
        participant = Util:GetPlayerName(),
    })
end

function Actions:Approve(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanApprove(nil, quest) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_APPROVED, { questId = questId })
end

function Actions:Reject(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanApprove(nil, quest) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_REJECTED, { questId = questId })
end

function Actions:Close(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanClose(nil, quest) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_CLOSED, { questId = questId })
end

function Actions:Delete(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanDelete(nil, quest) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_DELETED, { questId = questId })
end

function Actions:Cancel(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanCancel(nil, quest) then
        if quest and ns.StateMachine:IsTerminal(quest.status) then
            return false, ns.L["ERR_QUEST_TERMINAL"]
        end
        if quest and not ns.StateMachine:CanTransition(quest, C.EVENT.QUEST_CANCELLED) then
            return false, ns.L["ERR_CANNOT_CANCEL_STATUS"]
        end
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.QUEST_CANCELLED, { questId = questId })
end

function Actions:MarkRewardPaid(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.Rules:CanMarkRewardPaid(nil, quest) then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return self:Emit(C.EVENT.REWARD_PAID, { questId = questId })
end

function Actions:Expire(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not ns.StateMachine:CanExpire(quest) then
        return false
    end
    return self:Emit(C.EVENT.QUEST_EXPIRED, { questId = questId })
end

function Actions:ScheduleStart(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not quest or quest.timeMode ~= C.TIME_MODE.SCHEDULED then
        return false
    end
    if quest.status ~= C.STATUS.OPEN then
        return false
    end
    return self:Emit(C.EVENT.QUEST_SCHEDULE_STARTED, { questId = questId })
end

function Actions:GetQuestList()
    local store = ns.Storage:GetGuildStore()
    if not store then
        return {}
    end
    local list = {}
    for _, quest in pairs(store.quests) do
        table.insert(list, quest)
    end
    table.sort(list, function(a, b)
        return (a.createdAt or 0) > (b.createdAt or 0)
    end)
    return list
end

function Actions:GetQuest(questId)
    return ns.Storage:GetQuest(questId)
end
