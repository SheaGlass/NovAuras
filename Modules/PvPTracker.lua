-- Modules/PvPTracker.lua
-- Tracks enemy PvP cooldowns via inference (never reads Secret Values).
NovAuras = NovAuras or {}
NovAuras.PvPTracker = {}

local profiles = {}  -- [unitID] = { spec, cooldowns={[spellID]=duration} }
local timers   = {}  -- [unitID.."_"..spellID] = { expiry, startTime, duration, spellID, unitID }

local function GetOrCreateProfile(unitID)
    if not profiles[unitID] then
        profiles[unitID] = { spec = nil, cooldowns = {} }
    end
    return profiles[unitID]
end

function NovAuras.PvPTracker.HandleCast(unitID, spellID)
    local entry = NovAuras.PvPSpellDB.Get(spellID)
    if not entry then return end

    local profile = GetOrCreateProfile(unitID)
    local now = GetTime()
    local key = unitID .. "_" .. spellID

    -- Self-calibrate: if the spell fires while our timer still has time left,
    -- the real cooldown is shorter than we assumed — update it.
    if timers[key] and now < timers[key].expiry then
        local realDuration = now - timers[key].startTime
        if realDuration < timers[key].duration then
            profile.cooldowns[spellID] = realDuration
        end
    end

    -- Infer spec from the first spec-specific spell we see
    if not profile.spec then
        profile.spec = NovAuras.PvPSpellDB.SpecFromSpell(spellID)
    end

    -- Pick the best known duration (calibrated > spec-based > base)
    local duration = profile.cooldowns[spellID]
        or NovAuras.PvPSpellDB.GetDuration(spellID, profile.spec)

    timers[key] = {
        spellID   = spellID,
        unitID    = unitID,
        startTime = now,
        duration  = duration,
        expiry    = now + duration,
    }
end

function NovAuras.PvPTracker.GetTimer(unitID, spellID)
    return timers[unitID .. "_" .. spellID]
end

function NovAuras.PvPTracker.GetProfile(unitID)
    return profiles[unitID]
end

function NovAuras.PvPTracker.GetAllTimers()
    return timers
end

-- Module lifecycle — called by Init when entering PvP content
function NovAuras.PvPTracker:Load()
    -- Hook into TriggerSystem for enemy casts
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "UNIT_SPELLCAST_SUCCEEDED",
        function(unit, _, spellID)
            if unit and not UnitIsUnit(unit, "player") then
                local unitID = UnitGUID(unit) or unit
                NovAuras.PvPTracker.HandleCast(unitID, spellID)
            end
        end
    )

    -- Display frame (draggable, top-right)
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

    -- Refresh display at ~10 fps
    local refreshFrame = CreateFrame("Frame")
    refreshFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.1 then return end
        self.elapsed = 0

        for _, icon in ipairs(iconPool) do icon:Hide() end

        local now = GetTime()
        local yOffset = 0
        for key, timer in pairs(NovAuras.PvPTracker.GetAllTimers()) do
            if now < timer.expiry then
                local entry = NovAuras.PvPSpellDB.Get(timer.spellID)
                if entry then
                    local icon = GetIcon()
                    icon:SetPosition(0, yOffset)
                    icon:SetSpellTexture(entry.icon or 134400)
                    icon:SetTimer(timer.expiry)
                    icon:Show()
                    yOffset = yOffset - 36
                end
            end
        end
    end)

    print("NovAuras: PvP Tracker loaded")
end

NovAuras:RegisterModule("PvPTracker", NovAuras.PvPTracker)
