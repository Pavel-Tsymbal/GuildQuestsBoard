local _, ns = ...
local Schema = ns.Schema

local PersonalSettings = {}
ns.PersonalSettings = PersonalSettings

function PersonalSettings:Init()
end

function PersonalSettings:Get()
    return ns.Storage:GetCharDB()
end

function PersonalSettings:GetNotifications()
    return self:Get().notifications
end

function PersonalSettings:SetNotifications(key, value)
    local db = self:Get()
    db.notifications = db.notifications or Schema:DefaultCharSettings().notifications
    db.notifications[key] = value
    ns.GQ:Fire("PersonalSettingsChanged")
end

function PersonalSettings:SetLocale(locale)
    return ns.Locale:SetLocale(locale)
end

function PersonalSettings:SetMinimapHidden(hidden)
    local db = self:Get()
    db.ui.minimap = db.ui.minimap or {}
    db.ui.minimap.hide = hidden
    ns.GQ:Fire("MinimapChanged")
end

function PersonalSettings:IsNotificationDismissed(questId)
    local db = self:Get()
    return db.dismissedNotifications and db.dismissedNotifications[questId]
end

function PersonalSettings:DismissNotification(questId)
    local db = self:Get()
    db.dismissedNotifications = db.dismissedNotifications or {}
    db.dismissedNotifications[questId] = true
end

function PersonalSettings:ShouldShowNotification()
    local n = self:GetNotifications()
    if not n.enabled then
        return false
    end
    if not n.showInCombat and ns.Util:IsInCombat() then
        return false
    end
    return true
end
