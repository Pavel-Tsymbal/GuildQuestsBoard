local _, ns = ...



local AchievementsPanel = {}

ns.AchievementsPanel = AchievementsPanel



AchievementsPanel.earnedRows = {}

AchievementsPanel.catalogRows = {}



function AchievementsPanel:Init(earnedScroll, earnedScrollChild, catalogScroll, catalogScrollChild, viewFrame)
    self.earnedScroll = earnedScroll
    self.earnedScrollChild = earnedScrollChild
    self.catalogScroll = catalogScroll
    self.catalogScrollChild = catalogScrollChild
    self.viewFrame = viewFrame

    self.earnedHeader = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.earnedHeader:SetPoint("TOPLEFT", earnedScroll, "TOPLEFT", 4, -4)

    self.earnedHeader:SetWidth(740)

    self.earnedHeader:SetJustifyH("LEFT")



    self.earnedEmpty = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.earnedEmpty:SetPoint("CENTER", earnedScroll, "CENTER", 0, 0)

    self.earnedEmpty:SetWidth(560)

    self.earnedEmpty:SetJustifyH("CENTER")



    self.catalogSection = CreateFrame("Frame", nil, viewFrame)
    self.catalogSection:SetPoint("TOPLEFT", earnedScroll, "BOTTOMLEFT", 0, -8)
    self.catalogSection:SetPoint("TOPRIGHT", earnedScroll, "BOTTOMRIGHT", 0, -8)
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



function AchievementsPanel:FormatDate(timestamp)

    if not timestamp then

        return "?"

    end

    return date("%Y-%m-%d %H:%M", tonumber(timestamp) or timestamp)

end



function AchievementsPanel:CreateEarnedRow(parent, index)

    local row = CreateFrame("Frame", "GuildQuestsAchEarnedRow" .. index, parent, "BackdropTemplate")

    row:SetSize(760, 72)

    row:SetBackdrop({

        bgFile = "Interface\\Buttons\\WHITE8x8",

        edgeFile = "Interface\\Buttons\\WHITE8x8",

        tile = false,

        edgeSize = 1,

    })

    row:SetBackdropColor(0.12, 0.12, 0.16, 0.85)

    row:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)



    row.icon = row:CreateTexture(nil, "ARTWORK")

    row.icon:SetSize(40, 40)

    row.icon:SetPoint("LEFT", 10, 0)



    row.factionTag = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")

    row.factionTag:SetPoint("TOPRIGHT", -12, -8)

    row.factionTag:SetWidth(120)

    row.factionTag:SetJustifyH("RIGHT")



    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

    row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 0)

    row.title:SetWidth(520)

    row.title:SetJustifyH("LEFT")



    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")

    row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)

    row.meta:SetWidth(520)

    row.meta:SetJustifyH("LEFT")



    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")

    row.desc:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, -2)

    row.desc:SetWidth(620)

    row.desc:SetJustifyH("LEFT")



    row:SetScript("OnEnter", function(self)

        local entry = self.entry

        local earned = self.earned

        if not entry then

            return

        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        GameTooltip:ClearLines()

        GameTooltip:AddLine(ns.AchievementCatalog:GetTitle(entry), 1, 1, 1)

        GameTooltip:AddLine(ns.AchievementCatalog:GetFactionTagText(entry), 1, 1, 1)

        GameTooltip:AddLine(entry.zone or "", 1, 0.82, 0)

        GameTooltip:AddLine(entry.questName or "", 1, 1, 1, true)

        if earned and earned.level then

            GameTooltip:AddLine(string.format(ns.L["ACHIEV_TOOLTIP_LEVEL"], earned.level), 1, 1, 1)

        end

        GameTooltip:AddLine(ns.AchievementCatalog:GetLevelCapText(entry), 0.7, 0.7, 0.7, true)

        GameTooltip:Show()

    end)

    row:SetScript("OnLeave", function()

        GameTooltip:Hide()

    end)



    return row

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

    self.earnedHeader:SetText(ns.L["ACHIEV_SECTION_EARNED"])

    self.earnedEmpty:SetText(ns.L["ACHIEV_EARNED_EMPTY"])

    self:HideRows(self.earnedRows)



    local earnedList = ns.AchievementStorage:GetAllEarned()
    table.sort(earnedList, function(a, b)
        local entryA = ns.AchievementCatalog:GetById(a.id)
        local entryB = ns.AchievementCatalog:GetById(b.id)
        local levelA = entryA and entryA.levelCap or 999
        local levelB = entryB and entryB.levelCap or 999
        if levelA ~= levelB then
            return levelA < levelB
        end
        return (tonumber(a.earnedAt) or 0) > (tonumber(b.earnedAt) or 0)
    end)

    if #earnedList == 0 then

        self.earnedEmpty:Show()

        self.earnedScrollChild:SetHeight(120)

        return

    end



    self.earnedEmpty:Hide()

    local y = 24
    for i, earned in ipairs(earnedList) do

        local entry = ns.AchievementCatalog:GetById(earned.id)

        if entry and ns.AchievementCatalog:CanPlayerEarn(entry) then

            local row = self.earnedRows[i]

            if not row then

                row = self:CreateEarnedRow(self.earnedScrollChild, i)

                self.earnedRows[i] = row

            end

            row.entry = entry

            row.earned = earned

            row:SetPoint("TOPLEFT", 0, -y)

            row:Show()



            row.icon:SetTexture(entry.icon)

            row.title:SetText(ns.AchievementCatalog:GetTitle(entry))

            row.factionTag:SetText(ns.AchievementCatalog:GetFactionTagText(entry))

            row.meta:SetText(string.format(

                ns.L["ACHIEV_EARNED_META"],

                self:FormatDate(earned.earnedAt),

                earned.level or "?"

            ))

            row.desc:SetText(ns.AchievementCatalog:GetDescription(entry))



            y = y + 76

        end

    end

    self.earnedScrollChild:SetHeight(math.max(y + 8, 120))

end



function AchievementsPanel:RefreshCatalog()
    self:SyncFilterControls()
    self.catalogHeader:SetText(ns.L["ACHIEV_SECTION_CATALOG"])
    self.catalogEmpty:SetText(ns.L["ACHIEV_CATALOG_EMPTY_FILTER"])
    self:HideRows(self.catalogRows)

    local filters = ns.PersonalSettings:GetAchievementFilters()
    local catalog = ns.AchievementCatalog:GetAchievements(filters)
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

    if not self.earnedScrollChild then

        return

    end

    self:RefreshEarned()

    self:RefreshCatalog()

end

