local _, ns = ...
local C = ns.Constants
local Protocol = ns.Protocol

local Transport = {}
ns.Transport = Transport

Transport.messageQueue = {}
Transport.messagePumpActive = false

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

function Transport:Send(opcode, payload, channel, target, prio)
    channel = channel or "GUILD"
    local message = Protocol:Pack(opcode, payload or "")
    pcall(ns.GQ.SendCommMessage, ns.GQ, C.COMM_PREFIX, message, channel, target, prio or "NORMAL")
end

function Transport:SendToGuild(opcode, payload)
    if not IsInGuild() then
        return
    end
    self:Send(opcode, payload, "GUILD")
end

function Transport:SendWhisper(opcode, payload, target, prio)
    if not target then
        return false
    end
    local whisperTarget = ns.Util:FindOnlineRosterName(target)
    if not whisperTarget then
        return false
    end
    self:Send(opcode, payload, "WHISPER", whisperTarget, prio)
    return true
end

function Transport:PumpMessageQueue()
    if self.messagePumpActive or #self.messageQueue == 0 then
        return
    end
    self.messagePumpActive = true
    local item = table.remove(self.messageQueue, 1)
    ns.SyncEngine:HandleMessage(item.opcode, item.payload, item.sender, item.channel)
    self.messagePumpActive = false
    if #self.messageQueue > 0 then
        C_Timer.After(0, function()
            Transport:PumpMessageQueue()
        end)
    end
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
    table.insert(self.messageQueue, {
        opcode = opcode,
        payload = payload,
        sender = ns.Util:GetShortPlayerName(sender),
        channel = channel,
    })
    self:PumpMessageQueue()
end

function Transport:BroadcastEvent(event)
    local encoded = ns.Codec:EncodeEvent(event)
    if encoded then
        self:SendToGuild(C.OPCODE.EV, encoded)
    end
end

function Transport:SendEvents(target, events)
    if not target or not events or #events == 0 then
        return
    end
    self:SendEventChunks(target, events, 1, 20)
end

function Transport:SendEventChunks(target, events, startIndex, chunkSize)
    local chunk = {}
    local endIndex = math.min(startIndex + chunkSize - 1, #events)
    for j = startIndex, endIndex do
        chunk[#chunk + 1] = events[j]
    end
    local encoded = ns.Codec:EncodeEvents(chunk)
    if encoded then
        self:SendWhisper(C.OPCODE.RS, encoded, target, "BULK")
    end
    if endIndex < #events then
        C_Timer.After(0.05, function()
            Transport:SendEventChunks(target, events, endIndex + 1, chunkSize)
        end)
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
