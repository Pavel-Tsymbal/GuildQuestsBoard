local _, ns = ...
local Util = ns.Util

local Enricher = {}
ns.DeathLogEnricher = Enricher

Enricher.classFileToId = {}
Enricher.raceFileToId = {}
Enricher.memberByName = {}
Enricher.rosterFullName = {}
Enricher.memberCacheReady = false
Enricher.rebuildTimer = nil

function Enricher:Init()
    self:BuildLookupTables()
    ns.GQ:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        self:ScheduleMemberCacheRebuild()
    end)
    ns.GQ:RegisterEvent("PLAYER_GUILD_UPDATE", function()
        self:InvalidateMemberCache()
    end)
end

function Enricher:InvalidateMemberCache()
    self.memberCacheReady = false
end

function Enricher:ScheduleMemberCacheRebuild()
    if self.rebuildTimer then
        return
    end
    self.rebuildTimer = C_Timer.After(0.5, function()
        self.rebuildTimer = nil
        self:RebuildMemberCache()
    end)
end

function Enricher:RebuildMemberCache()
    self.memberByName = {}
    self.rosterFullName = {}
    self.memberCacheReady = false
    if not IsInGuild() then
        return
    end
    local guildName = self:GetGuildName()
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local rosterName, _, _, level, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
        if rosterName then
            local key = self:NormalizeName(rosterName)
            self.rosterFullName[key] = rosterName
            self.memberByName[key] = {
                guild = guildName,
                level = level,
                classId = self:ClassFileToId(classFile),
            }
        end
    end
    self.memberCacheReady = true
end

function Enricher:EnsureMemberCache()
    if not self.memberCacheReady then
        self:RebuildMemberCache()
    end
end

function Enricher:GetRosterFullName(name)
    if not name then
        return nil
    end
    self:EnsureMemberCache()
    return self.rosterFullName[self:NormalizeName(name)]
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
    self:EnsureMemberCache()
    local info = self.memberByName[self:NormalizeName(name)]
    return info ~= nil, info
end

function Enricher:PassesGuildFilter(name, guildHint)
    if guildHint and self:IsSameGuild(guildHint) then
        return true
    end
    if not name or not IsInGuild() then
        return false
    end
    self:EnsureMemberCache()
    return self.memberByName[self:NormalizeName(name)] ~= nil
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

function Enricher:LookupIdentity(name, callback)
    if not name or name == "" then
        if callback then
            callback(nil)
        end
        return
    end

    local _, rosterInfo = self:IsGuildMemberByRoster(name)
    if callback then
        callback(rosterInfo and self:WhoInfoFromApi(rosterInfo) or nil)
    end
end

function Enricher:ApplyWhoInfo(death, info)
    if not death or not info then
        return death
    end
    if info.level and info.level > 0 then
        death.level = ns.Storage:PreferDeathLevel(death.level, info.level)
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

    if not self:IsGuildMemberByRoster(death.name) then
        if callback then
            callback(death)
        end
        return
    end

    self:LookupIdentity(death.name, function(info)
        if info then
            self:ApplyWhoInfo(death, info)
        end
        if callback then
            callback(death)
        end
    end)
end
