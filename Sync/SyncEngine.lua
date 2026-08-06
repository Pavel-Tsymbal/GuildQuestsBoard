local _, ns = ...
local C = ns.Constants
local Util = ns.Util
local Protocol = ns.Protocol

local SyncEngine = {}
ns.SyncEngine = SyncEngine

SyncEngine.catchUpTimer = nil
SyncEngine.lastCatchUpTarget = nil
SyncEngine.settingsCatchUpAttempts = 0
SyncEngine.MAX_SETTINGS_CATCHUP_ATTEMPTS = 3

function SyncEngine:Init()
    ns.GQ:RegisterEvent("PLAYER_GUILD_UPDATE", function()
        SyncEngine:OnGuildChange()
    end)
    ns.GQ:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        SyncEngine:OnGuildChange()
    end)
    ns.GQ:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        if Util:GetGuildKey() then
            C_Timer.After(2, function()
                SyncEngine:RequestCatchUp(false)
            end)
        end
    end)
    ns.GQ:RegisterCallback("GuildRosterUpdated", function()
        ns.Replicator:FlushPendingSettingsEvents()
        if not SyncEngine:HasSettingsEvent() then
            C_Timer.After(1, function()
                SyncEngine:RequestCatchUpForMissingSettings()
            end)
        end
    end)
end

function SyncEngine:OnGuildReady()
    ns.Heartbeat:BroadcastNow()
    C_Timer.After(2, function()
        ns.Heartbeat:BroadcastNow()
    end)
    C_Timer.After(5, function()
        ns.Heartbeat:BroadcastNow()
    end)
    C_Timer.After(C.SYNC_CATCHUP_DELAY, function()
        self:RequestCatchUp(false)
        ns.Transport:SendStateHash(ns.Storage:GetStateHash(), ns.Storage:GetLogicalClock())
    end)
    C_Timer.After(C.SYNC_CATCHUP_DELAY + 4, function()
        ns.Replicator:FlushPendingSettingsEvents()
        self:RequestCatchUpForMissingSettings()
    end)
end

function SyncEngine:OnGuildChange()
    if Util:GetGuildKey() then
        ns.Storage:EnsureGuildStore()
        ns.GuildRank:Refresh()
        self.settingsCatchUpAttempts = 0
        self:OnGuildReady()
        ns.GQ:Fire("GuildChanged")
        ns.MainUI:UpdateTexts()
    else
        ns.Storage:OnGuildLeft()
        ns.MainUI:Hide()
        ns.QuestDetail:Hide()
        ns.CreateQuest:Hide()
        ns.GQ:Fire("GuildLeft")
    end
end

function SyncEngine:HandleMessage(opcode, payload, sender, channel)
    if sender == Util:GetPlayerName() then
        return
    end
    if opcode == C.OPCODE.HB then
        self:HandleHeartbeat(sender, payload)
    elseif opcode == C.OPCODE.EV then
        self:HandleEvent(payload, sender)
    elseif opcode == C.OPCODE.RQ then
        self:HandleEventRequest(sender, payload)
    elseif opcode == C.OPCODE.RS then
        self:HandleEventResponse(payload, sender)
    elseif opcode == C.OPCODE.SH then
        self:HandleStateHash(sender, payload)
    end
end

function SyncEngine:HandleHeartbeat(sender, payload)
    local data = Protocol:ParseHeartbeat(payload)
    ns.Heartbeat:HandleHeartbeat(sender, data)
end

function SyncEngine:HandleEvent(payload, sender)
    local event = ns.Codec:DecodeEvent(payload)
    if event then
        event.actor = event.actor or sender
        local applied = ns.Replicator:ProcessRemoteEvent(event, sender)
        if applied and event.type == C.EVENT.SETTINGS_UPDATED then
            self.settingsCatchUpAttempts = 0
        end
        ns.Replicator:FlushPendingSettingsEvents()
    elseif C.DEBUG_SYNC then
        ns.GQ:Print("Decode failed for event from " .. tostring(sender))
    end
end

function SyncEngine:HandleEventRequest(sender, payload)
    local sinceLamport, guildKey = Protocol:ParseEventRequest(payload)
    if not Util:SameGuildKey(guildKey, Util:GetGuildKey()) then
        return
    end
    local events = ns.Storage:GetEventsSince(sinceLamport)
    if #events > 0 then
        ns.Transport:SendEvents(sender, events)
    end
end

function SyncEngine:HandleEventResponse(payload, sender)
    local events = ns.Codec:DecodeEvents(payload)
    if not events or type(events) ~= "table" then
        return
    end
    table.sort(events, Util.CompareEventOrder)
    for _, event in ipairs(events) do
        ns.Replicator:ProcessRemoteEvent(event, sender, { allowRelayedSettings = true })
    end
    ns.Replicator:FlushPendingSettingsEvents()
    if self:HasSettingsEvent() then
        self.settingsCatchUpAttempts = 0
    else
        self:RequestCatchUpForMissingSettings()
    end
    ns.GQ:Fire("SyncComplete")
end

function SyncEngine:HandleStateHash(sender, payload)
    local hash, lamport = Protocol:ParseStateHashBeacon(payload)
    if hash ~= ns.Storage:GetStateHash() then
        self:OnHashMismatch(sender)
    end
end

function SyncEngine:GetSettingsRevision()
    local settings = ns.Storage:GetSettings()
    return settings and settings.revision or 0
end

function SyncEngine:HasSettingsEvent()
    local store = ns.Storage:GetGuildStore()
    if not store then
        return false
    end
    for _, event in ipairs(store.events) do
        if event.type == C.EVENT.SETTINGS_UPDATED then
            return true
        end
    end
    return false
end

function SyncEngine:GetCatchUpSinceLamport()
    local since = ns.Storage:GetMaxEventLamport()
    if since > 0 and not self:HasSettingsEvent() then
        return 0
    end
    return since
end

function SyncEngine:SelectCatchUpPeer(since, localHash)
    local bestPeer = nil
    local bestScore = -1
    local localRevision = self:GetSettingsRevision()
    local needsSettings = not self:HasSettingsEvent()

    for name, peer in pairs(ns.Heartbeat:GetPeers()) do
        if name ~= Util:GetPlayerName() and peer.compatible then
            local lamport = peer.logicalClock or 0
            local hashMismatch = peer.stateHash and peer.stateHash ~= localHash
            if lamport > since or hashMismatch then
                local score = lamport
                if hashMismatch then
                    score = score + 1000000
                end
                if needsSettings and (peer.settingsRevision or 0) > localRevision then
                    score = score + 500000 + (peer.settingsRevision or 0)
                end
                if score > bestScore then
                    bestScore = score
                    bestPeer = name
                end
            end
        end
    end

    return bestPeer
end

function SyncEngine:RequestCatchUpForMissingSettings()
    if self:HasSettingsEvent() then
        self.settingsCatchUpAttempts = 0
        return false
    end
    if self.settingsCatchUpAttempts >= self.MAX_SETTINGS_CATCHUP_ATTEMPTS then
        return false
    end

    local localRevision = self:GetSettingsRevision()
    local bestPeer = nil
    local bestRevision = localRevision

    for name, peer in pairs(ns.Heartbeat:GetPeers()) do
        if name ~= Util:GetPlayerName() and peer.compatible then
            local rev = peer.settingsRevision or 0
            if rev > bestRevision then
                bestRevision = rev
                bestPeer = name
            end
        end
    end

    if not bestPeer then
        bestPeer = self:SelectCatchUpPeer(0, ns.Storage:GetStateHash())
    end

    if bestPeer then
        self.settingsCatchUpAttempts = self.settingsCatchUpAttempts + 1
        ns.Transport:RequestEvents(bestPeer, 0)
        if C.DEBUG_SYNC then
            ns.GQ:Print(string.format(ns.L["DEBUG_SYNC_SETTINGS_CATCHUP"], bestPeer))
        end
        return true
    end

    return false
end

function SyncEngine:OnHashMismatch(sender)
    if self.catchUpTimer then
        ns.GQ:CancelTimer(self.catchUpTimer)
    end
    self.lastCatchUpTarget = sender
    self.catchUpTimer = ns.GQ:ScheduleTimer(function()
        ns.Transport:RequestEvents(sender, SyncEngine:GetCatchUpSinceLamport())
    end, 1 + math.random() * 2)
end

function SyncEngine:RequestCatchUp(verbose)
    if not IsInGuild() then
        return
    end
    local since = self:GetCatchUpSinceLamport()
    local localHash = ns.Storage:GetStateHash()
    local bestPeer = self:SelectCatchUpPeer(since, localHash)
    if bestPeer then
        ns.Transport:RequestEvents(bestPeer, since)
        if verbose then
            ns.GQ:Print(ns.L["SLASH_SYNC"])
        end
    elseif verbose then
        ns.GQ:Print(ns.L["SLASH_SYNC"])
        ns.Transport:SendStateHash(ns.Storage:GetStateHash(), ns.Storage:GetLogicalClock())
        if ns.Heartbeat:GetOnlineAddonCount() <= 1 then
            ns.GQ:Print(ns.L["SLASH_SYNC_NO_PEERS"])
        end
    end
end

function SyncEngine:GetOnlineAddonCount()
    return ns.Heartbeat:GetOnlineAddonCount()
end

function SyncEngine:PrintDebug()
    local gq = ns.GQ
    gq:Print("--- GuildQuests debug ---")
    gq:Print("Version: " .. C.VERSION)
    gq:Print("Guild key: " .. tostring(Util:GetGuildKey()))
    gq:Print("In guild: " .. tostring(IsInGuild()))
    local store = ns.Storage:GetGuildStore()
    if store then
        gq:Print(string.format(
            "Local: %d quests, %d events, lamport %d (applied %d)",
            Util:CountTable(store.quests),
            #store.events,
            store.logicalClock or 0,
            ns.Storage:GetMaxEventLamport()
        ))
        local settings = store.settings or {}
        gq:Print(string.format(
            "Settings: revision %d, has SETTINGS_UPDATED: %s, pending: %d",
            settings.revision or 0,
            tostring(self:HasSettingsEvent()),
            ns.Replicator:GetPendingSettingsCount()
        ))
    else
        gq:Print("Local: no guild store (not in guild or roster not loaded)")
    end
    local peerCount = 0
    for name, peer in pairs(ns.Heartbeat:GetPeers()) do
        peerCount = peerCount + 1
        gq:Print(string.format(
            "Peer: %s lamport=%d settingsRev=%d compatible=%s",
            name,
            peer.logicalClock or 0,
            peer.settingsRevision or 0,
            tostring(peer.compatible)
        ))
    end
    if peerCount == 0 then
        gq:Print("Peers: none (guild addon messages not received yet)")
    end
    gq:Print(string.format(
        "Online with addon (compatible): %d (quorum create: %d)",
        ns.Heartbeat:GetOnlineAddonCount(),
        (ns.Storage:GetSettings() or ns.Schema:DefaultGuildSettings()).sync.minOnlineToCreate or 2
    ))
    local sample = { type = C.EVENT.QUEST_CREATED, id = "debug-test", payload = { id = "debug-test", title = "Test" } }
    local encoded = ns.Codec:EncodeEvent(sample)
    local decoded = encoded and ns.Codec:DecodeEvent(encoded)
    if encoded and decoded then
        gq:Print("Codec self-test: OK")
    else
        gq:Print("Codec self-test: FAILED"
            .. (encoded and "" or " (encode failed)")
            .. (encoded and not decoded and " (decode failed)" or ""))
    end
    if encoded then
        local opcode, rest = Protocol:Unpack(Protocol:Pack(C.OPCODE.EV, encoded))
        gq:Print("Protocol self-test: " .. ((opcode == C.OPCODE.EV and rest == encoded) and "OK" or "FAILED"))
    end
    gq:Print("--- end debug ---")
end
