local _, ns = ...

local SettingsPanel = {}
ns.SettingsPanel = SettingsPanel

function SettingsPanel:Init(container)
    self.container = container

    self.tabPersonal = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    self.tabPersonal:SetSize(120, 24)
    self.tabPersonal:SetPoint("TOPLEFT", 0, 0)
    self.tabPersonal:SetText(ns.L["SETTINGS_PERSONAL"])
    self.tabPersonal:SetScript("OnClick", function()
        self:ShowPersonal()
    end)

    self.tabGuild = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    self.tabGuild:SetSize(120, 24)
    self.tabGuild:SetPoint("LEFT", self.tabPersonal, "RIGHT", 8, 0)
    self.tabGuild:SetText(ns.L["SETTINGS_GUILD"])
    self.tabGuild:SetScript("OnClick", function()
        self:ShowGuild()
    end)

    self.content = CreateFrame("Frame", nil, container)
    self.content:SetPoint("TOPLEFT", 0, -32)
    self.content:SetPoint("BOTTOMRIGHT", 0, 0)

    ns.GQ:RegisterCallback("LocaleChanged", function()
        self.tabPersonal:SetText(ns.L["SETTINGS_PERSONAL"])
        self.tabGuild:SetText(ns.L["SETTINGS_GUILD"])
        if ns.MainUI:IsSettingsView() then
            if self.activeTab == "guild" then
                self:ShowGuild()
            else
                self:ShowPersonal()
            end
        end
    end)
    ns.GQ:RegisterCallback("GuildSettingsUpdated", function()
        if ns.MainUI:IsSettingsView() and self.activeTab == "guild" then
            self:ShowGuild()
        end
    end)
end

function SettingsPanel:UpdateTabHighlight()
    if self.activeTab == "guild" then
        self.tabGuild:SetEnabled(false)
        self.tabPersonal:SetEnabled(true)
    else
        self.tabPersonal:SetEnabled(false)
        self.tabGuild:SetEnabled(true)
    end
end

function SettingsPanel:ClearContent()
    local children = { self.content:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    self.activePanel = nil
end

function SettingsPanel:AddCheck(parent, label, checked, tipKey, onChange, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 0, y)
    text:SetText(label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y + 4)
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function()
        onChange(cb:GetChecked())
    end)
    ns.AttachTooltip(text, tipKey)
    table.insert(parent.widgets, cb)
    table.insert(parent.widgets, text)
    return y - 28
end

function SettingsPanel:AddSlider(parent, label, value, min, max, tipKey, onChange, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 0, y)
    text:SetText(label .. ": " .. tostring(value))
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, y - 20)
    slider:SetWidth(220)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(value)
    slider:SetScript("OnValueChanged", function(_, v)
        text:SetText(label .. ": " .. tostring(math.floor(v)))
        onChange(math.floor(v))
    end)
    ns.AttachTooltip(text, tipKey)
    table.insert(parent.widgets, slider)
    table.insert(parent.widgets, text)
    return y - 52
end

function SettingsPanel:ShowPersonal()
    self.activeTab = "personal"
    self:UpdateTabHighlight()
    self:ClearContent()
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetAllPoints()
    panel.widgets = {}
    self.activePanel = panel
    local db = ns.PersonalSettings:Get()
    local y = 0

    y = self:AddCheck(panel, ns.L["SETTINGS_NOTIFICATIONS"], db.notifications.enabled, "PERSONAL_NOTIFICATIONS", function(v)
        ns.PersonalSettings:SetNotifications("enabled", v)
    end, y)

    y = self:AddSlider(panel, ns.L["SETTINGS_NOTIFICATION_DURATION"], db.notifications.duration or 5, 2, 15, "PERSONAL_DURATION", function(v)
        ns.PersonalSettings:SetNotifications("duration", v)
    end, y)

    y = self:AddCheck(panel, ns.L["SETTINGS_NOTIFICATION_SOUND"], db.notifications.sound, "PERSONAL_SOUND", function(v)
        ns.PersonalSettings:SetNotifications("sound", v)
    end, y)

    y = self:AddCheck(panel, ns.L["SETTINGS_NOTIFICATION_COMBAT"], db.notifications.showInCombat, "PERSONAL_COMBAT", function(v)
        ns.PersonalSettings:SetNotifications("showInCombat", v)
    end, y)

    y = self:AddCheck(panel, ns.L["SETTINGS_MINIMAP"], db.ui.minimap.hide, "PERSONAL_LOCALE", function(v)
        ns.PersonalSettings:SetMinimapHidden(v)
        ns.Minimap:Refresh()
    end, y)

    local localeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    localeLabel:SetPoint("TOPLEFT", 0, y)
    localeLabel:SetText(ns.L["SETTINGS_LOCALE"])
    ns.AttachTooltip(localeLabel, "PERSONAL_LOCALE")

    local enBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    enBtn:SetSize(80, 22)
    enBtn:SetPoint("TOPLEFT", 0, y - 22)
    enBtn:SetText(ns.L["LOCALE_EN"])
    enBtn:SetScript("OnClick", function()
        ns.PersonalSettings:SetLocale("enUS")
        self:ShowPersonal()
    end)

    local ruBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ruBtn:SetSize(80, 22)
    ruBtn:SetPoint("LEFT", enBtn, "RIGHT", 8, 0)
    ruBtn:SetText(ns.L["LOCALE_RU"])
    ruBtn:SetScript("OnClick", function()
        ns.PersonalSettings:SetLocale("ruRU")
        self:ShowPersonal()
    end)
end

function SettingsPanel:ShowGuild()
    self.activeTab = "guild"
    self:UpdateTabHighlight()
    self:ClearContent()
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetAllPoints()
    panel.widgets = {}
    self.activePanel = panel

    if not ns.GuildSettings:CanEdit() then
        local ro = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        ro:SetPoint("TOPLEFT", 0, 0)
        ro:SetWidth(760)
        ro:SetText(ns.L["GUILD_READONLY"])
        self:RenderGuildReadOnly(panel, -28)
        return
    end

    self:RenderGuildEditor(panel, 0)
end

function SettingsPanel:RenderGuildReadOnly(panel, y)
    local settings = ns.GuildSettings:Get()
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 0, y)
    fs:SetWidth(760)
    fs:SetJustifyH("LEFT")
    fs:SetText(string.format(
        "%s: create=%d accept=%d",
        ns.L["GUILD_SYNC"],
        settings.sync.minOnlineToCreate or 2,
        settings.sync.minOnlineToAccept or 2
    ))
end

function SettingsPanel:RenderGuildEditor(panel, y)
    local settings = ns.GuildSettings:EnsureRankRows()
    local minCreate = settings.sync.minOnlineToCreate or 2

    local createLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    createLabel:SetPoint("TOPLEFT", 0, y)
    createLabel:SetText(ns.L["GUILD_MIN_CREATE"] .. ": " .. minCreate)
    ns.AttachTooltip(createLabel, "GUILD_MIN_CREATE")

    local createSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    createSlider:SetPoint("TOPLEFT", 0, y - 24)
    createSlider:SetWidth(240)
    createSlider:SetMinMaxValues(1, 10)
    createSlider:SetValueStep(1)
    createSlider:SetObeyStepOnDrag(true)
    createSlider:SetValue(minCreate)
    createSlider:SetScript("OnValueChanged", function(_, v)
        settings.sync.minOnlineToCreate = math.floor(v)
        createLabel:SetText(ns.L["GUILD_MIN_CREATE"] .. ": " .. math.floor(v))
    end)

    y = y - 64
    local minAccept = settings.sync.minOnlineToAccept or 2
    local acceptLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    acceptLabel:SetPoint("TOPLEFT", 0, y)
    acceptLabel:SetText(ns.L["GUILD_MIN_ACCEPT"] .. ": " .. minAccept)
    ns.AttachTooltip(acceptLabel, "GUILD_MIN_ACCEPT")

    local acceptSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    acceptSlider:SetPoint("TOPLEFT", 0, y - 24)
    acceptSlider:SetWidth(240)
    acceptSlider:SetMinMaxValues(1, 10)
    acceptSlider:SetValueStep(1)
    acceptSlider:SetObeyStepOnDrag(true)
    acceptSlider:SetValue(minAccept)
    acceptSlider:SetScript("OnValueChanged", function(_, v)
        settings.sync.minOnlineToAccept = math.floor(v)
        acceptLabel:SetText(ns.L["GUILD_MIN_ACCEPT"] .. ": " .. math.floor(v))
    end)

    y = y - 64
    local permTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    permTitle:SetPoint("TOPLEFT", 0, y)
    permTitle:SetText(ns.L["GUILD_PERMISSIONS"])

    local permDefs = {
        { key = "create", label = "GUILD_PERM_CREATE", tip = "GUILD_PERM_CREATE" },
        { key = "approve", label = "GUILD_PERM_APPROVE", tip = "GUILD_PERM_APPROVE" },
        { key = "close", label = "GUILD_PERM_CLOSE", tip = "GUILD_PERM_CLOSE" },
        { key = "rewardPaid", label = "GUILD_PERM_REWARD", tip = "GUILD_PERM_REWARD" },
        { key = "delete", label = "GUILD_PERM_DELETE", tip = "GUILD_PERM_DELETE" },
    }
    local permColStart = 100
    local permColWidth = 72

    y = y - 22
    local rankHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rankHeader:SetPoint("TOPLEFT", 0, y)
    rankHeader:SetWidth(100)
    rankHeader:SetJustifyH("LEFT")
    rankHeader:SetText(ns.L["GUILD_PERM_RANK"])

    for i, def in ipairs(permDefs) do
        local header = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        header:SetPoint("TOPLEFT", permColStart + (i - 1) * permColWidth, y)
        header:SetWidth(permColWidth - 4)
        header:SetJustifyH("CENTER")
        header:SetText(ns.L[def.label])
        ns.AttachTooltip(header, def.tip)
    end

    y = y - 24
    local numRanks = ns.GuildRank:GetNumRanks()
    for rankIndex = 0, numRanks - 1 do
        local rankName = ns.GuildRank:GetRankName(rankIndex)
        local rankLine = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rankLine:SetPoint("TOPLEFT", 0, y)
        rankLine:SetWidth(100)
        rankLine:SetJustifyH("LEFT")
        rankLine:SetText(rankName)
        local perms = settings.permissions.ranks[rankIndex] or {}
        for i, def in ipairs(permDefs) do
            local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            cb:SetSize(24, 24)
            cb:SetPoint("TOPLEFT", permColStart + (i - 1) * permColWidth + 28, y + 2)
            cb:SetChecked(perms[def.key])
            cb:SetScript("OnClick", function()
                ns.GuildSettings:UpdateRankPermission(rankIndex, def.key, cb:GetChecked())
            end)
            ns.AttachTooltip(cb, def.tip)
        end
        y = y - 28
    end

    panel:SetHeight(math.max(-y + 32, 420))

    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(120, 24)
    save:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    save:SetText(ns.L["GUILD_SAVE"])
    save:SetScript("OnClick", function()
        local ok, err = ns.GuildSettings:Save(settings)
        if not ok then
            ns.GQ:Print(err)
        else
            ns.GQ:Print(ns.L["GUILD_SAVE"])
        end
    end)

    if ns.MainUI.settingsScroll then
        ns.MainUI.settingsScroll:UpdateScrollChildRect()
    end
end

function SettingsPanel:Show()
    ns.MainUI:ShowSettingsView()
end

function SettingsPanel:Hide()
    ns.MainUI:ShowBoardView()
end
