local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local QuestList = {}
ns.QuestList = QuestList

QuestList.rows = {}
QuestList.activeTab = "ALL"

function QuestList:Init()
    ns.GQ:RegisterCallback("LocaleChanged", function()
        self:RefreshIfVisible()
    end)
end

function QuestList:RefreshIfVisible()
    if ns.MainUI.frame and ns.MainUI.frame:IsShown() then
        ns.MainUI:Refresh()
    end
end

function QuestList:CreateRow(parent, index)
    local row = CreateFrame("Button", parent:GetName() .. "Row" .. index, parent, "BackdropTemplate")
    row:SetSize(760, 44)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    row:SetBackdropColor(0.12, 0.12, 0.16, 0.85)
    row:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "ADD")

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.title:SetPoint("LEFT", 10, 6)
    row.title:SetWidth(320)
    row.title:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetPoint("LEFT", 10, -10)
    row.meta:SetWidth(480)
    row.meta:SetJustifyH("LEFT")

    row.reward = row:CreateFontString(nil, "OVERLAY", "GameFontGreen")
    row.reward:SetPoint("RIGHT", -10, 4)
    row.reward:SetWidth(180)
    row.reward:SetJustifyH("RIGHT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", -10, -12)
    row.status:SetWidth(120)
    row.status:SetJustifyH("RIGHT")

    return row
end

function QuestList:Render(parent, quests, onClick)
    if not parent then
        return
    end
    for _, row in ipairs(self.rows) do
        row:Hide()
    end

    local y = 0
    for i, quest in ipairs(quests) do
        local row = self.rows[i]
        if not row then
            row = self:CreateRow(parent, i)
            self.rows[i] = row
        end
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()

        row.title:SetText(quest.title or "?")
        local cat = Util:GetCategoryLabel(quest.category)
        local pCount = Util:CountTable(quest.participants)
        local meta = string.format(
            "%s | %s | %s (%d/%s)",
            quest.creator or "?",
            cat,
            Util:GetQuestStatusForPlayer(quest),
            pCount,
            Util:GetParticipantsLimitText(quest.maxParticipants)
        )
        local maxLevel = Util:GetMaxLevelRequirement(quest)
        if maxLevel > 0 then
            meta = meta .. " | " .. ns.L["DETAIL_MAX_LEVEL"] .. ": " .. maxLevel
        end
        row.meta:SetText(meta)
        row.reward:SetText(Util:GetRewardText(quest))
        row.status:SetText(Util:GetQuestStatusForPlayer(quest))

        row:SetScript("OnClick", function()
            if onClick then
                onClick(quest.id)
            end
        end)
        y = y + 48
    end

    parent:SetHeight(math.max(y, 360))
end

function QuestList:SetTab(tab)
    self.activeTab = tab
end

function QuestList:GetTab()
    return self.activeTab
end

function QuestList:FilterByTab(quests)
    local tab = self.activeTab
    local player = Util:GetPlayerName()
    local filtered = {}
    for _, quest in ipairs(quests) do
        if tab == "ALL" then
            table.insert(filtered, quest)
        elseif tab == "OPEN" then
            if quest.status == C.STATUS.OPEN or quest.status == C.STATUS.GROUP_FORMING then
                table.insert(filtered, quest)
            elseif Util:IsMultiParticipantQuest(quest) then
                local maxP = quest.maxParticipants or 0
                local count = Util:CountTable(quest.participants)
                if maxP == 0 or count < maxP then
                    table.insert(filtered, quest)
                end
            end
        elseif tab == "MINE" then
            if quest.creator == player or (quest.participants and quest.participants[player]) then
                table.insert(filtered, quest)
            end
        elseif tab == "PERMANENT" then
            if quest.category == "PERMANENT" then
                table.insert(filtered, quest)
            end
        end
    end
    return filtered
end
