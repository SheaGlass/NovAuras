-- tests/test_triggers.lua
-- Mock WoW event system

local testDir = debug.getinfo(1, "S").source:match("^@(.+[/\\])")

_G.UIParent = {}
_G.SlashCmdList = {}
_G.IsInInstance = function() return false, nil end
_G.C_PvP = { GetZonePvpInfo = function() return nil end }

local eventHandlers = {}
_G.CreateFrame = function(frameType, name, parent, template)
    local f = {
        _events = {},
        _scripts = {},
    }
    f.RegisterEvent = function(self, event) self._events[event] = true end
    f.SetScript = function(self, ev, fn) self._scripts[ev] = fn end
    return f
end

dofile(testDir .. "../Core/Init.lua")
dofile(testDir .. "../Core/TriggerSystem.lua")

describe("EventTrigger", function()
    it("fires callback when registered event occurs", function()
        local fired = false
        NovAuras.TriggerSystem.RegisterEventTrigger("UNIT_AURA", function()
            fired = true
        end)
        NovAuras.TriggerSystem.FireEvent("UNIT_AURA", "player")
        assert.is_true(fired)
    end)

    it("passes event args to callback", function()
        local capturedUnit = nil
        NovAuras.TriggerSystem.RegisterEventTrigger("UNIT_AURA", function(unit)
            capturedUnit = unit
        end)
        NovAuras.TriggerSystem.FireEvent("UNIT_AURA", "player")
        assert.equals("player", capturedUnit)
    end)

    it("does not crash on callback error", function()
        NovAuras.TriggerSystem.RegisterEventTrigger("TEST_EVENT", function()
            error("intentional error")
        end)
        assert.has_no.errors(function()
            NovAuras.TriggerSystem.FireEvent("TEST_EVENT")
        end)
    end)
end)

describe("StatusTrigger", function()
    it("polls a function on interval", function()
        local callCount = 0
        NovAuras.TriggerSystem.RegisterStatusTrigger("test_poll", function()
            callCount = callCount + 1
            return callCount > 2
        end, 0.1)
        for i = 1, 3 do
            NovAuras.TriggerSystem.TickAll()
        end
        assert.is_true(callCount >= 3)
    end)
end)

describe("CustomLuaTrigger", function()
    it("executes user function and returns state", function()
        local state = NovAuras.TriggerSystem.RunCustomTrigger(
            "return { show = true, value = 42 }",
            {}
        )
        assert.is_not_nil(state)
        assert.is_true(state.show)
        assert.equals(42, state.value)
    end)

    it("returns nil on syntax error without crashing", function()
        local state = NovAuras.TriggerSystem.RunCustomTrigger(
            "this is not valid lua @@",
            {}
        )
        assert.is_nil(state)
    end)
end)
