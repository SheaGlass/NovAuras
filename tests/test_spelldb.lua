-- tests/test_spelldb.lua
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
dofile(testDir .. "../Modules/PvPSpellDB.lua")

describe("PvPSpellDB", function()
    it("returns entry for known spell", function()
        local entry = NovAuras.PvPSpellDB.Get(190319) -- Combustion
        assert.is_not_nil(entry)
        assert.equals("MAGE", entry.class)
        assert.equals("OFFENSIVE", entry.category)
    end)

    it("returns nil for unknown spell", function()
        assert.is_nil(NovAuras.PvPSpellDB.Get(999999999))
    end)

    it("has spec variants for interrupt spells", function()
        local variants = NovAuras.PvPSpellDB.GetSpecVariants(1766) -- Kick
        assert.is_not_nil(variants)
    end)

    it("infers spec from spec-specific spell", function()
        local spec = NovAuras.PvPSpellDB.SpecFromSpell(190319) -- Combustion = Fire
        assert.equals("Fire", spec)
    end)

    it("returns nil spec for ALL-spec spells", function()
        local spec = NovAuras.PvPSpellDB.SpecFromSpell(1766) -- Kick = ALL
        assert.is_nil(spec)
    end)

    it("GetDuration returns base duration without spec", function()
        local d = NovAuras.PvPSpellDB.GetDuration(190319)
        assert.equals(120, d)
    end)

    it("GetDuration returns talent duration with known spec+variant", function()
        local d = NovAuras.PvPSpellDB.GetDuration(1766, "Subtlety") -- Kick with talent
        assert.equals(12, d)
    end)

    it("GetDuration returns base when spec has no variant", function()
        local d = NovAuras.PvPSpellDB.GetDuration(45438, "Frost") -- Ice Block, no variant
        assert.equals(240, d)
    end)

    it("returns nil duration for unknown spell", function()
        local d = NovAuras.PvPSpellDB.GetDuration(999999999)
        assert.is_nil(d)
    end)

    it("trinkets are present", function()
        local entry = NovAuras.PvPSpellDB.Get(336126) -- Gladiator's Medallion
        assert.is_not_nil(entry)
        assert.equals("TRINKET", entry.category)
    end)

    it("racials are present", function()
        local entry = NovAuras.PvPSpellDB.Get(20594) -- Stoneform
        assert.is_not_nil(entry)
        assert.equals("RACIAL", entry.category)
    end)
end)
