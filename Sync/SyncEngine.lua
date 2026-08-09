local _, ns = ...
local C = ns.Constants
local Util = ns.Util
local Protocol = ns.Protocol

local SyncEngine = {}
ns.SyncEngine = SyncEngine

SyncEngine.catchUpTimer = nil
SyncEngine.lastCatchUpTarget = nil
SyncEngine.loginCatchUpPending = false

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
                ns.Projections:ReplayMissingDeaths()
                SyncEngine:RequestCatchUp(false)
            end)
        end
    end)
    ns.GQ:RegisterCallback("PeersUpdated", function()
        if SyncEngine.loginCatchUpPending then
            C_Timer.After(1, function()
                SyncEngine:RequestCatchUp(false, true)
            end)
        end
    end)
end

function SyncEngine:OnGuildReady()
    self.loginCatchUpPending = true
    C_Timer.After(20, function()
        self.loginCatchUpPending = false
    end)
    ns.Projections:ReplayMissingDeaths()
    ns.Heartbeat:BroadcastNow()
    C_Timer.After(2, function()
        ns.Heartbeat:BroadcastNow()
    end)
    C_Timer.After(5, function()
        ns.Heartbeat:BroadcastNow()
    end)
    C_Timer.After(C.SYNC_CATCHUP_DELAY, function()
        self:RequestCatchUp(false, true)
        ns.Transport:SendStateHash(ns.Storage:GetStateHash(), ns.Storage:GetLogicalClock())
    end)
end

function SyncEngine:OnGuildChange()
    if Util:GetGuildKey() then
        ns.Storage:EnsureGuildStore()
        ns.GuildRank:Refresh()
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
        ns.Replicator:ProcessRemoteEvent(event, sender)
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
        ns.Replicator:ProcessRemoteEvent(event, sender)
    end
    ns.Projections:ReplayMissingDeaths()
    ns.GQ:Fire("SyncComplete")
end

function SyncEngine:HandleStateHash(sender, payload)
    local hash, lamport = Protocol:ParseStateHashBeacon(payload)
    if hash ~= ns.Storage:GetStateHash() then
        self:OnHashMismatch(sender)
    end
end

function SyncEngine:GetCatchUpSince(peer, localHash, forceFull)
    if forceFull then
        return C.FULL_REPLAY_SINCE
    end
    if peer and peer.stateHash and peer.stateHash ~= localHash then
        return C.FULL_REPLAY_SINCE
    end
    local store = ns.Storage:GetGuildStore()
    if peer and peer.eventCount and store and peer.eventCount > #store.events then
        return C.FULL_REPLAY_SINCE
    end
    if ns.Storage:CountDeathEvents() > ns.Storage:CountDeathRecords() then
        return C.FULL_REPLAY_SINCE
    end
    return ns.Storage:GetMaxEventLamport()
end

function SyncEngine:SelectCatchUpPeer(forceFull)
    local localHash = ns.Storage:GetStateHash()
    local since = ns.Storage:GetMaxEventLamport()
    local bestPeer = nil
    local bestClock = -1
    local bestSince = since
    for name, peer in pairs(ns.Heartbeat:GetPeers()) do
        if name ~= Util:GetPlayerName() and peer.compatible then
            local clock = peer.logicalClock or 0
            local peerSince = self:GetCatchUpSince(peer, localHash, forceFull)
            if peerSince <= 0 or clock > since then
                if not bestPeer or clock > bestClock or (clock == bestClock and peerSince <= 0 and bestSince > 0) then
                    bestPeer = name
                    bestClock = clock
                    bestSince = peerSince
                end
            end
        end
    end
    return bestPeer, bestSince
end

function SyncEngine:OnHashMismatch(sender)
    if self.catchUpTimer then
        ns.GQ:CancelTimer(self.catchUpTimer)
    end
    self.lastCatchUpTarget = sender
    self.catchUpTimer = ns.GQ:ScheduleTimer(function()
        ns.Transport:RequestEvents(sender, C.FULL_REPLAY_SINCE)
    end, 1 + math.random() * 2)
end

function SyncEngine:RequestCatchUp(verbose, forceFull)
    if not IsInGuild() then
        return
    end
    if ns.Storage:CountDeathEvents() > ns.Storage:CountDeathRecords() then
        ns.Projections:ReplayMissingDeaths()
    end
    local bestPeer, bestSince = self:SelectCatchUpPeer(verbose or forceFull)
    if bestPeer then
        ns.Transport:RequestEvents(bestPeer, bestSince)
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
            "Local: %d quests, %d events, lamport %d (max event %d)",
            Util:CountTable(store.quests),
            #store.events,
            store.logicalClock or 0,
            ns.Storage:GetMaxEventLamport()
        ))
        gq:Print(string.format(
            "Deaths: %d records, %d death events",
            ns.Storage:CountDeathRecords(),
            ns.Storage:CountDeathEvents()
        ))
    else
        gq:Print("Local: no guild store (not in guild or roster not loaded)")
    end
    local peerCount = 0
    for name, peer in pairs(ns.Heartbeat:GetPeers()) do
        peerCount = peerCount + 1
        gq:Print(string.format(
            "Peer: %s lamport=%d events=%s hash=%s compatible=%s",
            name,
            peer.logicalClock or 0,
            peer.eventCount and tostring(peer.eventCount) or "?",
            tostring(peer.stateHash or "?"),
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
