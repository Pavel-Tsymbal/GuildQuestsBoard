local _, ns = ...

local Serializer = LibStub("AceSerializer-3.0")
local Deflate = LibStub("LibDeflate")

local Codec = {}
ns.Codec = Codec

function Codec:Encode(data)
    local serialized = Serializer:Serialize(data)
    if not serialized then
        return nil
    end
    local compressed = Deflate:CompressDeflate(serialized)
    if not compressed then
        return serialized
    end
    return Deflate:EncodeForWoWAddonChannel(compressed)
end

function Codec:Decode(payload)
    if not payload or payload == "" then
        return nil
    end
    local ok, result = pcall(function()
        local compressed = Deflate:DecodeForWoWAddonChannel(payload)
        if not compressed then
            compressed = Deflate:DecodeForPrint(payload)
        end
        if compressed then
            local decompressed = Deflate:DecompressDeflate(compressed)
            if decompressed then
                local success, data = Serializer:Deserialize(decompressed)
                if success then
                    return data
                end
            end
        end
        local success, data = Serializer:Deserialize(payload)
        if success then
            return data
        end
        return nil
    end)
    if ok then
        return result
    end
    return nil
end

function Codec:EncodeEvent(event)
    return self:Encode(event)
end

function Codec:DecodeEvent(payload)
    return self:Decode(payload)
end

function Codec:EncodeEvents(events)
    return self:Encode(events)
end

function Codec:DecodeEvents(payload)
    return self:Decode(payload)
end
