local _, ns = ...
local Util = ns.Util

local GuildRank = {}
ns.GuildRank = GuildRank

GuildRank.cache = {}
GuildRank.numRanks = 0

function GuildRank:Init()
    ns.GQ:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        GuildRank:OnRosterUpdate()
    end)
    C_Timer.After(2, function()
        GuildRank:Refresh()
    end)
end

function GuildRank:Refresh()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

function GuildRank:OnRosterUpdate()
    self:RebuildCache()
    ns.GQ:Fire("GuildRosterUpdated")
end

function GuildRank:RebuildCache()
    self.cache = {}
    self.numRanks = GuildControlGetNumGuildRanks and GuildControlGetNumGuildRanks() or 5
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name then
            local short = Util:GetShortPlayerName(name)
            local normalizedRank = self:NormalizeRankIndex(rankIndex)
            self.cache[short] = normalizedRank
            self.cache[name] = normalizedRank
        end
    end
end

function GuildRank:IsLocalPlayer(playerName)
    if not playerName then
        return true
    end
    local localName = Util:GetPlayerName()
    return playerName == localName or Util:GetShortPlayerName(playerName) == localName
end

function GuildRank:NormalizeRankIndex(rankIndex)
    if rankIndex == nil then
        return nil
    end
    return tonumber(rankIndex)
end

function GuildRank:GetLocalPlayerRankIndex()
    if IsGuildLeader("player") then
        return 0
    end
    local _, _, rankIndex = GetGuildInfo("player")
    rankIndex = self:NormalizeRankIndex(rankIndex)
    if rankIndex ~= nil then
        return rankIndex
    end
    local short = Util:GetShortPlayerName(Util:GetPlayerName())
    if self.cache[short] ~= nil then
        return self:NormalizeRankIndex(self.cache[short])
    end
    return nil
end

function GuildRank:GetRankIndex(playerName)
    if not playerName then
        playerName = Util:GetPlayerName()
    end
    if self:IsLocalPlayer(playerName) then
        local rankIndex = self:GetLocalPlayerRankIndex()
        if rankIndex ~= nil then
            return rankIndex
        end
    end
    local short = Util:GetShortPlayerName(playerName)
    if self.cache[playerName] ~= nil then
        return self:NormalizeRankIndex(self.cache[playerName])
    end
    if self.cache[short] ~= nil then
        return self:NormalizeRankIndex(self.cache[short])
    end
    self:Refresh()
    return self:NormalizeRankIndex(self.cache[short])
end

function GuildRank:GetNumRanks()
    return self.numRanks > 0 and self.numRanks or 5
end

function GuildRank:GetRankName(rankIndex)
    if GuildControlGetRankName then
        return GuildControlGetRankName(rankIndex + 1) or string.format(ns.L["GUILD_RANK_FALLBACK"], rankIndex)
    end
    return string.format(ns.L["GUILD_RANK_FALLBACK"], rankIndex)
end

function GuildRank:IsGuildMaster(playerName)
    if playerName and playerName ~= Util:GetPlayerName() then
        return self:GetRankIndex(playerName) == 0
    end
    return IsGuildLeader("player") == true
end

function GuildRank:IsOfficer(playerName)
    local rank = self:GetRankIndex(playerName)
    return rank ~= nil and rank <= 1
end
