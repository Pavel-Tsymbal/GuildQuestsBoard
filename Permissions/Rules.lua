local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Rules = {}
ns.Rules = Rules

function Rules:GetSettings()
    return ns.Storage:GetSettings() or ns.Schema:DefaultGuildSettings()
end

function Rules:IsPermissionEnabled(value)
    return value == true or value == 1
end

function Rules:GetDefaultRankPermissions(rankIndex)
    local defaults = ns.Schema:DefaultGuildSettings()
    local perms = defaults.permissions.ranks[rankIndex]
    if perms then
        return perms
    end
    return {
        create = rankIndex <= 3,
        approve = rankIndex <= 1,
        close = rankIndex <= 1,
        rewardPaid = rankIndex <= 1,
        delete = rankIndex <= 1,
    }
end

function Rules:GetRankPermissions(rankIndex)
    local settings = self:GetSettings()
    local ranks = settings.permissions and settings.permissions.ranks
    if ranks and ranks[rankIndex] then
        return ranks[rankIndex]
    end
    return self:GetDefaultRankPermissions(rankIndex)
end

function Rules:IsGuildMaster(playerName)
    local player = playerName or Util:GetPlayerName()
    if player == Util:GetPlayerName() and self:IsDebugGuildMaster() then
        return true
    end
    return ns.GuildRank:IsGuildMaster(playerName)
end

function Rules:HasRankPermission(playerName, key)
    if self:IsGuildMaster(playerName) then
        return true
    end
    local rankIndex = ns.GuildRank:GetRankIndex(playerName)
    if rankIndex == nil then
        return false
    end
    local perms = self:GetRankPermissions(rankIndex)
    return self:IsPermissionEnabled(perms[key])
end

function Rules:CanEditGuildSettings(playerName)
    if C.DEBUG_GUILD_MASTER then
        return true
    end
    if GuildQuestsCharDB and GuildQuestsCharDB.debugGuildMaster then
        return true
    end
    return self:IsGuildMaster(playerName)
end

function Rules:IsDebugGuildMaster()
    return C.DEBUG_GUILD_MASTER
        or (GuildQuestsCharDB and GuildQuestsCharDB.debugGuildMaster == true)
end

function Rules:SetDebugGuildMaster(enabled)
    if GuildQuestsCharDB then
        GuildQuestsCharDB.debugGuildMaster = enabled or nil
    end
end

function Rules:CanViewGuildSettings()
    return Util:GetGuildKey() ~= nil
end

function Rules:CanCreateQuest(playerName)
    if not Util:GetGuildKey() then
        return false, ns.L["ERR_NOT_IN_GUILD"]
    end
    if not self:HasRankPermission(playerName, "create") then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    if not self:IsGuildMaster(playerName) then
        local settings = self:GetSettings()
        local required = settings.sync.minOnlineToCreate or 1
        local online = ns.Heartbeat and ns.Heartbeat:GetOnlineAddonCount() or 1
        if online < required then
            return false, string.format(ns.L["ERR_QUORUM_CREATE"], required)
        end
    end
    return true
end

function Rules:CanAcceptQuest(playerName, quest)
    if not quest then
        return false
    end
    if not self:IsGuildMaster(playerName) then
        local settings = self:GetSettings()
        local required = settings.sync.minOnlineToAccept or 1
        local online = ns.Heartbeat and ns.Heartbeat:GetOnlineAddonCount() or 1
        if online < required then
            return false, string.format(ns.L["ERR_QUORUM_ACCEPT"], required)
        end
    end
    local count = Util:CountTable(quest.participants)
    if count >= (quest.maxParticipants or 1) then
        return false, ns.L["ERR_QUEST_FULL"]
    end
    if quest.participants and quest.participants[playerName or Util:GetPlayerName()] then
        return false, ns.L["ERR_NO_PERMISSION"]
    end
    return true
end

function Rules:CanApprove(playerName, quest)
    if not quest then
        return false
    end
    if self:IsGuildMaster(playerName) then
        return true
    end
    if self:IsQuestCreator(playerName, quest) then
        return true
    end
    return self:HasRankPermission(playerName, "approve")
end

function Rules:CanClose(playerName, quest)
    if not quest then
        return false
    end
    if self:IsGuildMaster(playerName) then
        return true
    end
    if self:IsQuestCreator(playerName, quest) then
        return true
    end
    return self:HasRankPermission(playerName, "close")
end

function Rules:CanMarkRewardPaid(playerName, quest)
    if not quest then
        return false
    end
    return self:HasRankPermission(playerName, "rewardPaid")
end

function Rules:IsQuestCreator(playerName, quest)
    if not quest or not quest.creator then
        return false
    end
    local name = Util:GetShortPlayerName(playerName or Util:GetPlayerName())
    return Util:GetShortPlayerName(quest.creator) == name
end

function Rules:CanDelete(playerName, quest)
    if not quest then
        return false
    end
    return self:HasRankPermission(playerName, "delete")
end

function Rules:CanCancel(playerName, quest)
    if not quest then
        return false
    end
    if not self:IsQuestCreator(playerName, quest) and not self:IsGuildMaster(playerName) then
        return false
    end
    if ns.StateMachine:IsTerminal(quest.status) then
        return false
    end
    return ns.StateMachine:CanTransition(quest, C.EVENT.QUEST_CANCELLED)
end

function Rules:CanSubmit(playerName, quest)
    if not quest or not quest.participants then
        return false
    end
    local name = playerName or Util:GetPlayerName()
    return quest.participants[name] ~= nil
end

function Rules:CanStart(playerName, quest)
    return self:CanSubmit(playerName, quest)
end
