local _, ns = ...
local C = ns.Constants

local Util = {}
ns.Util = Util

function Util:GetPlayerName()
    return UnitName("player")
end

function Util:GetRealmName()
    if GetNormalizedRealmName then
        return GetNormalizedRealmName() or GetRealmName()
    end
    return GetRealmName()
end

function Util:ExtractGuildName(guildKey)
    if not guildKey then
        return nil
    end
    return guildKey:match("^[^:]+:(.+)$") or guildKey
end

function Util:SameGuildKey(left, right)
    if not left or not right then
        return false
    end
    if left == right then
        return true
    end
    return self:ExtractGuildName(left) == self:ExtractGuildName(right)
end

function Util:GetPlayerKey()
    local name = self:GetPlayerName()
    local realm = self:GetRealmName()
    if name and realm then
        return name .. "-" .. realm
    end
    return name
end

function Util:GetShortPlayerName(fullName)
    if not fullName then
        return nil
    end
    if type(fullName) ~= "string" then
        if type(fullName) == "table" then
            fullName = fullName.fullName or fullName.name
        end
        if type(fullName) ~= "string" then
            return nil
        end
    end
    return (fullName:match("^([^%-]+)")) or fullName
end

function Util:IsGuildMemberOnline(playerName)
    if not playerName then
        return false
    end
    local online = self:GetOnlineGuildMembers()
    return online[self:GetShortPlayerName(playerName)] == true
end

function Util:InvalidateOnlineGuildCache()
    self.onlineGuildCache = nil
    self.onlineGuildCacheAt = 0
end

function Util:GetOnlineGuildMembers()
    local now = GetTime()
    if self.onlineGuildCache and now - (self.onlineGuildCacheAt or 0) < ns.Constants.ONLINE_ROSTER_CACHE_TTL then
        return self.onlineGuildCache
    end
    local online = {}
    if IsInGuild() then
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local rosterName, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
            if rosterName and (isOnline == true or isOnline == 1) then
                online[self:GetShortPlayerName(rosterName)] = true
            end
        end
    end
    self.onlineGuildCache = online
    self.onlineGuildCacheAt = now
    return online
end

function Util:StripChatLinks(text)
    if not text or text == "" then
        return ""
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x|H.-|h%[(.-)%]|h|r?", "%1")
    text = text:gsub("|H.-|h%[(.-)%]|h", "%1")
    text = text:gsub("|H.-|h([^|]+)|h", "%1")
    text = text:gsub("|r", "")
    return text
end

function Util:ExtractPlayerLinkName(text)
    if not text then
        return nil
    end
    local linkName = text:match("|Hplayer:([^|%[]+)")
    if linkName then
        return self:GetShortPlayerName(linkName)
    end
    return nil
end

function Util:SanitizePlayerName(name)
    if not name then
        return nil
    end
    if type(name) ~= "string" then
        if type(name) == "table" then
            name = name.fullName or name.name
        end
        if type(name) ~= "string" then
            return nil
        end
    end
    local linkName = self:ExtractPlayerLinkName(name)
    if linkName then
        return linkName
    end
    name = self:StripChatLinks(name)
    name = self:Trim(name)
    return self:GetShortPlayerName(name) or name
end

function Util:FindParticipantKey(quest, playerName)
    if not quest or not quest.participants then
        return nil
    end
    playerName = playerName or self:GetPlayerName()
    if quest.participants[playerName] then
        return playerName
    end
    local shortName = self:GetShortPlayerName(playerName)
    for name in pairs(quest.participants) do
        if self:GetShortPlayerName(name) == shortName then
            return name
        end
    end
    return nil
end

function Util:GetParticipant(quest, playerName)
    local key = self:FindParticipantKey(quest, playerName)
    if not key then
        return nil
    end
    return quest.participants[key], key
end

function Util:GetQuestStatusForPlayer(quest, playerName)
    if not quest then
        return "-"
    end
    if not self:UsesApprovalWorkflow(quest) then
        local participant = self:GetParticipant(quest, playerName)
        if participant and participant.status then
            return self:GetParticipantStatusLabel(participant.status)
        end
        if self:IsMultiParticipantQuest(quest) then
            return self:GetStatusLabel(C.STATUS.OPEN)
        end
    end
    return self:GetStatusLabel(quest.status)
end

function Util:GetGuildKey()
    local guildName = GetGuildInfo("player")
    if not guildName or guildName == "" then
        return nil
    end
    return self:GetRealmName() .. ":" .. guildName
end

function Util:GenerateUUID()
    self._uuidSeq = (self._uuidSeq or 0) + 1
    local seq = self._uuidSeq
    local t = GetServerTime()
    local f = math.floor(GetTime() * 1000000)
    return string.format(
        "%08x-%04x-4%03x-%04x-%08x",
        t % 0x100000000,
        f % 0x10000,
        seq % 0x1000,
        (t + seq) % 0x10000,
        (f + seq * 7919) % 0x100000000
    )
end

function Util:Now()
    return GetServerTime()
end

function Util:TimeFromParts(year, month, day, hour, min, sec)
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    hour = tonumber(hour) or 0
    min = tonumber(min) or 0
    sec = tonumber(sec) or 0
    if not year or not month or not day then
        return nil
    end

    local function isLeap(y)
        return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
    end

    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    local days = 0
    for y = 1970, year - 1 do
        days = days + (isLeap(y) and 366 or 365)
    end
    for m = 1, month - 1 do
        days = days + daysInMonth[m]
        if m == 2 and isLeap(year) then
            days = days + 1
        end
    end
    days = days + day - 1
    return days * 86400 + hour * 3600 + min * 60 + sec
end

function Util:GetMajorMinor(version)
    if not version then
        return "0.0"
    end
    local major, minor = version:match("^(%d+)%.(%d+)")
    if major and minor then
        return major .. "." .. minor
    end
    return version
end

function Util:VersionsCompatible(remoteVersion)
    return self:GetMajorMinor(remoteVersion) == self:GetMajorMinor(C.VERSION)
end

function Util:CountTable(t)
    local count = 0
    if t then
        for _ in pairs(t) do
            count = count + 1
        end
    end
    return count
end

function Util:CopyTable(src)
    if type(src) ~= "table" then
        return src
    end
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = self:CopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function Util:Trim(s)
    if not s then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lua # counts UTF-8 bytes; WoW text is UTF-8 (Cyrillic is 2 bytes per letter).
function Util:UTF8Len(str)
    if not str or str == "" then
        return 0
    end
    local len = 0
    local i = 1
    local byteLen = #str
    while i <= byteLen do
        local c = str:byte(i)
        if not c then
            break
        elseif c < 0x80 then
            i = i + 1
        elseif c < 0xE0 then
            i = i + 2
        elseif c < 0xF0 then
            i = i + 3
        else
            i = i + 4
        end
        len = len + 1
    end
    return len
end

function Util:ExceedsTextLimit(str, maxLen)
    return self:UTF8Len(str) > maxLen
end

function Util:FormatGold(amount)
    if not amount or amount <= 0 then
        return "0"
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, copper)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper)
    end
    return string.format("%dc", copper)
end

function Util:GetParticipantsLimitText(maxParticipants)
    if not maxParticipants or maxParticipants == 0 then
        return ns.L["PARTICIPANTS_UNLIMITED"]
    end
    return tostring(maxParticipants)
end

function Util:GetMaxLevelRequirement(quest)
    if not quest then
        return 0
    end
    return quest.maxLevel or quest.minLevel or 0
end

function Util:GetMaxLevelText(maxLevel)
    if not maxLevel or maxLevel == 0 then
        return ns.L["LEVEL_UNLIMITED"]
    end
    return tostring(maxLevel)
end

function Util:MeetsLevelRequirement(quest, playerName)
    local maxLevel = self:GetMaxLevelRequirement(quest)
    if maxLevel <= 0 then
        return true
    end
    if playerName and playerName ~= self:GetPlayerName() then
        return true
    end
    return UnitLevel("player") <= maxLevel
end

function Util:UsesApprovalWorkflow(quest)
    if not quest then
        return false
    end
    if quest.category == "PERMANENT" then
        return false
    end
    local maxP = quest.maxParticipants or 0
    return maxP == 1
end

function Util:IsMultiParticipantQuest(quest)
    if not quest then
        return false
    end
    if quest.category == "PERMANENT" then
        return true
    end
    local maxP = quest.maxParticipants or 0
    return maxP ~= 1
end

function Util:GetRewardText(quest)
    if not quest then
        return "-"
    end
    local reward = self:Trim(quest.reward or "")
    if reward ~= "" then
        return reward
    end
    if quest.rewardGold and quest.rewardGold > 0 then
        return self:FormatGold(quest.rewardGold)
    end
    return "-"
end

function Util:ParseGoldInput(text)
    text = self:Trim(text or "")
    if text == "" then
        return 0
    end
    local gold = text:match("(%d+)g") or text:match("^(%d+)$")
    gold = tonumber(gold) or 0
    local silver = tonumber(text:match("(%d+)s")) or 0
    local copper = tonumber(text:match("(%d+)c")) or 0
    if not text:match("[gsc]") and gold > 0 then
        return gold * 10000
    end
    return gold * 10000 + silver * 100 + copper
end

function Util:SimpleHash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 2147483647
    end
    return tostring(hash)
end

function Util:IsInCombat()
    return UnitAffectingCombat("player")
end

function Util.CompareEventOrder(a, b)
    if not a or not b then
        return false
    end
    if a.lamport ~= b.lamport then
        return a.lamport < b.lamport
    end
    if a.wallTime ~= b.wallTime then
        return a.wallTime < b.wallTime
    end
    return (a.actor or "") < (b.actor or "")
end

function Util:GetCategoryLabel(category)
    local L = ns.L
    if L then
        return L["CATEGORY_" .. category] or category
    end
    return category
end

function Util:GetStatusLabel(status)
    local L = ns.L
    if L then
        return L["STATUS_" .. status] or status
    end
    return status
end

function Util:GetParticipantStatusLabel(status)
    local L = ns.L
    if L and L["PARTICIPANT_" .. status] then
        return L["PARTICIPANT_" .. status]
    end
    return self:GetStatusLabel(status)
end
