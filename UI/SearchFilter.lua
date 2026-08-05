local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local SearchFilter = {}
ns.SearchFilter = SearchFilter

SearchFilter.filters = {
    category = nil,
    status = nil,
    minRewardGold = 0,
    scheduledOnly = false,
    hasDeadline = false,
    tab = "ALL",
}

function SearchFilter:Init()
    self.filters.tab = "ALL"
    self:BuildFilterBar()
    ns.GQ:RegisterCallback("LocaleChanged", function()
        self:UpdateFilterBarTexts()
    end)
end

function SearchFilter:BuildFilterBar()
    local parent = GuildQuestsMainFrameFilterBar
    if not parent then
        return
    end

    self.tabButtons = {}
    local tabs = {
        { key = "ALL", label = "BOARD_TAB_ALL" },
        { key = "OPEN", label = "BOARD_TAB_OPEN" },
        { key = "MINE", label = "BOARD_TAB_MINE" },
        { key = "SCHEDULED", label = "BOARD_TAB_SCHEDULED" },
    }
    for i, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(90, 22)
        btn:SetPoint("LEFT", (i - 1) * 94, 0)
        btn.tabKey = tab.key
        btn.labelKey = tab.label
        btn:SetText(ns.L[tab.label])
        btn:SetScript("OnClick", function(b)
            self.filters.tab = b.tabKey
            ns.QuestList:SetTab(b.tabKey)
            ns.MainUI:Refresh()
        end)
        self.tabButtons[i] = btn
    end

    local search = GuildQuestsMainFrameSearch
    if search then
        search:HookScript("OnTextChanged", function()
            ns.MainUI:Refresh()
        end)
        search:HookScript("OnEnterPressed", function(s)
            s:ClearFocus()
            ns.MainUI:Refresh()
        end)
    end
end

function SearchFilter:UpdateFilterBarTexts()
    if not self.tabButtons then
        return
    end
    for _, btn in ipairs(self.tabButtons) do
        btn:SetText(ns.L[btn.labelKey])
    end
end

function SearchFilter:SetCategory(category)
    self.filters.category = category
end

function SearchFilter:SetStatus(status)
    self.filters.status = status
end

function SearchFilter:SetMinReward(gold)
    self.filters.minRewardGold = gold or 0
end

function SearchFilter:SetScheduledOnly(value)
    self.filters.scheduledOnly = value
end

function SearchFilter:SetHasDeadline(value)
    self.filters.hasDeadline = value
end

function SearchFilter:MatchesSearch(quest, searchText)
    searchText = Util:Trim(searchText or ""):lower()
    if searchText == "" then
        return true
    end
    local function contains(value)
        return value and value:lower():find(searchText, 1, true)
    end
    if contains(quest.title) or contains(quest.creator) or contains(quest.categoryTag) then
        return true
    end
    for name in pairs(quest.participants or {}) do
        if contains(name) then
            return true
        end
    end
    return false
end

function SearchFilter:Apply(quests, searchText)
    ns.QuestList:SetTab(self.filters.tab or ns.QuestList:GetTab())
    quests = ns.QuestList:FilterByTab(quests)
    local result = {}
    for _, quest in ipairs(quests) do
        local include = true
        if self.filters.category and quest.category ~= self.filters.category then
            include = false
        end
        if include and self.filters.status and quest.status ~= self.filters.status then
            include = false
        end
        if include and self.filters.scheduledOnly and quest.timeMode ~= C.TIME_MODE.SCHEDULED then
            include = false
        end
        if include and self.filters.hasDeadline and quest.timeMode ~= C.TIME_MODE.DEADLINE then
            include = false
        end
        if include and (quest.rewardGold or 0) < (self.filters.minRewardGold or 0) then
            include = false
        end
        if include and not self:MatchesSearch(quest, searchText) then
            include = false
        end
        if include then
            table.insert(result, quest)
        end
    end
    return result
end

function SearchFilter:GetFilters()
    return self.filters
end
