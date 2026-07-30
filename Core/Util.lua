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
    return (fullName:match("^([^%-]+)")) or fullName
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
