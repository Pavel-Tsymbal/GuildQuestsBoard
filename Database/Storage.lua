local _, ns = ...
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

function Storage:GetMaxEventLamport()
    local store = self:GetGuildStore()
    if not store then
        return 0
    end
    local maxLamport = 0
    for _, event in ipairs(store.events) do
        if event.lamport and event.lamport > maxLamport then
            maxLamport = event.lamport
        end
    end
    return maxLamport
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
        if event.lamport and event.lamport > lamport then
            table.insert(result, event)
        end
    end
    table.sort(result, Util.CompareEventOrder)
    return result
end

function Storage:OnGuildLeft()
    -- keep persisted data; runtime modules handle UI reset
end
