local _, ns = ...
local C = ns.Constants
local Util = ns.Util
local Events = ns.Events

local GQ = LibStub("AceAddon-3.0"):NewAddon(
    C.ADDON_NAME,
    "AceEvent-3.0",
    "AceComm-3.0",
    "AceTimer-3.0"
)

ns.GQ = GQ
GQ.modules = {}

function GQ:OnInitialize()
    ns.ChatFilter:Init()
    ns.DB = ns.Storage
    ns.DB:Init()
    ns.Locale:Init()
    ns.PersonalSettings:Init()
    ns.AchievementTracker:Init()
    ns.AchievementNotifier:Init()
    ns.GuildRank:Init()
    ns.Permissions = ns.Rules
    ns.Projections:Init()
    ns.Replicator:Init()
    ns.Transport:Init()
    ns.Heartbeat:Init()
    ns.SyncEngine:Init()
    ns.StateMachine:Init()
    ns.Validator:Init()
    ns.QuestActions = ns.Actions
    ns.Actions:Init()
    ns.Scheduler:Init()
    ns.History = ns.Logger
    ns.Logger:Init()
    ns.GuildSettingsModule = ns.GuildSettings
    ns.GuildSettings:Init()
    ns.NotifyQueue = ns.Queue
    ns.Queue:Init()
    ns.Toast:Init()
    ns.DeathLog:Init()
    ns.UI = ns.MainUI
    ns.MainUI:Init()
    ns.QuestList:Init()
    ns.QuestDetail:Init()
    ns.CreateQuest:Init()
    ns.MainUI:RegisterEscapeFrames()
    ns.SearchFilter:Init()
    ns.MainUI:LayoutCreateButton()
    ns.Minimap:Init()

    SLASH_GUILDQUESTS1 = "/gq"
    SLASH_GUILDQUESTS2 = "/guildquests"
    SlashCmdList["GUILDQUESTS"] = function(msg)
        GQ:SlashCommand(msg)
    end

    Events:Fire("AddonLoaded")
end

function GQ:OnEnable()
    local function bootstrap()
        if Util:GetGuildKey() then
            ns.DB:EnsureGuildStore()
            ns.MainUI:UpdateCreateButtonState()
            if not self.bootstrapped then
                ns.Scheduler:Start()
                self.bootstrapped = true
            end
        end
    end
    ns.GuildRank:Refresh()
    bootstrap()
    C_Timer.After(3, bootstrap)
    Events:Fire("AddonEnabled")
end

function GQ:OnDisable()
    ns.Scheduler:Stop()
    ns.Heartbeat:Stop()
end

function GQ:RegisterModule(name, mod)
    self.modules[name] = mod
    if mod.OnRegister then
        mod:OnRegister(self)
    end
end

function GQ:Print(msg, ...)
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33aa33GuildQuests:|r " .. string.format(tostring(msg), ...)
    )
end

function GQ:SlashCommand(input)
    input = Util:Trim(input or ""):lower()
    if input == "" or input == "board" then
        ns.MainUI:Toggle()
    elseif input == "create" then
        ns.CreateQuest:Show()
    elseif input == "settings" then
        ns.MainUI:ShowSettings()
    elseif input == "sync" then
        ns.SyncEngine:RequestCatchUp(true)
    elseif input == "debug" then
        ns.SyncEngine:PrintDebug()
    elseif input == "debugsync" then
        C.DEBUG_SYNC = not C.DEBUG_SYNC
        self:Print(C.DEBUG_SYNC and ns.L["SLASH_DEBUGSYNC_ON"] or ns.L["SLASH_DEBUGSYNC_OFF"])
    elseif input == "testgm" then
        if C.DEBUG_GUILD_MASTER then
            self:Print(ns.L["SLASH_TESTGM_FORCED"])
        else
            local enabled = not ns.Rules:IsDebugGuildMaster()
            ns.Rules:SetDebugGuildMaster(enabled)
            self:Print(enabled and ns.L["SLASH_TESTGM_ON"] or ns.L["SLASH_TESTGM_OFF"])
        end
    elseif input:match("^testachiev") or input:match("^testachievement") then
        local query = Util:Trim(input:match("^testachiev%s+(.+)$") or input:match("^testachievement%s+(.+)$") or "")
        self:TestAchievementNotify(query)
    elseif input:match("^testdeath") then
        local name = Util:Trim(input:match("^testdeath%s+(.+)$") or "")
        self:TestDeathNotify(name)
    else
        self:Print(ns.L["SLASH_HELP"])
    end
end

function GQ:TestAchievementNotify(query)
    if query ~= "" and not ns.AchievementNotifier:ShowTest(query) then
        self:Print(string.format(ns.L["SLASH_TESTACHIEV_UNKNOWN"], query))
        return
    end
    if query == "" then
        local entry = ns.AchievementCatalog:GetDefaultTestEntry()
        if entry then
            ns.AchievementNotifier:Show(entry)
        end
    end
    self:Print(ns.L["SLASH_TESTACHIEV"])
end

function GQ:TestDeathNotify(name)
    ns.DeathLogNotifier:ShowTest(name)
    self:Print(ns.L["SLASH_TESTDEATH"])
end

function GQ:Fire(event, ...)
    Events:Fire(event, ...)
end

function GQ:RegisterCallback(event, callback)
    Events:Register(event, callback, self)
end
