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

function CreateQuest:GetParticipantsModeLabel(unlimited)
    if unlimited then
        return ns.L["PARTICIPANTS_UNLIMITED"]
    end
    return ns.L["PARTICIPANTS_LIMITED"]
end

function CreateQuest:GetLevelModeLabel(unlimited)
    if unlimited then
        return ns.L["LEVEL_UNLIMITED"]
    end
    return ns.L["LEVEL_LIMITED"]
end

function CreateQuest:AddLabel(localeKey, offsetY)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, offsetY)
    self.labels[localeKey] = fs
    fs:SetText(ns.L[localeKey])
    return fs
end

function CreateQuest:AddInput(labelKey, offsetY, height)
    self:AddLabel(labelKey, offsetY)
    local box = CreateFrame("EditBox", nil, self.content, "InputBoxTemplate")
    box:SetSize(460, height or 24)
    box:SetPoint("TOPLEFT", 20, offsetY - 18)
    box:SetAutoFocus(false)
    return box
end

function CreateQuest:AddDropdown(labelKey, offsetY, width, initialize)
    self:AddLabel(labelKey, offsetY)
    local dropdown = CreateFrame("Frame", nil, self.content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 8, offsetY - 22)
    UIDropDownMenu_SetWidth(dropdown, width or 180)
    UIDropDownMenu_Initialize(dropdown, initialize)
    return dropdown
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

function CreateQuest:RefreshMaxLevelDropdown()
    if not self.fields.maxLevelValue then
        return
    end
    local items = {}
    for level = 1, C.MAX_LEVEL do
        table.insert(items, {
            value = level,
            text = tostring(level),
        })
    end
    self.fields.maxLevelValue.onSelect = function(value)
        self.selectedMaxLevel = value
    end
    self.fields.maxLevelValue:SetScrollItems(items, self.selectedMaxLevel or 1)
end

function CreateQuest:Init()
    self.labels = {}

    self.frame = CreateFrame("Frame", "GuildQuestsCreateFrame", UIParent, "BackdropTemplate")
    self.frame:SetSize(520, 620)
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.frame:Hide()
    ns.Theme:ApplyPanel(self.frame)
    self.frame:EnableMouse(true)

    local close = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() self:Hide() end)

    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 16, -16)

    self.scroll = CreateFrame("ScrollFrame", "GuildQuestsCreateScroll", self.frame, "UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT", 12, -40)
    self.scroll:SetPoint("BOTTOMRIGHT", -28, 52)

    self.content = CreateFrame("Frame", nil, self.scroll)
    self.content:SetWidth(460)
    self.scroll:SetScrollChild(self.content)

    local y = -8
    self.fields = {}

    self.fields.title = self:AddInput("CREATE_QUEST_TITLE", y)
    y = y - 52
    y = self:CreateDescriptionField(y)
    y = y - 12

    self.fields.reward = self:AddInput("CREATE_REWARD", y)
    y = y - 52

    self.fields.category = self:AddDropdown("CREATE_CATEGORY", y, 180, function(_, level, menuList)
        for _, cat in ipairs(C.CATEGORIES) do
            local info = UIDropDownMenu_CreateInfo()
            local category = cat
            info.text = Util:GetCategoryLabel(category)
            info.value = category
            info.func = function()
                self.selectedCategory = category
                UIDropDownMenu_SetText(self.fields.category, Util:GetCategoryLabel(category))
                if category == "PERMANENT" then
                    self.participantsUnlimited = true
                    UIDropDownMenu_SetText(
                        self.fields.maxParticipantsMode,
                        self:GetParticipantsModeLabel(true)
                    )
                end
                self:UpdateFormLayout()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    y = y - 58

    self.fields.timeMode = self:AddDropdown("CREATE_TIME_MODE", y, 180, function()
        local modes = {
            C.TIME_MODE.NONE,
            C.TIME_MODE.DEADLINE,
            C.TIME_MODE.SCHEDULED,
        }
        for _, mode in ipairs(modes) do
            local info = UIDropDownMenu_CreateInfo()
            local selectedMode = mode
            info.text = self:GetTimeModeLabel(selectedMode)
            info.value = selectedMode
            info.func = function()
                self.selectedTimeMode = selectedMode
                UIDropDownMenu_SetText(self.fields.timeMode, self:GetTimeModeLabel(selectedMode))
                self:UpdateTimeValueVisibility()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    self:AddLabel("CREATE_DEADLINE", y - 58)
    self.dateTimePicker = ns.DateTimePicker:Create(self.content)
    self.dateTimePicker:SetPoint("TOPLEFT", 8, y - 80)
    self.layout = {
        timeModeY = y,
        maxParticipantsY = y - 138,
        maxParticipantsCompactY = y - 58,
        contentBottomExpandedY = y - 190,
        contentBottomExpandedLimitedY = y - 248,
        contentBottomExpandedNoMaxY = y - 132,
        contentBottomCompactY = y - 110,
        contentBottomCompactLimitedY = y - 168,
        contentBottomCompactNoMaxY = y - 58,
    }

    self:AddLabel("CREATE_MAX_PARTICIPANTS", y - 138)
    self.fields.maxParticipantsMode = CreateFrame("Frame", nil, self.content, "UIDropDownMenuTemplate")
    self.fields.maxParticipantsMode:SetPoint("TOPLEFT", 8, y - 160)
    UIDropDownMenu_SetWidth(self.fields.maxParticipantsMode, 180)
    UIDropDownMenu_Initialize(self.fields.maxParticipantsMode, function()
        local modes = {
            { unlimited = true },
            { unlimited = false },
        }
        for _, mode in ipairs(modes) do
            local info = UIDropDownMenu_CreateInfo()
            local unlimited = mode.unlimited
            info.text = self:GetParticipantsModeLabel(unlimited)
            info.value = unlimited
            info.func = function()
                self.participantsUnlimited = unlimited
                UIDropDownMenu_SetText(
                    self.fields.maxParticipantsMode,
                    self:GetParticipantsModeLabel(unlimited)
                )
                self:UpdateFormLayout()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    self:AddLabel("CREATE_PARTICIPANTS_LIMIT", y - 196)
    self.labels["CREATE_PARTICIPANTS_LIMIT"]:Hide()
    self.fields.maxParticipantsLimit = CreateFrame("EditBox", nil, self.content, "InputBoxTemplate")
    self.fields.maxParticipantsLimit:SetSize(120, 24)
    self.fields.maxParticipantsLimit:SetPoint("TOPLEFT", 20, y - 214)
    self.fields.maxParticipantsLimit:SetAutoFocus(false)
    if self.fields.maxParticipantsLimit.SetNumeric then
        self.fields.maxParticipantsLimit:SetNumeric(true)
    end
    self.fields.maxParticipantsLimit:SetMaxLetters(2)
    self.fields.maxParticipantsLimit:SetScript("OnTextChanged", function(editBox)
        local text = editBox:GetText() or ""
        local digits = text:match("^(%d*)")
        if digits ~= text then
            editBox:SetText(digits or "")
            editBox:SetCursorPosition(string.len(digits or ""))
        end
    end)
    self.fields.maxParticipantsLimit:Hide()

    self:AddLabel("CREATE_MIN_LEVEL", y - 252)
    self.fields.minLevelMode = CreateFrame("Frame", nil, self.content, "UIDropDownMenuTemplate")
    self.fields.minLevelMode:SetPoint("TOPLEFT", 8, y - 274)
    UIDropDownMenu_SetWidth(self.fields.minLevelMode, 180)
    UIDropDownMenu_Initialize(self.fields.minLevelMode, function()
        local modes = {
            { unlimited = true },
            { unlimited = false },
        }
        for _, mode in ipairs(modes) do
            local info = UIDropDownMenu_CreateInfo()
            local unlimited = mode.unlimited
            info.text = self:GetLevelModeLabel(unlimited)
            info.value = unlimited
            info.func = function()
                self.levelUnlimited = unlimited
                UIDropDownMenu_SetText(
                    self.fields.minLevelMode,
                    self:GetLevelModeLabel(unlimited)
                )
                self:UpdateFormLayout()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    self:AddLabel("CREATE_LEVEL_VALUE", y - 310)
    self.labels["CREATE_LEVEL_VALUE"]:Hide()
    self.fields.maxLevelValue = ns.DateTimePicker:CreateScrollDropdown(
        self.content,
        "GuildQuestsCreateMaxLevelDropdown",
        180
    )
    self.fields.maxLevelValue:SetPoint("TOPLEFT", 8, y - 332)
    self.fields.maxLevelValue:Hide()

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
    self.participantsUnlimited = true
    self.levelUnlimited = true
    self.selectedMaxLevel = 1

    self:RefreshMaxLevelDropdown()
    self:UpdateTexts()
    self:UpdateTimeValueVisibility()

    ns.GQ:RegisterCallback("LocaleChanged", function()
        self:UpdateTexts()
        if self.dateTimePicker then
            self.dateTimePicker.refresh()
        end
    end)
end

function CreateQuest:CreateDescriptionField(y)
    self.labels["CREATE_QUEST_DESC"] = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.labels["CREATE_QUEST_DESC"]:SetPoint("TOPLEFT", 16, y)

    local scrollBG = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    scrollBG:SetSize(460, 110)
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

    local scroll = CreateFrame("ScrollFrame", "GuildQuestsCreateDescScroll", self.content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", scrollBG, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -6, 6)
    scroll:EnableMouse(true)

    local desc = CreateFrame("EditBox", "GuildQuestsCreateDescEdit", scroll)
    desc:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    desc:SetMultiLine(true)
    desc:SetFontObject(ChatFontNormal)
    desc:SetWidth(420)
    desc:SetHeight(160)
    desc:SetAutoFocus(false)
    desc:EnableMouse(true)
    desc:EnableKeyboard(true)
    -- 0 = no EditBox byte cap; length is enforced on submit (UTF-8 characters, not bytes).
    desc:SetMaxLetters(0)
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

function CreateQuest:SetDropdownRow(labelKey, dropdown, offsetY)
    local label = self.labels[labelKey]
    if label then
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", 16, offsetY)
    end
    if dropdown then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", 8, offsetY - 22)
    end
end

function CreateQuest:UpdateFormLayout()
    local mode = self.selectedTimeMode or C.TIME_MODE.NONE
    local showTimeValue = mode ~= C.TIME_MODE.NONE
    local label = self.labels["CREATE_DEADLINE"]

    if label then
        label:SetShown(showTimeValue)
        if showTimeValue then
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", 16, self.layout.timeModeY - 58)
        end
    end
    if self.dateTimePicker then
        self.dateTimePicker:SetShown(showTimeValue)
        if showTimeValue then
            self.dateTimePicker:ClearAllPoints()
            self.dateTimePicker:SetPoint("TOPLEFT", 8, self.layout.timeModeY - 80)
        end
    end

    if showTimeValue then
        self:UpdateTimeValueLabel()
    end

    local showMaxParticipants = self.selectedCategory ~= "PERMANENT"
    if self.labels["CREATE_MAX_PARTICIPANTS"] then
        self.labels["CREATE_MAX_PARTICIPANTS"]:SetShown(showMaxParticipants)
    end
    if self.fields.maxParticipantsMode then
        self.fields.maxParticipantsMode:SetShown(showMaxParticipants)
    end

    local maxY = showTimeValue and self.layout.maxParticipantsY or self.layout.maxParticipantsCompactY
    if showMaxParticipants then
        self:SetDropdownRow("CREATE_MAX_PARTICIPANTS", self.fields.maxParticipantsMode, maxY)
    end

    local limited = showMaxParticipants and not self.participantsUnlimited
    if self.labels["CREATE_PARTICIPANTS_LIMIT"] then
        self.labels["CREATE_PARTICIPANTS_LIMIT"]:SetShown(limited)
        if limited then
            self.labels["CREATE_PARTICIPANTS_LIMIT"]:ClearAllPoints()
            self.labels["CREATE_PARTICIPANTS_LIMIT"]:SetPoint("TOPLEFT", 16, maxY - 58)
        end
    end
    if self.fields.maxParticipantsLimit then
        self.fields.maxParticipantsLimit:SetShown(limited)
        if limited then
            self.fields.maxParticipantsLimit:ClearAllPoints()
            self.fields.maxParticipantsLimit:SetPoint("TOPLEFT", 20, maxY - 76)
        end
    end

    local participantsBottomY = maxY
    if showMaxParticipants then
        participantsBottomY = limited and (maxY - 76) or (maxY - 22)
    end
    local levelY = participantsBottomY - 36
    self:SetDropdownRow("CREATE_MIN_LEVEL", self.fields.minLevelMode, levelY)

    local levelLimited = not self.levelUnlimited
    if self.labels["CREATE_LEVEL_VALUE"] then
        self.labels["CREATE_LEVEL_VALUE"]:SetShown(levelLimited)
        if levelLimited then
            self.labels["CREATE_LEVEL_VALUE"]:ClearAllPoints()
            self.labels["CREATE_LEVEL_VALUE"]:SetPoint("TOPLEFT", 16, levelY - 58)
        end
    end
    if self.fields.maxLevelValue then
        self.fields.maxLevelValue:SetShown(levelLimited)
        if levelLimited then
            self.fields.maxLevelValue:ClearAllPoints()
            self.fields.maxLevelValue:SetPoint("TOPLEFT", 8, levelY - 80)
        end
    end

    local contentBottomY
    if not showMaxParticipants then
        contentBottomY = showTimeValue
            and self.layout.contentBottomExpandedNoMaxY
            or self.layout.contentBottomCompactNoMaxY
    elseif showTimeValue then
        contentBottomY = limited
            and self.layout.contentBottomExpandedLimitedY
            or self.layout.contentBottomExpandedY
    else
        contentBottomY = limited
            and self.layout.contentBottomCompactLimitedY
            or self.layout.contentBottomCompactY
    end
    if levelLimited then
        contentBottomY = contentBottomY - 58
    else
        contentBottomY = contentBottomY - 36
    end
    self.content:SetHeight(math.abs(contentBottomY) + 24)
    self.scroll:UpdateScrollChildRect()
end

function CreateQuest:UpdateTimeValueVisibility()
    self:UpdateFormLayout()
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

    self.title:SetText(ns.L["CREATE_TITLE"])
    for key, label in pairs(self.labels or {}) do
        label:SetText(ns.L[key])
    end
    self:UpdateTimeValueLabel()
    self:UpdateTimeValueVisibility()
    self.submit:SetText(ns.L["CREATE_SUBMIT"])
    self.cancel:SetText(ns.L["CREATE_CANCEL"])

    if self.selectedCategory then
        UIDropDownMenu_SetText(self.fields.category, Util:GetCategoryLabel(self.selectedCategory))
    end
    if self.selectedTimeMode then
        UIDropDownMenu_SetText(self.fields.timeMode, self:GetTimeModeLabel(self.selectedTimeMode))
    end
    if self.fields.maxParticipantsMode then
        UIDropDownMenu_SetText(
            self.fields.maxParticipantsMode,
            self:GetParticipantsModeLabel(self.participantsUnlimited ~= false)
        )
    end
    if self.fields.minLevelMode then
        UIDropDownMenu_SetText(
            self.fields.minLevelMode,
            self:GetLevelModeLabel(self.levelUnlimited ~= false)
        )
    end
    self:RefreshMaxLevelDropdown()
end

function CreateQuest:Reset()
    self.fields.title:SetText("")
    self.fields.desc:SetText("")
    self.fields.reward:SetText("")
    self.participantsUnlimited = true
    self.levelUnlimited = true
    self.selectedMaxLevel = 1
    self.fields.maxParticipantsLimit:SetText("5")
    self.selectedCategory = "OTHER"
    self.selectedTimeMode = C.TIME_MODE.NONE
    UIDropDownMenu_SetText(self.fields.category, Util:GetCategoryLabel("OTHER"))
    UIDropDownMenu_SetText(self.fields.timeMode, self:GetTimeModeLabel(C.TIME_MODE.NONE))
    UIDropDownMenu_SetText(
        self.fields.maxParticipantsMode,
        self:GetParticipantsModeLabel(true)
    )
    UIDropDownMenu_SetText(
        self.fields.minLevelMode,
        self:GetLevelModeLabel(true)
    )
    self:RefreshMaxLevelDropdown()
    ns.DateTimePicker:SetDefault(self.dateTimePicker)
    self.dateTimePicker.refresh()
    self:UpdateTimeValueVisibility()
end

function CreateQuest:Show()
    if not Util:GetGuildKey() then
        ns.GQ:Print(ns.L["ERR_NOT_IN_GUILD"])
        return
    end
    local canCreate, err = ns.Rules:CanCreateQuest()
    if not canCreate then
        ns.GQ:Print(err or ns.L["ERR_NO_PERMISSION"])
        return
    end
    self:UpdateTexts()
    self:Reset()
    self.scroll:SetVerticalScroll(0)
    self.frame:Show()
end

function CreateQuest:Hide()
    self.frame:Hide()
end

function CreateQuest:Submit()
    self.fields.desc:ClearFocus()
    self.fields.title:ClearFocus()

    local maxParticipants = 0
    if self.selectedCategory ~= "PERMANENT" and not self.participantsUnlimited then
        maxParticipants = tonumber(self.fields.maxParticipantsLimit:GetText()) or 0
    end

    local maxLevel = 0
    if not self.levelUnlimited then
        maxLevel = self.selectedMaxLevel or 1
    end

    local data = {
        title = self.fields.title:GetText() or "",
        description = self.fields.desc:GetText() or "",
        category = self.selectedCategory,
        reward = Util:Trim(self.fields.reward:GetText() or ""),
        timeMode = self.selectedTimeMode,
        maxParticipants = maxParticipants,
        maxLevel = maxLevel,
        itemRewards = {},
    }
    local ts = ns.DateTimePicker:GetTimestamp(self.dateTimePicker)
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
