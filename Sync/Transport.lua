local _, ns = ...
local C = ns.Constants
local Protocol = ns.Protocol

local Transport = {}
ns.Transport = Transport

function Transport:Init()
    ns.GQ:RegisterComm(C.COMM_PREFIX, function(prefix, message, channel, sender)
        Transport:OnCommReceived(prefix, message, channel, sender)
    end)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(C.COMM_PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(C.COMM_PREFIX)
    end
end

function Transport:ResolveMemberName(name)
    if not name or not IsInGuild() then
        return name
    end
    local short = ns.Util:GetShortPlayerName(name)
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local rosterName = GetGuildRosterInfo(i)
        if rosterName and ns.Util:GetShortPlayerName(rosterName) == short then
            return rosterName
        end
    end
    return name
end

function Transport:Send(opcode, payload, channel, target)
    channel = channel or "GUILD"
    local message = Protocol:Pack(opcode, payload or "")
    ns.GQ:SendCommMessage(C.COMM_PREFIX, message, channel, target, "NORMAL")
end

function Transport:SendToGuild(opcode, payload)
    if not IsInGuild() then
        return
    end
    self:Send(opcode, payload, "GUILD")
end

function Transport:SendWhisper(opcode, payload, target)
    if not target then
        return
    end
    target = self:ResolveMemberName(target)
    self:Send(opcode, payload, "WHISPER", target)
end

function Transport:OnCommReceived(prefix, message, channel, sender)
    if prefix ~= C.COMM_PREFIX then
        return
    end
    local opcode, payload = Protocol:Unpack(message)
    if not opcode then
        if C.DEBUG_SYNC then
            ns.GQ:Print("Ignored addon message (bad opcode) from " .. tostring(sender))
        end
        return
    end
    sender = ns.Util:GetShortPlayerName(sender)
    ns.SyncEngine:HandleMessage(opcode, payload, sender, channel)
end

function Transport:BroadcastEvent(event)
    local encoded = ns.Codec:EncodeEvent(event)
    if encoded then
        self:SendToGuild(C.OPCODE.EV, encoded)
    end
end

function Transport:SendEvents(target, events)
    local encoded = ns.Codec:EncodeEvents(events)
    if encoded and target then
        self:SendWhisper(C.OPCODE.RS, encoded, target)
    end
end

function Transport:RequestEvents(target, sinceLamport)
    local payload = Protocol:BuildEventRequest(sinceLamport, ns.Util:GetGuildKey())
    self:SendWhisper(C.OPCODE.RQ, payload, target)
end

function Transport:SendHeartbeat(data)
    local payload = Protocol:BuildHeartbeat(
        data.version,
        data.lamport,
        data.stateHash,
        data.guildKey,
        data.eventCount
    )
    self:SendToGuild(C.OPCODE.HB, payload)
end

function Transport:SendStateHash(stateHash, lamport)
    self:SendToGuild(C.OPCODE.SH, Protocol:BuildStateHashBeacon(stateHash, lamport))
end
