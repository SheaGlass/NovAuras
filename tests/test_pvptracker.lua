-- tests/test_pvptracker.lua
local testDir = debug.getinfo(1, "S").source:match("^@(.+[/\\])")

_G.UIParent = {}
_G.SlashCmdList = {}
_G.IsInInstance = function() return false, nil end
_G.C_PvP = { GetZonePvpInfo = function() return nil end }
_G.GetTime = function() return 100 end
_G.C_Timer = { After = function(t, fn) fn() end }
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

describe("PvPTracker", function()
    it("tracks a cast and starts a timer", function()
        NovAuras.PvPTracker.HandleCast("enemy-realm", 190319) -- Combustion, 120s
        local timer = NovAuras.PvPTracker.GetTimer("enemy-realm", 190319)
        assert.is_not_nil(timer)
        assert.equals(100 + 120, timer.expiry) -- GetTime() + duration
    end)

    it("detects spec from first cast", function()
        NovAuras.PvPTracker.HandleCast("mage-realm", 190319) -- Combustion = Fire
        local profile = NovAuras.PvPTracker.GetProfile("mage-realm")
        assert.equals("Fire", profile.spec)
    end)

    it("does not overwrite detected spec on later casts", function()
        NovAuras.PvPTracker.HandleCast("mage2-realm", 190319) -- Fire from Combustion
        NovAuras.PvPTracker.HandleCast("mage2-realm", 2139)   -- Counterspell (ALL spec)
        local profile = NovAuras.PvPTracker.GetProfile("mage2-realm")
        assert.equals("Fire", profile.spec)
    end)

    it("ignores unknown spells", function()
        local before = NovAuras.PvPTracker.GetTimer("unknown-realm", 999999999)
        NovAuras.PvPTracker.HandleCast("unknown-realm", 999999999)
        local after = NovAuras.PvPTracker.GetTimer("unknown-realm", 999999999)
        assert.is_nil(before)
        assert.is_nil(after)
    end)

    it("self-calibrates if ability fires before timer expires", function()
        -- First cast at t=100, Kick default 15s → expiry 115
        _G.GetTime = function() return 100 end
        NovAuras.PvPTracker.HandleCast("rogue-realm", 1766)
        -- Fire again at t=112 (before 115 expiry) → real duration = 12
        _G.GetTime = function() return 112 end
        NovAuras.PvPTracker.HandleCast("rogue-realm", 1766)
        local profile = NovAuras.PvPTracker.GetProfile("rogue-realm")
        assert.equals(12, profile.cooldowns[1766])
    end)

    it("uses calibrated duration on subsequent casts", function()
        -- After calibration above, next cast at t=112 should use 12s
        local timer = NovAuras.PvPTracker.GetTimer("rogue-realm", 1766)
        assert.equals(112 + 12, timer.expiry)
    end)

    it("GetAllTimers returns table", function()
        local all = NovAuras.PvPTracker.GetAllTimers()
        assert.is_not_nil(all)
        assert.equals("table", type(all))
    end)
end)
