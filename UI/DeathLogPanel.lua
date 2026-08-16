local _, ns = ...
local C = ns.Constants

local DeathLogPanel = {}
ns.DeathLogPanel = DeathLogPanel

DeathLogPanel.rows = {}

function DeathLogPanel:Init(scrollChild, viewFrame, scrollFrame)
    self.scrollChild = scrollChild
    self.viewFrame = viewFrame
    self.scrollFrame = scrollFrame

    self.header = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, 8)
    self.header:SetWidth(740)
    self.header:SetJustifyH("LEFT")
    self.header:SetText(ns.L["DEATHLOG_COLUMNS"])

    self.emptyText = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.emptyText:SetPoint("TOP", viewFrame, "TOP", 0, -20)
    self.emptyText:SetWidth(560)
    self.emptyText:SetJustifyH("CENTER")

    self.summaryText = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.summaryText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    self.summaryText:SetWidth(520)
    self.summaryText:SetJustifyH("LEFT")

    self.reqPanel = CreateFrame("Frame", nil, viewFrame, "BackdropTemplate")
    self.reqPanel:SetPoint("BOTTOMLEFT", 0, 0)
    self.reqPanel:SetPoint("BOTTOMRIGHT", -28, 0)
    self.reqPanel:SetHeight(124)
    self.reqPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    self.reqPanel:SetBackdropColor(0.08, 0.08, 0.11, 0.92)
    self.reqPanel:SetBackdropBorderColor(0.78, 0.62, 0.22, 0.85)

    self.reqWip = self.reqPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.reqWip:SetPoint("TOPLEFT", 12, -8)
    self.reqWip:SetWidth(740)
    self.reqWip:SetJustifyH("LEFT")

    self.reqTitle = self.reqPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.reqTitle:SetPoint("TOPLEFT", self.reqWip, "BOTTOMLEFT", 0, -6)
    self.reqTitle:SetWidth(740)
    self.reqTitle:SetJustifyH("LEFT")

    self.reqChannel = self.reqPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.reqChannel:SetPoint("TOPLEFT", self.reqTitle, "BOTTOMLEFT", 0, -4)
    self.reqChannel:SetWidth(740)
    self.reqChannel:SetJustifyH("LEFT")

    self.reqBody = self.reqPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.reqBody:SetPoint("TOPLEFT", self.reqChannel, "BOTTOMLEFT", 0, -6)
    self.reqBody:SetWidth(740)
    self.reqBody:SetJustifyH("LEFT")

    self:SetupBackground(viewFrame, scrollFrame)

    ns.GQ:RegisterCallback("LocaleChanged", function()
        if ns.MainUI and ns.MainUI:IsDeathLogView() then
            self:Refresh()
        end
    end)
end

function DeathLogPanel:SetupBackground(viewFrame, scrollFrame)
    local baseLevel = viewFrame:GetFrameLevel()

    self.bgFrame = CreateFrame("Frame", nil, viewFrame)
    self.bgFrame:SetPoint("TOPLEFT", 0, 0)
    self.bgFrame:SetPoint("BOTTOMRIGHT", -28, 132)
    self.bgFrame:SetFrameLevel(baseLevel + 1)
    self.bgFrame:EnableMouse(false)

    self.bgSkull = self.bgFrame:CreateTexture(nil, "BACKGROUND")
    -- Target-frame skull art has no item-icon square border.
    self.bgSkull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    self.bgSkull:SetSize(320, 320)
    self.bgSkull:SetPoint("CENTER", 0, -24)
    self.bgSkull:SetAlpha(0.16)
    self.bgSkull:SetVertexColor(0.92, 0.84, 0.68)

    if scrollFrame then
        scrollFrame:SetFrameLevel(baseLevel + 3)
    end
    if self.reqPanel then
        self.reqPanel:SetFrameLevel(baseLevel + 3)
    end
end

function DeathLogPanel:IsHardcoreDeathsChannelJoined()
    local channelIndex = GetChannelName("HardcoreDeaths")
    return channelIndex and channelIndex > 0
end

function DeathLogPanel:UpdateRequirements()
    if not self.reqPanel then
        return
    end
    self.reqTitle:SetText(ns.L["DEATHLOG_REQUIREMENTS_TITLE"])
    self.reqWip:SetText("|cffffcc00" .. ns.L["DEATHLOG_WIP_NOTICE"] .. "|r")
    if self:IsHardcoreDeathsChannelJoined() then
        self.reqChannel:SetText("|cff33aa33" .. ns.L["DEATHLOG_REQ_CHANNEL_OK"] .. "|r")
    else
        self.reqChannel:SetText("|cffff5555" .. ns.L["DEATHLOG_REQ_CHANNEL_MISSING"] .. "|r")
    end
    self.reqBody:SetText(ns.L["DEATHLOG_REQUIREMENTS_BODY"])
end

function DeathLogPanel:CreateRow(parent, index)
    local row = CreateFrame("Frame", "GuildQuestsDeathLogRow" .. index, parent, "BackdropTemplate")
    row:SetSize(760, 44)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    row:SetBackdropColor(0.12, 0.12, 0.16, 0.85)
    row:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.nameText:SetPoint("LEFT", 10, 6)
    row.nameText:SetWidth(180)
    row.nameText:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetPoint("LEFT", 10, -10)
    row.meta:SetWidth(420)
    row.meta:SetJustifyH("LEFT")

    row.dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.dateText:SetPoint("RIGHT", -10, 4)
    row.dateText:SetWidth(130)
    row.dateText:SetJustifyH("RIGHT")

    row.sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    row.sourceText:SetPoint("RIGHT", -10, -12)
    row.sourceText:SetWidth(200)
    row.sourceText:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
        if not self.entry then
            return
        end
        local entry = self.entry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(ns.DeathLog:GetColoredName(entry), 1, 1, 1)
        GameTooltip:AddLine(string.format(
            "%s %s | %s | %s",
            ns.L["DEATHLOG_COL_LEVEL"] .. ": " .. (entry.level or "?"),
            ns.DeathLog:GetClassLabel(entry.classId),
            ns.DeathLog:GetRaceLabel(entry.raceId),
            ns.DeathLog:FormatDate(entry.date)
        ), 1, 0.82, 0, true)
        GameTooltip:AddLine((entry.zone or "?") .. " — " .. (entry.source or "?"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

function DeathLogPanel:Refresh()
    if not self.scrollChild then
        return
    end

    self:UpdateRequirements()

    for _, row in ipairs(self.rows) do
        row:Hide()
    end

    self.header:SetText(ns.L["DEATHLOG_COLUMNS"])
    local entries, totalCount = ns.DeathLog:GetEntries()

    if #entries == 0 then
        self.header:Hide()
        self.summaryText:Hide()
        self.emptyText:SetText(ns.L["DEATHLOG_EMPTY"])
        self.emptyText:Show()
        self.scrollChild:SetHeight(280)
        return
    end

    self.emptyText:Hide()
    self.header:Show()
    if totalCount > #entries then
        self.summaryText:SetText(string.format(ns.L["DEATHLOG_COUNT_LIMITED"], #entries, totalCount))
        self.summaryText:Show()
    else
        self.summaryText:SetText(string.format(ns.L["DEATHLOG_COUNT"], totalCount))
        self.summaryText:Show()
    end

    local y = 24
    for i, entry in ipairs(entries) do
        local row = self.rows[i]
        if not row then
            row = self:CreateRow(self.scrollChild, i)
            self.rows[i] = row
        end
        row.entry = entry
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()

        row.nameText:SetText(ns.DeathLog:GetColoredName(entry))
        row.meta:SetText(ns.DeathLog:FormatMetaLine(entry))
        row.dateText:SetText(ns.DeathLog:FormatDate(entry.date))
        row.sourceText:SetText(entry.source ~= "" and entry.source or ns.L["DEATHLOG_SOURCE_UNKNOWN"])

        y = y + 48
    end

    self.scrollChild:SetHeight(math.max(y + 8, 280))
end
