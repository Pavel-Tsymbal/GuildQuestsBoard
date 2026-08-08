local _, ns = ...
local Util = ns.Util

local Enricher = {}
ns.DeathLogEnricher = Enricher

Enricher.whoQueue = {}
Enricher.whoPending = nil
Enricher.whoFrame = nil
Enricher.classFileToId = {}
Enricher.raceFileToId = {}

function Enricher:Init()
    self:BuildLookupTables()
    self.whoFrame = CreateFrame("Frame")
    self.whoFrame:RegisterEvent("WHO_LIST_UPDATE")
    self.whoFrame:SetScript("OnEvent", function()
        self:OnWhoListUpdate()
    end)
end

function Enricher:BuildLookupTables()
    self.classFileToId = {}
    for id = 1, 13 do
        local _, file = GetClassInfo(id)
        if file then
            self.classFileToId[file] = id
            self.classFileToId[string.lower(file)] = id
        end
    end

    self.raceFileToId = {}
    for id = 1, 12 do
        if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
            local raceInfo = C_CreatureInfo.GetRaceInfo(id)
            if raceInfo and raceInfo.clientFileString then
                self.raceFileToId[raceInfo.clientFileString] = id
                self.raceFileToId[string.lower(raceInfo.clientFileString)] = id
            end
        end
    end
end

function Enricher:NormalizeName(name)
    return name and string.lower(Util:GetShortPlayerName(name) or name) or ""
end

function Enricher:NormalizeWhoName(name)
    if not name then
        return nil
    end
    return string.lower(Util:GetShortPlayerName(name) or name)
end

function Enricher:GetGuildName()
    return GetGuildInfo("player")
end

function Enricher:IsSameGuild(guildName)
    local myGuild = self:GetGuildName()
    if not myGuild or myGuild == "" or not guildName or guildName == "" then
        return false
    end
    return string.lower(myGuild) == string.lower(guildName)
end

function Enricher:ClassFileToId(classFile)
    if not classFile then
        return nil
    end
    if DeathNotificationLib and DeathNotificationLib.CLASS_FILE_TO_ID then
        local id = DeathNotificationLib.CLASS_FILE_TO_ID[classFile]
        if id then
            return id
        end
    end
    return self.classFileToId[classFile] or self.classFileToId[string.lower(classFile)]
end

function Enricher:RaceToId(raceFile, raceName)
    if DeathNotificationLib then
        if raceName and DeathNotificationLib.RACE_NAME_TO_ID then
            local id = DeathNotificationLib.RACE_NAME_TO_ID[raceName]
            if id then
                return id
            end
        end
        if raceFile and DeathNotificationLib.RACE_FILE_TO_ID then
            local id = DeathNotificationLib.RACE_FILE_TO_ID[raceFile]
            if id then
                return id
            end
        end
    end

    if raceFile then
        local id = self.raceFileToId[raceFile] or self.raceFileToId[string.lower(raceFile)]
        if id then
            return id
        end
    end

    if raceName then
        for id = 1, 12 do
            if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
                local raceInfo = C_CreatureInfo.GetRaceInfo(id)
                if raceInfo and raceInfo.raceName
                    and string.lower(raceInfo.raceName) == string.lower(raceName) then
                    return id
                end
            end
        end
    end
    return nil
end

function Enricher:RaceClassFromGUID(guid)
    if not guid or guid == "" or not GetPlayerInfoByGUID then
        return nil, nil
    end
    local ok, englishClass, _, englishRace = pcall(GetPlayerInfoByGUID, guid)
    if not ok then
        return nil, nil
    end
    local classId = englishClass and self:ClassFileToId(englishClass) or nil
    local raceId = englishRace and self:RaceToId(englishRace, nil) or nil
    return raceId, classId
end

function Enricher:IsGuildMemberByRoster(name)
    if not IsInGuild() or not name then
        return false, nil
    end
    local target = self:NormalizeName(name)
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local rosterName, _, _, level, _, _, _, _, _, _, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if rosterName and self:NormalizeName(rosterName) == target then
            local classId = self:ClassFileToId(classFile)
            local raceId, guidClassId = self:RaceClassFromGUID(guid)
            return true, {
                guild = self:GetGuildName(),
                level = level,
                classId = classId or guidClassId,
                raceId = raceId,
            }
        end
    end
    return false, nil
end

function Enricher:PassesGuildFilter(name, guildHint)
    if guildHint and self:IsSameGuild(guildHint) then
        return true
    end
    return self:IsGuildMemberByRoster(name)
end

function Enricher:ApplyImmediateEnrichment(death, playerGuid)
    if not death then
        return death
    end

    local _, rosterInfo = self:IsGuildMemberByRoster(death.name)
    if rosterInfo then
        self:ApplyWhoInfo(death, rosterInfo)
    end

    if playerGuid and (not death.classId or not death.raceId) then
        local raceId, classId = self:RaceClassFromGUID(playerGuid)
        if raceId then
            death.raceId = raceId
        end
        if classId then
            death.classId = classId
        end
    end

    return death
end

function Enricher:WhoInfoFromApi(info)
    if not info then
        return nil
    end
    if type(info) == "table" and info.classId then
        return info
    end

    local classFile = info.filename or info.classFile
    local raceName = info.raceStr or info.race
    return {
        name = info.fullName or info.name,
        guild = info.fullGuildName or info.guild,
        level = info.level,
        classId = self:ClassFileToId(classFile),
        raceId = self:RaceToId(info.raceFile, raceName),
    }
end

function Enricher:QueueWho(name, callback)
    if not name or name == "" then
        return
    end

    if DeathNotificationLib and DeathNotificationLib.WhoPlayer then
        DeathNotificationLib.WhoPlayer(name, function(info)
            if callback then
                callback(self:WhoInfoFromApi(info))
            end
        end)
        return
    end

    table.insert(self.whoQueue, { name = name, callback = callback })
    self:PumpWhoQueue()
end

function Enricher:PumpWhoQueue()
    if self.whoPending or #self.whoQueue == 0 then
        return
    end
    local item = table.remove(self.whoQueue, 1)
    self.whoPending = item
    self.whoPendingKey = self:NormalizeWhoName(item.name)

    if FriendsFrame then
        FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
    end
    if C_FriendList and C_FriendList.SetWhoToUi then
        C_FriendList.SetWhoToUi(true)
    end

    local query = 'n-"' .. Util:GetShortPlayerName(item.name) .. '"'
    if C_FriendList and C_FriendList.SendWho then
        C_FriendList.SendWho(query)
    else
        SendWho(query)
    end

    C_Timer.After(5, function()
        if self.whoPending == item then
            self:FinishWhoRequest(nil)
        end
    end)
end

function Enricher:FinishWhoRequest(info)
    local item = self.whoPending
    self.whoPending = nil
    self.whoPendingKey = nil

    if FriendsFrame then
        FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
    end

    if item and item.callback then
        item.callback(self:WhoInfoFromApi(info))
    end
    self:PumpWhoQueue()
end

function Enricher:ParseWhoResult(index)
    if C_FriendList and C_FriendList.GetWhoInfo then
        local result = C_FriendList.GetWhoInfo(index)
        if type(result) == "table" then
            return {
                name = result.fullName or result.name,
                guild = result.fullGuildName or result.guild,
                level = result.level,
                classFile = result.filename or result.classFile,
                raceFile = result.raceFile,
                raceName = result.raceStr or result.race,
            }
        end
        local name, guild, level, _, _, _, classFile, _, raceFile = C_FriendList.GetWhoInfo(index)
        return {
            name = name,
            guild = guild,
            level = level,
            classFile = classFile,
            raceFile = raceFile,
        }
    end
    if GetWhoInfo then
        local name, guild, level, _, _, _, classFile = GetWhoInfo(index)
        return {
            name = name,
            guild = guild,
            level = level,
            classFile = classFile,
        }
    end
end

function Enricher:ReadWhoResult(name)
    local target = self:NormalizeWhoName(name)
    local count = 0
    if C_FriendList and C_FriendList.GetNumWhoResults then
        count = C_FriendList.GetNumWhoResults()
    elseif GetNumWhoResults then
        count = GetNumWhoResults()
    end
    for i = 1, count do
        local parsed = self:ParseWhoResult(i)
        if parsed and parsed.name and self:NormalizeWhoName(parsed.name) == target then
            return self:WhoInfoFromApi(parsed)
        end
    end
    return nil
end

function Enricher:OnWhoListUpdate()
    if not self.whoPending then
        return
    end
    local info = self:ReadWhoResult(self.whoPending.name)
    self:FinishWhoRequest(info)
end

function Enricher:ApplyWhoInfo(death, info)
    if not death or not info then
        return death
    end
    if info.level and info.level > 0 then
        death.level = info.level
    end
    if info.classId then
        death.classId = info.classId
    end
    if info.raceId then
        death.raceId = info.raceId
    end
    if info.guild then
        death.guild = info.guild
    end
    if death.classId and death.raceId and death.level and death.level > 0 then
        if death.quality ~= "full" then
            death.quality = "enriched"
        end
    end
    return death
end

function Enricher:ScheduleMissingIdentity(death, callback)
    if not death or (death.classId and death.raceId) then
        if callback then
            callback(death)
        end
        return
    end

    self:QueueWho(death.name, function(info)
        if info then
            self:ApplyWhoInfo(death, info)
            if callback then
                callback(death)
            end
        end
    end)
end
