local _, ns = ...
local Util = ns.Util

local Logger = {}
ns.Logger = Logger

function Logger:Init()
end

function Logger:GetTimeline(questId)
    local quest = ns.Storage:GetQuest(questId)
    if not quest or not quest.history then
        return {}
    end
    local timeline = {}
    for _, entry in ipairs(quest.history) do
        table.insert(timeline, {
            action = entry.action,
            label = ns.Projections:GetHistoryLabel(entry.action),
            actor = entry.actor,
            target = entry.target,
            timestamp = entry.timestamp,
        })
    end
    return timeline
end

function Logger:FormatEntry(entry)
    local label = ns.Projections:GetHistoryLabel(entry.action)
    if entry.target then
        return string.format("%s — %s (%s)", label, entry.actor, entry.target)
    end
    return string.format("%s — %s", label, entry.actor)
end

function Logger:GetFormattedTimeline(questId)
    local timeline = self:GetTimeline(questId)
    local lines = {}
    for _, entry in ipairs(timeline) do
        table.insert(lines, self:FormatEntry(entry))
    end
    return lines
end
