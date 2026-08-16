local _, ns = ...
local C = ns.Constants
local Util = ns.Util
local Schema = ns.Schema

local Storage = {}
ns.Storage = Storage

function Storage:Init()
    GuildQuestsDB = GuildQuestsDB or { schemaVersion = ns.Constants.SCHEMA_VERSION, guilds = {} }
    GuildQuestsCharDB = GuildQuestsCharDB or Schema:DefaultCharSettings()
    GuildQuestsCharDB.minimap = GuildQuestsCharDB.minimap or {}
    ns.Migration:Run(GuildQuestsDB)
    self:MergeDefaults(GuildQuestsCharDB, Schema:DefaultCharSettings())
end

function Storage:MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = Util:CopyTable(v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            self:MergeDefaults(target[k], v)
        end
    end
end

function Storage:GetCharDB()
    return GuildQuestsCharDB
end

function Storage:GetGuildKey()
    return Util:GetGuildKey()
end

function Storage:EnsureGuildStore()
    local guildKey = Util:GetGuildKey()
    if not guildKey then
        return nil
    end
    GuildQuestsDB.guilds = GuildQuestsDB.guilds or {}
    if not GuildQuestsDB.guilds[guildKey] then
        GuildQuestsDB.guilds[guildKey] = Schema:DefaultGuildStore()
    end
    local store = GuildQuestsDB.guilds[guildKey]
    store.settings = store.settings or Schema:DefaultGuildSettings()
    store.quests = store.quests or {}
    store.deaths = store.deaths or {}
    store.events = store.events or {}
    store.seenEventIds = store.seenEventIds or {}
    store.logicalClock = store.logicalClock or 0
    ns.Schema:EnsureRankPermissions(store.settings, ns.GuildRank and ns.GuildRank:GetNumRanks() or 5)
    return store
end

function Storage:GetGuildStore()
    return self:EnsureGuildStore()
end

function Storage:GetQuest(questId)
    local store = self:GetGuildStore()
    if store then
        return store.quests[questId]
    end
end

function Storage:GetSettings()
    local store = self:GetGuildStore()
    if store then
        return store.settings
    end
end

function Storage:GetEvents()
    local store = self:GetGuildStore()
    if store then
        return store.events
    end
    return {}
end

function Storage:HasSeenEvent(eventId)
    local store = self:GetGuildStore()
    return store and store.seenEventIds[eventId] == true
end

function Storage:MarkEventSeen(eventId)
    local store = self:GetGuildStore()
    if store then
        store.seenEventIds[eventId] = true
    end
end

function Storage:NextLamport(receivedClock)
    local store = self:GetGuildStore()
    if not store then
        return 1
    end
    local nextClock = math.max(store.logicalClock, receivedClock or 0) + 1
    store.logicalClock = nextClock
    return nextClock
end

function Storage:AppendEvent(event)
    local store = self:GetGuildStore()
    if not store then
        return false
    end
    if store.seenEventIds[event.id] then
        return false
    end
    store.seenEventIds[event.id] = true
    table.insert(store.events, event)
    if event.lamport and event.lamport > store.logicalClock then
        store.logicalClock = event.lamport
    end
    store._eventCount = #store.events
    if event.lamport and event.lamport > (store._maxEventLamport or 0) then
        store._maxEventLamport = event.lamport
    end
    if event.type == C.EVENT.GUILD_MEMBER_DIED then
        store._deathEventCount = (store._deathEventCount or 0) + 1
    end
    store.stateHash = Util:SimpleHash(tostring(#store.events) .. ":" .. store.logicalClock)
    return true
end

function Storage:UpdateQuest(quest)
    local store = self:GetGuildStore()
    if store and quest and quest.id then
        store.quests[quest.id] = quest
        store.stateHash = Util:SimpleHash(tostring(#store.events) .. ":" .. store.logicalClock .. ":" .. quest.id)
    end
end

function Storage:RemoveQuest(questId)
    local store = self:GetGuildStore()
    if store and questId then
        store.quests[questId] = nil
        store.stateHash = Util:SimpleHash(tostring(#store.events) .. ":" .. store.logicalClock .. ":del:" .. questId)
    end
end

function Storage:UpdateSettings(settings)
    local store = self:GetGuildStore()
    if store then
        store.settings = settings
    end
end

function Storage:GetStateHash()
    local store = self:GetGuildStore()
    return store and store.stateHash or "0"
end

function Storage:InvalidateDeathStats()
    local store = self:GetGuildStore()
    if store then
        store._deathEventCount = nil
        store._deathRecordCount = nil
    end
end

function Storage:CountDeathEvents()
    local store = self:GetGuildStore()
    if not store or not store.events then
        return 0
    end
    if store._deathEventCount == nil then
        local count = 0
        for _, event in ipairs(store.events) do
            if event.type == C.EVENT.GUILD_MEMBER_DIED then
                count = count + 1
            end
        end
        store._deathEventCount = count
    end
    return store._deathEventCount
end

function Storage:CountDeathRecords()
    local store = self:GetGuildStore()
    if not store then
        return 0
    end
    if store._deathRecordCount == nil then
        store._deathRecordCount = Util:CountTable(store.deaths or {})
    end
    return store._deathRecordCount
end

function Storage:HasDeathProjectionGap()
    return self:CountDeathEvents() > self:CountDeathRecords()
end

function Storage:GetEventCount()
    local store = self:GetGuildStore()
    if not store or not store.events then
        return 0
    end
    store._eventCount = store._eventCount or #store.events
    return store._eventCount
end

function Storage:GetMaxEventLamport()
    local store = self:GetGuildStore()
    if not store then
        return 0
    end
    if store._maxEventLamport == nil then
        local maxLamport = 0
        for _, event in ipairs(store.events) do
            if event.lamport and event.lamport > maxLamport then
                maxLamport = event.lamport
            end
        end
        store._maxEventLamport = maxLamport
    end
    return store._maxEventLamport or 0
end

function Storage:GetLogicalClock()
    local store = self:GetGuildStore()
    return store and store.logicalClock or 0
end

function Storage:GetEventsSince(lamport)
    local result = {}
    local store = self:GetGuildStore()
    if not store then
        return result
    end
    for _, event in ipairs(store.events) do
        if lamport <= 0 then
            table.insert(result, event)
        else
            local eventLamport = event.lamport or 0
            if eventLamport > lamport then
                table.insert(result, event)
            end
        end
    end
    table.sort(result, Util.CompareEventOrder)
    return result
end

function Storage:GetDeaths()
    local store = self:GetGuildStore()
    if not store then
        return {}
    end
    return store.deaths or {}
end

function Storage:MakeDeathDedupKey(death)
    if not death or not death.name then
        return nil
    end
    local bucket = math.floor((tonumber(death.date) or 0) / C.DEATHLOG_DEDUP_WINDOW)
    return string.lower(Util:GetShortPlayerName(death.name) or death.name) .. "|" .. (death.realm or "") .. "|" .. bucket
end

function Storage:NormalizeDeathName(name)
    if not name then
        return ""
    end
    name = string.lower(Util:SanitizePlayerName(name) or name or "")
    return string.lower(Util:GetShortPlayerName(name) or name)
end

function Storage:PreferDeathLevel(current, incoming)
    current = tonumber(current) or 0
    incoming = tonumber(incoming) or 0
    if incoming <= 0 then
        return current
    end
    if current <= 0 then
        return incoming
    end
    return math.max(current, incoming)
end

function Storage:DeathsMatchIdentity(left, right)
    if not left or not right or not left.name or not right.name then
        return false
    end
    if self:NormalizeDeathName(left.name) ~= self:NormalizeDeathName(right.name) then
        return false
    end
    local leftClass = tonumber(left.classId) or 0
    local rightClass = tonumber(right.classId) or 0
    if leftClass > 0 and rightClass > 0 and leftClass ~= rightClass then
        return false
    end
    local leftRace = tonumber(left.raceId) or 0
    local rightRace = tonumber(right.raceId) or 0
    if leftRace > 0 and rightRace > 0 and leftRace ~= rightRace then
        return false
    end
    return true
end

function Storage:DeathIdentityKey(death)
    if not death or not death.name then
        return nil
    end
    local classId = tonumber(death.classId) or 0
    local raceId = tonumber(death.raceId) or 0
    return string.format("%s|%d|%d", self:NormalizeDeathName(death.name), classId, raceId)
end

function Storage:FindRecentRepeatDeath(death, windowSeconds)
    if not death or not death.name then
        return nil, nil
    end
    windowSeconds = windowSeconds or C.DEATHLOG_REPEAT_WINDOW
    local targetDate = tonumber(death.date) or Util:Now()
    for id, existing in pairs(self:GetDeaths()) do
        if death.id and existing.id == death.id then
            -- skip self
        elseif self:DeathsMatchIdentity(death, existing) then
            local existingDate = tonumber(existing.date) or 0
            if math.abs(existingDate - targetDate) <= windowSeconds then
                return existing, id
            end
        end
    end
    return nil, nil
end

function Storage:FindDeathForMerge(death)
    if not death or not death.name then
        return nil, nil
    end

    local dedupKey = death.dedupKey or self:MakeDeathDedupKey(death)
    local targetDate = tonumber(death.date) or 0

    for id, existing in pairs(self:GetDeaths()) do
        if dedupKey and existing.dedupKey == dedupKey then
            return existing, id
        end
    end

    for id, existing in pairs(self:GetDeaths()) do
        if self:DeathsMatchIdentity(death, existing) then
            local existingDate = tonumber(existing.date) or 0
            if math.abs(existingDate - targetDate) <= C.DEATHLOG_REPEAT_WINDOW then
                return existing, id
            end
        end
    end

    return nil, nil
end

function Storage:MergeDeath(existing, incoming)
    local merged = Util:CopyTable(existing)
    local fields = { "level", "classId", "raceId", "guild", "source", "zone", "mapId", "date", "reportedBy", "quality" }
    for _, field in ipairs(fields) do
        local value = incoming[field]
        if value ~= nil and value ~= "" and value ~= 0 then
            if field == "quality" then
                if value == "full" or merged.quality ~= "full" then
                    merged.quality = value
                end
            elseif field == "level" then
                merged.level = self:PreferDeathLevel(merged.level, value)
            else
                merged[field] = value
            end
        end
    end
    if not merged.dedupKey then
        merged.dedupKey = self:MakeDeathDedupKey(merged)
    end
    return merged
end

function Storage:UpsertDeath(death)
    local store = self:GetGuildStore()
    if not store or not death or not death.id then
        return nil
    end
    store.deaths = store.deaths or {}
    death.dedupKey = death.dedupKey or self:MakeDeathDedupKey(death)
    for id, existing in pairs(store.deaths) do
        if existing.dedupKey and death.dedupKey and existing.dedupKey == death.dedupKey then
            store.deaths[id] = self:MergeDeath(existing, death)
            store._deathRecordCount = nil
            return id
        end
    end
    store.deaths[death.id] = death
    store._deathRecordCount = nil
    return death.id
end

function Storage:GetDeathList(limit)
    local deaths = self:GetDeaths()
    local list = {}
    for _, death in pairs(deaths) do
        list[#list + 1] = death
    end
    table.sort(list, function(a, b)
        return (tonumber(a.date) or 0) > (tonumber(b.date) or 0)
    end)
    if limit and #list > limit then
        local trimmed = {}
        for i = 1, limit do
            trimmed[i] = list[i]
        end
        return trimmed, #list
    end
    return list, #list
end

function Storage:OnGuildLeft()
    -- keep persisted data; runtime modules handle UI reset
end
