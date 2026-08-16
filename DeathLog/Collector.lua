local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Collector = {}
ns.DeathLogCollector = Collector

Collector.frame = nil
Collector.pendingSource = nil
Collector.hardcoreChannelId = nil
Collector.channelListenerActive = false
Collector.combatLogActive = false

local DAMAGE_SUBEVENTS = {
    SWING_DAMAGE = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    RANGE_DAMAGE = true,
    ENVIRONMENTAL_DAMAGE = true,
}

function Collector:Init()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("PLAYER_DEAD")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("CHAT_MSG_SYSTEM")
    pcall(function()
        self.frame:RegisterEvent("HARDCORE_DEATHS")
    end)
    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
end

function Collector:SetCombatLogActive(active)
    if active == self.combatLogActive then
        return
    end
    self.combatLogActive = active
    if active then
        self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        self.frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self.pendingSource = nil
    end
end

function Collector:SetChannelListenerActive(active)
    if active == self.channelListenerActive then
        return
    end
    self.channelListenerActive = active
    if active then
        self.frame:RegisterEvent("CHAT_MSG_CHANNEL")
    else
        self.frame:UnregisterEvent("CHAT_MSG_CHANNEL")
    end
end

function Collector:IsHardcoreActive()
    if C_GameRules and C_GameRules.IsHardcoreActive then
        return C_GameRules.IsHardcoreActive()
    end
    return true
end

function Collector:EnsureHardcoreChannel()
    if not self:IsHardcoreActive() then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        if not self.channelRetryTimer then
            self.channelRetryTimer = C_Timer.After(3, function()
                self.channelRetryTimer = nil
                self:EnsureHardcoreChannel()
            end)
        end
        return
    end
    local channelIndex = GetChannelName("HardcoreDeaths")
    if channelIndex and channelIndex > 0 then
        self.hardcoreChannelId = channelIndex
        self:SetChannelListenerActive(true)
        return
    end
    pcall(function()
        if JoinPermanentChannel then
            JoinPermanentChannel("HardcoreDeaths")
        else
            JoinChannelByName("HardcoreDeaths")
        end
    end)
    channelIndex = GetChannelName("HardcoreDeaths")
    if channelIndex and channelIndex > 0 then
        self.hardcoreChannelId = channelIndex
        self:SetChannelListenerActive(true)
    end
end

function Collector:NormalizeChannelLabel(channelName)
    if not channelName or type(channelName) ~= "string" or channelName == "" then
        return ""
    end
    return channelName:gsub("^%d+%.%s*", ""):lower()
end

function Collector:IsHardcoreDeathChannel(channelName, channelIndex)
    local label = self:NormalizeChannelLabel(channelName)
    if label == "hardcoredeaths" or label:find("hardcoredeaths", 1, true) then
        return true
    end
    if type(channelIndex) == "number" and channelIndex > 0 then
        local resolved = GetChannelName(channelIndex)
        if type(resolved) == "string" and resolved ~= "" then
            label = self:NormalizeChannelLabel(resolved)
            if label == "hardcoredeaths" or label:find("hardcoredeaths", 1, true) then
                return true
            end
        end
    end
    return false
end

function Collector:GetPlayerZone()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local mapId
    if C_Map and C_Map.GetBestMapForUnit then
        mapId = C_Map.GetBestMapForUnit("player")
        if mapId and C_Map.GetMapInfo then
            local mapInfo = C_Map.GetMapInfo(mapId)
            if mapInfo and mapInfo.name and mapInfo.name ~= "" then
                zone = mapInfo.name
            end
        end
    end
    return zone, mapId
end

function Collector:BuildOwnDeathRecord(sourceName)
    local _, classFile = UnitClass("player")
    local classId = select(3, UnitClass("player"))
    local raceId = select(3, UnitRace("player"))
    local zone, mapId = self:GetPlayerZone()
    return ns.Schema:NewDeathRecord({
        name = Util:GetPlayerName(),
        realm = Util:GetRealmName(),
        level = UnitLevel("player"),
        classId = classId,
        raceId = raceId,
        guild = GetGuildInfo("player"),
        source = sourceName or ns.L["DEATHLOG_SOURCE_UNKNOWN"],
        zone = zone,
        mapId = mapId,
        date = Util:Now(),
        reportedBy = Util:GetPlayerName(),
        quality = "full",
    })
end

function Collector:OnCombatLog()
    local _, subevent, _, sourceName, _, _, _, destGUID, _, _, _, spellName = CombatLogGetCurrentEventInfo()
    if destGUID ~= UnitGUID("player") then
        return
    end
    if not DAMAGE_SUBEVENTS[subevent] then
        return
    end
    if subevent == "ENVIRONMENTAL_DAMAGE" then
        self.pendingSource = spellName or ns.L["DEATHLOG_SOURCE_ENVIRONMENT"]
    elseif sourceName and sourceName ~= "" then
        self.pendingSource = sourceName
    elseif spellName and spellName ~= "" then
        self.pendingSource = spellName
    end
end

function Collector:OnPlayerDead()
    if not IsInGuild() then
        self.pendingSource = nil
        return
    end
    local death = self:BuildOwnDeathRecord(self.pendingSource)
    self.pendingSource = nil
    ns.DeathLog:RecordDeath(death)
end

function Collector:ParseDeathLevel(plain)
    if not plain or plain == "" then
        return nil
    end
    return tonumber(plain:match("[Aa]t%s+[Ll]evel%s+(%d+)"))
        or tonumber(plain:match("[Tt]hey%s+were%s+[Ll]evel%s+(%d+)"))
        or tonumber(plain:match("[Ll]evel%s+(%d+)"))
        or tonumber(plain:match("%([Ll]evel%s+(%d+)%)"))
        or tonumber(plain:match("(%d+)[%-%s]*[Gg][Oo][%-%s]*[Uu]ров"))
        or tonumber(plain:match("[Uu]ров(?:ень)?[^%d]*(%d+)"))
        or tonumber(plain:match("(%d+)%s*[Uu]ров"))
        or tonumber(plain:match("(%d+)%s*[Уу]ров"))
end

function Collector:ParseBlizzardDeathMessage(text)
    if not text or text == "" then
        return nil
    end

    local name = Util:ExtractPlayerLinkName(text)
    local plain = Util:StripChatLinks(text)
    plain = Util:Trim(plain)

    if not name then
        name = plain:match("^([^%s]+)")
    end
    name = Util:SanitizePlayerName(name)
    if not name or name == "" then
        return nil
    end

    local level = self:ParseDeathLevel(plain)

    local source, zone = plain:match("[Ss]lain%s+by%s+(.-)%s+in%s+(.+)")
    if not source then
        source = plain:match("[Uu]бит%s+([^%.%[!]+)")
            or plain:match("[Cc]lain%s+([^%.%[!]+)")
            or plain:match("[Pp]ogib%s+([^%.%[!]+)")
            or plain:match("[Bb]y%s+([^%.%[!]+)")
            or plain:match("[Ff]rom%s+([^%.%[!]+)")
            or plain:match("[Tt]o%s+([^%.%[!]+)")
    end
    if not zone then
        zone = plain:match("[Ii]n%s+([^%.%[!]+)")
            or plain:match("[Vv]%s+([^%.%[!]+)")
            or plain:match("[Вв]%s+([^%.%[!]+)")
    end

    if source then
        source = Util:Trim(source)
        local beforeIn = source:match("^(.-)%s+[Ii]n%s+")
            or source:match("^(.-)%s+[Vv]%s+")
            or source:match("^(.-)%s+[Вв]%s+")
        if beforeIn then
            source = Util:Trim(beforeIn)
        end
    end
    if zone then
        zone = Util:Trim(zone)
        zone = zone:match("^(.-)!") or zone
        zone = zone:match("^(.-)%s+They%s+were") or zone
        zone = Util:Trim(zone)
    end

    return {
        name = name,
        level = level,
        source = source,
        zone = zone,
    }
end

function Collector:SubmitBlizzardDeath(parsed, playerGuid)
    local death = ns.Schema:NewDeathRecord({
        name = parsed.name,
        realm = Util:GetRealmName(),
        level = parsed.level or 0,
        source = parsed.source or ns.L["DEATHLOG_SOURCE_UNKNOWN"],
        zone = parsed.zone or "",
        date = Util:Now(),
        reportedBy = Util:GetPlayerName(),
        quality = "partial",
    })

    ns.DeathLogEnricher:ApplyImmediateEnrichment(death, playerGuid)

    local function commit()
        if not ns.DeathLog:IsGuildMemberDeath(death.name, death.guild) then
            return
        end
        ns.DeathLog:RecordDeath(death)
        ns.DeathLog:ScheduleDNLBackfill(death.name)
        ns.DeathLogEnricher:ScheduleMissingIdentity(death, function(updated)
            ns.DeathLog:MergeDeath(updated)
        end)
    end

    local isMember, rosterInfo = ns.DeathLogEnricher:IsGuildMemberByRoster(death.name)
    if isMember then
        if rosterInfo then
            ns.DeathLogEnricher:ApplyWhoInfo(death, rosterInfo)
        end
        commit()
    end
end

function Collector:OnChannelDeathMessage(message, playerGuid)
    if not IsInGuild() then
        return
    end
    local parsed = self:ParseBlizzardDeathMessage(message)
    if not parsed then
        return
    end
    self:SubmitBlizzardDeath(parsed, playerGuid)
end

function Collector:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:EnsureHardcoreChannel()
        if IsInGuild() and InCombatLockdown and InCombatLockdown() then
            self:SetCombatLogActive(true)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if IsInGuild() then
            self:SetCombatLogActive(true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:SetCombatLogActive(false)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatLog()
    elseif event == "PLAYER_DEAD" then
        self:OnPlayerDead()
    elseif event == "HARDCORE_DEATHS" then
        local message = ...
        self:OnChannelDeathMessage(message)
    elseif event == "CHAT_MSG_CHANNEL" then
        local message, _, _, channelName, _, _, _, channelIndex, _, _, _, playerGuid = ...
        if self:IsHardcoreDeathChannel(channelName, channelIndex) then
            self:OnChannelDeathMessage(message, playerGuid)
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        if message and (message:find("has died", 1, true) or message:find("погиб", 1, true) or message:find("умер", 1, true)) then
            self:OnChannelDeathMessage(message)
        end
    end
end
