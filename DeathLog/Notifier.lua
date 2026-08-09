local _, ns = ...
local Util = ns.Util

local Notifier = {}
ns.DeathLogNotifier = Notifier

Notifier.DURATION = 5
Notifier.FADE_IN = 0.35
Notifier.FADE_OUT = 0.45
Notifier.SKULL_ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

function Notifier:Init()
    self.lastNotifiedKey = nil
    self.frame = CreateFrame("Frame", "GuildQuestsDeathToast", UIParent, "BackdropTemplate")
    self.frame:SetSize(400, 96)
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.frame:SetFrameLevel(120)
    self.frame:SetClampedToScreen(true)
    self.frame:Hide()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)

    self.frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    self.frame:SetBackdropColor(0.06, 0.04, 0.05, 0.94)
    self.frame:SetBackdropBorderColor(0.55, 0.14, 0.12, 1)

    self.accent = self.frame:CreateTexture(nil, "ARTWORK")
    self.accent:SetPoint("TOPLEFT", 1, -1)
    self.accent:SetPoint("TOPRIGHT", -1, -1)
    self.accent:SetHeight(3)
    self.accent:SetColorTexture(0.78, 0.18, 0.14, 0.95)

    self.glow = self.frame:CreateTexture(nil, "BACKGROUND")
    self.glow:SetPoint("TOPLEFT", 8, -8)
    self.glow:SetPoint("BOTTOMRIGHT", -8, 8)
    self.glow:SetColorTexture(0.35, 0.08, 0.06, 0.20)

    self.iconBorder = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    self.iconBorder:SetSize(54, 54)
    self.iconBorder:SetPoint("LEFT", 14, 0)
    self.iconBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    self.iconBorder:SetBackdropColor(0.12, 0.06, 0.06, 1)
    self.iconBorder:SetBackdropBorderColor(0.72, 0.20, 0.16, 1)

    self.icon = self.iconBorder:CreateTexture(nil, "ARTWORK")
    self.icon:SetTexture(self.SKULL_ICON)
    self.icon:SetPoint("TOPLEFT", 4, -4)
    self.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    self.icon:SetVertexColor(0.92, 0.84, 0.68)

    self.heading = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.heading:SetPoint("TOPLEFT", self.iconBorder, "TOPRIGHT", 14, -6)
    self.heading:SetTextColor(0.95, 0.45, 0.35)

    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", self.heading, "BOTTOMLEFT", 0, -2)
    self.title:SetWidth(300)
    self.title:SetJustifyH("LEFT")

    self.body = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.body:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.body:SetWidth(300)
    self.body:SetJustifyH("LEFT")

    self.zoneTag = self.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.zoneTag:SetPoint("BOTTOMRIGHT", -14, 10)
    self.zoneTag:SetWidth(120)
    self.zoneTag:SetJustifyH("RIGHT")

    self.fadeTimer = nil
    self.hideTimer = nil
    self.animGroup = nil
end

function Notifier:CancelTimers()
    if self.fadeTimer then
        ns.GQ:CancelTimer(self.fadeTimer)
        self.fadeTimer = nil
    end
    if self.hideTimer then
        ns.GQ:CancelTimer(self.hideTimer)
        self.hideTimer = nil
    end
end

function Notifier:AnimateIn()
    if self.animGroup then
        self.animGroup:Stop()
        self.animGroup = nil
    end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
    self.animGroup = self.frame:CreateAnimationGroup()
    local move = self.animGroup:CreateAnimation("Translation")
    move:SetOffset(0, 20)
    move:SetDuration(self.FADE_IN)
    move:SetSmoothing("OUT")
    self.animGroup:Play()
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

function Notifier:FormatDeathBody(death)
    local level = death.level and death.level > 0 and death.level or "?"
    local source = death.source ~= "" and death.source or ns.L["DEATHLOG_SOURCE_UNKNOWN"]
    return string.format(ns.L["DEATHLOG_NOTIFY_DETAIL"], level, source)
end

function Notifier:ShowDeath(death)
    if not death or not self.frame then
        return
    end

    self:CancelTimers()
    if self.animGroup then
        self.animGroup:Stop()
        self.animGroup = nil
    end

    self.heading:SetText(ns.L["DEATHLOG_NOTIFY_TITLE"])
    self.title:SetText(ns.DeathLog:GetColoredName(death))
    self.body:SetText(self:FormatDeathBody(death))
    self.zoneTag:SetText(death.zone ~= "" and death.zone or "")

    local settings = ns.PersonalSettings:GetDeathNotifications()
    if settings.sound then
        pcall(function()
            PlaySound(8959)
        end)
    end

    self.frame:SetAlpha(0)
    self.frame:Show()
    self:AnimateIn()
    UIFrameFadeIn(self.frame, self.FADE_IN, 0, 1)

    self.fadeTimer = ns.GQ:ScheduleTimer(function()
        UIFrameFadeOut(Notifier.frame, Notifier.FADE_OUT, 1, 0)
        Notifier.hideTimer = ns.GQ:ScheduleTimer(function()
            Notifier:Hide(true)
        end, Notifier.FADE_OUT + 0.05)
    end, self.DURATION)
end

function Notifier:Hide(silent)
    self:CancelTimers()
    if self.animGroup then
        self.animGroup:Stop()
        self.animGroup = nil
    end
    self.frame:Hide()
    self.frame:SetAlpha(1)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
end

function Notifier:ShowTest(nameQuery)
    local _, _, classId = UnitClass("player")
    local death = {
        name = (nameQuery ~= "" and nameQuery) or "Testplayer",
        level = UnitLevel("player") > 0 and UnitLevel("player") or 10,
        source = "Hogger",
        zone = "Elwynn Forest",
        classId = classId,
    }
    self:ShowDeath(death)
    return true
end
