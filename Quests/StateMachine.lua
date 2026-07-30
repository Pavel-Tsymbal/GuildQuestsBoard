local _, ns = ...
local C = ns.Constants

local StateMachine = {}
ns.StateMachine = StateMachine

StateMachine.normalTransitions = {
    [C.STATUS.OPEN] = {
        [C.EVENT.QUEST_CLAIMED] = C.STATUS.CLAIMED,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
        [C.EVENT.QUEST_EXPIRED] = C.STATUS.EXPIRED,
    },
    [C.STATUS.CLAIMED] = {
        [C.EVENT.QUEST_STARTED] = C.STATUS.IN_PROGRESS,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
        [C.EVENT.QUEST_EXPIRED] = C.STATUS.EXPIRED,
    },
    [C.STATUS.IN_PROGRESS] = {
        [C.EVENT.QUEST_SUBMITTED] = C.STATUS.SUBMITTED,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
        [C.EVENT.QUEST_EXPIRED] = C.STATUS.EXPIRED,
    },
    [C.STATUS.SUBMITTED] = {
        [C.EVENT.QUEST_APPROVED] = C.STATUS.COMPLETED,
        [C.EVENT.QUEST_REJECTED] = C.STATUS.IN_PROGRESS,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
    },
    [C.STATUS.COMPLETED] = {
        [C.EVENT.QUEST_CLOSED] = C.STATUS.CLOSED,
        [C.EVENT.REWARD_PAID] = C.STATUS.CLOSED,
    },
}

StateMachine.scheduledTransitions = {
    [C.STATUS.OPEN] = {
        [C.EVENT.QUEST_SCHEDULE_STARTED] = C.STATUS.GROUP_FORMING,
        [C.EVENT.QUEST_CLAIMED] = C.STATUS.CLAIMED,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
    },
    [C.STATUS.GROUP_FORMING] = {
        [C.EVENT.QUEST_STARTED] = C.STATUS.IN_PROGRESS,
        [C.EVENT.QUEST_CLAIMED] = C.STATUS.CLAIMED,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
    },
    [C.STATUS.CLAIMED] = {
        [C.EVENT.QUEST_STARTED] = C.STATUS.IN_PROGRESS,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
    },
    [C.STATUS.IN_PROGRESS] = {
        [C.EVENT.QUEST_SUBMITTED] = C.STATUS.SUBMITTED,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
    },
    [C.STATUS.SUBMITTED] = {
        [C.EVENT.QUEST_APPROVED] = C.STATUS.COMPLETED,
        [C.EVENT.QUEST_REJECTED] = C.STATUS.IN_PROGRESS,
        [C.EVENT.QUEST_CANCELLED] = C.STATUS.CANCELLED,
    },
    [C.STATUS.COMPLETED] = {
        [C.EVENT.QUEST_CLOSED] = C.STATUS.CLOSED,
        [C.EVENT.REWARD_PAID] = C.STATUS.CLOSED,
    },
}

function StateMachine:Init()
end

function StateMachine:GetTransitionTable(quest)
    if quest and quest.timeMode == C.TIME_MODE.SCHEDULED then
        return self.scheduledTransitions
    end
    return self.normalTransitions
end

function StateMachine:CanTransition(quest, eventType)
    if not quest then
        return false
    end
    local transitions = self:GetTransitionTable(quest)
    local fromMap = transitions[quest.status]
    if not fromMap then
        return false
    end
    return fromMap[eventType] ~= nil
end

function StateMachine:GetNextStatus(quest, eventType)
    local transitions = self:GetTransitionTable(quest)
    local fromMap = transitions[quest.status]
    if fromMap then
        return fromMap[eventType]
    end
end

function StateMachine:IsTerminal(status)
    return status == C.STATUS.CLOSED
        or status == C.STATUS.CANCELLED
        or status == C.STATUS.EXPIRED
end

function StateMachine:IsActive(quest)
    if not quest then
        return false
    end
    return not self:IsTerminal(quest.status)
end

function StateMachine:CanExpire(quest)
    if not quest then
        return false
    end
    if quest.timeMode == C.TIME_MODE.SCHEDULED then
        return false
    end
    if quest.timeMode ~= C.TIME_MODE.DEADLINE then
        return false
    end
    return quest.status == C.STATUS.OPEN
        or quest.status == C.STATUS.CLAIMED
        or quest.status == C.STATUS.IN_PROGRESS
end
