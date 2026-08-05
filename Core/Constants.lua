local _, ns = ...
ns.Constants = {
    ADDON_NAME = "GuildQuests",
    VERSION = "1.0.0",
    COMM_PREFIX = "GuildQuests",
    SCHEMA_VERSION = 1,

    HEARTBEAT_INTERVAL = 45,
    HEARTBEAT_TIMEOUT = 90,
    SCHEDULER_TICK = 30,
    EXPIRY_GRACE = 60,
    SYNC_CATCHUP_DELAY = 3,

    -- Set to false before release; grants guild settings edit access without being GM.
    DEBUG_GUILD_MASTER = false,
    DEBUG_SYNC = false,

    TITLE_MAX = 80,
    DESC_MAX = 500,
    TAG_MAX = 40,
    MAX_PARTICIPANTS = 40,
    MAX_ITEM_REWARDS = 5,

    TIME_MODE = {
        NONE = "NONE",
        DEADLINE = "DEADLINE",
        SCHEDULED = "SCHEDULED",
    },

    STATUS = {
        OPEN = "OPEN",
        CLAIMED = "CLAIMED",
        GROUP_FORMING = "GROUP_FORMING",
        IN_PROGRESS = "IN_PROGRESS",
        SUBMITTED = "SUBMITTED",
        COMPLETED = "COMPLETED",
        CLOSED = "CLOSED",
        EXPIRED = "EXPIRED",
        CANCELLED = "CANCELLED",
    },

    PARTICIPANT_STATUS = {
        ACCEPTED = "ACCEPTED",
        ACTIVE = "ACTIVE",
        SUBMITTED = "SUBMITTED",
    },

    CATEGORIES = {
        "PERMANENT",
        "ACHIEVEMENT",
        "DUNGEON",
        "FARMING",
        "CRAFTING",
        "PVP",
        "SOCIAL",
        "OTHER",
    },

    EVENT = {
        QUEST_CREATED = "QUEST_CREATED",
        QUEST_UPDATED = "QUEST_UPDATED",
        QUEST_CLAIMED = "QUEST_CLAIMED",
        QUEST_STARTED = "QUEST_STARTED",
        QUEST_SUBMITTED = "QUEST_SUBMITTED",
        QUEST_APPROVED = "QUEST_APPROVED",
        QUEST_REJECTED = "QUEST_REJECTED",
        QUEST_COMPLETED = "QUEST_COMPLETED",
        QUEST_CLOSED = "QUEST_CLOSED",
        QUEST_CANCELLED = "QUEST_CANCELLED",
        QUEST_DELETED = "QUEST_DELETED",
        QUEST_EXPIRED = "QUEST_EXPIRED",
        QUEST_SCHEDULE_STARTED = "QUEST_SCHEDULE_STARTED",
        REWARD_PAID = "REWARD_PAID",
        SETTINGS_UPDATED = "SETTINGS_UPDATED",
    },

    OPCODE = {
        HB = "HB",
        EV = "EV",
        RQ = "RQ",
        RS = "RS",
        SH = "SH",
        GA = "GA",
    },

    HISTORY = {
        CREATED = "CREATED",
        ACCEPTED = "ACCEPTED",
        STARTED = "STARTED",
        SUBMITTED = "SUBMITTED",
        APPROVED = "APPROVED",
        REJECTED = "REJECTED",
        REWARD_PAID = "REWARD_PAID",
        CLOSED = "CLOSED",
        CANCELLED = "CANCELLED",
        DELETED = "DELETED",
        EXPIRED = "EXPIRED",
        SCHEDULE_STARTED = "SCHEDULE_STARTED",
        UPDATED = "UPDATED",
    },
}
