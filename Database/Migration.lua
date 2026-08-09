local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Migration = {}
ns.Migration = Migration

function Migration:Run(db)
    db.schemaVersion = db.schemaVersion or 1

    if db.schemaVersion < 2 then
        self:ClearAllDeathData(db)
        db.schemaVersion = 2
    end

    if db.schemaVersion < 3 then
        self:RepairUnlamportedEvents(db)
        db.schemaVersion = 3
    end

    if db.schemaVersion < C.SCHEMA_VERSION then
        db.schemaVersion = C.SCHEMA_VERSION
    end
end

function Migration:ClearAllDeathData(db)
    if not db or not db.guilds then
        return
    end
    for _, store in pairs(db.guilds) do
        store.deaths = {}
        if store.events then
            local kept = {}
            for _, event in ipairs(store.events) do
                if event.type ~= C.EVENT.GUILD_MEMBER_DIED then
                    kept[#kept + 1] = event
                end
            end
            store.events = kept
        end
    end
end

function Migration:RepairUnlamportedEvents(db)
    if not db or not db.guilds then
        return
    end
    for _, store in pairs(db.guilds) do
        if store.events then
            table.sort(store.events, function(a, b)
                local left = a.wallTime or 0
                local right = b.wallTime or 0
                if left == right then
                    return (a.lamport or 0) < (b.lamport or 0)
                end
                return left < right
            end)
            local maxLamport = 0
            for _, event in ipairs(store.events) do
                if event.lamport and event.lamport >= 1 and event.lamport > maxLamport then
                    maxLamport = event.lamport
                end
            end
            local clock = math.max(store.logicalClock or 0, maxLamport)
            for _, event in ipairs(store.events) do
                if not event.lamport or event.lamport < 1 then
                    clock = clock + 1
                    event.lamport = clock
                end
            end
            store.logicalClock = clock
            store.stateHash = Util:SimpleHash(tostring(#store.events) .. ":" .. store.logicalClock)
        end
    end
end
