local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local CreateQuest = {}
ns.CreateQuest = CreateQuest

function CreateQuest:Init()
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
    self.title:SetText(ns.L["CREATE_TITLE"])

    local y = -44
    self.fields = {}

    local function addLabel(text, offsetY)
        local fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 16, offsetY)
        fs:SetText(text)
        return fs
    end

    local function addInput(name, offsetY, height)
        addLabel(name, offsetY)
        local box = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
        box:SetSize(400, height or 24)
        box:SetPoint("TOPLEFT", 20, offsetY - 18)
        box:SetAutoFocus(false)
        return box
    end

    self.fields.title = addInput(ns.L["CREATE_QUEST_TITLE"], y)
    y = y - 52
    y = self:CreateDescriptionField(y)
    y = y - 12

    addLabel(ns.L["CREATE_CATEGORY"], y)
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

    self.fields.tag = addInput(ns.L["CREATE_TAG"], y - 48)
    y = y - 96
    self.fields.reward = addInput(ns.L["CREATE_REWARD_GOLD"], y)
    y = y - 52

    addLabel(ns.L["CREATE_TIME_MODE"], y)
    self.fields.timeMode = CreateFrame("Frame", nil, self.frame, "UIDropDownMenuTemplate")
    self.fields.timeMode:SetPoint("TOPLEFT", 8, y - 8)
    UIDropDownMenu_SetWidth(self.fields.timeMode, 180)
    UIDropDownMenu_Initialize(self.fields.timeMode, function()
        local info = UIDropDownMenu_CreateInfo()
        local modes = {
            { key = C.TIME_MODE.NONE, label = ns.L["TIME_MODE_NONE"] },
            { key = C.TIME_MODE.DEADLINE, label = ns.L["TIME_MODE_DEADLINE"] },
            { key = C.TIME_MODE.SCHEDULED, label = ns.L["TIME_MODE_SCHEDULED"] },
        }
        for _, m in ipairs(modes) do
            info.text = m.label
            info.value = m.key
            info.func = function()
                self.selectedTimeMode = m.key
                UIDropDownMenu_SetText(self.fields.timeMode, m.label)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    self.fields.timeValue = addInput(ns.L["CREATE_DEADLINE"], y - 48)
    self.fields.timeValue:SetText("YYYY-MM-DD HH:MM")
    y = y - 96
    self.fields.maxParticipants = addInput(ns.L["CREATE_MAX_PARTICIPANTS"], y)
    self.fields.maxParticipants:SetText("1")

    self.submit = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.submit:SetSize(120, 24)
    self.submit:SetPoint("BOTTOMRIGHT", -16, 16)
    self.submit:SetText(ns.L["CREATE_SUBMIT"])
    self.submit:SetScript("OnClick", function() self:Submit() end)

    self.cancel = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.cancel:SetSize(120, 24)
    self.cancel:SetPoint("RIGHT", self.submit, "LEFT", -8, 0)
    self.cancel:SetText(ns.L["CREATE_CANCEL"])
    self.cancel:SetScript("OnClick", function() self:Hide() end)

    self.selectedCategory = "OTHER"
    self.selectedTimeMode = C.TIME_MODE.NONE
end

function CreateQuest:CreateDescriptionField(y)
    local label = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetText(ns.L["CREATE_QUEST_DESC"])

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

function CreateQuest:ParseDateTime(text)
    text = Util:Trim(text)
    if text == "" or text == "YYYY-MM-DD HH:MM" then
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
    UIDropDownMenu_SetText(self.fields.timeMode, ns.L["TIME_MODE_NONE"])
end

function CreateQuest:Show()
    if not Util:GetGuildKey() then
        ns.GQ:Print(ns.L["ERR_NOT_IN_GUILD"])
        return
    end
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
