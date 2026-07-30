local _, ns = ...
local C = ns.Constants

local Migration = {}
ns.Migration = Migration

function Migration:Run(db)
    db.schemaVersion = db.schemaVersion or 1
    if db.schemaVersion < C.SCHEMA_VERSION then
        db.schemaVersion = C.SCHEMA_VERSION
    end
end
