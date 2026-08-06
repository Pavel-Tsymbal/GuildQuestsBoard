local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Replicator = {}
ns.Replicator = Replicator

Replicator.conflicts = {}

function Replicator:Init()
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

function Replicator:ProcessRemoteEvent(event, sender)
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
        if not ns.GuildRank:IsGuildMaster(sender) and event.actor ~= sender then
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
    end
    return true, event
end

function Replicator:GetConflicts()
    return self.conflicts
end
