local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Schema = {}
ns.Schema = Schema

function Schema:DefaultGuildSettings()
    return {
        revision = 1,
        permissions = {
            ranks = {
                [0] = { create = true, approve = true, close = true, rewardPaid = true, delete = true },
                [1] = { create = true, approve = true, close = true, rewardPaid = true, delete = true },
                [2] = { create = true, approve = false, close = false, rewardPaid = false, delete = false },
                [3] = { create = true, approve = false, close = false, rewardPaid = false, delete = false },
                [4] = { create = false, approve = false, close = false, rewardPaid = false, delete = false },
            },
        },
        sync = {
            minOnlineToCreate = 2,
            minOnlineToAccept = 2,
        },
        lastModifiedBy = nil,
        lastModifiedAt = 0,
    }
end

function Schema:DefaultCharSettings()
    return {
        locale = nil,
        notifications = {
            enabled = true,
            duration = 5,
            position = "TOPRIGHT",
            sound = true,
            showInCombat = false,
        },
        deathNotifications = {
            enabled = true,
            sound = true,
            showInCombat = true,
        },
        ui = {
            minimap = { hide = false, angle = 220 },
            windowPositions = {},
        },
        dismissedNotifications = {},
        achievements = {},
        achievementFilters = {
            excludeSpeedrun = false,
        },
    }
end

function Schema:NewDeathRecord(data)
    local now = Util:Now()
    data = data or {}
    return {
        id = data.id or Util:GenerateUUID(),
        name = data.name,
        realm = data.realm or Util:GetRealmName(),
        level = data.level or 0,
        classId = data.classId,
        raceId = data.raceId,
        guild = data.guild,
        source = data.source or "",
        zone = data.zone or "",
        mapId = data.mapId,
        date = data.date or now,
        reportedBy = data.reportedBy,
        quality = data.quality or "partial",
        dedupKey = data.dedupKey,
    }
end

function Schema:NewQuest(data)
    local now = Util:Now()
    return {
        id = data.id or Util:GenerateUUID(),
        revision = 1,
        creator = data.creator,
        creatorRealm = data.creatorRealm,
        title = data.title,
        description = data.description,
        category = data.category or "OTHER",
        categoryTag = data.categoryTag or "",
        reward = data.reward or "",
        rewardGold = data.rewardGold or 0,
        itemRewards = data.itemRewards or {},
        timeMode = data.timeMode or C.TIME_MODE.NONE,
        deadline = data.deadline,
        scheduledAt = data.scheduledAt,
        status = data.status or C.STATUS.OPEN,
        maxParticipants = data.maxParticipants or 0,
        maxLevel = data.maxLevel or 0,
        participants = {},
        createdAt = now,
        updatedAt = now,
        closedAt = nil,
        history = {},
    }
end

function Schema:NewEvent(eventType, actor, payload)
    return {
        id = Util:GenerateUUID(),
        type = eventType,
        guildKey = Util:GetGuildKey(),
        actor = actor,
        lamport = 0,
        wallTime = Util:Now(),
        payload = payload or {},
    }
end

function Schema:DefaultGuildStore()
    return {
        logicalClock = 0,
        stateHash = "0",
        settings = self:DefaultGuildSettings(),
        quests = {},
        deaths = {},
        events = {},
        seenEventIds = {},
    }
end

function Schema:EnsureRankPermissions(settings, numRanks)
    settings.permissions = settings.permissions or { ranks = {} }
    settings.permissions.ranks = settings.permissions.ranks or {}
    for i = 0, math.max(numRanks - 1, 4) do
        if not settings.permissions.ranks[i] then
            settings.permissions.ranks[i] = {
                create = i <= 3,
                approve = i <= 1,
                close = i <= 1,
                rewardPaid = i <= 1,
                delete = i <= 1,
            }
        elseif settings.permissions.ranks[i].delete == nil then
            settings.permissions.ranks[i].delete = i <= 1
        end
    end
end
