local _, ns = ...

ns.SettingTooltips = {
    GUILD_MIN_CREATE = "TOOLTIP_GUILD_MIN_CREATE",
    GUILD_MIN_ACCEPT = "TOOLTIP_GUILD_MIN_ACCEPT",
    GUILD_PERM_CREATE = "TOOLTIP_GUILD_PERM_CREATE",
    GUILD_PERM_APPROVE = "TOOLTIP_GUILD_PERM_APPROVE",
    GUILD_PERM_CLOSE = "TOOLTIP_GUILD_PERM_CLOSE",
    GUILD_PERM_REWARD = "TOOLTIP_GUILD_PERM_REWARD",
    GUILD_PERM_DELETE = "TOOLTIP_GUILD_PERM_DELETE",
    PERSONAL_NOTIFICATIONS = "TOOLTIP_PERSONAL_NOTIFICATIONS",
    PERSONAL_DURATION = "TOOLTIP_PERSONAL_DURATION",
    PERSONAL_POSITION = "TOOLTIP_PERSONAL_POSITION",
    PERSONAL_SOUND = "TOOLTIP_PERSONAL_SOUND",
    PERSONAL_COMBAT = "TOOLTIP_PERSONAL_COMBAT",
    PERSONAL_LOCALE = "TOOLTIP_PERSONAL_LOCALE",
}

function ns.GetSettingTooltip(key)
    local tipKey = ns.SettingTooltips[key]
    if tipKey then
        return ns.L[tipKey]
    end
end

function ns.AttachTooltip(widget, tipKey)
    if not widget then
        return
    end
    widget:HookScript("OnEnter", function(self)
        local text = ns.GetSettingTooltip(tipKey)
        if not text or text == "" then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        for line in text:gmatch("[^\n]+") do
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end
