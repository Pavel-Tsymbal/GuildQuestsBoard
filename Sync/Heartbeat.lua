local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Heartbeat = {}
ns.Heartbeat = Heartbeat

Heartbeat.peers = {}
Heartbeat.timer = nil

function Heartbeat:Init()
    self.timer = ns.GQ:ScheduleRepeatingTimer(function()
        Heartbeat:Tick()
    end, C.HEARTBEAT_INTERVAL)
    ns.GQ:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        Heartbeat:PrunePeers()
    end)
end

function Heartbeat:Stop()
    if self.timer then
        ns.GQ:CancelTimer(self.timer)
        self.timer = nil
    end
end

function Heartbeat:OnRosterUpdate()
    self:PrunePeers()
end

function Heartbeat:Tick()
    if not Util:GetGuildKey() then
        return
    end
    self:PrunePeers()
    ns.Transport:SendHeartbeat({
        version = C.VERSION,
        lamport = ns.Storage:GetLogicalClock(),
        stateHash = ns.Storage:GetStateHash(),
        guildKey = Util:GetGuildKey(),
        settingsRevision = (ns.Storage:GetSettings() or {}).revision or 0,
    })
    self:RegisterPeer(
        Util:GetPlayerName(),
        C.VERSION,
        ns.Storage:GetLogicalClock(),
        ns.Storage:GetStateHash(),
        (ns.Storage:GetSettings() or {}).revision or 0
    )
end

function Heartbeat:RegisterPeer(name, version, lamport, stateHash, settingsRevision)
    if not name then
        return
    end
    name = Util:GetShortPlayerName(name)
    local hadPeer = self.peers[name] ~= nil
    local wasCompatible = hadPeer and self.peers[name].compatible
    self.peers[name] = {
        name = name,
        addonVersion = version,
        lastHeartbeat = Util:Now(),
        logicalClock = lamport or 0,
        stateHash = stateHash,
        settingsRevision = settingsRevision or 0,
        compatible = Util:VersionsCompatible(version),
    }
    local compatibleCount = self:GetOnlineAddonCount()
    if not hadPeer or wasCompatible ~= self.peers[name].compatible then
        ns.GQ:Fire("PeersUpdated", compatibleCount)
    end
end

function Heartbeat:HandleHeartbeat(sender, data)
    if data.guildKey and not Util:SameGuildKey(data.guildKey, Util:GetGuildKey()) then
        return
    end
    local compatible = Util:VersionsCompatible(data.version)
    self:RegisterPeer(sender, data.version, data.lamport, data.stateHash, data.settingsRevision)
    if not compatible then
        ns.GQ:Fire("VersionMismatch", sender, data.version)
    end
    if data.stateHash and data.stateHash ~= ns.Storage:GetStateHash() then
        ns.SyncEngine:OnHashMismatch(sender)
    end
end

function Heartbeat:PrunePeers()
    local now = Util:Now()
    local changed = false
    for name, peer in pairs(self.peers) do
        if now - peer.lastHeartbeat > C.HEARTBEAT_TIMEOUT then
            self.peers[name] = nil
            changed = true
        end
    end
    if changed then
        ns.GQ:Fire("PeersUpdated", self:GetOnlineAddonCount())
    end
end

function Heartbeat:BroadcastNow()
    self:Tick()
end

function Heartbeat:GetOnlineAddonCount()
    self:PrunePeers()
    local count = 0
    for _, peer in pairs(self.peers) do
        if peer.compatible then
            count = count + 1
        end
    end
    if count == 0 then
        return 1
    end
    return count
end

function Heartbeat:GetPeers()
    self:PrunePeers()
    return self.peers
end

function Heartbeat:HasVersionMismatch()
    for _, peer in pairs(self.peers) do
        if not peer.compatible then
            return true
        end
    end
    return false
end
