local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local Toast = {}
ns.Toast = Toast

function Toast:Init()
    self.frame = CreateFrame("Frame", "GuildQuestsToast", UIParent, "BackdropTemplate")
    self.frame:SetSize(280, 72)
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
    self.title:SetWidth(250)
    self.title:SetJustifyH("LEFT")

    self.body = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.body:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.body:SetWidth(250)
    self.body:SetJustifyH("LEFT")

    self.close = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.close:SetPoint("TOPRIGHT", -2, -2)

    self.frame:EnableMouse(true)
    self.frame:SetScript("OnMouseUp", function()
        if self.currentQuestId then
            ns.QuestDetail:Show(self.currentQuestId)
            self:Hide()
        end
    end)
    self.close:SetScript("OnClick", function()
        if self.currentQuestId then
            ns.Queue:Dismiss(self.currentQuestId)
        end
        self:Hide()
    end)

    self.fadeTimer = nil
    self.onDone = nil
end

function Toast:GetPosition()
    local pos = ns.PersonalSettings:GetNotifications().position or "TOPRIGHT"
    self.frame:ClearAllPoints()
    if pos == "TOP" then
        self.frame:SetPoint("TOP", UIParent, "TOP", 0, -80)
    elseif pos == "BOTTOM" then
        self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
    elseif pos == "BOTTOMRIGHT" then
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 120)
    else
        self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -80)
    end
end

function Toast:IsVisible()
    return self.frame and self.frame:IsShown()
end

function Toast:ShowQuest(quest, onDone)
    if not quest then
        return
    end
    self.onDone = onDone
    self.currentQuestId = quest.id
    self:GetPosition()
    self.title:SetText(ns.L["NOTIFY_NEW_QUEST"])
    local reward = Util:GetRewardText(quest)
    local body = quest.title .. "\n" .. ns.L["DETAIL_REWARD"] .. ": " .. reward
    if quest.timeMode == C.TIME_MODE.SCHEDULED and quest.scheduledAt then
        body = body .. "\n" .. ns.L["DETAIL_SCHEDULED"] .. ": " .. date("%Y-%m-%d %H:%M", quest.scheduledAt)
    end
    self.body:SetText(body)

    local n = ns.PersonalSettings:GetNotifications()
    if n.sound then
        pcall(function()
            PlaySound(12867, "Master")
        end)
    end

    self.frame:SetAlpha(0)
    self.frame:Show()
    UIFrameFadeIn(self.frame, 0.25, 0, 1)

    if self.fadeTimer then
        ns.GQ:CancelTimer(self.fadeTimer)
    end
    local duration = n.duration or 5
    self.fadeTimer = ns.GQ:ScheduleTimer(function()
        UIFrameFadeOut(self.frame, 0.35, 1, 0)
        ns.GQ:ScheduleTimer(function()
            Toast:Hide()
        end, 0.4)
    end, duration)
end

function Toast:Hide()
    if self.fadeTimer then
        ns.GQ:CancelTimer(self.fadeTimer)
        self.fadeTimer = nil
    end
    self.frame:Hide()
    self.currentQuestId = nil
    if self.onDone then
        self.onDone()
        self.onDone = nil
    end
end
