local _, ns = ...

local C = ns.Constants

local Util = ns.Util



local DeathLog = {}

ns.DeathLog = DeathLog



DeathLog.dnlAttached = false



function DeathLog:IsGuildMemberDeath(name, guildHint)

    return ns.DeathLogEnricher:PassesGuildFilter(name, guildHint)

end



function DeathLog:ShouldAlertDeath(death)

    if not death or not death.name then

        return false

    end

    return self:IsGuildMemberDeath(death.name, death.guild)

end



function DeathLog:Init()

    ns.DeathLogEnricher:Init()

    ns.DeathLogCollector:Init()

    ns.DeathLogNotifier:Init()

    self:TryHookDeathNotificationLib()



    ns.GQ:RegisterCallback("GuildMemberDied", function(_, death, isLocal)
        ns.DeathLogNotifier:OnDeath(death, isLocal)
        if ns.MainUI and ns.MainUI:IsDeathLogView() then
            ns.DeathLogPanel:Refresh()
        end
    end)

    ns.GQ:RegisterCallback("SyncComplete", function()
        local replayed = ns.Projections:ReplayMissingDeaths()
        if replayed > 0 and ns.MainUI and ns.MainUI:IsDeathLogView() then
            ns.DeathLogPanel:Refresh()
        end
    end)
end



function DeathLog:GetEntries(limit)

    limit = limit or C.DEATHLOG_DISPLAY_MAX

    local entries, totalCount = ns.Storage:GetDeathList(limit)

    local changed = false

    for _, entry in ipairs(entries) do

        if entry.name and (not entry.classId or not entry.raceId) then

            if self:BackfillFromDNL(entry.name) then

                changed = true

            end

        end

    end

    if changed then

        entries, totalCount = ns.Storage:GetDeathList(limit)

    end

    return entries, totalCount

end



function DeathLog:MergeDeath(death)

    if not death or not death.name or not IsInGuild() then

        return false

    end

    if not self:IsGuildMemberDeath(death.name, death.guild) then

        return false

    end



    death.name = Util:SanitizePlayerName(death.name) or death.name

    death.dedupKey = death.dedupKey or ns.Storage:MakeDeathDedupKey(death)



    local existing = ns.Storage:FindDeathForMerge(death)

    if existing then

        death.id = existing.id

        if existing.date and (not death.date or death.date == 0) then

            death.date = existing.date

        end

        death.dedupKey = existing.dedupKey or death.dedupKey

    end



    local id = ns.Storage:UpsertDeath(death)

    if not id then

        return false

    end



    local stored = ns.Storage:GetDeaths()[id] or death

    ns.GQ:Fire("GuildMemberDied", stored, false, true)

    if ns.MainUI and ns.MainUI:IsDeathLogView() then

        ns.DeathLogPanel:Refresh()

    end

    return true

end



function DeathLog:ApplyDNLIdentity(death, playerData)

    if not death or not playerData then

        return death

    end

    if playerData.class_id then

        death.classId = playerData.class_id

    end

    if playerData.race_id then

        death.raceId = playerData.race_id

    end

    if playerData.guild and playerData.guild ~= "" then

        death.guild = playerData.guild

    end

    if playerData.level and playerData.level > 0 then

        death.level = playerData.level

    end

    if death.classId and death.raceId then

        death.quality = "enriched"

    end

    return death

end



function DeathLog:BackfillFromDNL(name)

    if not name or not DeathNotificationLib or not DeathNotificationLib.GetDeathRecord then

        return false

    end



    local playerData = DeathNotificationLib.GetDeathRecord(name)

    if not playerData or (not playerData.class_id and not playerData.race_id) then

        return false

    end



    self:ImportFromDNL(playerData, true)

    return true

end



function DeathLog:ScheduleDNLBackfill(name)

    if not name then

        return

    end

    for _, delay in ipairs({ 6, 12, 20 }) do

        C_Timer.After(delay, function()

            ns.DeathLog:BackfillFromDNL(name)

        end)

    end

end



function DeathLog:ResolveDNLSource(playerData)

    if not playerData then

        return ns.L["DEATHLOG_SOURCE_UNKNOWN"]

    end

    if playerData.extra_data and playerData.extra_data.pvp_source_name then

        return playerData.extra_data.pvp_source_name

    end

    local sourceId = tonumber(playerData.source_id)

    if sourceId and DeathNotificationLib and DeathNotificationLib.ID_TO_NPC then

        local npcName = DeathNotificationLib.ID_TO_NPC[sourceId]

        if npcName and npcName ~= "" then

            return npcName

        end

    end

    return ns.L["DEATHLOG_SOURCE_UNKNOWN"]

end



function DeathLog:ResolveDNLZone(playerData)

    if not playerData then

        return ""

    end

    if playerData.map_id and C_Map and C_Map.GetMapInfo then

        local mapInfo = C_Map.GetMapInfo(playerData.map_id)

        if mapInfo and mapInfo.name and mapInfo.name ~= "" then

            return mapInfo.name

        end

    end

    if playerData.instance_id and DeathNotificationLib and DeathNotificationLib.ID_TO_INSTANCE then

        return DeathNotificationLib.ID_TO_INSTANCE[playerData.instance_id] or ""

    end

    return ""

end



function DeathLog:ImportFromDNL(playerData, mergeOnly)

    if not playerData or not playerData.name or not IsInGuild() then

        return

    end



    local name = Util:SanitizePlayerName(playerData.name) or playerData.name

    if not self:IsGuildMemberDeath(name, playerData.guild) then

        return

    end



    local existing = ns.Storage:FindDeathForMerge({

        name = name,

        realm = Util:GetRealmName(),

        date = playerData.date or Util:Now(),

    })



    if existing then

        local death = Util:CopyTable(existing)

        self:ApplyDNLIdentity(death, playerData)

        local resolvedSource = self:ResolveDNLSource(playerData)

        if resolvedSource ~= ns.L["DEATHLOG_SOURCE_UNKNOWN"] then

            death.source = resolvedSource

        end

        local resolvedZone = self:ResolveDNLZone(playerData)

        if resolvedZone ~= "" then

            death.zone = resolvedZone

        end

        self:MergeDeath(death)

        return

    end



    if mergeOnly then

        return

    end



    local death = ns.Schema:NewDeathRecord({

        name = name,

        realm = Util:GetRealmName(),

        level = playerData.level or 0,

        classId = playerData.class_id,

        raceId = playerData.race_id,

        guild = playerData.guild,

        source = self:ResolveDNLSource(playerData),

        zone = self:ResolveDNLZone(playerData),

        date = playerData.date or Util:Now(),

        reportedBy = Util:GetPlayerName(),

        quality = (playerData.class_id and playerData.race_id) and "enriched" or "partial",

    })



    self:RecordDeath(death)

end



function DeathLog:OnDNLDeath(playerData)

    self:ImportFromDNL(playerData, false)

end



function DeathLog:TryHookDeathNotificationLib()

    if not DeathNotificationLib then

        return

    end



    if DeathNotificationLib.AttachAddon and not self.dnlAttached then

        local ok = pcall(function()

            DeathNotificationLib.AttachAddon({

                name = C.ADDON_NAME,

                tag = "GQB",

                addon_version = C.VERSION,

                isUnitTracked = function(unit)

                    return UnitIsUnit(unit, "player") and IsInGuild()

                end,

                settings = {

                    addonless_logging = true,

                    peer_reporting = true,

                    auto_blizzard_deaths = true,

                },

            })

        end)

        if ok then

            self.dnlAttached = true

        end

    end



    local hooked = false

    if DeathNotificationLib.HookOnNewAddonEntry then

        hooked = DeathNotificationLib.HookOnNewAddonEntry(C.ADDON_NAME, function(playerData)

            ns.DeathLog:OnDNLDeath(playerData)

        end)

    end

    if not hooked and DeathNotificationLib.HookOnNewEntry then

        DeathNotificationLib.HookOnNewEntry(function(playerData)

            ns.DeathLog:OnDNLDeath(playerData)

        end)

    end

end



function DeathLog:RecordDeath(death)

    if not death or not death.name or not IsInGuild() then

        return false

    end

    death.name = Util:SanitizePlayerName(death.name) or death.name

    if not self:IsGuildMemberDeath(death.name, death.guild) then

        return false

    end



    death.dedupKey = death.dedupKey or ns.Storage:MakeDeathDedupKey(death)

    if not death.guild then

        local playerName = Util:GetShortPlayerName(Util:GetPlayerName())

        if playerName and Util:GetShortPlayerName(death.name) == playerName then

            death.guild = GetGuildInfo("player")

        end

    end



    local event = ns.Schema:NewEvent(C.EVENT.GUILD_MEMBER_DIED, Util:GetPlayerName(), {

        death = death,

    })

    event.lamport = ns.Storage:NextLamport()

    return ns.Replicator:ProcessLocalEvent(event)

end



function DeathLog:GetClassLabel(classId)

    if not classId or not GetClassInfo then

        return "?"

    end

    local className = GetClassInfo(classId)

    return className or "?"

end



function DeathLog:GetRaceLabel(raceId)

    if not raceId then

        return "?"

    end

    if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then

        local raceInfo = C_CreatureInfo.GetRaceInfo(raceId)

        if raceInfo and raceInfo.raceName then

            return raceInfo.raceName

        end

    end

    return "?"

end



function DeathLog:SanitizeName(name)

    return Util:SanitizePlayerName(name)

end



function DeathLog:FormatMetaLine(death)

    if not death then

        return "?"

    end

    local parts = {}

    local level = death.level and death.level > 0 and death.level or "?"

    parts[#parts + 1] = ns.L["DEATHLOG_COL_LEVEL"] .. " " .. level

    if death.classId then

        parts[#parts + 1] = self:GetClassLabel(death.classId)

    end

    if death.raceId then

        parts[#parts + 1] = self:GetRaceLabel(death.raceId)

    end

    local zone = death.zone and Util:Trim(death.zone) or ""

    if zone ~= "" then

        if zone:match("^[Bb]y%s+") or zone:match("^[Uu]бит") then

            local fixedZone = zone:match(".-%s+[Ii]n%s+(.+)")

            if fixedZone then

                zone = Util:Trim(fixedZone)

            end

        end

        zone = zone:match("^(.-)!") or zone

        zone = zone:match("^(.-)%s+They%s+were") or zone

        zone = Util:Trim(zone)

    end

    if zone ~= "" then

        parts[#parts + 1] = zone

    end

    return table.concat(parts, " | ")

end



function DeathLog:GetColoredName(death)

    local name = self:SanitizeName(death and death.name) or "?"

    if death.classId and GetClassInfo then

        local _, classFile = GetClassInfo(death.classId)

        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then

            return "|c" .. RAID_CLASS_COLORS[classFile].colorStr .. name .. "|r"

        end

    end

    return name

end



function DeathLog:FormatDate(timestamp)

    if not timestamp then

        return "?"

    end

    return date("%Y-%m-%d %H:%M", tonumber(timestamp) or timestamp)

end

