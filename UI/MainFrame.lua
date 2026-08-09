local _, ns = ...
local Util = ns.Util

local MainUI = {}
ns.MainUI = MainUI

function MainUI:Init()
    self.frame = GuildQuestsMainFrame
    self.frameTitle = GuildQuestsMainFrameTitle
    self.frameCreate = GuildQuestsMainFrameCreate
    self.frameClose = GuildQuestsMainFrameClose
    self.frameSearch = GuildQuestsMainFrameSearch
    self.filterBar = GuildQuestsMainFrameFilterBar
    self.scrollFrame = GuildQuestsMainFrameScroll
    self.scrollChild = self.scrollFrame and self.scrollFrame:GetScrollChild()
    self.activeView = "board"

    ns.Theme:ApplyPanel(self.frame)

    self.frameEmpty = self.frame:CreateFontString("GuildQuestsMainFrameEmptyText", "OVERLAY", "GameFontDisable")
    self.frameEmpty:SetPoint("CENTER", self.scrollFrame, "CENTER")
    self.frameEmpty:Hide()

    self.tabBoard = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.tabBoard:SetSize(110, 22)
    self.tabBoard:SetPoint("TOPLEFT", 300, -12)
    self.tabBoard:SetText(ns.L["MAIN_TAB_BOARD"])
    self.tabBoard:SetScript("OnClick", function()
        self:ShowBoardView()
    end)

    self.tabAchievements = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.tabAchievements:SetSize(110, 22)
    self.tabAchievements:SetPoint("LEFT", self.tabBoard, "RIGHT", 8, 0)
    self.tabAchievements:SetText(ns.L["MAIN_TAB_ACHIEVEMENTS"])
    self.tabAchievements:SetScript("OnClick", function()
        self:ShowAchievementsView()
    end)

    self.tabDeathLog = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.tabDeathLog:SetSize(110, 22)
    self.tabDeathLog:SetPoint("LEFT", self.tabAchievements, "RIGHT", 8, 0)
    self.tabDeathLog:SetText(ns.L["MAIN_TAB_DEATHLOG"])
    self.tabDeathLog:SetScript("OnClick", function()
        self:ShowDeathLogView()
    end)

    self.tabSettings = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.tabSettings:SetSize(110, 22)
    self.tabSettings:SetPoint("LEFT", self.tabDeathLog, "RIGHT", 8, 0)
    self.tabSettings:SetText(ns.L["MAIN_TAB_SETTINGS"])
    self.tabSettings:SetScript("OnClick", function()
        self:ShowSettingsView()
    end)

    self.settingsView = CreateFrame("Frame", nil, self.frame)
    self.settingsView:SetPoint("TOPLEFT", 12, -104)
    self.settingsView:SetSize(800, 460)
    self.settingsView:Hide()

    self.settingsScroll = CreateFrame("ScrollFrame", nil, self.settingsView, "UIPanelScrollFrameTemplate")
    self.settingsScroll:SetPoint("TOPLEFT", 0, 0)
    self.settingsScroll:SetPoint("BOTTOMRIGHT", 0, 0)

    self.settingsContainer = CreateFrame("Frame", nil, self.settingsScroll)
    self.settingsContainer:SetSize(780, 460)
    self.settingsScroll:SetScrollChild(self.settingsContainer)

    ns.SettingsPanel:Init(self.settingsContainer)

    self.achievementsView = CreateFrame("Frame", nil, self.frame)
    self.achievementsView:SetPoint("TOPLEFT", 12, -104)
    self.achievementsView:SetPoint("BOTTOMRIGHT", -12, 16)
    self.achievementsView:Hide()

    self.achievementsEarnedScroll = CreateFrame("ScrollFrame", nil, self.achievementsView, "UIPanelScrollFrameTemplate")
    self.achievementsEarnedScroll:SetPoint("TOPLEFT", 0, 0)
    self.achievementsEarnedScroll:SetPoint("BOTTOMRIGHT", self.achievementsView, "TOPRIGHT", -28, -210)

    self.achievementsEarnedScrollChild = CreateFrame("Frame", nil, self.achievementsEarnedScroll)
    self.achievementsEarnedScrollChild:SetSize(760, 180)
    self.achievementsEarnedScroll:SetScrollChild(self.achievementsEarnedScrollChild)

    self.achievementsCatalogScroll = CreateFrame("ScrollFrame", nil, self.achievementsView, "UIPanelScrollFrameTemplate")
    self.achievementsCatalogScroll:SetPoint("BOTTOMRIGHT", -28, 0)

    self.achievementsCatalogScrollChild = CreateFrame("Frame", nil, self.achievementsCatalogScroll)
    self.achievementsCatalogScrollChild:SetSize(760, 180)
    self.achievementsCatalogScroll:SetScrollChild(self.achievementsCatalogScrollChild)

    ns.AchievementsPanel:Init(
        self.achievementsEarnedScroll,
        self.achievementsEarnedScrollChild,
        self.achievementsCatalogScroll,
        self.achievementsCatalogScrollChild,
        self.achievementsView
    )
    ns.AchievementsPanel:SetDividerAnchor(self.achievementsEarnedScroll)

    self.deathlogView = CreateFrame("Frame", nil, self.frame)
    self.deathlogView:SetPoint("TOPLEFT", 12, -104)
    self.deathlogView:SetPoint("BOTTOMRIGHT", -12, 16)
    self.deathlogView:Hide()

    self.deathlogScroll = CreateFrame("ScrollFrame", nil, self.deathlogView, "UIPanelScrollFrameTemplate")
    self.deathlogScroll:SetPoint("TOPLEFT", 0, 0)
    self.deathlogScroll:SetPoint("BOTTOMRIGHT", -28, 132)

    self.deathlogScrollChild = CreateFrame("Frame", nil, self.deathlogScroll)
    self.deathlogScrollChild:SetSize(760, 360)
    self.deathlogScroll:SetScrollChild(self.deathlogScrollChild)

    ns.DeathLogPanel:Init(self.deathlogScrollChild, self.deathlogView, self.deathlogScroll)

    self.frameTitle:SetText(ns.L["BOARD_TITLE"])
    self.frameCreate:SetText(ns.L["BOARD_CREATE"])
    self.frameEmpty:SetText(ns.L["BOARD_EMPTY"])
    if self.frameSearch.SetPlaceholderText then
        self.frameSearch:SetPlaceholderText(ns.L["SEARCH_PLACEHOLDER"])
    end

    self.frameCreate:SetScript("OnClick", function()
        local canCreate, err = ns.Rules:CanCreateQuest()
        if canCreate then
            ns.CreateQuest:Show()
        elseif err then
            ns.GQ:Print(err)
        end
    end)
    self:SetupCreateButtonTooltip()
    self.frameClose:SetScript("OnClick", function()
        self:Hide()
    end)
    self.frame:SetScript("OnMouseUp", function(f)
        f:StopMovingOrSizing()
    end)
    self.frame:SetScript("OnMouseDown", function(f)
        if f:IsMovable() then
            f:StartMoving()
        end
    end)

    ns.GQ:RegisterCallback("QuestUpdated", function()
        self:Refresh()
    end)
    ns.GQ:RegisterCallback("SyncComplete", function()
        self:Refresh()
    end)
    ns.GQ:RegisterCallback("QuestDeleted", function()
        self:Refresh()
    end)
    ns.GQ:RegisterCallback("LocaleChanged", function()
        self:UpdateTexts()
    end)
    ns.GQ:RegisterCallback("GuildLeft", function()
        self:Hide()
    end)
    ns.GQ:RegisterCallback("GuildChanged", function()
        self:UpdateTexts()
        if self.frame:IsShown() then
            self:Refresh()
        end
    end)
    ns.GQ:RegisterCallback("GuildSettingsUpdated", function()
        self:UpdateCreateButtonState()
    end)
    ns.GQ:RegisterCallback("GuildRosterUpdated", function()
        self:UpdateCreateButtonState()
    end)
    ns.GQ:RegisterCallback("PeersUpdated", function()
        self:UpdateCreateButtonState()
    end)
    ns.GQ:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        self:UpdateCreateButtonState()
    end)
    ns.GQ:RegisterEvent("PLAYER_GUILD_UPDATE", function()
        self:UpdateCreateButtonState()
    end)
    self:UpdateCreateButtonState()
end

function MainUI:LayoutCreateButton()
    if not self.frameCreate or not self.filterBar then
        return
    end
    self.frameCreate:SetParent(self.filterBar)
    self.frameCreate:ClearAllPoints()
    self.frameCreate:SetPoint("RIGHT", self.filterBar, "RIGHT", 0, 0)
    self.frameCreate:SetFrameLevel(self.filterBar:GetFrameLevel() + 20)
    self.frameCreate:Raise()
end

function MainUI:SetupCreateButtonTooltip()
    local btn = self.frameCreate
    if not btn then
        return
    end
    local overlay = CreateFrame("Frame", btn:GetName() .. "TooltipOverlay", btn)
    overlay:SetAllPoints(btn)
    overlay:EnableMouse(true)
    overlay:Hide()
    self.frameCreateTooltipOverlay = overlay

    overlay:SetScript("OnEnter", function()
        local lines = ns.Rules:GetCreateQuestDisabledTooltipLines()
        if not lines then
            return
        end
        GameTooltip:SetOwner(overlay, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:ClearLines()
        for index, line in ipairs(lines) do
            if index == 1 then
                GameTooltip:AddLine(line, 1, 0.82, 0, true)
            else
                GameTooltip:AddLine(line, 1, 1, 1, true)
            end
        end
        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function MainUI:UpdateCreateButtonState()
    if not self.frameCreate then
        return
    end
    local canCreate = ns.Rules:CanCreateQuest()
    self.frameCreate:SetEnabled(canCreate)
    if self.frameCreateTooltipOverlay then
        if canCreate then
            self.frameCreateTooltipOverlay:EnableMouse(false)
            self.frameCreateTooltipOverlay:Hide()
        else
            self.frameCreateTooltipOverlay:EnableMouse(true)
            self.frameCreateTooltipOverlay:Show()
        end
    end
end

function MainUI:IsSettingsView()
    return self.activeView == "settings"
end

function MainUI:IsAchievementsView()
    return self.activeView == "achievements"
end

function MainUI:IsDeathLogView()
    return self.activeView == "deathlog"
end

function MainUI:UpdateTabHighlight()
    self.tabBoard:SetEnabled(self.activeView ~= "board")
    self.tabAchievements:SetEnabled(self.activeView ~= "achievements")
    self.tabDeathLog:SetEnabled(self.activeView ~= "deathlog")
    self.tabSettings:SetEnabled(self.activeView ~= "settings")
end

function MainUI:UpdateTexts()
    self.tabBoard:SetText(ns.L["MAIN_TAB_BOARD"])
    self.tabAchievements:SetText(ns.L["MAIN_TAB_ACHIEVEMENTS"])
    self.tabDeathLog:SetText(ns.L["MAIN_TAB_DEATHLOG"])
    self.tabSettings:SetText(ns.L["MAIN_TAB_SETTINGS"])
    self.frameCreate:SetText(ns.L["BOARD_CREATE"])
    self.frameEmpty:SetText(ns.L["BOARD_EMPTY"])
    if self.frameSearch.SetPlaceholderText then
        self.frameSearch:SetPlaceholderText(ns.L["SEARCH_PLACEHOLDER"])
    end
    if self.activeView == "board" then
        self.frameTitle:SetText(ns.L["BOARD_TITLE"])
    elseif self.activeView == "achievements" then
        self.frameTitle:SetText(ns.L["MAIN_TAB_ACHIEVEMENTS"])
    elseif self.activeView == "deathlog" then
        self.frameTitle:SetText(ns.L["MAIN_TAB_DEATHLOG"])
    else
        self.frameTitle:SetText(ns.L["SETTINGS_TITLE"])
    end
    self:UpdateCreateButtonState()
end

function MainUI:SetBoardWidgetsShown(shown, showFilterBar)
    self.frameSearch:SetShown(shown)
    self.filterBar:SetShown(shown and showFilterBar ~= false)
    self.scrollFrame:SetShown(shown)
    self.frameCreate:SetShown(shown)
    if not shown then
        self.frameEmpty:Hide()
    end
end

function MainUI:ShowBoardView()
    self.activeView = "board"
    self.settingsView:Hide()
    self.achievementsView:Hide()
    self.deathlogView:Hide()
    self:SetBoardWidgetsShown(true, true)
    self.frameTitle:SetText(ns.L["BOARD_TITLE"])
    self:UpdateTabHighlight()
    self:UpdateCreateButtonState()
    self:Refresh()
end

function MainUI:ShowAchievementsView()
    self.activeView = "achievements"
    self.settingsView:Hide()
    self.deathlogView:Hide()
    self.achievementsView:Show()
    self:SetBoardWidgetsShown(false)
    self.frameTitle:SetText(ns.L["MAIN_TAB_ACHIEVEMENTS"])
    self:UpdateTabHighlight()
    ns.AchievementsPanel:Refresh()
end

function MainUI:ShowDeathLogView()
    self.activeView = "deathlog"
    self.settingsView:Hide()
    self.achievementsView:Hide()
    self.deathlogView:Show()
    self:SetBoardWidgetsShown(false)
    self.frameTitle:SetText(ns.L["MAIN_TAB_DEATHLOG"])
    self:UpdateTabHighlight()
    ns.DeathLogPanel:Refresh()
end

function MainUI:ShowSettingsView()
    self.activeView = "settings"
    self.achievementsView:Hide()
    self.deathlogView:Hide()
    self:SetBoardWidgetsShown(false)
    self.settingsView:Show()
    self.frameTitle:SetText(ns.L["SETTINGS_TITLE"])
    self:UpdateTabHighlight()
    ns.SettingsPanel:ShowPersonal()
end

function MainUI:Show()
    if not Util:GetGuildKey() then
        ns.GQ:Print(ns.L["ERR_NOT_IN_GUILD"])
        return
    end
    ns.Storage:EnsureGuildStore()
    ns.Heartbeat:BroadcastNow()
    self:UpdateCreateButtonState()
    self.frame:Show()
    if self.activeView == "settings" then
        self:ShowSettingsView()
    elseif self.activeView == "achievements" then
        self:ShowAchievementsView()
    elseif self.activeView == "deathlog" then
        self:ShowDeathLogView()
    else
        self:ShowBoardView()
    end
end

function MainUI:ShowSettings()
    if not Util:GetGuildKey() then
        ns.GQ:Print(ns.L["ERR_NOT_IN_GUILD"])
        return
    end
    ns.Storage:EnsureGuildStore()
    self.frame:Show()
    self:ShowSettingsView()
end

function MainUI:Hide()
    self.frame:Hide()
end

function MainUI:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MainUI:Refresh()
    if not self.frame:IsShown() or self.activeView ~= "board" then
        return
    end
    local quests = ns.Actions:GetQuestList()
    quests = ns.SearchFilter:Apply(quests, self.frameSearch:GetText())
    ns.QuestList:Render(self.scrollChild, quests, function(questId)
        ns.QuestDetail:Show(questId)
    end)
    self.frameEmpty:SetShown(#quests == 0)
end

function MainUI:GetSearchBox()
    return self.frameSearch
end

function MainUI:GetFrame()
    return self.frame
end
