-- Modules/PvPTracker.lua
-- Tracks enemy PvP cooldowns via inference.
-- Never reads Secret Values — all enemy aura/cooldown data is opaque in Midnight.
NovAuras = NovAuras or {}
NovAuras.PvPTracker = {}

-- profiles[guid] = { spec, cooldowns={[spellID]=duration} }
-- timers[guid.."_"..spellID] = { expiry, startTime, duration, spellID, guid, uncertain }
local profiles = {}
local timers   = {}

-- ============================================================
-- Internal helpers
-- ============================================================

local function SafeUnit(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return NovAuras.SafeGetValue(result)
end

local function GetGUID(unit)
    return SafeUnit(UnitGUID, unit)
end

local function IsEnemy(unit)
    return SafeUnit(UnitIsEnemy, "player", unit) == true
end

local function IsSelf(unit)
    return SafeUnit(UnitIsUnit, unit, "player") == true
end

local function GetOrCreateProfile(guid)
    if not profiles[guid] then
        profiles[guid] = { spec = nil, cooldowns = {} }
    end
    return profiles[guid]
end

local function TimerKey(guid, spellID)
    return guid .. "_" .. spellID
end

-- ============================================================
-- Public API
-- ============================================================

function NovAuras.PvPTracker.HandleCast(unitOrGUID, spellID, useAsGUID)
    local entry = NovAuras.PvPSpellDB.Get(spellID)
    if not entry then return end

    -- Accept either a unit token or a pre-resolved GUID
    local guid
    if useAsGUID then
        guid = unitOrGUID
    else
        guid = GetGUID(unitOrGUID)
    end
    if not guid then return end

    local profile = GetOrCreateProfile(guid)
    local now = GetTime()
    local key = TimerKey(guid, spellID)

    -- Self-calibrate: if the spell fires while our timer still has time,
    -- the real cooldown is shorter — update the profile's learned duration.
    if timers[key] and now < timers[key].expiry then
        local realDuration = now - timers[key].startTime
        if realDuration < timers[key].duration then
            profile.cooldowns[spellID] = realDuration
        end
    end

    -- Spec inference from first spec-specific spell observed
    if not profile.spec then
        profile.spec = NovAuras.PvPSpellDB.SpecFromSpell(spellID)
    end

    local duration = profile.cooldowns[spellID]
        or NovAuras.PvPSpellDB.GetDuration(spellID, profile.spec)

    timers[key] = {
        spellID   = spellID,
        guid      = guid,
        startTime = now,
        duration  = duration,
        expiry    = now + duration,
        uncertain = false,
    }
end

-- Called when UNIT_AURA fires for a tracked enemy unit.
-- Marks all active timers for that unit as uncertain since aura state changed
-- but we can't read what changed (Secret Value).
function NovAuras.PvPTracker.HandleAuraChange(guid)
    local now = GetTime()
    for key, timer in pairs(timers) do
        if timer.guid == guid and now < timer.expiry then
            timer.uncertain = true
        end
    end
end

-- Wipe all data for a specific GUID (enemy left arena, new match, etc.)
function NovAuras.PvPTracker.ClearUnit(guid)
    profiles[guid] = nil
    for key, timer in pairs(timers) do
        if timer.guid == guid then
            timers[key] = nil
        end
    end
end

-- Wipe everything — called on zone change.
function NovAuras.PvPTracker.Reset()
    profiles = {}
    timers   = {}
end

function NovAuras.PvPTracker.GetTimer(unitOrGUID, spellID, useAsGUID)
    local guid
    if useAsGUID then
        guid = unitOrGUID
    else
        guid = GetGUID(unitOrGUID) or unitOrGUID
    end
    return timers[TimerKey(guid, spellID)]
end

function NovAuras.PvPTracker.GetProfile(unitOrGUID, useAsGUID)
    local guid
    if useAsGUID then
        guid = unitOrGUID
    else
        guid = GetGUID(unitOrGUID) or unitOrGUID
    end
    return profiles[guid]
end

function NovAuras.PvPTracker.GetAllTimers()
    return timers
end

-- ============================================================
-- Module lifecycle
-- ============================================================

function NovAuras.PvPTracker:Load()
    -- --------------------------------------------------------
    -- Event: enemy cast completed
    -- UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    -- Fires for arena1-5 unit tokens in Midnight.
    -- --------------------------------------------------------
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "UNIT_SPELLCAST_SUCCEEDED",
        function(unit, _, spellID)
            if not unit or IsSelf(unit) then return end
            if not IsEnemy(unit) then return end
            local guid = GetGUID(unit)
            if not guid then return end
            NovAuras.PvPTracker.HandleCast(guid, spellID, true)
        end
    )

    -- --------------------------------------------------------
    -- Event: enemy unit aura state changed
    -- UNIT_AURA(unit) fires in Midnight for arena units.
    -- Aura values are Secret Values — we only note that something changed.
    -- --------------------------------------------------------
    NovAuras.TriggerSystem.ListenForEvent("UNIT_AURA")
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "UNIT_AURA",
        function(unit)
            if not unit or IsSelf(unit) then return end
            if not IsEnemy(unit) then return end
            local guid = GetGUID(unit)
            if not guid then return end
            NovAuras.PvPTracker.HandleAuraChange(guid)
        end
    )

    -- --------------------------------------------------------
    -- Event: arena opponent slot updated (enemy joins/leaves)
    -- ARENA_OPPONENT_UPDATE(unit, updateReason)
    -- --------------------------------------------------------
    NovAuras.TriggerSystem.ListenForEvent("ARENA_OPPONENT_UPDATE")
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "ARENA_OPPONENT_UPDATE",
        function(unit, updateReason)
            if not unit then return end
            local guid = GetGUID(unit)
            if guid then
                NovAuras.PvPTracker.ClearUnit(guid)
            end
        end
    )

    -- --------------------------------------------------------
    -- Event: zone change — wipe stale data from previous match
    -- --------------------------------------------------------
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "PLAYER_ENTERING_WORLD",
        function()
            NovAuras.PvPTracker.Reset()
        end
    )

    -- --------------------------------------------------------
    -- Display frame (draggable, top-right)
    -- --------------------------------------------------------
    local displayFrame = CreateFrame("Frame", "NovAurasPvPFrame", UIParent)
    displayFrame:SetSize(200, 400)
    displayFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -200)
    displayFrame:SetMovable(true)
    displayFrame:EnableMouse(true)
    displayFrame:RegisterForDrag("LeftButton")
    displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
    displayFrame:SetScript("OnDragStop", displayFrame.StopMovingOrSizing)

    local iconPool = {}
    local function GetIcon()
        for _, icon in ipairs(iconPool) do
            if not icon:IsShown() then return icon end
        end
        local icon = NovAuras.DisplayEngine.NewIconRegion(displayFrame)
        icon:SetSize(32, 32)
        table.insert(iconPool, icon)
        return icon
    end

    -- Refresh at ~10 fps
    local refreshFrame = CreateFrame("Frame")
    refreshFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.1 then return end
        self.elapsed = 0

        for _, icon in ipairs(iconPool) do icon:Hide() end

        local now = GetTime()
        local yOffset = 0
        for _, timer in pairs(NovAuras.PvPTracker.GetAllTimers()) do
            if now < timer.expiry then
                local entry = NovAuras.PvPSpellDB.Get(timer.spellID)
                if entry then
                    local icon = GetIcon()
                    icon:SetPosition(0, yOffset)
                    icon:SetSpellTexture(entry.icon or 134400)
                    icon:SetTimer(timer.expiry)
                    -- Uncertain timers (aura state changed, may have expired early)
                    -- show at 50% alpha as a visual hint
                    icon.frame:SetAlpha(timer.uncertain and 0.5 or 1.0)
                    icon:Show()
                    yOffset = yOffset - 36
                end
            end
        end
    end)

    print("NovAuras: PvP Tracker loaded")
end

NovAuras:RegisterModule("PvPTracker", NovAuras.PvPTracker)
