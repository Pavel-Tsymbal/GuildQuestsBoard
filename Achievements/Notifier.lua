local _, ns = ...

local Notifier = {}
ns.AchievementNotifier = Notifier

Notifier.DURATION = 5
Notifier.FADE_IN = 0.35
Notifier.FADE_OUT = 0.45

function Notifier:Init()
    self.frame = CreateFrame("Frame", "GuildQuestsAchievementToast", UIParent, "BackdropTemplate")
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
    self.frame:SetBackdropColor(0.05, 0.05, 0.08, 0.94)
    self.frame:SetBackdropBorderColor(0.78, 0.62, 0.22, 1)

    self.accent = self.frame:CreateTexture(nil, "ARTWORK")
    self.accent:SetPoint("TOPLEFT", 1, -1)
    self.accent:SetPoint("TOPRIGHT", -1, -1)
    self.accent:SetHeight(3)
    self.accent:SetColorTexture(0.95, 0.78, 0.25, 0.95)

    self.glow = self.frame:CreateTexture(nil, "BACKGROUND")
    self.glow:SetPoint("TOPLEFT", 8, -8)
    self.glow:SetPoint("BOTTOMRIGHT", -8, 8)
    self.glow:SetColorTexture(0.35, 0.28, 0.08, 0.18)

    self.iconBorder = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    self.iconBorder:SetSize(54, 54)
    self.iconBorder:SetPoint("LEFT", 14, 0)
    self.iconBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    self.iconBorder:SetBackdropColor(0.10, 0.08, 0.05, 1)
    self.iconBorder:SetBackdropBorderColor(0.90, 0.72, 0.20, 1)

    self.icon = self.iconBorder:CreateTexture(nil, "ARTWORK")
    self.icon:SetPoint("TOPLEFT", 3, -3)
    self.icon:SetPoint("BOTTOMRIGHT", -3, 3)

    self.heading = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.heading:SetPoint("TOPLEFT", self.iconBorder, "TOPRIGHT", 14, -6)
    self.heading:SetTextColor(0.95, 0.78, 0.25)

    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", self.heading, "BOTTOMLEFT", 0, -2)
    self.title:SetWidth(300)
    self.title:SetJustifyH("LEFT")

    self.body = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.body:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.body:SetWidth(300)
    self.body:SetJustifyH("LEFT")

    self.factionTag = self.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.factionTag:SetPoint("BOTTOMRIGHT", -14, 10)
    self.factionTag:SetWidth(120)
    self.factionTag:SetJustifyH("RIGHT")

    self.fadeTimer = nil
    self.hideTimer = nil
    self.soundTimer = nil
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
    if self.soundTimer then
        ns.GQ:CancelTimer(self.soundTimer)
        self.soundTimer = nil
    end
end

function Notifier:PlaySoundKit(soundId)
    if not soundId then
        return
    end
    pcall(PlaySound, soundId)
end

function Notifier:PlaySoundFilePath(path)
    if not path then
        return
    end
    pcall(PlaySoundFile, path)
end

function Notifier:PlaySound()
    -- Classic Era: single-arg PlaySound(id) on the SFX channel (same as Hardcore toasts).
    self:PlaySoundKit(888)
    self:PlaySoundKit(623)

    if self.soundTimer then
        ns.GQ:CancelTimer(self.soundTimer)
    end
    self.soundTimer = ns.GQ:ScheduleTimer(function()
        Notifier:PlaySoundKit(12867)
        Notifier:PlaySoundFilePath("Sound\\Interface\\levelup2.ogg")
        Notifier:PlaySoundFilePath("Sound\\Interface\\LevelUp.ogg")
        Notifier.soundTimer = nil
    end, 0.15)
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

function Notifier:Show(entry)
    if not entry or not self.frame then
        return
    end

    self:CancelTimers()
    if self.animGroup then
        self.animGroup:Stop()
        self.animGroup = nil
    end

    self.heading:SetText(ns.L["ACHIEV_TOAST_TITLE"])
    self.title:SetText(ns.AchievementCatalog:GetTitle(entry))
    self.body:SetText(ns.AchievementCatalog:GetDescription(entry))
    self.factionTag:SetText(ns.AchievementCatalog:GetFactionTagText(entry))
    self.icon:SetTexture(entry.icon or "Interface\\Icons\\Achievement_General")

    self.frame:SetAlpha(0)
    self.frame:Show()
    self:AnimateIn()
    UIFrameFadeIn(self.frame, self.FADE_IN, 0, 1)
    C_Timer.After(0, function()
        Notifier:PlaySound()
    end)

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

function Notifier:ShowTest(query)
    local entry = ns.AchievementCatalog:FindByQuery(query)
    if not entry then
        return false
    end
    self:Show(entry)
    return true
end
