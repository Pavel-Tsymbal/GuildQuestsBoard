local _, ns = ...
local LDB = LibStub("LibDataBroker-1.1", true)
local LibDBIcon = LibStub("LibDBIcon-1.0", true)

local Minimap = {}
ns.Minimap = Minimap

function Minimap:Init()
    if not LDB or not LibDBIcon then
        return
    end

    local broker = LDB:NewDataObject("GuildQuests", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Note_06",
        OnClick = function(_, button)
            if button == "RightButton" then
                self:ShowContextMenu()
            else
                ns.MainUI:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(ns.L["ADDON_NAME"])
            tooltip:AddLine(ns.L["MINIMAP_LEFT_CLICK"], 1, 1, 1)
            tooltip:AddLine(ns.L["MINIMAP_CREATE"], 0.8, 0.8, 0.8)
            tooltip:AddLine(ns.L["MINIMAP_SETTINGS"], 0.8, 0.8, 0.8)
        end,
    })

    LibDBIcon:Register("GuildQuests", broker, GuildQuestsCharDB and GuildQuestsCharDB.minimap or {})
    self.broker = broker
    self:Refresh()

    ns.GQ:RegisterCallback("MinimapChanged", function()
        self:Refresh()
    end)
    ns.GQ:RegisterCallback("VersionMismatch", function()
        ns.GQ:Print(ns.L["ERR_VERSION_MISMATCH"])
    end)
end

function Minimap:Refresh()
    if not LibDBIcon then
        return
    end
    local db = ns.PersonalSettings:Get()
    local hide = db.ui and db.ui.minimap and db.ui.minimap.hide
    if hide then
        LibDBIcon:Hide("GuildQuests")
    else
        LibDBIcon:Show("GuildQuests")
    end
end

function Minimap:ShowContextMenu()
    local menu = CreateFrame("Frame", "GuildQuestsMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    local function initialize(_, level)
        local info = UIDropDownMenu_CreateInfo()
        local canCreate = ns.Rules:HasRankPermission(nil, "create")
        info.text = ns.L["MINIMAP_CREATE"]
        info.notCheckable = true
        info.disabled = not canCreate
        info.func = function()
            if canCreate then
                ns.CreateQuest:Show()
            end
        end
        UIDropDownMenu_AddButton(info)

        info.text = ns.L["MINIMAP_SETTINGS"]
        info.func = function()
            ns.MainUI:ShowSettings()
        end
        UIDropDownMenu_AddButton(info)

        info.text = ns.L["BOARD_TITLE"]
        info.func = function()
            ns.MainUI:Toggle()
        end
        UIDropDownMenu_AddButton(info)
    end
    UIDropDownMenu_Initialize(menu, initialize, "MENU")
    ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

function Minimap:CheckVersionWarning()
    if ns.Heartbeat and ns.Heartbeat:HasVersionMismatch() then
        ns.GQ:Print(ns.L["ERR_VERSION_MISMATCH"])
    end
end
