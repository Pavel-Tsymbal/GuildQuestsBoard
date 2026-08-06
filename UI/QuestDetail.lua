local _, ns = ...
local C = ns.Constants
local Util = ns.Util

local QuestDetail = {}
ns.QuestDetail = QuestDetail

function QuestDetail:Init()
    self.frame = CreateFrame("Frame", "GuildQuestsDetailFrame", UIParent, "BackdropTemplate")
    self.frame:SetSize(480, 520)
    self.frame:SetPoint("CENTER", 180, 0)
    self.frame:SetFrameStrata("DIALOG")
    self.frame:Hide()
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)

    local close = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() self:Hide() end)

    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 16, -16)
    self.title:SetWidth(420)
    self.title:SetJustifyH("LEFT")

    self.actions = CreateFrame("Frame", nil, self.frame)
    self.actions:SetPoint("BOTTOMLEFT", 12, 12)
    self.actions:SetPoint("BOTTOMRIGHT", -12, 12)
    self.actions:SetHeight(80)

    self.scrollFrame = CreateFrame("ScrollFrame", nil, self.frame, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 16, -44)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self.actions, "TOPRIGHT", -28, 8)

    self.scrollChild = CreateFrame("Frame", nil, self.scrollFrame)
    self.scrollChild:SetWidth(410)
    self.scrollChild:SetHeight(1)
    self.scrollFrame:SetScrollChild(self.scrollChild)

    self.info = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.info:SetPoint("TOPLEFT", 0, 0)
    self.info:SetWidth(410)
    self.info:SetJustifyH("LEFT")

    self.desc = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.desc:SetPoint("TOPLEFT", self.info, "BOTTOMLEFT", 0, -12)
    self.desc:SetWidth(410)
    self.desc:SetJustifyH("LEFT")

    self.participants = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.participants:SetPoint("TOPLEFT", self.desc, "BOTTOMLEFT", 0, -12)
    self.participants:SetWidth(410)
    self.participants:SetJustifyH("LEFT")

    self.history = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.history:SetPoint("TOPLEFT", self.participants, "BOTTOMLEFT", 0, -12)
    self.history:SetWidth(410)
    self.history:SetJustifyH("LEFT")

    self.buttons = {}

    ns.GQ:RegisterCallback("LocaleChanged", function()
        self:UpdateDeleteDialog()
        if self.currentId and self.frame:IsShown() then
            self:Show(self.currentId)
        end
    end)

    self:UpdateDeleteDialog()

    ns.GQ:RegisterCallback("QuestUpdated", function(_, questId)
        if self.currentId == questId and self.frame:IsShown() then
            self:Show(questId)
        end
    end)
    ns.GQ:RegisterCallback("QuestDeleted", function(_, questId)
        if self.currentId == questId then
            self:Hide()
        end
    end)
end

function QuestDetail:UpdateDeleteDialog()
    StaticPopupDialogs["GUILDQUESTS_CONFIRM_DELETE"] = {
        text = ns.L["DELETE_CONFIRM"],
        button1 = YES,
        button2 = NO,
        OnAccept = function(_, questId)
            local ok, err = ns.Actions:Delete(questId)
            if not ok and err then
                ns.GQ:Print(err)
            else
                QuestDetail:Hide()
                ns.MainUI:Refresh()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function QuestDetail:ConfirmDelete(questId, questTitle)
    StaticPopup_Show("GUILDQUESTS_CONFIRM_DELETE", questTitle or "?", nil, questId)
end

function QuestDetail:UpdateScrollHeight()
    local height = self.info:GetStringHeight() + 12
        + self.desc:GetStringHeight() + 12
        + self.participants:GetStringHeight() + 12
        + self.history:GetStringHeight() + 16
    local viewHeight = self.scrollFrame:GetHeight()
    self.scrollChild:SetHeight(math.max(height, viewHeight))
    self.scrollFrame:SetVerticalScroll(0)
end

function QuestDetail:UpdateActionsHeight(buttonCount)
    local rows = math.max(1, math.ceil(buttonCount / 3))
    self.actions:SetHeight(rows * 28 + 16)
end

function QuestDetail:ClearButtons()
    for _, btn in ipairs(self.buttons) do
        btn:Hide()
    end
    self.buttonCount = 0
end

function QuestDetail:AddButton(text, onClick)
    self.buttonCount = (self.buttonCount or 0) + 1
    local index = self.buttonCount
    local btn = self.buttons[index]
    if not btn then
        btn = CreateFrame("Button", nil, self.actions, "UIPanelButtonTemplate")
        btn:SetSize(130, 24)
        self.buttons[index] = btn
    end
    local col = (index - 1) % 3
    local row = math.floor((index - 1) / 3)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", col * 140, -row * 28)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    btn:Show()
    self:UpdateActionsHeight(index)
    return btn
end

function QuestDetail:Show(questId)
    local quest = ns.Actions:GetQuest(questId)
    if not quest then
        return
    end
    self.currentId = questId
    self.frame:Show()
    self.title:SetText(quest.title)

    local lines = {
        ns.L["DETAIL_CREATOR"] .. ": " .. (quest.creator or "?"),
        ns.L["DETAIL_REWARD"] .. ": " .. Util:GetRewardText(quest),
        Util:GetCategoryLabel(quest.category),
        Util:GetQuestStatusForPlayer(quest),
    }
    if quest.deadline then
        table.insert(lines, ns.L["DETAIL_DEADLINE"] .. ": " .. date("%Y-%m-%d %H:%M", quest.deadline))
    end
    if quest.scheduledAt then
        table.insert(lines, ns.L["DETAIL_SCHEDULED"] .. ": " .. date("%Y-%m-%d %H:%M", quest.scheduledAt))
    end
    local maxLevel = Util:GetMaxLevelRequirement(quest)
    if maxLevel > 0 then
        table.insert(lines, ns.L["DETAIL_MAX_LEVEL"] .. ": " .. maxLevel)
    end
    self.info:SetText(table.concat(lines, "\n"))
    self.desc:SetText(quest.description or "")

    local parts = {}
    for name, data in pairs(quest.participants or {}) do
        table.insert(parts, name .. " (" .. Util:GetParticipantStatusLabel(data.status or "?") .. ")")
    end
    self.participants:SetText(ns.L["DETAIL_PARTICIPANTS"] .. ":\n" .. (#parts > 0 and table.concat(parts, "\n") or "-"))

    local histLines = ns.Logger:GetFormattedTimeline(questId)
    self.history:SetText(ns.L["DETAIL_HISTORY"] .. ":\n" .. (#histLines > 0 and table.concat(histLines, "\n") or "-"))

    self:ClearButtons()
    self:UpdateActionsHeight(0)

    local function act(label, fn)
        self:AddButton(label, function()
            local ok, err = fn()
            if not ok and err then
                ns.GQ:Print(err)
            else
                self:Show(questId)
                ns.MainUI:Refresh()
            end
        end)
    end

    if ns.Rules:CanAcceptQuest(nil, quest) then
        act(ns.L["DETAIL_ACCEPT"], function() return ns.Actions:Claim(questId) end)
    end
    if ns.Rules:CanSubmit(nil, quest) then
        act(ns.L["DETAIL_SUBMIT"], function() return ns.Actions:Submit(questId) end)
    end
    if Util:UsesApprovalWorkflow(quest) and ns.Rules:CanApprove(nil, quest) and quest.status == C.STATUS.SUBMITTED then
        act(ns.L["DETAIL_APPROVE"], function() return ns.Actions:Approve(questId) end)
        act(ns.L["DETAIL_REJECT"], function() return ns.Actions:Reject(questId) end)
    end
    if Util:UsesApprovalWorkflow(quest) and ns.Rules:CanMarkRewardPaid(nil, quest) and quest.status == C.STATUS.COMPLETED then
        act(ns.L["DETAIL_REWARD_PAID"], function() return ns.Actions:MarkRewardPaid(questId) end)
    end
    if ns.Rules:CanCancel(nil, quest) then
        act(ns.L["DETAIL_CANCEL"], function() return ns.Actions:Cancel(questId) end)
    end
    if ns.Rules:CanDelete(nil, quest) then
        self:AddButton(ns.L["DETAIL_DELETE"], function()
            self:ConfirmDelete(questId, quest.title)
        end)
    end

    self:UpdateScrollHeight()
end

function QuestDetail:Hide()
    self.frame:Hide()
    self.currentId = nil
end
