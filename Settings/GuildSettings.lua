local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local GuildSettings = {}
ns.GuildSettings = GuildSettings

function GuildSettings:Init()
end

function GuildSettings:Get()
    return ns.Storage:GetSettings() or ns.Schema:DefaultGuildSettings()
end

function GuildSettings:CanEdit()
    return ns.Rules:CanEditGuildSettings()
end

function GuildSettings:Save(settings)
    if not self:CanEdit() then
        return false, ns.L["GUILD_READONLY"]
    end
    settings = Util:CopyTable(settings)
    settings.revision = (settings.revision or 0) + 1
    settings.lastModifiedBy = Util:GetPlayerName()
    settings.lastModifiedAt = Util:Now()
    ns.Schema:EnsureRankPermissions(settings, ns.GuildRank:GetNumRanks())
    local event = ns.Schema:NewEvent(C.EVENT.SETTINGS_UPDATED, Util:GetPlayerName(), {
        settings = settings,
    })
    event.lamport = ns.Storage:NextLamport()
    ns.Replicator:ProcessLocalEvent(event)
    return true
end

function GuildSettings:UpdateSync(key, value)
    local settings = Util:CopyTable(self:Get())
    settings.sync = settings.sync or {}
    settings.sync[key] = value
    return self:Save(settings)
end

function GuildSettings:UpdateRankPermission(rankIndex, key, value)
    local settings = Util:CopyTable(self:Get())
    settings.permissions = settings.permissions or { ranks = {} }
    settings.permissions.ranks[rankIndex] = settings.permissions.ranks[rankIndex] or {}
    settings.permissions.ranks[rankIndex][key] = value and true or false
    return self:Save(settings)
end

function GuildSettings:EnsureRankRows()
    local settings = self:Get()
    ns.Schema:EnsureRankPermissions(settings, ns.GuildRank:GetNumRanks())
    return settings
end
