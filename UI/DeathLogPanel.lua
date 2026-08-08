local _, ns = ...
local Util = ns.Util

local DeathLogPanel = {}
ns.DeathLogPanel = DeathLogPanel

DeathLogPanel.rows = {}
DeathLogPanel.maxRows = 200

local function normalizeRealm(name)
    if not name then
        return ""
    end
    return string.lower(name:gsub("%s+", ""))
end

local function realmMatches(serverName)
    if not serverName then
        return false
    end
    local current = normalizeRealm(Util:GetRealmName())
    local other = normalizeRealm(serverName)
    if current == "" or other == "" then
        return false
    end
    return current == other or current:find(other, 1, true) or other:find(current, 1, true)
end

local function entryMatchesGuild(entry)
    if DeathNotificationLib and DeathNotificationLib.PassesGuildFilterMode then
        return DeathNotificationLib.PassesGuildFilterMode(entry, "my_guild")
    end
    local guildName = GetGuildInfo("player")
    if not guildName or guildName == "" then
        return false
    end
    if not entry or not entry.guild or entry.guild == "" then
        return false
    end
    return string.lower(entry.guild) == string.lower(guildName)
end

local function shouldShowEntry(entry)
    if type(Deathlog_shouldShowEntry) == "function" then
        return Deathlog_shouldShowEntry(entry)
    end
    return entry ~= nil
end

local function formatDate(timestamp)
    if not timestamp then
        return "?"
    end
    return date("%Y-%m-%d %H:%M", tonumber(timestamp) or timestamp)
end

local function getZoneName(entry)
    if not entry then
        return ""
    end
    if entry.map_id and C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(entry.map_id)
        if mapInfo and mapInfo.name then
            return mapInfo.name
        end
    end
    if entry.instance_id and type(id_to_instance) == "table" then
        return id_to_instance[entry.instance_id] or tostring(entry.instance_id)
    end
    return ""
end

local function getSourceName(entry)
    if type(DeathlogGetCachedSource) == "function" then
        return DeathlogGetCachedSource(entry) or ""
    end
    if entry.source then
        return entry.source
    end
    if entry.source_id and type(Deathlog_GetSourceNameById) == "function" then
        local pvpName = entry.extra_data and entry.extra_data.pvp_source_name
        return Deathlog_GetSourceNameById(tonumber(entry.source_id), pvpName) or ""
    end
    return ""
end

local function getColoredName(entry)
    local name = entry.name or "?"
    local classId = entry.class_id
    if classId and type(deathlog_class_colors) == "table" and deathlog_class_colors[classId] then
        return "|c" .. deathlog_class_colors[classId].colorStr .. name .. "|r"
    end
    if classId and GetClassInfo then
        local className = GetClassInfo(classId)
        if className then
            return name .. " (" .. className .. ")"
        end
    end
    return name
end

function DeathLogPanel:CollectEntries()
    local data = _G.deathlog_data
    if type(data) ~= "table" then
        return {}, 0
    end

    local entries = {}
    for serverName, entryTbl in pairs(data) do
        if realmMatches(serverName) and type(entryTbl) == "table" then
            for _, entry in pairs(entryTbl) do
                if shouldShowEntry(entry) and entryMatchesGuild(entry) then
                    entries[#entries + 1] = entry
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        return (tonumber(a.date) or 0) > (tonumber(b.date) or 0)
    end)

    if #entries > self.maxRows then
        local trimmed = {}
        for i = 1, self.maxRows do
            trimmed[i] = entries[i]
        end
        return trimmed, #entries
    end

    return entries, #entries
end

function DeathLogPanel:CreateRow(parent, index)
    local row = CreateFrame("Button", parent:GetName() .. "DeathLogRow" .. index, parent, "BackdropTemplate")
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
    row.title:SetWidth(420)
    row.title:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetPoint("LEFT", 10, -10)
    row.meta:SetWidth(520)
    row.meta:SetJustifyH("LEFT")

    row.dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.dateText:SetPoint("RIGHT", -10, 4)
    row.dateText:SetWidth(140)
    row.dateText:SetJustifyH("RIGHT")

    row.sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    row.sourceText:SetPoint("RIGHT", -10, -12)
    row.sourceText:SetWidth(220)
    row.sourceText:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
        if type(Deathlog_setTooltipFromEntry) == "function" and self.entry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            Deathlog_setTooltipFromEntry(self.entry)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

function DeathLogPanel:Init(scrollChild, viewFrame)
    self.scrollChild = scrollChild
    self.viewFrame = viewFrame

    self.emptyText = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.emptyText:SetPoint("CENTER", scrollChild, "CENTER", 0, 20)
    self.emptyText:SetWidth(520)
    self.emptyText:SetJustifyH("CENTER")

    self.summaryText = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.summaryText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, 8)
    self.summaryText:SetWidth(520)
    self.summaryText:SetJustifyH("LEFT")

    ns.GQ:RegisterCallback("LocaleChanged", function()
        if ns.MainUI and ns.MainUI:IsDeathLogView() then
            self:Refresh()
        end
    end)
end

function DeathLogPanel:Refresh()
    if not self.scrollChild then
        return
    end

    for _, row in ipairs(self.rows) do
        row:Hide()
    end

    local entries, totalCount = self:CollectEntries()

    if #entries == 0 then
        self.summaryText:Hide()
        self.emptyText:SetText(ns.L["DEATHLOG_EMPTY"])
        self.emptyText:Show()
        self.scrollChild:SetHeight(360)
        return
    end

    self.emptyText:Hide()
    self.summaryText:SetText(string.format(ns.L["DEATHLOG_COUNT"], totalCount or #entries))
    self.summaryText:Show()

    local y = 28
    for i, entry in ipairs(entries) do
        local row = self.rows[i]
        if not row then
            row = self:CreateRow(self.scrollChild, i)
            self.rows[i] = row
        end
        row.entry = entry
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()

        local level = entry.level or "?"
        row.title:SetText(string.format("Lv %s — %s", level, getColoredName(entry)))

        local zone = getZoneName(entry)
        local meta = zone ~= "" and zone or (entry.guild or "")
        row.meta:SetText(meta)
        row.dateText:SetText(formatDate(entry.date))
        row.sourceText:SetText(getSourceName(entry))

        y = y + 48
    end

    self.scrollChild:SetHeight(math.max(y + 8, 360))
end
