local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Replicator = {}
ns.Replicator = Replicator

Replicator.conflicts = {}
Replicator.pendingSettingsEvents = {}

function Replicator:Init()
    ns.GQ:RegisterCallback("GuildRosterUpdated", function()
        self:FlushPendingSettingsEvents()
    end)
end

function Replicator:EvaluateSettingsAcceptance(event, sender, options)
    options = options or {}
    local actor = event.actor or sender

    if ns.GuildRank:IsGuildMaster(sender) then
        return "accept"
    end

    if options.allowRelayedSettings and ns.GuildRank:IsGuildMaster(actor) then
        return "accept"
    end

    if options.allowRelayedSettings then
        local actorRank = ns.GuildRank:GetRankIndex(actor)
        if actorRank == nil then
            return "defer"
        end
        return "reject"
    end

    local senderRank = ns.GuildRank:GetRankIndex(sender)
    if senderRank == nil then
        return "defer"
    end
    return "reject"
end

function Replicator:QueuePendingSettingsEvent(event, sender, options)
    if not event or not event.id then
        return
    end
    self.pendingSettingsEvents[event.id] = {
        event = event,
        sender = sender,
        options = options or {},
    }
    if C.DEBUG_SYNC then
        ns.GQ:Print(string.format(ns.L["DEBUG_SYNC_SETTINGS_DEFERRED"], tostring(sender)))
    end
end

function Replicator:GetPendingSettingsCount()
    return Util:CountTable(self.pendingSettingsEvents)
end

function Replicator:FlushPendingSettingsEvents()
    local pending = self.pendingSettingsEvents
    if not pending or not next(pending) then
        return 0
    end

    local applied = 0
    local toRemove = {}

    for id, entry in pairs(pending) do
        local verdict = self:EvaluateSettingsAcceptance(entry.event, entry.sender, entry.options)
        if verdict == "accept" then
            if self:ProcessRemoteEvent(entry.event, entry.sender, entry.options, true) then
                applied = applied + 1
            end
            toRemove[id] = true
        elseif verdict == "reject" then
            if C.DEBUG_SYNC then
                ns.GQ:Print(string.format(ns.L["DEBUG_SYNC_SETTINGS_REJECTED"], tostring(entry.sender)))
            end
            toRemove[id] = true
        end
    end

    for id in pairs(toRemove) do
        pending[id] = nil
    end

    if applied > 0 and C.DEBUG_SYNC then
        ns.GQ:Print(string.format(ns.L["DEBUG_SYNC_SETTINGS_APPLIED"], applied))
    end

    return applied
end

function Replicator:ProcessLocalEvent(event)
    if not event or not event.guildKey then
        event.guildKey = Util:GetGuildKey()
    end
    if not event.guildKey then
        return false, ns.L["ERR_NOT_IN_GUILD"]
    end
    if event.type ~= C.EVENT.SETTINGS_UPDATED then
        local quest = event.payload and event.payload.questId and ns.Storage:GetQuest(event.payload.questId)
        if event.type == C.EVENT.QUEST_CREATED then
            -- no prior quest
        elseif event.type == C.EVENT.QUEST_DELETED then
            if not quest or not ns.Rules:CanDelete(event.actor, quest) then
                table.insert(self.conflicts, event)
                return false, ns.L["ERR_NO_PERMISSION"]
            end
        elseif not ns.Validator:ValidateEvent(quest, event.type) then
            table.insert(self.conflicts, event)
            return false, ns.L["ERR_NO_PERMISSION"]
        end
    end
    return self:ApplyEvent(event, true)
end

function Replicator:ProcessRemoteEvent(event, sender, options, fromPendingFlush)
    options = options or {}
    if not event or not event.id then
        return false
    end
    if event.guildKey and not Util:SameGuildKey(event.guildKey, Util:GetGuildKey()) then
        return false
    end
    if ns.Storage:HasSeenEvent(event.id) then
        return false
    end
    if event.type == C.EVENT.SETTINGS_UPDATED then
        local verdict = self:EvaluateSettingsAcceptance(event, sender, options)
        if verdict == "defer" then
            if not fromPendingFlush then
                self:QueuePendingSettingsEvent(event, sender, options)
            end
            return false
        elseif verdict == "reject" then
            if C.DEBUG_SYNC then
                ns.GQ:Print(string.format(ns.L["DEBUG_SYNC_SETTINGS_REJECTED"], tostring(sender)))
            end
            return false
        end
    end
    local quest = event.payload and event.payload.questId and ns.Storage:GetQuest(event.payload.questId)
    if event.type ~= C.EVENT.QUEST_CREATED
        and event.type ~= C.EVENT.SETTINGS_UPDATED
        and event.type ~= C.EVENT.QUEST_DELETED then
        if quest and not ns.StateMachine:CanTransition(quest, event.type) then
            if event.type == C.EVENT.QUEST_SUBMITTED and not Util:UsesApprovalWorkflow(quest) then
                -- per-participant submit does not change quest status
            elseif Util:IsMultiParticipantQuest(quest)
                and (event.type == C.EVENT.QUEST_CLAIMED
                    or event.type == C.EVENT.QUEST_STARTED
                    or event.type == C.EVENT.QUEST_CANCELLED) then
                -- multi-participant quests keep global status OPEN
            elseif event.type ~= C.EVENT.REWARD_PAID then
                table.insert(self.conflicts, event)
                return false
            end
        end
    end
    return self:ApplyEvent(event, false)
end

function Replicator:ApplyEvent(event, isLocal)
    if ns.Storage:HasSeenEvent(event.id) then
        return false
    end
    if isLocal and not event.lamport then
        event.lamport = ns.Storage:NextLamport()
    end
    if not ns.Storage:AppendEvent(event) then
        return false
    end
    ns.Projections:ApplyEvent(event)
    if isLocal then
        ns.Transport:BroadcastEvent(event)
    end
    if event.type == C.EVENT.QUEST_DELETED then
        local questId = event.payload and event.payload.questId
        if questId then
            ns.GQ:Fire("QuestDeleted", questId)
        end
    else
        ns.GQ:Fire("QuestUpdated", event.payload and event.payload.questId or event.payload and event.payload.id)
        if event.type == C.EVENT.QUEST_CREATED then
            local questId = event.payload and event.payload.id
            if questId then
                ns.GQ:Fire("QuestCreated", questId)
            end
        end
    end
    if event.type == C.EVENT.SETTINGS_UPDATED then
        ns.GQ:Fire("GuildSettingsUpdated")
        if ns.Heartbeat then
            ns.Heartbeat:BroadcastNow()
        end
    end
    return true, event
end

function Replicator:GetConflicts()
    return self.conflicts
end
