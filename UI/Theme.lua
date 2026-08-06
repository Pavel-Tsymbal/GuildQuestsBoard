local _, ns = ...

local Theme = {}
ns.Theme = Theme

function Theme:EnsureBackdrop(frame)
    if frame.SetBackdrop then
        return true
    end
    if BackdropTemplateMixin and Mixin then
        Mixin(frame, BackdropTemplateMixin)
        if frame.OnBackdropLoaded then
            frame:OnBackdropLoaded()
        end
    end
    return frame.SetBackdrop ~= nil
end

function Theme:ApplyPanel(frame)
    if not self:EnsureBackdrop(frame) then
        return
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
    frame:SetBackdropBorderColor(0.78, 0.62, 0.22, 1)
end
