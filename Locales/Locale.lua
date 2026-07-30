local _, ns = ...

local Locale = {}
ns.Locale = Locale

Locale.localeData = {}
Locale.current = "enUS"

function Locale:Init()
    local charLocale = GuildQuestsCharDB and GuildQuestsCharDB.locale
    if charLocale and self.localeData[charLocale] then
        self.current = charLocale
    else
        local clientLocale = GetLocale()
        if self.localeData[clientLocale] then
            self.current = clientLocale
        else
            self.current = "enUS"
        end
    end
    self:Apply()
end

function Locale:Register(locale, data)
    self.localeData[locale] = data
end

function Locale:SetLocale(locale)
    if not self.localeData[locale] then
        return false
    end
    self.current = locale
    if GuildQuestsCharDB then
        GuildQuestsCharDB.locale = locale
    end
    self:Apply()
    if ns.GQ then
        ns.GQ:Fire("LocaleChanged", locale)
    end
    return true
end

function Locale:GetLocale()
    return self.current
end

function Locale:Apply()
    ns.L = setmetatable({}, {
        __index = function(_, key)
            local data = Locale.localeData[Locale.current]
            if data and data[key] then
                return data[key]
            end
            local fallback = Locale.localeData["enUS"]
            if fallback and fallback[key] then
                return fallback[key]
            end
            return key
        end,
    })
end

function Locale:Get(key, ...)
    local value = ns.L[key] or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end
