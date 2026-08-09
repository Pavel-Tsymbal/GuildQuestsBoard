local _, ns = ...



local AchievementsPanel = {}

ns.AchievementsPanel = AchievementsPanel



AchievementsPanel.earnedIcons = {}

AchievementsPanel.catalogRows = {}

AchievementsPanel.EARNED_ICON_SIZE = 40
AchievementsPanel.EARNED_ICON_GAP = 6
AchievementsPanel.EARNED_ICON_PAD_X = 4
AchievementsPanel.EARNED_ICON_PAD_TOP = 0
AchievementsPanel.EARNED_ICON_PAD_BOTTOM = 2



function AchievementsPanel:Init(earnedFrame, catalogScroll, catalogScrollChild, viewFrame)
    self.earnedFrame = earnedFrame
    self.catalogScroll = catalogScroll
    self.catalogScrollChild = catalogScrollChild
    self.viewFrame = viewFrame

    earnedFrame:SetClipsChildren(false)

    self.earnedEmpty = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.earnedEmpty:SetPoint("CENTER", earnedFrame, "CENTER", 0, 0)

    self.earnedEmpty:SetWidth(560)

    self.earnedEmpty:SetJustifyH("CENTER")



    self.catalogSection = CreateFrame("Frame", nil, viewFrame)
    self.catalogSection:SetPoint("TOPLEFT", earnedFrame, "BOTTOMLEFT", 0, -4)
    self.catalogSection:SetPoint("TOPRIGHT", earnedFrame, "BOTTOMRIGHT", 0, -4)
    self.catalogSection:SetHeight(46)

    self.catalogHeader = self.catalogSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.catalogHeader:SetPoint("TOPLEFT", 4, -2)
    self.catalogHeader:SetWidth(740)
    self.catalogHeader:SetJustifyH("LEFT")

    self.filterBar = CreateFrame("Frame", nil, self.catalogSection)
    self.filterBar:SetPoint("TOPLEFT", self.catalogHeader, "BOTTOMLEFT", -4, -4)
    self.filterBar:SetPoint("TOPRIGHT", self.catalogSection, "TOPRIGHT", 0, 0)
    self.filterBar:SetHeight(24)

    self.excludeSpeedrunCheck = CreateFrame("CheckButton", nil, self.filterBar, "UICheckButtonTemplate")
    self.excludeSpeedrunCheck:SetPoint("LEFT", 4, 0)
    self.excludeSpeedrunLabel = self.filterBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.excludeSpeedrunLabel:SetPoint("LEFT", self.excludeSpeedrunCheck, "RIGHT", 2, 0)

    local panel = self
    self.excludeSpeedrunCheck:SetScript("OnClick", function()
        ns.PersonalSettings:SetAchievementFilter("excludeSpeedrun", panel.excludeSpeedrunCheck:GetChecked())
        panel:RefreshCatalog()
    end)

    catalogScroll:ClearAllPoints()
    catalogScroll:SetPoint("TOPLEFT", self.filterBar, "BOTTOMLEFT", 0, -6)
    catalogScroll:SetPoint("BOTTOMRIGHT", viewFrame, "BOTTOMRIGHT", -28, 0)

    self.catalogEmpty = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.catalogEmpty:SetPoint("CENTER", catalogScroll, "CENTER", 0, 0)

    self.catalogEmpty:SetWidth(560)

    self.catalogEmpty:SetJustifyH("CENTER")

    self.catalogEmpty:Hide()



    self.divider = viewFrame:CreateTexture(nil, "ARTWORK")

    self.divider:SetColorTexture(0.78, 0.62, 0.22, 0.45)

    self.divider:SetHeight(1)



    ns.GQ:RegisterCallback("AchievementEarned", function()

        if ns.MainUI and ns.MainUI:IsAchievementsView() then

            self:Refresh()

        end

    end)

    ns.GQ:RegisterCallback("AchievementFiltersChanged", function()
        if ns.MainUI and ns.MainUI:IsAchievementsView() then
            self:SyncFilterControls()
            self:RefreshCatalog()
        end
    end)

    ns.GQ:RegisterCallback("LocaleChanged", function()

        if ns.MainUI and ns.MainUI:IsAchievementsView() then

            self:Refresh()

        end

    end)

end



function AchievementsPanel:SetDividerAnchor(topFrame)

    if not self.divider or not topFrame then

        return

    end

    self.divider:ClearAllPoints()

    self.divider:SetPoint("TOPLEFT", topFrame, "BOTTOMLEFT", 0, -4)

    self.divider:SetPoint("TOPRIGHT", topFrame, "BOTTOMRIGHT", -28, -4)

end



function AchievementsPanel:SyncFilterControls()
    local filters = ns.PersonalSettings:GetAchievementFilters()
    self.excludeSpeedrunCheck:SetChecked(filters.excludeSpeedrun)
    self.excludeSpeedrunLabel:SetText(ns.L["ACHIEV_FILTER_EXCLUDE_SPEEDRUN"])
end



function AchievementsPanel:GetEarnedFrameWidth()
    local width = self.earnedFrame and self.earnedFrame:GetWidth() or 0
    if width < 100 and self.viewFrame then
        width = self.viewFrame:GetWidth() or 0
        if width > 28 then
            width = width - 28
        end
    end
    if width < 100 then
        width = 760
    end
    return width
end

function AchievementsPanel:GetEarnedIconCols()
    local frameWidth = self:GetEarnedFrameWidth()
    local cellStep = self.EARNED_ICON_SIZE + self.EARNED_ICON_GAP
    return math.max(1, math.floor((frameWidth - self.EARNED_ICON_PAD_X * 2 + self.EARNED_ICON_GAP) / cellStep))
end

function AchievementsPanel:GetEarnedFrameHeight(iconCount, cols)
    if iconCount <= 0 then
        return 48
    end
    cols = math.max(cols, 1)
    local iconSize = self.EARNED_ICON_SIZE
    local cellStep = iconSize + self.EARNED_ICON_GAP
    local rows = math.ceil(iconCount / cols)
    return self.EARNED_ICON_PAD_TOP + (rows - 1) * cellStep + iconSize + self.EARNED_ICON_PAD_BOTTOM
end



function AchievementsPanel:FormatDate(timestamp)

    if not timestamp then

        return "?"

    end

    return date("%Y-%m-%d %H:%M", tonumber(timestamp) or timestamp)

end



function AchievementsPanel:ShowEarnedTooltip(cell, entry, earned)
    if not entry then
        return
    end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(ns.AchievementCatalog:GetTitle(entry), 1, 1, 1)
    GameTooltip:AddLine(ns.AchievementCatalog:GetFactionTagText(entry), 1, 1, 1)
    GameTooltip:AddLine(ns.AchievementCatalog:GetDescription(entry), 1, 1, 1, true)
    if entry.zone and entry.zone ~= "" then
        GameTooltip:AddLine(entry.zone, 1, 0.82, 0)
    end
    if entry.questName and entry.questName ~= "" then
        GameTooltip:AddLine(entry.questName, 0.92, 0.92, 0.92)
    end
    if earned then
        GameTooltip:AddLine(string.format(
            ns.L["ACHIEV_EARNED_META"],
            self:FormatDate(earned.earnedAt),
            earned.level or "?"
        ), 0.55, 0.95, 0.55)
    end
    GameTooltip:AddLine(ns.AchievementCatalog:GetLevelCapText(entry), 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end



function AchievementsPanel:CreateEarnedIcon(parent, index)
    local cell = CreateFrame("Button", "GuildQuestsAchEarnedIcon" .. index, parent, "BackdropTemplate")
    cell:SetSize(self.EARNED_ICON_SIZE, self.EARNED_ICON_SIZE)
    cell:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    cell:SetBackdropColor(0.10, 0.08, 0.05, 0.95)
    cell:SetBackdropBorderColor(0.78, 0.62, 0.22, 0.95)

    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 3, -3)
    cell.icon:SetPoint("BOTTOMRIGHT", -3, 3)

    cell:SetScript("OnEnter", function(self)
        AchievementsPanel:ShowEarnedTooltip(self, self.entry, self.earned)
    end)
    cell:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return cell
end



function AchievementsPanel:CreateCatalogRow(parent, index)

    local row = CreateFrame("Frame", "GuildQuestsAchCatalogRow" .. index, parent, "BackdropTemplate")

    row:SetSize(760, 52)

    row:SetBackdrop({

        bgFile = "Interface\\Buttons\\WHITE8x8",

        edgeFile = "Interface\\Buttons\\WHITE8x8",

        tile = false,

        edgeSize = 1,

    })

    row:SetBackdropColor(0.10, 0.10, 0.13, 0.75)

    row:SetBackdropBorderColor(0.22, 0.22, 0.28, 1)



    row.icon = row:CreateTexture(nil, "ARTWORK")

    row.icon:SetSize(36, 36)

    row.icon:SetPoint("LEFT", 10, 0)



    row.factionTag = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")

    row.factionTag:SetPoint("TOPRIGHT", -12, -6)

    row.factionTag:SetWidth(120)

    row.factionTag:SetJustifyH("RIGHT")



    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

    row.title:SetPoint("LEFT", row.icon, "RIGHT", 10, 4)

    row.title:SetWidth(520)

    row.title:SetJustifyH("LEFT")



    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")

    row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)

    row.meta:SetWidth(520)

    row.meta:SetJustifyH("LEFT")



    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontGreen")

    row.status:SetPoint("RIGHT", -12, 0)

    row.status:SetWidth(90)

    row.status:SetJustifyH("RIGHT")



    row:SetScript("OnEnter", function(self)

        local entry = self.entry

        if not entry then

            return

        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        GameTooltip:ClearLines()

        GameTooltip:AddLine(ns.AchievementCatalog:GetTitle(entry), 1, 1, 1)

        GameTooltip:AddLine(ns.AchievementCatalog:GetFactionTagText(entry), 1, 1, 1)

        GameTooltip:AddLine(ns.AchievementCatalog:GetDescription(entry), 1, 1, 1, true)

        GameTooltip:AddLine(entry.zone or "", 1, 0.82, 0)

        GameTooltip:Show()

    end)

    row:SetScript("OnLeave", function()

        GameTooltip:Hide()

    end)



    return row

end



function AchievementsPanel:HideRows(rows)

    for _, row in ipairs(rows) do

        row:Hide()

    end

end



function AchievementsPanel:RefreshEarned()
    self.earnedEmpty:SetText(ns.L["ACHIEV_EARNED_EMPTY"])
    self:HideRows(self.earnedIcons)

    local earnedList = ns.AchievementStorage:GetAllEarned()
    table.sort(earnedList, function(a, b)
        local atA = tonumber(a.earnedAt) or 0
        local atB = tonumber(b.earnedAt) or 0
        if atA ~= atB then
            return atA < atB
        end
        return (a.id or "") < (b.id or "")
    end)

    local visible = {}
    for _, earned in ipairs(earnedList) do
        local entry = ns.AchievementCatalog:GetById(earned.id)
        if entry and ns.AchievementCatalog:CanPlayerEarn(entry) then
            visible[#visible + 1] = { entry = entry, earned = earned }
        end
    end

    if #visible == 0 then
        self.earnedEmpty:Show()
        self.earnedFrame:SetHeight(48)
        return
    end

    self.earnedEmpty:Hide()

    local iconSize = self.EARNED_ICON_SIZE
    local iconGap = self.EARNED_ICON_GAP
    local padX = self.EARNED_ICON_PAD_X
    local padTop = self.EARNED_ICON_PAD_TOP
    local cols = self:GetEarnedIconCols()
    local cellStep = iconSize + iconGap

    for i, item in ipairs(visible) do
        local cell = self.earnedIcons[i]
        if not cell then
            cell = self:CreateEarnedIcon(self.earnedFrame, i)
            self.earnedIcons[i] = cell
        end

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = padX + col * cellStep
        local y = -(padTop + row * cellStep)

        cell.entry = item.entry
        cell.earned = item.earned
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", x, y)
        cell:Show()
        cell.icon:SetTexture(item.entry.icon)
        cell.icon:SetVertexColor(1, 1, 1)
    end

    self.earnedFrame:SetHeight(self:GetEarnedFrameHeight(#visible, cols))
end



function AchievementsPanel:RefreshCatalog()
    self:SyncFilterControls()
    self.catalogEmpty:SetText(ns.L["ACHIEV_CATALOG_EMPTY_FILTER"])
    self:HideRows(self.catalogRows)

    local filters = ns.PersonalSettings:GetAchievementFilters()
    local catalog = ns.AchievementCatalog:GetAchievements(filters)
    self.catalogHeader:SetText(string.format(ns.L["ACHIEV_SECTION_CATALOG_COUNT"], #catalog))
    if #catalog == 0 then
        self.catalogEmpty:Show()
        self.catalogScrollChild:SetHeight(120)
        return
    end

    self.catalogEmpty:Hide()



    local y = 8
    for i, entry in ipairs(catalog) do

        local row = self.catalogRows[i]

        if not row then

            row = self:CreateCatalogRow(self.catalogScrollChild, i)

            self.catalogRows[i] = row

        end

        row.entry = entry

        row:SetPoint("TOPLEFT", 0, -y)

        row:Show()



        local earned = ns.AchievementStorage:IsEarned(entry.id)

        row.icon:SetTexture(entry.icon)

        if earned then

            row.icon:SetVertexColor(1, 1, 1)

        else

            row.icon:SetVertexColor(0.45, 0.45, 0.45)

        end

        row.title:SetText(ns.AchievementCatalog:GetTitle(entry))

        row.factionTag:SetText(ns.AchievementCatalog:GetFactionTagText(entry))

        row.meta:SetText(ns.AchievementCatalog:GetLevelCapText(entry))

        row.status:SetText(earned and ns.L["ACHIEV_COMPLETED"] or "")



        y = y + 56

    end

    self.catalogScrollChild:SetHeight(math.max(y + 8, 120))

end



function AchievementsPanel:Refresh()

    if not self.earnedFrame then

        return

    end

    self:RefreshEarned()

    self:RefreshCatalog()

end

