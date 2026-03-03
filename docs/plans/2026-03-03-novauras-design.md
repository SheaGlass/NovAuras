# NovAuras — Design Document
**Date:** 2026-03-03
**WoW Version:** 12.0 (Midnight)

---

## Overview

NovAuras is a full-suite WoW addon for Midnight that rebuilds WeakAuras from the ground up. It combines:
- A WeakAuras-style HUD display engine (auras, cooldowns, resources)
- DBM/BigWigs-style boss timers via the new official encounter API
- OmniBar-style PvP cooldown tracker with spec inference and self-calibration

Single addon install. Internally modular — modules lazy-load only when relevant content is entered.

---

## Architecture: Approach C — Single Addon, Internally Modular

### File Layout

```
NovAuras/
├── NovAuras.toc
├── Core/
│   ├── Init.lua              -- Bootstrap, module registry
│   ├── DisplayEngine.lua     -- Regions: Icon, Bar, Text, Progress
│   ├── TriggerSystem.lua     -- Event/Status/Custom Lua triggers
│   ├── ConditionSystem.lua   -- Show/hide logic, AND/OR conditions
│   ├── AnimationSystem.lua   -- Entry/exit/loop animations
│   ├── ConfigGUI.lua         -- Visual editor (AceGUI-based)
│   └── Transmission.lua      -- Share auras via base64 strings
├── Modules/
│   ├── BossTimers.lua        -- Lazy loads in instances
│   ├── PvPTracker.lua        -- Lazy loads in PvP/arenas
│   └── PvPSpellDB.lua        -- SpellID → cooldown duration map
└── Libs/
    └── AceGUI/               -- Embedded UI widget library
```

### Module Loading

Core always loads on login. On `PLAYER_ENTERING_WORLD`:
- `IsInInstance()` returns raid/dungeon → load `BossTimers`
- Zone is arena/battleground → load `PvPTracker`

---

## Core Display Engine

### Region Types
| Region | Description |
|---|---|
| Icon | Spell icon with cooldown sweep, stack count, timer text |
| Bar | Horizontal/vertical progress bar with timer |
| Text | Dynamic text with format strings |
| Progress | Circular/radial progress texture |
| Model | 3D model display |
| Group | Container for multiple regions, move together |

---

## Trigger System

### Three Trigger Types
| Type | Mechanism | Midnight Handling |
|---|---|---|
| Event | Fires on WoW events (UNIT_AURA, SPELL_UPDATE_COOLDOWN, etc.) | Returns nil gracefully when API yields a Secret Value |
| Status | Polls game state on a tick (health %, resource, zone) | Falls back to last known value when restricted |
| Custom Lua | User-written function, full power | Sandbox — user handles secrets themselves |

### Secret Values Compatibility Layer
Every API call that can return a secret value wraps through a safety check:

```lua
local function SafeGetValue(val)
    if type(val) == "userdata" then  -- secret value type
        return nil  -- gracefully return nil, never error
    end
    return val
end
```

Auras never hard-error in Midnight — they go inactive when data is restricted.

---

## Boss Timers Module

Built entirely on Blizzard's official encounter API. No guesswork parsing.

### APIs Used
```lua
C_EncounterEvents.GetEventList(encounterID)
C_EncounterEvents.GetEventInfo(eventID)
C_EncounterEvents.SetEventSound(eventID, soundID)
C_EncounterTimeline.GetSortedEventList(encounterID)
C_EncounterTimeline.SetViewType(viewType)
C_EncounterWarnings.SetWarningsShown(true)
```

### Display
- Scrolling timeline bar showing upcoming boss abilities
- Countdown text per ability
- Fully customisable: position, scale, colour per encounter event
- Audio alerts via `C_EncounterEvents.PlayEventSound()`

---

## PvP Cooldown Tracker Module

### Core Principle
Enemy cooldown values are Secret Values in Midnight — they cannot be read directly.
NovAuras uses an **inference engine** that never touches a secret value.

### Inference Flow
```
1. UNIT_SPELLCAST_SUCCEEDED fires for enemy cast
         ↓
2. Look up spellID in PvPSpellDB
         ↓
3. Start local C_Timer countdown for that enemy + spellID
         ↓
4. Display as Icon region with countdown sweep
         ↓
5. OnAuraApplied/OnAuraRemoved events reset or confirm timer
```

### Talent Handling — 2 Layers

**Layer 1: Spec Detection via Observed Abilities**

Cannot inspect enemy talent trees in PvP — `CanInspect()` returns false on enemies.
Instead, infer spec from the first few observed casts:

```lua
profile.spec = NovAuras.PvPSpellDB.SpecFromSpell[spellID]
-- e.g. casting Combustion → Fire Mage
-- Once spec known, load meta talent assumptions for that spec
```

**Layer 2: Dynamic Self-Calibration**

If ability comes off cooldown before the timer expires, update the real duration:

```lua
if observedReadyTime < trackedExpiry then
    profile.cooldowns[spellID] = actualObservedDuration
end
```

**Fallback:** Always default to shortest known cooldown duration for that spec.

---

## PvP Spell Database (PvPSpellDB.lua)

### Structure
```lua
NovAuras.PvPSpellDB = {
    -- [spellID] = { name, class, spec, duration, category, icon }

    -- MAGE
    [190319] = { name="Combustion",    class="MAGE",    spec="Fire",   duration=120, category="OFFENSIVE" },
    [45438]  = { name="Ice Block",     class="MAGE",    spec="Frost",  duration=240, category="DEFENSIVE" },
    [12042]  = { name="Arcane Power",  class="MAGE",    spec="Arcane", duration=90,  category="OFFENSIVE" },

    -- TRINKETS
    [336126] = { name="Gladiator's Medallion", class="ALL", spec="ALL", duration=120, category="TRINKET" },
    [195710] = { name="Adaptation",            class="ALL", spec="ALL", duration=60,  category="TRINKET" },
}

-- Spec variants for talent-modified cooldowns
NovAuras.PvPSpellDB.SpecVariants = {
    [spellID] = {
        ["Assassination"] = { base=15, withTalent=12 },
        ["Subtlety"]      = { base=15, withTalent=12 },
    }
}
```

### Categories Tracked
| Category | Examples |
|---|---|
| OFFENSIVE | Combustion, Recklessness, Vendetta |
| DEFENSIVE | Ice Block, Shield Wall, Divine Shield |
| CC | Blind, Polymorph, Kidney Shot |
| INTERRUPT | Kick, Counterspell, Pummel |
| TRINKET | Gladiator's Medallion, Adaptation, Insignia |
| RACIAL | Stoneform, Will to Survive, War Stomp |

Covers all classes, all specs, all PvP trinkets, all racials.
Standalone file — community-updatable each patch without touching other systems.

### Display Grouping
Cooldowns group by enemy player, sorted by category (DEFENSIVE → OFFENSIVE → CC → TRINKET).

---

## Config GUI — Hybrid Visual Editor

### Simple Mode
Dropdown-driven trigger builder, condition builder, drag-to-position.
Accessible to all players with no Lua knowledge required.

### Advanced Mode (Power Users)
Every field replaceable with a custom Lua function — same as classic WeakAuras:

```lua
function(state)
    local name, _, count, _, duration, expiry =
        AuraUtil.FindUnitAuraByName("player", "Combustion")
    if name then
        state.show = true
        state.expirationTime = expiry
        state.stacks = count
    end
    return state.show
end
```

Full access: custom triggers, custom conditions, custom text formatters, custom animations.

---

## Transmission

Share auras between players via base64-encoded serialised strings.
- `/nv send <player>` — whisper an aura
- `/nv share` — broadcast to raid/party chat
- Import via paste dialog in the Config GUI

---

## Midnight API Restrictions Summary

| Data | Status | Our Approach |
|---|---|---|
| Enemy cooldown values | Secret Value | Inference + self-calibration |
| Enemy auras in PvP | Secret Value | Observed cast detection |
| Enemy talent trees | Not inspectable | Spec inference from casts |
| Boss cast details | Secret Value | C_EncounterEvents official API |
| Player own auras | Accessible | Direct API calls |
| Player secondary resources | Accessible | Direct API calls |
| CLEU enemy events | Restricted | OnAuraApplied/OnAuraRemoved events |
