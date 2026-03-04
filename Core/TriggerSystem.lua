-- Core/TriggerSystem.lua
NovAuras = NovAuras or {}
NovAuras.TriggerSystem = {}

local eventCallbacks = {}
local statusTriggers = {}

-- Register an event-based trigger
function NovAuras.TriggerSystem.RegisterEventTrigger(event, callback)
    if not eventCallbacks[event] then
        eventCallbacks[event] = {}
    end
    table.insert(eventCallbacks[event], callback)
end

-- Internal: fire all callbacks for an event
function NovAuras.TriggerSystem.FireEvent(event, ...)
    if eventCallbacks[event] then
        for _, cb in ipairs(eventCallbacks[event]) do
            local ok, err = pcall(cb, ...)
            if not ok then
                print("NovAuras trigger error:", err)
            end
        end
    end
end

-- WoW event listener frame
local listenerFrame = CreateFrame("Frame")
listenerFrame:SetScript("OnEvent", function(self, event, ...)
    NovAuras.TriggerSystem.FireEvent(event, ...)
end)

-- Register a WoW event for listening
function NovAuras.TriggerSystem.ListenForEvent(event)
    listenerFrame:RegisterEvent(event)
end

-- Default events always listened
NovAuras.TriggerSystem.ListenForEvent("UNIT_AURA")
NovAuras.TriggerSystem.ListenForEvent("SPELL_UPDATE_COOLDOWN")
NovAuras.TriggerSystem.ListenForEvent("UNIT_SPELLCAST_SUCCEEDED")
NovAuras.TriggerSystem.ListenForEvent("PLAYER_ENTERING_WORLD")
NovAuras.TriggerSystem.ListenForEvent("PLAYER_REGEN_DISABLED")
NovAuras.TriggerSystem.ListenForEvent("PLAYER_REGEN_ENABLED")
NovAuras.TriggerSystem.ListenForEvent("ENCOUNTER_START")
NovAuras.TriggerSystem.ListenForEvent("ENCOUNTER_END")
NovAuras.TriggerSystem.ListenForEvent("ENCOUNTER_TIMELINE_VIEW_ACTIVATED")

-- Status trigger: poll a function on an interval
function NovAuras.TriggerSystem.RegisterStatusTrigger(id, fn, interval)
    statusTriggers[id] = { fn = fn, interval = interval or 0.1, elapsed = 0 }
end

function NovAuras.TriggerSystem.TickAll(elapsed)
    elapsed = elapsed or 0.1
    for id, trigger in pairs(statusTriggers) do
        trigger.elapsed = trigger.elapsed + elapsed
        if trigger.elapsed >= trigger.interval then
            trigger.elapsed = 0
            local ok, result = pcall(trigger.fn)
            if not ok then
                print("NovAuras status trigger error:", result)
            end
        end
    end
end

-- Ticker frame (in-game only)
local tickFrame = CreateFrame("Frame")
tickFrame:SetScript("OnUpdate", function(self, elapsed)
    NovAuras.TriggerSystem.TickAll(elapsed)
end)

-- Custom Lua trigger: run user code
function NovAuras.TriggerSystem.RunCustomTrigger(code, state)
    local loader = loadstring or load
    local fn, err = loader("local state = ...; " .. code)
    if not fn then
        print("NovAuras custom trigger syntax error:", err)
        return nil
    end
    local ok, result = pcall(fn, state)
    if not ok then
        print("NovAuras custom trigger runtime error:", result)
        return nil
    end
    return result
end
