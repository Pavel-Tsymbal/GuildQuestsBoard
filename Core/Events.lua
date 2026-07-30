local _, ns = ...

local Events = {}
ns.Events = Events

Events.handlers = {}

function Events:Register(event, callback, owner)
    if not self.handlers[event] then
        self.handlers[event] = {}
    end
    table.insert(self.handlers[event], { callback = callback, owner = owner })
end

function Events:UnregisterAll(owner)
    for event, list in pairs(self.handlers) do
        for i = #list, 1, -1 do
            if list[i].owner == owner then
                table.remove(list, i)
            end
        end
        if #list == 0 then
            self.handlers[event] = nil
        end
    end
end

function Events:Fire(event, ...)
    local list = self.handlers[event]
    if not list then
        return
    end
    for _, entry in ipairs(list) do
        local ok, err = pcall(entry.callback, entry.owner, ...)
        if not ok and ns.GQ and ns.GQ.Print then
            ns.GQ:Print("Event error:", event, err)
        end
    end
end
