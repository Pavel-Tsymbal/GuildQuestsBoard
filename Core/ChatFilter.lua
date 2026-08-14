local _, ns = ...

local ChatFilter = {}
ns.ChatFilter = ChatFilter

ChatFilter.initialized = false

local function isWhisperTargetMissingMessage(msg)
    if type(msg) ~= "string" or msg == "" then
        return false
    end
    local lower = msg:lower()
    if lower:find("no player named", 1, true)
        and lower:find("currently playing", 1, true) then
        return true
    end
    if msg:find("Игрок с именем", 1, true)
        and (msg:find("не найден", 1, true) or msg:find("не в игре", 1, true)) then
        return true
    end
    return false
end

function ChatFilter:ShouldSuppress(msg)
    return isWhisperTargetMissingMessage(msg)
end

function ChatFilter:HookFrame(frame)
    if not frame or frame._gqChatFilterHooked or not frame.AddMessage then
        return
    end
    frame._gqChatFilterHooked = true
    local original = frame.AddMessage
    frame.AddMessage = function(self, text, ...)
        if ChatFilter:ShouldSuppress(text) then
            return
        end
        return original(self, text, ...)
    end
end

function ChatFilter:HookAllFrames()
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        self:HookFrame(_G["ChatFrame" .. i])
    end
    self:HookFrame(DEFAULT_CHAT_FRAME)
end

function ChatFilter:Init()
    if self.initialized then
        return
    end
    self.initialized = true
    self:HookAllFrames()
    if FCF_OpenNewWindow then
        hooksecurefunc("FCF_OpenNewWindow", function()
            C_Timer.After(0, function()
                ChatFilter:HookAllFrames()
            end)
        end)
    end
end
