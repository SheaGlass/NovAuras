-- tests/test_conditions.lua
local testDir = debug.getinfo(1, "S").source:match("^@(.+[/\\])")

_G.UIParent = {}
_G.SlashCmdList = {}
_G.IsInInstance = function() return false, nil end
_G.C_PvP = { GetZonePvpInfo = function() return nil end }
_G.CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function() end
    return f
end

dofile(testDir .. "../Core/Init.lua")
dofile(testDir .. "../Core/ConditionSystem.lua")

describe("ConditionSystem", function()
    it("AND: returns true when all conditions pass", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {
            { type = "zone", zone = "arena", current = "arena" },
            { type = "health", op = "lt", threshold = 50, current = 40 },
        })
        assert.is_true(result)
    end)

    it("AND: returns false when any condition fails", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {
            { type = "zone", zone = "arena", current = "arena" },
            { type = "health", op = "lt", threshold = 50, current = 80 },
        })
        assert.is_false(result)
    end)

    it("OR: returns true when any condition passes", function()
        local result = NovAuras.ConditionSystem.Evaluate("OR", {
            { type = "zone", zone = "arena", current = "bg" },
            { type = "health", op = "lt", threshold = 50, current = 30 },
        })
        assert.is_true(result)
    end)

    it("OR: returns false when all conditions fail", function()
        local result = NovAuras.ConditionSystem.Evaluate("OR", {
            { type = "zone", zone = "arena", current = "bg" },
            { type = "health", op = "gt", threshold = 90, current = 50 },
        })
        assert.is_false(result)
    end)

    it("returns true when condition list is empty", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {})
        assert.is_true(result)
    end)

    it("health gt operator works", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {
            { type = "health", op = "gt", threshold = 50, current = 80 },
        })
        assert.is_true(result)
    end)

    it("health eq operator works", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {
            { type = "health", op = "eq", threshold = 100, current = 100 },
        })
        assert.is_true(result)
    end)

    it("returns false for nil health (secret value)", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {
            { type = "health", op = "lt", threshold = 50, current = nil },
        })
        assert.is_false(result)
    end)

    it("custom condition: returns true when fn returns true", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {
            { type = "custom", fn = function() return true end },
        })
        assert.is_true(result)
    end)

    it("custom condition: returns false when fn errors", function()
        local result = NovAuras.ConditionSystem.Evaluate("AND", {
            { type = "custom", fn = function() error("oops") end },
        })
        assert.is_false(result)
    end)
end)
