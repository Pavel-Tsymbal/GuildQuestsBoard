local _, ns = ...
local C = ns.Constants

local Migration = {}
ns.Migration = Migration

function Migration:Run(db)
    db.schemaVersion = db.schemaVersion or 1

    if db.schemaVersion < 2 then
        self:ClearAllDeathData(db)
        db.schemaVersion = 2
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
