local _, ns = ...
local Util = ns.Util

local Notifier = {}
ns.DeathLogNotifier = Notifier

function Notifier:Init()
    self.lastNotifiedKey = nil
    self.frame = CreateFrame("Frame", "GuildQuestsDeathToast", UIParent, "BackdropTemplate")
    self.frame:SetSize(320, 80)
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.frame:SetClampedToScreen(true)
    self.frame:Hide()
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 12, -10)
    self.title:SetWidth(290)
    self.title:SetJustifyH("LEFT")

    self.body = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.body:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.body:SetWidth(290)
    self.body:SetJustifyH("LEFT")

    self.close = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.close:SetPoint("TOPRIGHT", -2, -2)
    self.close:SetScript("OnClick", function()
        self:Hide()
    end)

    self.fadeTimer = nil
end

function Notifier:GetPosition()
    local pos = ns.PersonalSettings:GetNotifications().position or "TOPRIGHT"
    self.frame:ClearAllPoints()
    if pos == "TOP" then
        self.frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    elseif pos == "BOTTOM" then
        self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)
    elseif pos == "BOTTOMRIGHT" then
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 160)
    else
        self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -120)
    end
end

function Notifier:ShouldNotify()
    return ns.PersonalSettings:ShouldShowDeathNotification()
end

function Notifier:OnDeath(death, isLocal)
    if not death or not self:ShouldNotify() then
        return
    end
    if not ns.DeathLog:ShouldAlertDeath(death) then
        return
    end
    local playerName = Util:GetShortPlayerName(UnitName("player"))
    if playerName and Util:GetShortPlayerName(death.name) == playerName then
        return
    end
    if death.dedupKey and death.dedupKey == self.lastNotifiedKey then
        return
    end
    self.lastNotifiedKey = death.dedupKey
    self:ShowDeath(death)
end

function Notifier:ShowDeath(death)
    if not death then
        return
    end
    self:GetPosition()
    self.title:SetText(ns.L["DEATHLOG_NOTIFY_TITLE"])
    local level = death.level and death.level > 0 and death.level or "?"
    local source = death.source ~= "" and death.source or ns.L["DEATHLOG_SOURCE_UNKNOWN"]
    local zone = death.zone ~= "" and (" (" .. death.zone .. ")") or ""
    self.body:SetText(string.format(
        ns.L["DEATHLOG_NOTIFY_BODY"],
        level,
        ns.DeathLog:GetColoredName(death),
        source,
        zone
    ))

    local settings = ns.PersonalSettings:GetDeathNotifications()
    if settings.sound then
        pcall(function()
            PlaySound(8959, "Master")
        end)
    end

    self.frame:SetAlpha(0)
    self.frame:Show()
    UIFrameFadeIn(self.frame, 0.25, 0, 1)

    if self.fadeTimer then
        ns.GQ:CancelTimer(self.fadeTimer)
    end
    local duration = ns.PersonalSettings:GetNotifications().duration or 5
    self.fadeTimer = ns.GQ:ScheduleTimer(function()
        UIFrameFadeOut(Notifier.frame, 0.35, 1, 0)
        ns.GQ:ScheduleTimer(function()
            Notifier:Hide()
        end, 0.4)
    end, duration)
end

function Notifier:Hide()
    if self.fadeTimer then
        ns.GQ:CancelTimer(self.fadeTimer)
        self.fadeTimer = nil
    end
    self.frame:Hide()
end
