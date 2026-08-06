local _, ns = ...
local C = ns.Constants

local Protocol = {}
ns.Protocol = Protocol

-- Opcodes are always exactly two characters (HB, EV, RQ, RS, SH).
-- Payload follows immediately with no separator, so encoded data cannot break unpacking.

function Protocol:Pack(opcode, payload)
    return opcode .. (payload or "")
end

function Protocol:Unpack(message)
    if not message or message == "" then
        return nil, nil
    end
    local opcode = message:sub(1, 2)
    if self:ValidateOpcode(opcode) then
        local payload = message:sub(3)
        -- Legacy wire format used \31 between opcode and payload.
        if payload:sub(1, 1) == "\31" then
            payload = payload:sub(2)
        end
        return opcode, payload
    end
    local legacyOp, legacyPayload = message:match("^([^\31]+)\31(.*)$")
    if legacyOp and self:ValidateOpcode(legacyOp) then
        return legacyOp, legacyPayload
    end
    return nil, nil
end

function Protocol:ValidateOpcode(opcode)
    for _, value in pairs(C.OPCODE) do
        if value == opcode then
            return true
        end
    end
    return false
end

function Protocol:BuildHeartbeat(version, lamport, stateHash, guildKey, settingsRevision)
    return table.concat({
        version,
        tostring(lamport),
        stateHash or "0",
        guildKey or "",
        tostring(settingsRevision or 0),
    }, "|")
end

function Protocol:ParseHeartbeat(payload)
    local version, lamport, stateHash, guildKey, settingsRevision = payload:match("([^|]*)|([^|]*)|([^|]*)|([^|]*)|?(.*)")
    return {
        version = version,
        lamport = tonumber(lamport) or 0,
        stateHash = stateHash,
        guildKey = guildKey,
        settingsRevision = tonumber(settingsRevision) or 0,
    }
end

function Protocol:BuildStateHashBeacon(stateHash, lamport)
    return tostring(stateHash or "0") .. "|" .. tostring(lamport or 0)
end

function Protocol:ParseStateHashBeacon(payload)
    local hash, lamport = payload:match("([^|]*)|([^|]*)")
    return hash, tonumber(lamport) or 0
end

function Protocol:BuildEventRequest(sinceLamport, guildKey)
    return tostring(sinceLamport or 0) .. "|" .. (guildKey or "")
end

function Protocol:ParseEventRequest(payload)
    local lamport, guildKey = payload:match("([^|]*)|(.*)")
    return tonumber(lamport) or 0, guildKey
end
