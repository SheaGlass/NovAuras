-- tests/test_pvptracker.lua
local testDir = debug.getinfo(1, "S").source:match("^@(.+[/\\])")

_G.UIParent = {}
_G.SlashCmdList = {}
_G.IsInInstance = function() return false, nil end
_G.C_PvP = { GetZonePvpInfo = function() return nil end }
_G.GetTime = function() return 100 end
_G.C_Timer = { After = function(t, fn) fn() end }

-- Simulate arena1 being an enemy unit with a stable GUID
local unitGUIDs = {
    ["arena1"] = "Player-1234-AABBCCDD",
    ["arena2"] = "Player-1234-EEFF0011",
}
_G.UnitGUID    = function(unit) return unitGUIDs[unit] end
_G.UnitIsEnemy = function(a, b)
    if a == "player" and unitGUIDs[b] then return true end
    return false
end
_G.UnitIsUnit  = function(a, b)
    return a == b
end

_G.CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function() end
    return f
end

dofile(testDir .. "../Core/Init.lua")
dofile(testDir .. "../Core/TriggerSystem.lua")
dofile(testDir .. "../Modules/PvPSpellDB.lua")
dofile(testDir .. "../Modules/PvPTracker.lua")

-- ============================================================
-- Core tracking
-- ============================================================
describe("PvPTracker: core tracking", function()
    before_each(function()
        NovAuras.PvPTracker.Reset()
        _G.GetTime = function() return 100 end
    end)

    it("tracks a cast via GUID and starts a timer", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319) -- Combustion 120s
        local timer = NovAuras.PvPTracker.GetTimer("arena1", 190319)
        assert.is_not_nil(timer)
        assert.equals(220, timer.expiry) -- 100 + 120
    end)

    it("detects spec from first cast", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319) -- Fire Mage
        local guid = UnitGUID("arena1")
        local profile = NovAuras.PvPTracker.GetProfile(guid, true)
        assert.equals("Fire", profile.spec)
    end)

    it("does not overwrite spec once detected", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319) -- Combustion → Fire
        NovAuras.PvPTracker.HandleCast("arena1", 2139)   -- Counterspell (ALL spec)
        local guid = UnitGUID("arena1")
        local profile = NovAuras.PvPTracker.GetProfile(guid, true)
        assert.equals("Fire", profile.spec)
    end)

    it("ignores unknown spells", function()
        NovAuras.PvPTracker.HandleCast("arena1", 999999999)
        local timer = NovAuras.PvPTracker.GetTimer("arena1", 999999999)
        assert.is_nil(timer)
    end)

    it("ignores units with no GUID (SafeGetValue nil path)", function()
        -- UnitGUID returns nil for this unit
        local savedGUIDs = unitGUIDs
        _G.UnitGUID = function(unit) return nil end
        NovAuras.PvPTracker.HandleCast("arena3", 190319)
        local timer = NovAuras.PvPTracker.GetTimer("arena3", 190319)
        assert.is_nil(timer)
        _G.UnitGUID = function(unit) return unitGUIDs[unit] end
    end)
end)

-- ============================================================
-- Self-calibration
-- ============================================================
describe("PvPTracker: self-calibration", function()
    before_each(function()
        NovAuras.PvPTracker.Reset()
        _G.GetTime = function() return 100 end
    end)

    it("updates learned duration when ability fires early", function()
        NovAuras.PvPTracker.HandleCast("arena1", 1766) -- Kick, base 15s → expiry 115
        _G.GetTime = function() return 112 end          -- fires at 112, before 115
        NovAuras.PvPTracker.HandleCast("arena1", 1766)
        local guid = UnitGUID("arena1")
        local profile = NovAuras.PvPTracker.GetProfile(guid, true)
        assert.equals(12, profile.cooldowns[1766])
    end)

    it("uses calibrated duration on next cast", function()
        NovAuras.PvPTracker.HandleCast("arena1", 1766) -- first cast at 100
        _G.GetTime = function() return 112 end
        NovAuras.PvPTracker.HandleCast("arena1", 1766) -- fires early → calibrated to 12
        local timer = NovAuras.PvPTracker.GetTimer("arena1", 1766)
        assert.equals(112 + 12, timer.expiry)
    end)
end)

-- ============================================================
-- Midnight API: UNIT_AURA uncertainty
-- ============================================================
describe("PvPTracker: Midnight UNIT_AURA handling", function()
    before_each(function()
        NovAuras.PvPTracker.Reset()
        _G.GetTime = function() return 100 end
    end)

    it("marks active timers as uncertain when UNIT_AURA fires", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319) -- Combustion
        local guid = UnitGUID("arena1")
        NovAuras.PvPTracker.HandleAuraChange(guid)
        local timer = NovAuras.PvPTracker.GetTimer("arena1", 190319)
        assert.is_true(timer.uncertain)
    end)

    it("new timers start as certain (uncertain = false)", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319)
        local timer = NovAuras.PvPTracker.GetTimer("arena1", 190319)
        assert.is_false(timer.uncertain)
    end)

    it("does not mark expired timers as uncertain", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319) -- expiry 220
        _G.GetTime = function() return 300 end            -- past expiry
        local guid = UnitGUID("arena1")
        NovAuras.PvPTracker.HandleAuraChange(guid)        -- should not touch expired timer
        local timer = NovAuras.PvPTracker.GetTimer("arena1", 190319)
        assert.is_false(timer.uncertain)                  -- expired, HandleAuraChange skips it
    end)
end)

-- ============================================================
-- Midnight API: unit cleanup
-- ============================================================
describe("PvPTracker: unit and zone cleanup", function()
    before_each(function()
        NovAuras.PvPTracker.Reset()
        _G.GetTime = function() return 100 end
    end)

    it("ClearUnit removes all timers for that GUID", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319)
        NovAuras.PvPTracker.HandleCast("arena1", 45438)
        local guid = UnitGUID("arena1")
        NovAuras.PvPTracker.ClearUnit(guid)
        assert.is_nil(NovAuras.PvPTracker.GetTimer("arena1", 190319))
        assert.is_nil(NovAuras.PvPTracker.GetTimer("arena1", 45438))
    end)

    it("ClearUnit leaves other units' timers intact", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319)
        NovAuras.PvPTracker.HandleCast("arena2", 45438)
        local guid1 = UnitGUID("arena1")
        NovAuras.PvPTracker.ClearUnit(guid1)
        assert.is_nil(NovAuras.PvPTracker.GetTimer("arena1", 190319))
        assert.is_not_nil(NovAuras.PvPTracker.GetTimer("arena2", 45438))
    end)

    it("Reset wipes all timers and profiles", function()
        NovAuras.PvPTracker.HandleCast("arena1", 190319)
        NovAuras.PvPTracker.HandleCast("arena2", 45438)
        NovAuras.PvPTracker.Reset()
        assert.is_nil(NovAuras.PvPTracker.GetTimer("arena1", 190319))
        assert.is_nil(NovAuras.PvPTracker.GetTimer("arena2", 45438))
    end)

    it("GetAllTimers returns a table", function()
        local all = NovAuras.PvPTracker.GetAllTimers()
        assert.equals("table", type(all))
    end)
end)
