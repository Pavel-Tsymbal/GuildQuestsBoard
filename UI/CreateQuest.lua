local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local CreateQuest = {}
ns.CreateQuest = CreateQuest

function CreateQuest:GetTimeModeLabel(mode)
    if mode == C.TIME_MODE.DEADLINE then
        return ns.L["TIME_MODE_DEADLINE"]
    end
    if mode == C.TIME_MODE.SCHEDULED then
        return ns.L["TIME_MODE_SCHEDULED"]
    end
    return ns.L["TIME_MODE_NONE"]
end

function CreateQuest:GetTimeValueLabelKey(mode)
    if mode == C.TIME_MODE.SCHEDULED then
        return "CREATE_SCHEDULED"
    end
    return "CREATE_DEADLINE"
end

function CreateQuest:AddLabel(localeKey, offsetY)
    local fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, offsetY)
    self.labels[localeKey] = fs
    fs:SetText(ns.L[localeKey])
    return fs
end

function CreateQuest:AddInput(labelKey, offsetY, height)
    self:AddLabel(labelKey, offsetY)
    local box = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
    box:SetSize(400, height or 24)
    box:SetPoint("TOPLEFT", 20, offsetY - 18)
    box:SetAutoFocus(false)
    return box
end

function CreateQuest:AttachBlinkingCaret(editBox)
    local caret = editBox:CreateTexture(nil, "OVERLAY")
    caret:SetColorTexture(1, 1, 1, 0.9)
    caret:SetSize(2, 14)
    caret:Hide()

    local blinkOn = true
    local elapsed = 0

    local function positionCaret(offset, height)
        caret:ClearAllPoints()
        caret:SetPoint("TOPLEFT", editBox, "TOPLEFT", (offset or 0) + 3, -2)
        caret:SetSize(2, height or 14)
    end

    local function refreshCaret()
        if editBox:HasFocus() and blinkOn then
            caret:Show()
        else
            caret:Hide()
        end
    end

    editBox:SetBlinkSpeed(0)
    editBox:SetScript("OnCursorChanged", function(_, offset, height)
        positionCaret(offset, height)
        refreshCaret()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        blinkOn = true
        elapsed = 0
        local text = self:GetText() or ""
        self:SetCursorPosition(string.len(text))
        refreshCaret()
    end)
    editBox:SetScript("OnEditFocusLost", function()
        caret:Hide()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        if self:HasFocus() then
            refreshCaret()
        end
    end)
    editBox:SetScript("OnUpdate", function(_, dt)
        if not editBox:HasFocus() then
            return
        end
        elapsed = elapsed + dt
        if elapsed >= 0.53 then
            elapsed = 0
            blinkOn = not blinkOn
            refreshCaret()
        end
    end)
end

function CreateQuest:Init()
    self.labels = {}

    self.frame = CreateFrame("Frame", "GuildQuestsCreateFrame", UIParent, "BackdropTemplate")
    self.frame:SetSize(460, 560)
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.frame:Hide()
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    self.frame:EnableMouse(true)

    local close = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() self:Hide() end)

    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 16, -16)

    local y = -44
    self.fields = {}

    self.fields.title = self:AddInput("CREATE_QUEST_TITLE", y)
    y = y - 52
    y = self:CreateDescriptionField(y)
    y = y - 12

    self:AddLabel("CREATE_CATEGORY", y)
    self.fields.category = CreateFrame("Frame", nil, self.frame, "UIDropDownMenuTemplate")
    self.fields.category:SetPoint("TOPLEFT", 8, y - 8)
    UIDropDownMenu_SetWidth(self.fields.category, 180)
    UIDropDownMenu_Initialize(self.fields.category, function(_, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for _, cat in ipairs(C.CATEGORIES) do
            info.text = Util:GetCategoryLabel(cat)
            info.value = cat
            info.func = function()
                self.selectedCategory = cat
                UIDropDownMenu_SetText(self.fields.category, Util:GetCategoryLabel(cat))
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    self.fields.tag = self:AddInput("CREATE_TAG", y - 48)
    y = y - 96
    self.fields.reward = self:AddInput("CREATE_REWARD_GOLD", y)
    y = y - 52

    self:AddLabel("CREATE_TIME_MODE", y)
    self.fields.timeMode = CreateFrame("Frame", nil, self.frame, "UIDropDownMenuTemplate")
    self.fields.timeMode:SetPoint("TOPLEFT", 8, y - 8)
    UIDropDownMenu_SetWidth(self.fields.timeMode, 180)
    UIDropDownMenu_Initialize(self.fields.timeMode, function()
        local info = UIDropDownMenu_CreateInfo()
        local modes = {
            C.TIME_MODE.NONE,
            C.TIME_MODE.DEADLINE,
            C.TIME_MODE.SCHEDULED,
        }
        for _, mode in ipairs(modes) do
            info.text = self:GetTimeModeLabel(mode)
            info.value = mode
            info.func = function()
                self.selectedTimeMode = mode
                UIDropDownMenu_SetText(self.fields.timeMode, self:GetTimeModeLabel(mode))
                self:UpdateTimeValueLabel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    self.fields.timeValue = self:AddInput("CREATE_DEADLINE", y - 48)
    y = y - 96
    self.fields.maxParticipants = self:AddInput("CREATE_MAX_PARTICIPANTS", y)
    self.fields.maxParticipants:SetText("1")

    self.submit = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.submit:SetSize(120, 24)
    self.submit:SetPoint("BOTTOMRIGHT", -16, 16)
    self.submit:SetScript("OnClick", function() self:Submit() end)

    self.cancel = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.cancel:SetSize(120, 24)
    self.cancel:SetPoint("RIGHT", self.submit, "LEFT", -8, 0)
    self.cancel:SetScript("OnClick", function() self:Hide() end)

    self.selectedCategory = "OTHER"
    self.selectedTimeMode = C.TIME_MODE.NONE
    self.datePlaceholder = ns.L["CREATE_DATE_PLACEHOLDER"]

    self:UpdateTexts()

    ns.GQ:RegisterCallback("LocaleChanged", function()
        self:UpdateTexts()
    end)
end

function CreateQuest:CreateDescriptionField(y)
    self.labels["CREATE_QUEST_DESC"] = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.labels["CREATE_QUEST_DESC"]:SetPoint("TOPLEFT", 16, y)

    local scrollBG = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    scrollBG:SetSize(400, 110)
    scrollBG:SetPoint("TOPLEFT", 20, y - 18)
    scrollBG:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    scrollBG:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
    scrollBG:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)

    local scroll = CreateFrame("ScrollFrame", "GuildQuestsCreateDescScroll", self.frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", scrollBG, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -6, 6)
    scroll:EnableMouse(true)

    local desc = CreateFrame("EditBox", "GuildQuestsCreateDescEdit", scroll)
    desc:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    desc:SetMultiLine(true)
    desc:SetFontObject(ChatFontNormal)
    desc:SetWidth(360)
    desc:SetHeight(160)
    desc:SetAutoFocus(false)
    desc:EnableMouse(true)
    desc:EnableKeyboard(true)
    desc:SetMaxLetters(C.DESC_MAX)
    desc:SetTextInsets(4, 4, 4, 4)
    desc:SetScript("OnMouseDown", function(editBox)
        editBox:SetFocus()
    end)
    desc:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)
    desc:SetScript("OnTextChanged", function(editBox)
        local text = editBox:GetText() or ""
        local lines = select(2, text:gsub("\n", "\n")) + 1
        local height = math.max(lines * 14 + 14, 160)
        editBox:SetHeight(height)
        scroll:UpdateScrollChildRect()
    end)
    self:AttachBlinkingCaret(desc)
    scroll:SetScript("OnMouseDown", function()
        desc:SetFocus()
    end)
    scrollBG:EnableMouse(true)
    scrollBG:SetScript("OnMouseDown", function()
        desc:SetFocus()
    end)
    scroll:SetScrollChild(desc)
    self.fields.desc = desc

    return y - 130
end

function CreateQuest:UpdateTimeValueLabel()
    local labelKey = self:GetTimeValueLabelKey(self.selectedTimeMode)
    if self.labels["CREATE_DEADLINE"] then
        self.labels["CREATE_DEADLINE"]:SetText(ns.L[labelKey])
    end
end

function CreateQuest:UpdateTexts()
    if not self.frame then
        return
    end

    self.datePlaceholder = ns.L["CREATE_DATE_PLACEHOLDER"]
    self.title:SetText(ns.L["CREATE_TITLE"])
    for key, label in pairs(self.labels or {}) do
        label:SetText(ns.L[key])
    end
    self:UpdateTimeValueLabel()
    self.submit:SetText(ns.L["CREATE_SUBMIT"])
    self.cancel:SetText(ns.L["CREATE_CANCEL"])

    if self.selectedCategory then
        UIDropDownMenu_SetText(self.fields.category, Util:GetCategoryLabel(self.selectedCategory))
    end
    if self.selectedTimeMode then
        UIDropDownMenu_SetText(self.fields.timeMode, self:GetTimeModeLabel(self.selectedTimeMode))
    end

    local timeText = self.fields.timeValue:GetText() or ""
    if timeText == ""
        or timeText == self.datePlaceholder
        or timeText == "YYYY-MM-DD HH:MM"
        or timeText == "ГГГГ-ММ-ДД ЧЧ:ММ" then
        self.fields.timeValue:SetText(self.datePlaceholder)
    end
end

function CreateQuest:ParseDateTime(text)
    text = Util:Trim(text)
    if text == ""
        or text == self.datePlaceholder
        or text == "YYYY-MM-DD HH:MM"
        or text == "ГГГГ-ММ-ДД ЧЧ:ММ" then
        return nil
    end
    local y, m, d, h, min = text:match("(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+)")
    if not y then
        return nil
    end
    return Util:TimeFromParts(y, m, d, h, min, 0)
end

function CreateQuest:Reset()
    self.fields.title:SetText("")
    self.fields.desc:SetText("")
    self.fields.tag:SetText("")
    self.fields.reward:SetText("")
    self.fields.maxParticipants:SetText("1")
    self.selectedCategory = "OTHER"
    self.selectedTimeMode = C.TIME_MODE.NONE
    UIDropDownMenu_SetText(self.fields.category, Util:GetCategoryLabel("OTHER"))
    UIDropDownMenu_SetText(self.fields.timeMode, self:GetTimeModeLabel(C.TIME_MODE.NONE))
    self:UpdateTimeValueLabel()
    self.fields.timeValue:SetText(self.datePlaceholder)
end

function CreateQuest:Show()
    if not Util:GetGuildKey() then
        ns.GQ:Print(ns.L["ERR_NOT_IN_GUILD"])
        return
    end
    self:UpdateTexts()
    self:Reset()
    self.frame:Show()
end

function CreateQuest:Hide()
    self.frame:Hide()
end

function CreateQuest:Submit()
    self.fields.desc:ClearFocus()
    self.fields.title:ClearFocus()

    local data = {
        title = self.fields.title:GetText() or "",
        description = self.fields.desc:GetText() or "",
        category = self.selectedCategory,
        categoryTag = self.fields.tag:GetText(),
        rewardGold = Util:ParseGoldInput(self.fields.reward:GetText()),
        timeMode = self.selectedTimeMode,
        maxParticipants = tonumber(self.fields.maxParticipants:GetText()) or 1,
        itemRewards = {},
    }
    local ts = self:ParseDateTime(self.fields.timeValue:GetText())
    if self.selectedTimeMode == C.TIME_MODE.DEADLINE then
        data.deadline = ts
    elseif self.selectedTimeMode == C.TIME_MODE.SCHEDULED then
        data.scheduledAt = ts
    end

    local ok, err = ns.Actions:Create(data)
    if not ok then
        ns.GQ:Print(err or ns.L["ERR_NO_PERMISSION"])
        return
    end
    self:Hide()
    ns.MainUI:Refresh()
    if ns.MainUI.frame and not ns.MainUI.frame:IsShown() then
        ns.MainUI:Show()
    end
end
