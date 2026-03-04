-- Modules/PvPSpellDB.lua
-- Community-updatable PvP spell database.
-- Add new spells here each patch without touching other systems.
NovAuras = NovAuras or {}
NovAuras.PvPSpellDB = {}

local DB = {
    -- ===== MAGE =====
    [190319] = { name="Combustion",          class="MAGE",        spec="Fire",    duration=120, category="OFFENSIVE" },
    [45438]  = { name="Ice Block",           class="MAGE",        spec="Frost",   duration=240, category="DEFENSIVE" },
    [12042]  = { name="Arcane Power",        class="MAGE",        spec="Arcane",  duration=90,  category="OFFENSIVE" },
    [2139]   = { name="Counterspell",        class="MAGE",        spec="ALL",     duration=24,  category="INTERRUPT" },
    [66]     = { name="Invisibility",        class="MAGE",        spec="ALL",     duration=300, category="DEFENSIVE" },
    [122]    = { name="Frost Nova",          class="MAGE",        spec="ALL",     duration=30,  category="CC"        },

    -- ===== WARRIOR =====
    [871]    = { name="Shield Wall",         class="WARRIOR",     spec="Prot",    duration=240, category="DEFENSIVE" },
    [1719]   = { name="Recklessness",        class="WARRIOR",     spec="Arms",    duration=90,  category="OFFENSIVE" },
    [6552]   = { name="Pummel",              class="WARRIOR",     spec="ALL",     duration=15,  category="INTERRUPT" },
    [12292]  = { name="Bloodbath",           class="WARRIOR",     spec="Arms",    duration=60,  category="OFFENSIVE" },
    [23920]  = { name="Spell Reflect",       class="WARRIOR",     spec="ALL",     duration=25,  category="DEFENSIVE" },
    [46968]  = { name="Shockwave",           class="WARRIOR",     spec="Prot",    duration=40,  category="CC"        },

    -- ===== ROGUE =====
    [1766]   = { name="Kick",               class="ROGUE",       spec="ALL",     duration=15,  category="INTERRUPT" },
    [2094]   = { name="Blind",              class="ROGUE",       spec="ALL",     duration=120, category="CC"        },
    [31224]  = { name="Cloak of Shadows",   class="ROGUE",       spec="ALL",     duration=60,  category="DEFENSIVE" },
    [13750]  = { name="Adrenaline Rush",    class="ROGUE",       spec="Outlaw",  duration=120, category="OFFENSIVE" },
    [36554]  = { name="Shadowstep",         class="ROGUE",       spec="Subtlety",duration=20,  category="OFFENSIVE" },
    [1833]   = { name="Cheap Shot",         class="ROGUE",       spec="ALL",     duration=15,  category="CC"        },

    -- ===== PALADIN =====
    [642]    = { name="Divine Shield",      class="PALADIN",     spec="ALL",     duration=300, category="DEFENSIVE" },
    [498]    = { name="Divine Protection",  class="PALADIN",     spec="ALL",     duration=120, category="DEFENSIVE" },
    [96231]  = { name="Rebuke",             class="PALADIN",     spec="ALL",     duration=15,  category="INTERRUPT" },
    [31884]  = { name="Avenging Wrath",     class="PALADIN",     spec="Ret",     duration=120, category="OFFENSIVE" },
    [853]    = { name="Hammer of Justice",  class="PALADIN",     spec="ALL",     duration=60,  category="CC"        },
    [6940]   = { name="Blessing of Sacrifice",class="PALADIN",   spec="ALL",     duration=120, category="DEFENSIVE" },

    -- ===== PRIEST =====
    [8122]   = { name="Psychic Scream",     class="PRIEST",      spec="ALL",     duration=45,  category="CC"        },
    [47585]  = { name="Dispersion",         class="PRIEST",      spec="Shadow",  duration=120, category="DEFENSIVE" },
    [10060]  = { name="Power Infusion",     class="PRIEST",      spec="ALL",     duration=120, category="OFFENSIVE" },
    [64044]  = { name="Psychic Horror",     class="PRIEST",      spec="Shadow",  duration=45,  category="CC"        },
    [586]    = { name="Fade",               class="PRIEST",      spec="ALL",     duration=30,  category="DEFENSIVE" },

    -- ===== DRUID =====
    [22812]  = { name="Barkskin",           class="DRUID",       spec="ALL",     duration=60,  category="DEFENSIVE" },
    [106951] = { name="Berserk",            class="DRUID",       spec="Feral",   duration=180, category="OFFENSIVE" },
    [78675]  = { name="Solar Beam",         class="DRUID",       spec="Balance", duration=60,  category="INTERRUPT" },
    [5211]   = { name="Mighty Bash",        class="DRUID",       spec="ALL",     duration=50,  category="CC"        },
    [339]    = { name="Entangling Roots",   class="DRUID",       spec="ALL",     duration=30,  category="CC"        },
    [61336]  = { name="Survival Instincts", class="DRUID",       spec="Feral",   duration=180, category="DEFENSIVE" },

    -- ===== HUNTER =====
    [19574]  = { name="Bestial Wrath",      class="HUNTER",      spec="BM",      duration=90,  category="OFFENSIVE" },
    [147362] = { name="Counter Shot",       class="HUNTER",      spec="MM",      duration=24,  category="INTERRUPT" },
    [187707] = { name="Muzzle",             class="HUNTER",      spec="SV",      duration=15,  category="INTERRUPT" },
    [186265] = { name="Aspect of the Turtle",class="HUNTER",     spec="ALL",     duration=180, category="DEFENSIVE" },
    [3355]   = { name="Freezing Trap",      class="HUNTER",      spec="ALL",     duration=25,  category="CC"        },

    -- ===== SHAMAN =====
    [108271] = { name="Astral Shift",       class="SHAMAN",      spec="ALL",     duration=120, category="DEFENSIVE" },
    [51514]  = { name="Hex",                class="SHAMAN",      spec="ALL",     duration=30,  category="CC"        },
    [57994]  = { name="Wind Shear",         class="SHAMAN",      spec="ALL",     duration=12,  category="INTERRUPT" },
    [2825]   = { name="Bloodlust",          class="SHAMAN",      spec="ALL",     duration=300, category="OFFENSIVE" },
    [192058] = { name="Capacitor Totem",    class="SHAMAN",      spec="ALL",     duration=45,  category="CC"        },

    -- ===== WARLOCK =====
    [104773] = { name="Unending Resolve",   class="WARLOCK",     spec="ALL",     duration=180, category="DEFENSIVE" },
    [118699] = { name="Mortal Coil",        class="WARLOCK",     spec="ALL",     duration=45,  category="CC"        },
    [19647]  = { name="Spell Lock",         class="WARLOCK",     spec="ALL",     duration=24,  category="INTERRUPT" },
    [48020]  = { name="Demonic Circle: Teleport",class="WARLOCK",spec="ALL",     duration=30,  category="DEFENSIVE" },
    [6789]   = { name="Mortal Coil",        class="WARLOCK",     spec="ALL",     duration=45,  category="CC"        },

    -- ===== DEATH KNIGHT =====
    [48792]  = { name="Icebound Fortitude", class="DEATHKNIGHT", spec="ALL",     duration=180, category="DEFENSIVE" },
    [47528]  = { name="Mind Freeze",        class="DEATHKNIGHT", spec="ALL",     duration=15,  category="INTERRUPT" },
    [49206]  = { name="Summon Gargoyle",    class="DEATHKNIGHT", spec="Unholy",  duration=180, category="OFFENSIVE" },
    [91797]  = { name="Hungering Cold",     class="DEATHKNIGHT", spec="Frost",   duration=45,  category="CC"        },

    -- ===== DEMON HUNTER =====
    [196555] = { name="Netherwalk",         class="DEMONHUNTER", spec="Havoc",   duration=180, category="DEFENSIVE" },
    [183752] = { name="Consume Magic",      class="DEMONHUNTER", spec="ALL",     duration=10,  category="INTERRUPT" },
    [191427] = { name="Metamorphosis",      class="DEMONHUNTER", spec="Havoc",   duration=240, category="OFFENSIVE" },
    [179057] = { name="Chaos Nova",         class="DEMONHUNTER", spec="Havoc",   duration=60,  category="CC"        },

    -- ===== EVOKER =====
    [357214] = { name="Time Spiral",        class="EVOKER",      spec="ALL",     duration=120, category="DEFENSIVE" },
    [351338] = { name="Quell",              class="EVOKER",      spec="ALL",     duration=20,  category="INTERRUPT" },
    [370537] = { name="Stasis",             class="EVOKER",      spec="ALL",     duration=90,  category="CC"        },

    -- ===== MONK =====
    [122783] = { name="Diffuse Magic",      class="MONK",        spec="ALL",     duration=90,  category="DEFENSIVE" },
    [116705] = { name="Spear Hand Strike",  class="MONK",        spec="ALL",     duration=15,  category="INTERRUPT" },
    [137639] = { name="Storm, Earth & Fire",class="MONK",        spec="WW",      duration=90,  category="OFFENSIVE" },
    [119381] = { name="Leg Sweep",          class="MONK",        spec="ALL",     duration=45,  category="CC"        },
    [115078] = { name="Paralysis",          class="MONK",        spec="ALL",     duration=45,  category="CC"        },

    -- ===== PvP TRINKETS =====
    [336126] = { name="Gladiator's Medallion",  class="ALL", spec="ALL", duration=120, category="TRINKET" },
    [195710] = { name="Adaptation",             class="ALL", spec="ALL", duration=60,  category="TRINKET" },
    [208683] = { name="Gladiator's Insignia",   class="ALL", spec="ALL", duration=120, category="TRINKET" },

    -- ===== RACIALS =====
    [20549]  = { name="War Stomp",          class="ALL", spec="ALL", duration=90,  category="RACIAL" },
    [7744]   = { name="Will to Survive",    class="ALL", spec="ALL", duration=180, category="RACIAL" },
    [20594]  = { name="Stoneform",          class="ALL", spec="ALL", duration=120, category="RACIAL" },
    [58984]  = { name="Shadowmeld",         class="ALL", spec="ALL", duration=120, category="RACIAL" },
    [28880]  = { name="Gift of the Naaru",  class="ALL", spec="ALL", duration=180, category="RACIAL" },
    [255647] = { name="Light's Judgment",   class="ALL", spec="ALL", duration=150, category="RACIAL" },
    [256948] = { name="Fireblood",          class="ALL", spec="ALL", duration=120, category="RACIAL" },
    [312924] = { name="Ancestral Call",     class="ALL", spec="ALL", duration=120, category="RACIAL" },
    [274738] = { name="Haymaker",           class="ALL", spec="ALL", duration=150, category="RACIAL" },
}

-- Talent-modified cooldown variants
local SpecVariants = {
    [1766]  = { -- Kick
        ["Assassination"] = { base=15, withTalent=12 },
        ["Subtlety"]      = { base=15, withTalent=12 },
        ["Outlaw"]        = { base=15, withTalent=12 },
    },
    [2139]  = { -- Counterspell
        ["Fire"]          = { base=24, withTalent=20 },
        ["Frost"]         = { base=24, withTalent=20 },
        ["Arcane"]        = { base=24, withTalent=20 },
    },
    [6552]  = { -- Pummel
        ["Arms"]          = { base=15, withTalent=12 },
        ["Fury"]          = { base=15, withTalent=12 },
    },
    [57994] = { -- Wind Shear
        ["Elemental"]     = { base=12, withTalent=9 },
        ["Enhancement"]   = { base=12, withTalent=9 },
        ["Restoration"]   = { base=12, withTalent=9 },
    },
}

function NovAuras.PvPSpellDB.Get(spellID)
    return DB[spellID]
end

function NovAuras.PvPSpellDB.GetSpecVariants(spellID)
    return SpecVariants[spellID]
end

function NovAuras.PvPSpellDB.SpecFromSpell(spellID)
    local entry = DB[spellID]
    if entry and entry.spec ~= "ALL" then
        return entry.spec
    end
    return nil
end

-- Returns best duration estimate given known spec (defaults to base duration)
function NovAuras.PvPSpellDB.GetDuration(spellID, spec)
    local entry = DB[spellID]
    if not entry then return nil end
    local variants = SpecVariants[spellID]
    if variants and spec and variants[spec] then
        return variants[spec].withTalent
    end
    return entry.duration
end
