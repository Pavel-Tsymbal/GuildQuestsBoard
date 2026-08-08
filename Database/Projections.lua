local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Projections = {}
ns.Projections = Projections

local EVENT_TO_HISTORY = {
    [C.EVENT.QUEST_CREATED] = C.HISTORY.CREATED,
    [C.EVENT.QUEST_CLAIMED] = C.HISTORY.ACCEPTED,
    [C.EVENT.QUEST_STARTED] = C.HISTORY.STARTED,
    [C.EVENT.QUEST_SUBMITTED] = C.HISTORY.SUBMITTED,
    [C.EVENT.QUEST_APPROVED] = C.HISTORY.APPROVED,
    [C.EVENT.QUEST_REJECTED] = C.HISTORY.REJECTED,
    [C.EVENT.REWARD_PAID] = C.HISTORY.REWARD_PAID,
    [C.EVENT.QUEST_CLOSED] = C.HISTORY.CLOSED,
    [C.EVENT.QUEST_CANCELLED] = C.HISTORY.CANCELLED,
    [C.EVENT.QUEST_DELETED] = C.HISTORY.DELETED,
    [C.EVENT.QUEST_EXPIRED] = C.HISTORY.EXPIRED,
    [C.EVENT.QUEST_SCHEDULE_STARTED] = C.HISTORY.SCHEDULE_STARTED,
    [C.EVENT.QUEST_UPDATED] = C.HISTORY.UPDATED,
}

function Projections:Init()
end

function Projections:ApplyEvent(event)
    if not event or not event.type then
        return false
    end
    if event.type == C.EVENT.SETTINGS_UPDATED then
        return self:ApplySettingsEvent(event)
    end
    if event.type == C.EVENT.GUILD_MEMBER_DIED then
        return self:ApplyDeathEvent(event)
    end
    if event.type == C.EVENT.QUEST_CREATED then
        return self:ApplyQuestCreated(event)
    end
    if event.type == C.EVENT.QUEST_DELETED then
        return self:ApplyQuestDeleted(event)
    end
    return self:ApplyQuestMutation(event)
end

function Projections:ApplySettingsEvent(event)
    local payload = event.payload or {}
    if payload.settings then
        ns.Storage:UpdateSettings(Util:CopyTable(payload.settings))
        return true
    end
    return false
end

function Projections:ApplyQuestDeleted(event)
    local questId = event.payload and event.payload.questId
    if not questId then
        return false
    end
    ns.Storage:RemoveQuest(questId)
    return true
end

function Projections:ApplyDeathEvent(event)
    local death = event.payload and event.payload.death
    if not death then
        return false
    end
    if ns.DeathLogEnricher and not ns.DeathLogEnricher:PassesGuildFilter(death.name, death.guild) then
        return false
    end
    ns.Storage:UpsertDeath(death)
    return true
end

function Projections:ApplyQuestCreated(event)
    local payload = event.payload or {}
    local quest = ns.Schema:NewQuest(payload)
    quest.id = payload.id or quest.id
    quest.creator = payload.creator or event.actor
    quest.status = C.STATUS.OPEN
    self:AppendHistory(quest, event, C.HISTORY.CREATED)
    ns.Storage:UpdateQuest(quest)
    return true
end

function Projections:ApplyQuestMutation(event)
    local payload = event.payload or {}
    local questId = payload.questId
    if not questId then
        return false
    end
    local quest = ns.Storage:GetQuest(questId)
    if not quest and event.type ~= C.EVENT.QUEST_CREATED then
        return false
    end
    if not quest then
        return false
    end

    quest.revision = (quest.revision or 0) + 1
    quest.updatedAt = event.wallTime or Util:Now()

    if event.type == C.EVENT.QUEST_UPDATED then
        for k, v in pairs(payload.fields or {}) do
            quest[k] = v
        end
        self:AppendHistory(quest, event, C.HISTORY.UPDATED)
    elseif event.type == C.EVENT.QUEST_CLAIMED then
        if quest.status == C.STATUS.CANCELLED then
            quest.participants = {}
        end
        quest.participants = quest.participants or {}
        quest.participants[payload.participant or event.actor] = {
            status = C.PARTICIPANT_STATUS.ACCEPTED,
            joinedAt = event.wallTime,
        }
        if not Util:IsMultiParticipantQuest(quest) then
            local nextStatus = ns.StateMachine:GetNextStatus(quest, event.type)
            if nextStatus then
                quest.status = nextStatus
            end
        end
        self:AppendHistory(quest, event, C.HISTORY.ACCEPTED, payload.participant)
    elseif event.type == C.EVENT.QUEST_STARTED then
        local name = payload.participant or event.actor
        local key = Util:FindParticipantKey(quest, name)
        if key then
            quest.participants[key].status = C.PARTICIPANT_STATUS.ACTIVE
        end
        if not Util:IsMultiParticipantQuest(quest) then
            local nextStatus = ns.StateMachine:GetNextStatus(quest, event.type)
            if nextStatus then
                quest.status = nextStatus
            end
        end
        self:AppendHistory(quest, event, C.HISTORY.STARTED, name)
    elseif event.type == C.EVENT.QUEST_SUBMITTED then
        local name = payload.participant or event.actor
        local key = Util:FindParticipantKey(quest, name)
        if key then
            if Util:UsesApprovalWorkflow(quest) then
                quest.participants[key].status = C.PARTICIPANT_STATUS.SUBMITTED
                quest.status = C.STATUS.SUBMITTED
            else
                quest.participants[key].status = C.PARTICIPANT_STATUS.COMPLETED
            end
        end
        self:AppendHistory(quest, event, C.HISTORY.SUBMITTED, name)
    elseif event.type == C.EVENT.QUEST_APPROVED then
        quest.status = C.STATUS.COMPLETED
        self:AppendHistory(quest, event, C.HISTORY.APPROVED)
    elseif event.type == C.EVENT.QUEST_REJECTED then
        quest.status = C.STATUS.IN_PROGRESS
        self:AppendHistory(quest, event, C.HISTORY.REJECTED)
    elseif event.type == C.EVENT.QUEST_COMPLETED then
        quest.status = C.STATUS.COMPLETED
    elseif event.type == C.EVENT.REWARD_PAID then
        quest.rewardPaid = true
        self:AppendHistory(quest, event, C.HISTORY.REWARD_PAID)
    elseif event.type == C.EVENT.QUEST_CLOSED then
        quest.status = C.STATUS.CLOSED
        quest.closedAt = event.wallTime
        self:AppendHistory(quest, event, C.HISTORY.CLOSED)
    elseif event.type == C.EVENT.QUEST_CANCELLED then
        if Util:IsMultiParticipantQuest(quest) then
            local key = Util:FindParticipantKey(quest, event.actor)
            if key then
                quest.participants[key] = nil
            end
        else
            quest.status = C.STATUS.OPEN
            quest.participants = {}
            quest.closedAt = nil
        end
        self:AppendHistory(quest, event, C.HISTORY.CANCELLED)
    elseif event.type == C.EVENT.QUEST_EXPIRED then
        quest.status = C.STATUS.EXPIRED
        quest.closedAt = event.wallTime
        self:AppendHistory(quest, event, C.HISTORY.EXPIRED)
    elseif event.type == C.EVENT.QUEST_SCHEDULE_STARTED then
        local nextStatus = ns.StateMachine:GetNextStatus(quest, event.type)
        if nextStatus then
            quest.status = nextStatus
        end
        self:AppendHistory(quest, event, C.HISTORY.SCHEDULE_STARTED)
    else
        return false
    end

    ns.Storage:UpdateQuest(quest)
    return true
end

function Projections:AppendHistory(quest, event, action, target)
    quest.history = quest.history or {}
    table.insert(quest.history, {
        id = event.id,
        action = action,
        actor = event.actor,
        target = target,
        timestamp = event.wallTime,
    })
end

function Projections:RebuildFromEvents()
    local store = ns.Storage:GetGuildStore()
    if not store then
        return
    end
    store.quests = {}
    store.deaths = {}
    store.settings = ns.Schema:DefaultGuildSettings()
    for _, event in ipairs(store.events) do
        self:ApplyEvent(event)
    end
end

function Projections:GetHistoryLabel(action)
    local key = "HISTORY_" .. action
    return ns.L[key] or action
end
