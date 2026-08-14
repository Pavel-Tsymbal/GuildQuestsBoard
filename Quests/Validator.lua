local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Validator = {}
ns.Validator = Validator

function Validator:Init()
end

function Validator:ValidateCreate(data)
    data = data or {}
    local title = Util:Trim(data.title)
    local description = Util:Trim(data.description)
    if title == "" then
        return false, ns.L["ERR_INVALID_TITLE"]
    end
    if Util:ExceedsTextLimit(title, C.TITLE_MAX) then
        return false, ns.L["ERR_INVALID_TITLE"]
    end
    if description == "" then
        return false, ns.L["ERR_INVALID_DESC"]
    end
    if Util:ExceedsTextLimit(description, C.DESC_MAX) then
        return false, string.format(ns.L["ERR_DESC_TOO_LONG"], C.DESC_MAX)
    end
    local maxP = tonumber(data.maxParticipants)
    if maxP == nil then
        maxP = 0
    end
    if maxP ~= 0 and (maxP < 1 or maxP > C.MAX_PARTICIPANTS) then
        return false, ns.L["ERR_INVALID_PARTICIPANTS"]
    end
    local maxLevel = tonumber(data.maxLevel)
    if maxLevel == nil then
        maxLevel = tonumber(data.minLevel) or 0
    end
    if maxLevel ~= 0 and (maxLevel < 1 or maxLevel > C.MAX_LEVEL) then
        return false, ns.L["ERR_INVALID_LEVEL"]
    end
    local reward = Util:Trim(data.reward or "")
    if Util:ExceedsTextLimit(reward, C.REWARD_MAX) then
        return false, ns.L["ERR_INVALID_REWARD"]
    end
    local timeMode = data.timeMode or C.TIME_MODE.NONE
    if timeMode == C.TIME_MODE.DEADLINE and not data.deadline then
        return false, ns.L["ERR_INVALID_DATE"]
    end
    if timeMode == C.TIME_MODE.SCHEDULED and not data.scheduledAt then
        return false, ns.L["ERR_INVALID_DATE"]
    end
    local validCategory = false
    for _, cat in ipairs(C.CATEGORIES) do
        if data.category == cat then
            validCategory = true
            break
        end
    end
    if not validCategory then
        data.category = "OTHER"
    end
    return true, nil
end

function Validator:SanitizeCreate(data)
    local itemRewards = {}
    if data.itemRewards then
        for i, entry in ipairs(data.itemRewards) do
            if i <= C.MAX_ITEM_REWARDS and entry.text and entry.text ~= "" then
                table.insert(itemRewards, {
                    text = entry.text,
                    itemLink = entry.itemLink,
                })
            end
        end
    end
    return {
        id = Util:GenerateUUID(),
        creator = Util:GetPlayerName(),
        creatorRealm = Util:GetRealmName(),
        title = Util:Trim(data.title),
        description = Util:Trim(data.description),
        category = data.category or "OTHER",
        categoryTag = "",
        reward = Util:Trim(data.reward or ""),
        rewardGold = 0,
        itemRewards = itemRewards,
        timeMode = data.timeMode or C.TIME_MODE.NONE,
        deadline = data.deadline,
        scheduledAt = data.scheduledAt,
        maxParticipants = tonumber(data.maxParticipants) or 0,
        maxLevel = tonumber(data.maxLevel) or tonumber(data.minLevel) or 0,
    }
end

function Validator:ValidateEvent(quest, eventType)
    if eventType == C.EVENT.QUEST_CREATED then
        return true
    end
    if eventType == C.EVENT.QUEST_DELETED then
        return quest ~= nil
    end
    if not quest then
        return false
    end
    if ns.StateMachine:IsTerminal(quest.status) and eventType ~= C.EVENT.QUEST_CREATED then
        return false
    end
    if eventType == C.EVENT.QUEST_SUBMITTED and not Util:UsesApprovalWorkflow(quest) then
        return quest.status == C.STATUS.IN_PROGRESS
            or quest.status == C.STATUS.OPEN
            or quest.status == C.STATUS.GROUP_FORMING
            or quest.status == C.STATUS.CLAIMED
    end
    if Util:IsMultiParticipantQuest(quest) then
        if eventType == C.EVENT.QUEST_CLAIMED or eventType == C.EVENT.QUEST_STARTED then
            return quest.status == C.STATUS.OPEN
                or quest.status == C.STATUS.GROUP_FORMING
                or quest.status == C.STATUS.CANCELLED
                or quest.status == C.STATUS.IN_PROGRESS
        end
        if eventType == C.EVENT.QUEST_CANCELLED then
            return not ns.StateMachine:IsTerminal(quest.status)
        end
    end
    return ns.StateMachine:CanTransition(quest, eventType)
        or eventType == C.EVENT.REWARD_PAID
        or eventType == C.EVENT.QUEST_UPDATED
end
