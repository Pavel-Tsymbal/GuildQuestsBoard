local _, ns = ...
local Util = ns.Util

local DateTimePicker = {}
ns.DateTimePicker = DateTimePicker

local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local SCROLL_ITEM_HEIGHT = 16
local SCROLL_VISIBLE_ITEMS = 8
local SCROLL_LIST_PADDING = 16

local function configureDropdown(dropdown, width)
    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_SetAnchor(dropdown, 0, 0, "TOPLEFT", dropdown, "BOTTOMLEFT")
end

local function createScrollDropdown(parent, name, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    configureDropdown(dropdown, width)
    UIDropDownMenu_Initialize(dropdown, function() end)

    local popup = CreateFrame("Frame", name .. "Popup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:SetSize(width + 24, SCROLL_VISIBLE_ITEMS * SCROLL_ITEM_HEIGHT + SCROLL_LIST_PADDING)
    popup:Hide()
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(width)
    scroll:SetScrollChild(content)

    dropdown.popup = popup
    dropdown.content = content
    dropdown.rows = {}

    local function hidePopup()
        popup:Hide()
    end

    popup:SetScript("OnHide", function()
        if dropdown.closeWatcher then
            dropdown.closeWatcher:SetScript("OnUpdate", nil)
            dropdown.closeWatcher = nil
        end
    end)

    local function showPopup()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, 0)
        popup:Show()

        if dropdown.closeWatcher then
            return
        end

        dropdown.closeWatcher = CreateFrame("Frame", nil, UIParent)
        dropdown.closeWatcher:SetScript("OnUpdate", function(self)
            if not popup:IsShown() then
                self:SetScript("OnUpdate", nil)
                dropdown.closeWatcher = nil
                return
            end

            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                if not popup:IsMouseOver() and not dropdown:IsMouseOver() then
                    hidePopup()
                end
            end
        end)
    end

    function dropdown:SetScrollItems(items, selectedValue)
        local selectedText = items[1] and items[1].text or ""
        local selectedIndex = 1
        for index, item in ipairs(items) do
            local row = self.rows[index]
            if not row then
                row = CreateFrame("Button", nil, self.content)
                row:SetSize(width, SCROLL_ITEM_HEIGHT)
                row:SetNormalFontObject("GameFontHighlightSmall")
                row:SetHighlightFontObject("GameFontHighlightSmall")
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                if index == 1 then
                    row:SetPoint("TOPLEFT", 0, 0)
                else
                    row:SetPoint("TOPLEFT", self.rows[index - 1], "BOTTOMLEFT", 0, 0)
                end
                self.rows[index] = row
            end

            row.value = item.value
            row:SetText(item.text)
            row:Show()
            if item.value == selectedValue then
                selectedText = item.text
                selectedIndex = index
            end
            row:SetScript("OnClick", function(btn)
                dropdown.onSelect(btn.value, btn:GetText())
                UIDropDownMenu_SetText(dropdown, btn:GetText())
                hidePopup()
            end)
        end

        for index = #items + 1, #self.rows do
            self.rows[index]:Hide()
        end

        self.content:SetHeight(#items * SCROLL_ITEM_HEIGHT)
        self.scrollToIndex = selectedIndex
        UIDropDownMenu_SetText(dropdown, selectedText)
    end

    local function scrollToSelected()
        local index = dropdown.scrollToIndex or 1
        local offset = math.max(0, (index - 1) * SCROLL_ITEM_HEIGHT - SCROLL_ITEM_HEIGHT * 2)
        scroll:SetVerticalScroll(offset)
    end

    local button = _G[name .. "Button"]
    button:SetScript("OnClick", function()
        if popup:IsShown() then
            hidePopup()
        else
            showPopup()
            scrollToSelected()
        end
    end)

    return dropdown
end

function DateTimePicker:IsLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

function DateTimePicker:DaysInMonth(year, month)
    if month == 2 and self:IsLeapYear(year) then
        return 29
    end
    return MONTH_DAYS[month] or 31
end

function DateTimePicker:GetMonthLabel(month)
    local ts = Util:TimeFromParts(2020, month, 1, 0, 0, 0)
    if ts then
        return date("%b", ts)
    end
    return tostring(month)
end

function DateTimePicker:Create(parent)
    local picker = CreateFrame("Frame", nil, parent)
    picker:SetSize(460, 52)
    local gap = -18

    picker.values = {
        year = 0,
        month = 1,
        day = 1,
        hour = 0,
        min = 0,
    }

    local function setDropdownText(dropdown, text)
        UIDropDownMenu_SetText(dropdown, text)
    end

    local function addOption(dropdown, text, value, onSelect)
        local info = UIDropDownMenu_CreateInfo()
        info.text = text
        info.value = value
        info.func = function()
            onSelect(value, text)
        end
        UIDropDownMenu_AddButton(info)
    end

    local function refreshDayDropdown()
        UIDropDownMenu_Initialize(picker.dayDropdown, function()
            local maxDay = DateTimePicker:DaysInMonth(picker.values.year, picker.values.month)
            if picker.values.day > maxDay then
                picker.values.day = maxDay
            end
            for day = 1, maxDay do
                local label = string.format("%02d", day)
                addOption(picker.dayDropdown, label, day, function(value, text)
                    picker.values.day = value
                    setDropdownText(picker.dayDropdown, text)
                end)
            end
        end)
        setDropdownText(picker.dayDropdown, string.format("%02d", picker.values.day))
    end

    local function refreshMonthDropdown()
        UIDropDownMenu_Initialize(picker.monthDropdown, function()
            for month = 1, 12 do
                local label = DateTimePicker:GetMonthLabel(month)
                addOption(picker.monthDropdown, label, month, function(value, text)
                    picker.values.month = value
                    setDropdownText(picker.monthDropdown, text)
                    refreshDayDropdown()
                end)
            end
        end)
        setDropdownText(picker.monthDropdown, self:GetMonthLabel(picker.values.month))
    end

    local function refreshYearDropdown()
        local currentYear = date("*t", GetServerTime()).year
        UIDropDownMenu_Initialize(picker.yearDropdown, function()
            for year = currentYear, currentYear + 2 do
                local label = tostring(year)
                addOption(picker.yearDropdown, label, year, function(value, text)
                    picker.values.year = value
                    setDropdownText(picker.yearDropdown, text)
                    refreshDayDropdown()
                end)
            end
        end)
        setDropdownText(picker.yearDropdown, tostring(picker.values.year))
    end

    local function refreshHourDropdown()
        UIDropDownMenu_Initialize(picker.hourDropdown, function()
            for hour = 0, 23 do
                local label = string.format("%02d", hour)
                addOption(picker.hourDropdown, label, hour, function(value, text)
                    picker.values.hour = value
                    setDropdownText(picker.hourDropdown, text)
                end)
            end
        end)
        setDropdownText(picker.hourDropdown, string.format("%02d", picker.values.hour))
    end

    local function refreshMinuteDropdown()
        local items = {}
        for minute = 0, 59 do
            table.insert(items, {
                value = minute,
                text = string.format("%02d", minute),
            })
        end
        picker.minuteDropdown.onSelect = function(value, text)
            picker.values.min = value
        end
        picker.minuteDropdown:SetScrollItems(items, picker.values.min)
    end

    picker.dayDropdown = CreateFrame("Frame", nil, picker, "UIDropDownMenuTemplate")
    picker.dayDropdown:SetPoint("TOPLEFT", 0, 0)
    configureDropdown(picker.dayDropdown, 48)

    picker.monthDropdown = CreateFrame("Frame", nil, picker, "UIDropDownMenuTemplate")
    picker.monthDropdown:SetPoint("LEFT", picker.dayDropdown, "RIGHT", gap, 0)
    configureDropdown(picker.monthDropdown, 72)

    picker.yearDropdown = CreateFrame("Frame", nil, picker, "UIDropDownMenuTemplate")
    picker.yearDropdown:SetPoint("LEFT", picker.monthDropdown, "RIGHT", gap, 0)
    configureDropdown(picker.yearDropdown, 58)

    picker.hourDropdown = CreateFrame("Frame", nil, picker, "UIDropDownMenuTemplate")
    picker.hourDropdown:SetPoint("LEFT", picker.yearDropdown, "RIGHT", gap, 0)
    configureDropdown(picker.hourDropdown, 48)

    picker.minuteLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    picker.minuteLabel:SetPoint("LEFT", picker.hourDropdown, "RIGHT", -10, 2)
    picker.minuteLabel:SetText(":")

    picker.minuteDropdown = createScrollDropdown(picker, "GuildQuestsDateMinuteDropdown", 48)
    picker.minuteDropdown:SetPoint("LEFT", picker.minuteLabel, "RIGHT", -6, 0)

    picker.refresh = function()
        refreshDayDropdown()
        refreshMonthDropdown()
        refreshYearDropdown()
        refreshHourDropdown()
        refreshMinuteDropdown()
    end

    self:SetDefault(picker)
    picker.refresh()
    return picker
end

function DateTimePicker:SetDefault(picker)
    local now = date("*t", GetServerTime() + 3600)
    now.min = 0
    now.sec = 0
    picker.values.year = now.year
    picker.values.month = now.month
    picker.values.day = now.day
    picker.values.hour = now.hour
    picker.values.min = now.min
end

function DateTimePicker:SetTimestamp(picker, timestamp)
    if not picker or not timestamp then
        return
    end
    local parts = date("*t", timestamp)
    picker.values.year = parts.year
    picker.values.month = parts.month
    picker.values.day = parts.day
    picker.values.hour = parts.hour
    picker.values.min = parts.min
    picker.refresh()
end

function DateTimePicker:GetTimestamp(picker)
    if not picker then
        return nil
    end
    local values = picker.values
    return Util:TimeFromParts(
        values.year,
        values.month,
        values.day,
        values.hour,
        values.min,
        0
    )
end
