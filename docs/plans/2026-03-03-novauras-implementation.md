# NovAuras Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build NovAuras — a full-suite WoW Midnight (12.0) addon rebuilding WeakAuras with boss timers and PvP cooldown tracking.

**Architecture:** Single addon install, internally modular. Core always loads. BossTimers and PvPTracker lazy-load on PLAYER_ENTERING_WORLD based on content type. Secret Values compatibility layer wraps all combat API calls so auras degrade gracefully instead of erroring.

**Tech Stack:** Lua 5.1 (WoW), WoW 12.0 Addon API, AceGUI-3.0 (embedded), busted (Lua unit testing for pure logic), in-game /reload for WoW API testing.

---

## Testing Approach

Two testing modes used throughout:

**busted** — for pure logic (no WoW API). Install once:
```bash
luarocks install busted
```
Run: `busted tests/` from the `NovAuras/` directory.

**In-game** — for anything using WoW frames/events/API. Copy addon folder to:
`C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\NovAuras\`
Then `/reload` in-game. Check errors with `/novdebug`.

---

## Task 1: Project Scaffold

**Files:**
- Create: `NovAuras.toc`
- Create: `Core/Init.lua`
- Create: `Core/DisplayEngine.lua` (empty stub)
- Create: `Core/TriggerSystem.lua` (empty stub)
- Create: `Core/ConditionSystem.lua` (empty stub)
- Create: `Core/AnimationSystem.lua` (empty stub)
- Create: `Core/ConfigGUI.lua` (empty stub)
- Create: `Core/Transmission.lua` (empty stub)
- Create: `Modules/BossTimers.lua` (empty stub)
- Create: `Modules/PvPTracker.lua` (empty stub)
- Create: `Modules/PvPSpellDB.lua` (empty stub)
- Create: `tests/` (empty directory)

**Step 1: Create NovAuras.toc**

```toc
## Interface: 120100
## Title: NovAuras
## Notes: WeakAuras rebuilt for Midnight
## Version: 0.1.0
## Author: Shea
## DefaultState: enabled
## SavedVariables: NovAurasDB

# Libraries
Libs\AceGUI-3.0\AceGUI-3.0.xml

# Core (always loads)
Core\Init.lua
Core\DisplayEngine.lua
Core\TriggerSystem.lua
Core\ConditionSystem.lua
Core\AnimationSystem.lua
Core\ConfigGUI.lua
Core\Transmission.lua

# Modules (loaded on demand by Init.lua)
Modules\PvPSpellDB.lua
Modules\PvPTracker.lua
Modules\BossTimers.lua
```

**Step 2: Create Core/Init.lua**

```lua
NovAuras = NovAuras or {}
NovAuras.version = "0.1.0"
NovAuras.modules = {}

-- Register a module for lazy loading
function NovAuras:RegisterModule(name, module)
    self.modules[name] = module
end

-- Load modules based on content type
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, isLogin, isReload)
    local inInstance, instanceType = IsInInstance()

    if inInstance and (instanceType == "raid" or instanceType == "party") then
        if NovAuras.modules["BossTimers"] then
            NovAuras.modules["BossTimers"]:Load()
        end
    end

    local zone = C_PvP.GetZonePvpInfo and C_PvP.GetZonePvpInfo()
    if zone == "arena" or zone == "battleground" then
        if NovAuras.modules["PvPTracker"] then
            NovAuras.modules["PvPTracker"]:Load()
        end
    end
end)

-- Debug command
SLASH_NOVDEBUG1 = "/novdebug"
SlashCmdList["NOVDEBUG"] = function()
    print("NovAuras v" .. NovAuras.version .. " loaded.")
    print("Modules:", #NovAuras.modules)
end
```

**Step 3: Create stub files**

Each of the remaining Core/ and Modules/ files gets one line:
```lua
-- NovAuras: <filename> stub
```

**Step 4: Copy to WoW AddOns folder and /reload in-game**

Expected: No Lua errors. `/novdebug` prints version string.

**Step 5: Commit**

```bash
git add NovAuras.toc Core/ Modules/ tests/
git commit -m "feat: project scaffold and init module registry"
```

---

## Task 2: Secret Values Compatibility Layer

**Files:**
- Modify: `Core/Init.lua`
- Create: `tests/test_secrets.lua`

**Step 1: Write the failing test**

```lua
-- tests/test_secrets.lua
local NovAuras = { secrets = {} }
-- Mock: load only the SafeGetValue function
dofile("Core/Init.lua") -- will fail until function exists

describe("SafeGetValue", function()
    it("returns number values unchanged", function()
        assert.equals(42, NovAuras.SafeGetValue(42))
    end)

    it("returns string values unchanged", function()
        assert.equals("hello", NovAuras.SafeGetValue("hello"))
    end)

    it("returns nil for nil input", function()
        assert.is_nil(NovAuras.SafeGetValue(nil))
    end)

    it("returns nil for userdata (secret value)", function()
        local fakeSecret = newproxy(true)  -- userdata in Lua 5.1
        assert.is_nil(NovAuras.SafeGetValue(fakeSecret))
    end)
end)
```

**Step 2: Run to verify it fails**

```bash
busted tests/test_secrets.lua
```
Expected: FAIL — `SafeGetValue` not defined.

**Step 3: Add SafeGetValue to Core/Init.lua**

```lua
-- Add to NovAuras table in Init.lua:
function NovAuras.SafeGetValue(val)
    if type(val) == "userdata" then
        return nil
    end
    return val
end
```

**Step 4: Run test to verify it passes**

```bash
busted tests/test_secrets.lua
```
Expected: 4 tests PASS.

**Step 5: Commit**

```bash
git add Core/Init.lua tests/test_secrets.lua
git commit -m "feat: add SafeGetValue secret values compatibility layer"
```

---

## Task 3: Display Engine — Base Region

**Files:**
- Modify: `Core/DisplayEngine.lua`
- Create: `tests/test_display.lua`

**Step 1: Write failing test**

```lua
-- tests/test_display.lua
-- Mock WoW CreateFrame for unit testing
CreateFrame = function(frameType, name, parent)
    return {
        frameType = frameType,
        shown = false,
        x = 0, y = 0,
        width = 0, height = 0,
        SetPoint = function(self, ...) end,
        SetSize = function(self, w, h) self.width=w; self.height=h end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        IsShown = function(self) return self.shown end,
    }
end

dofile("Core/DisplayEngine.lua")

describe("BaseRegion", function()
    it("creates with default properties", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        assert.equals("Icon", r.regionType)
        assert.is_false(r:IsShown())
    end)

    it("can be shown and hidden", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        r:Show()
        assert.is_true(r:IsShown())
        r:Hide()
        assert.is_false(r:IsShown())
    end)
end)
```

**Step 2: Run to verify it fails**

```bash
busted tests/test_display.lua
```

**Step 3: Implement base region in Core/DisplayEngine.lua**

```lua
NovAuras = NovAuras or {}
NovAuras.DisplayEngine = {}

local BaseRegion = {}
BaseRegion.__index = BaseRegion

function NovAuras.DisplayEngine.NewRegion(regionType, parent)
    local frame = CreateFrame("Frame", nil, parent or UIParent)
    local region = setmetatable({}, BaseRegion)
    region.frame = frame
    region.regionType = regionType
    region.data = {}
    return region
end

function BaseRegion:Show()
    self.frame:Show()
end

function BaseRegion:Hide()
    self.frame:Hide()
end

function BaseRegion:IsShown()
    return self.frame:IsShown()
end

function BaseRegion:SetSize(w, h)
    self.frame:SetSize(w, h)
end

function BaseRegion:SetPosition(x, y)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end
```

**Step 4: Run tests**

```bash
busted tests/test_display.lua
```
Expected: PASS.

**Step 5: Commit**

```bash
git add Core/DisplayEngine.lua tests/test_display.lua
git commit -m "feat: add base region to display engine"
```

---

## Task 4: Display Engine — Icon Region

**Files:**
- Modify: `Core/DisplayEngine.lua`

**Step 1: Add mock texture to test helper**

Add to `tests/test_display.lua` CreateFrame mock — update SetTexture mock:
```lua
CreateFrame = function(frameType, name, parent)
    local f = { ... } -- existing mock
    f.CreateTexture = function(self)
        return {
            texture = nil,
            SetTexture = function(self, t) self.texture = t end,
            SetAllPoints = function(self) end,
            SetVertexColor = function(self, r,g,b,a) end,
        }
    end
    f.CreateFontString = function(self)
        return {
            text = "",
            SetText = function(self, t) self.text = t end,
            SetPoint = function(self, ...) end,
            SetFont = function(self, ...) end,
        }
    end
    return f
end
```

**Step 2: Write failing test for Icon region**

```lua
describe("IconRegion", function()
    it("sets spell texture", function()
        local icon = NovAuras.DisplayEngine.NewIconRegion()
        icon:SetSpellTexture(136243) -- spell icon ID
        assert.equals(136243, icon.texture:GetTexture())
    end)

    it("sets stack count text", function()
        local icon = NovAuras.DisplayEngine.NewIconRegion()
        icon:SetStacks(5)
        assert.equals("5", icon.stackText.text)
    end)
end)
```

**Step 3: Run to verify fails**

```bash
busted tests/test_display.lua
```

**Step 4: Implement IconRegion**

```lua
-- Add to Core/DisplayEngine.lua

local IconRegion = setmetatable({}, { __index = BaseRegion })
IconRegion.__index = IconRegion

function NovAuras.DisplayEngine.NewIconRegion(parent)
    local region = NovAuras.DisplayEngine.NewRegion("Icon", parent)
    setmetatable(region, IconRegion)

    region.texture = region.frame:CreateTexture(nil, "BACKGROUND")
    region.texture:SetAllPoints()

    region.stackText = region.frame:CreateFontString(nil, "OVERLAY")
    region.stackText:SetPoint("BOTTOMRIGHT", region.frame, "BOTTOMRIGHT", -2, 2)
    region.stackText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    region.timerText = region.frame:CreateFontString(nil, "OVERLAY")
    region.timerText:SetPoint("CENTER", region.frame, "CENTER", 0, 0)
    region.timerText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

    return region
end

function IconRegion:SetSpellTexture(textureID)
    self.texture:SetTexture(textureID)
end

function IconRegion:SetStacks(count)
    if count and count > 1 then
        self.stackText:SetText(tostring(count))
    else
        self.stackText:SetText("")
    end
end

function IconRegion:SetTimer(expiry)
    local remaining = expiry - GetTime()
    if remaining > 0 then
        self.timerText:SetText(string.format("%.1f", remaining))
    else
        self.timerText:SetText("")
    end
end
```

**Step 5: Run tests**

```bash
busted tests/test_display.lua
```
Expected: PASS.

**Step 6: In-game test**

Add to Init.lua temporarily:
```lua
-- Quick smoke test — remove after verifying
C_Timer.After(2, function()
    local icon = NovAuras.DisplayEngine.NewIconRegion()
    icon:SetSize(64, 64)
    icon:SetPosition(0, 200)
    icon:SetSpellTexture(136243)
    icon:SetStacks(3)
    icon:Show()
end)
```
/reload — should see an icon appear on screen.

**Step 7: Remove smoke test, commit**

```bash
git add Core/DisplayEngine.lua tests/test_display.lua
git commit -m "feat: add icon region with texture, stacks, timer text"
```

---

## Task 5: Display Engine — Bar Region

**Files:**
- Modify: `Core/DisplayEngine.lua`
- Modify: `tests/test_display.lua`

**Step 1: Write failing test**

```lua
describe("BarRegion", function()
    it("sets fill percentage", function()
        local bar = NovAuras.DisplayEngine.NewBarRegion()
        bar:SetValue(0.75)
        assert.equals(0.75, bar.fill)
    end)

    it("clamps value between 0 and 1", function()
        local bar = NovAuras.DisplayEngine.NewBarRegion()
        bar:SetValue(1.5)
        assert.equals(1.0, bar.fill)
        bar:SetValue(-0.5)
        assert.equals(0.0, bar.fill)
    end)
end)
```

**Step 2: Implement BarRegion**

```lua
local BarRegion = setmetatable({}, { __index = BaseRegion })
BarRegion.__index = BarRegion

function NovAuras.DisplayEngine.NewBarRegion(parent)
    local region = NovAuras.DisplayEngine.NewRegion("Bar", parent)
    setmetatable(region, BarRegion)
    region.fill = 0

    region.bg = region.frame:CreateTexture(nil, "BACKGROUND")
    region.bg:SetAllPoints()
    region.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    region.bar = region.frame:CreateTexture(nil, "BORDER")
    region.bar:SetPoint("LEFT", region.frame, "LEFT", 0, 0)

    region.label = region.frame:CreateFontString(nil, "OVERLAY")
    region.label:SetPoint("LEFT", region.frame, "LEFT", 4, 0)
    region.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

    region.timerText = region.frame:CreateFontString(nil, "OVERLAY")
    region.timerText:SetPoint("RIGHT", region.frame, "RIGHT", -4, 0)
    region.timerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")

    return region
end

function BarRegion:SetValue(pct)
    self.fill = math.max(0, math.min(1, pct))
    local w = self.frame:GetWidth() * self.fill
    self.bar:SetWidth(math.max(1, w))
end

function BarRegion:SetLabel(text)
    self.label:SetText(text or "")
end

function BarRegion:SetColor(r, g, b, a)
    self.bar:SetColorTexture(r, g, b, a or 1)
end
```

**Step 3: Run tests, commit**

```bash
busted tests/test_display.lua
git add Core/DisplayEngine.lua
git commit -m "feat: add bar region with fill, label, color"
```

---

## Task 6: Display Engine — Text & Progress Regions

**Files:**
- Modify: `Core/DisplayEngine.lua`

**Step 1: Add TextRegion**

```lua
local TextRegion = setmetatable({}, { __index = BaseRegion })
TextRegion.__index = TextRegion

function NovAuras.DisplayEngine.NewTextRegion(parent)
    local region = NovAuras.DisplayEngine.NewRegion("Text", parent)
    setmetatable(region, TextRegion)

    region.text = region.frame:CreateFontString(nil, "OVERLAY")
    region.text:SetAllPoints()
    region.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    return region
end

function TextRegion:SetText(str)
    self.text:SetText(str or "")
end

function TextRegion:SetFontSize(size)
    self.text:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
end
```

**Step 2: Add ProgressRegion (circular)**

```lua
local ProgressRegion = setmetatable({}, { __index = BaseRegion })
ProgressRegion.__index = ProgressRegion

function NovAuras.DisplayEngine.NewProgressRegion(parent)
    local region = NovAuras.DisplayEngine.NewRegion("Progress", parent)
    setmetatable(region, ProgressRegion)
    -- Uses CooldownFrame for circular sweep
    region.cooldown = CreateFrame("Cooldown", nil, region.frame, "CooldownFrameTemplate")
    region.cooldown:SetAllPoints()
    return region
end

function ProgressRegion:SetCooldown(start, duration)
    self.cooldown:SetCooldown(start, duration)
end
```

**Step 3: Commit**

```bash
git add Core/DisplayEngine.lua
git commit -m "feat: add text and progress (circular) regions"
```

---

## Task 7: Trigger System — Event Triggers

**Files:**
- Modify: `Core/TriggerSystem.lua`
- Create: `tests/test_triggers.lua`

**Step 1: Write failing test**

```lua
-- tests/test_triggers.lua
-- Mock WoW event system
local eventHandlers = {}
CreateFrame = function()
    return {
        RegisterEvent = function(self, event) eventHandlers[event] = true end,
        SetScript = function(self, _, fn) self._fn = fn end,
    }
end

dofile("Core/Init.lua")
dofile("Core/TriggerSystem.lua")

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
end)
```

**Step 2: Run to verify fails**

```bash
busted tests/test_triggers.lua
```

**Step 3: Implement TriggerSystem**

```lua
-- Core/TriggerSystem.lua
NovAuras = NovAuras or {}
NovAuras.TriggerSystem = {}

local eventCallbacks = {}
local statusTickers = {}

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
```

**Step 4: Run tests**

```bash
busted tests/test_triggers.lua
```
Expected: PASS.

**Step 5: Commit**

```bash
git add Core/TriggerSystem.lua tests/test_triggers.lua
git commit -m "feat: add event trigger system with pcall safety"
```

---

## Task 8: Trigger System — Status & Custom Lua Triggers

**Files:**
- Modify: `Core/TriggerSystem.lua`
- Modify: `tests/test_triggers.lua`

**Step 1: Write failing tests**

```lua
describe("StatusTrigger", function()
    it("polls a function on interval", function()
        local callCount = 0
        NovAuras.TriggerSystem.RegisterStatusTrigger("test", function()
            callCount = callCount + 1
            return callCount > 2
        end, 0.1)
        -- Simulate 3 ticks
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
        assert.is_true(state.show)
        assert.equals(42, state.value)
    end)

    it("returns nil on Lua error without crashing", function()
        local state = NovAuras.TriggerSystem.RunCustomTrigger(
            "this is not valid lua @@",
            {}
        )
        assert.is_nil(state)
    end)
end)
```

**Step 2: Implement**

```lua
-- Add to Core/TriggerSystem.lua

local statusTriggers = {}

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

-- Ticker frame
local tickFrame = CreateFrame("Frame")
tickFrame:SetScript("OnUpdate", function(self, elapsed)
    NovAuras.TriggerSystem.TickAll(elapsed)
end)

-- Custom Lua trigger: run user code in sandboxed environment
function NovAuras.TriggerSystem.RunCustomTrigger(code, state)
    local fn, err = loadstring("local state = ...; " .. code)
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
```

**Step 3: Run tests, commit**

```bash
busted tests/test_triggers.lua
git add Core/TriggerSystem.lua
git commit -m "feat: add status polling and custom lua trigger support"
```

---

## Task 9: Condition System

**Files:**
- Modify: `Core/ConditionSystem.lua`
- Create: `tests/test_conditions.lua`

**Step 1: Write failing tests**

```lua
-- tests/test_conditions.lua
dofile("Core/Init.lua")
dofile("Core/ConditionSystem.lua")

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
end)
```

**Step 2: Implement**

```lua
-- Core/ConditionSystem.lua
NovAuras = NovAuras or {}
NovAuras.ConditionSystem = {}

local function EvalOne(cond)
    if cond.type == "zone" then
        return cond.current == cond.zone
    elseif cond.type == "health" then
        local val = NovAuras.SafeGetValue(cond.current)
        if val == nil then return false end
        if cond.op == "lt" then return val < cond.threshold end
        if cond.op == "gt" then return val > cond.threshold end
        if cond.op == "eq" then return val == cond.threshold end
    elseif cond.type == "custom" then
        local ok, result = pcall(cond.fn)
        return ok and result
    end
    return false
end

function NovAuras.ConditionSystem.Evaluate(logic, conditions)
    if not conditions or #conditions == 0 then return true end
    if logic == "AND" then
        for _, cond in ipairs(conditions) do
            if not EvalOne(cond) then return false end
        end
        return true
    elseif logic == "OR" then
        for _, cond in ipairs(conditions) do
            if EvalOne(cond) then return true end
        end
        return false
    end
    return false
end
```

**Step 3: Run tests, commit**

```bash
busted tests/test_conditions.lua
git add Core/ConditionSystem.lua tests/test_conditions.lua
git commit -m "feat: add AND/OR condition evaluation system"
```

---

## Task 10: Animation System

**Files:**
- Modify: `Core/AnimationSystem.lua`

**Step 1: Implement**

Animations use WoW's native `AnimationGroup` API — no unit tests needed (WoW API only).

```lua
-- Core/AnimationSystem.lua
NovAuras = NovAuras or {}
NovAuras.AnimationSystem = {}

-- Create a fade-in animation on a frame
function NovAuras.AnimationSystem.FadeIn(frame, duration)
    duration = duration or 0.3
    local ag = frame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(duration)
    ag:Play()
    return ag
end

-- Create a fade-out animation on a frame
function NovAuras.AnimationSystem.FadeOut(frame, duration, callback)
    duration = duration or 0.3
    local ag = frame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(duration)
    if callback then
        ag:SetScript("OnFinished", callback)
    end
    ag:Play()
    return ag
end

-- Scale pulse (entry animation)
function NovAuras.AnimationSystem.Pulse(frame, duration)
    duration = duration or 0.2
    local ag = frame:CreateAnimationGroup()
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetScale(1.3, 1.3)
    scaleUp:SetDuration(duration / 2)
    scaleUp:SetOrder(1)
    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetScale(1/1.3, 1/1.3)
    scaleDown:SetDuration(duration / 2)
    scaleDown:SetOrder(2)
    ag:Play()
    return ag
end
```

**Step 2: In-game test**

Temporarily add to Init.lua:
```lua
C_Timer.After(1, function()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(64, 64)
    f:SetPoint("CENTER")
    local tex = f:CreateTexture()
    tex:SetAllPoints()
    tex:SetColorTexture(1, 0, 0, 1)
    f:Show()
    NovAuras.AnimationSystem.Pulse(f, 0.4)
end)
```
/reload — should see a red square pulse at screen centre.

**Step 3: Remove test code, commit**

```bash
git add Core/AnimationSystem.lua
git commit -m "feat: add fade and pulse animation helpers"
```

---

## Task 11: PvP Spell Database

**Files:**
- Modify: `Modules/PvPSpellDB.lua`
- Create: `tests/test_spelldb.lua`

**Step 1: Write failing test**

```lua
-- tests/test_spelldb.lua
dofile("Core/Init.lua")
dofile("Modules/PvPSpellDB.lua")

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

    it("infers spec from spell cast", function()
        local spec = NovAuras.PvPSpellDB.SpecFromSpell(190319) -- Combustion
        assert.equals("Fire", spec)
    end)
end)
```

**Step 2: Build the database**

```lua
-- Modules/PvPSpellDB.lua
NovAuras = NovAuras or {}
NovAuras.PvPSpellDB = {}

local DB = {
    -- ===== MAGE =====
    [190319] = { name="Combustion",       class="MAGE",    spec="Fire",    duration=120, category="OFFENSIVE" },
    [45438]  = { name="Ice Block",        class="MAGE",    spec="Frost",   duration=240, category="DEFENSIVE" },
    [12042]  = { name="Arcane Power",     class="MAGE",    spec="Arcane",  duration=90,  category="OFFENSIVE" },
    [2139]   = { name="Counterspell",     class="MAGE",    spec="ALL",     duration=24,  category="INTERRUPT" },
    [66]     = { name="Invisibility",     class="MAGE",    spec="ALL",     duration=300, category="DEFENSIVE" },

    -- ===== WARRIOR =====
    [871]    = { name="Shield Wall",      class="WARRIOR", spec="Prot",    duration=240, category="DEFENSIVE" },
    [1719]   = { name="Recklessness",     class="WARRIOR", spec="Arms",    duration=90,  category="OFFENSIVE" },
    [6552]   = { name="Pummel",           class="WARRIOR", spec="ALL",     duration=15,  category="INTERRUPT" },
    [12292]  = { name="Bloodbath",        class="WARRIOR", spec="Arms",    duration=60,  category="OFFENSIVE" },

    -- ===== ROGUE =====
    [1766]   = { name="Kick",            class="ROGUE",   spec="ALL",     duration=15,  category="INTERRUPT" },
    [2094]   = { name="Blind",           class="ROGUE",   spec="ALL",     duration=120, category="CC"        },
    [31224]  = { name="Cloak of Shadows",class="ROGUE",   spec="ALL",     duration=60,  category="DEFENSIVE" },
    [13750]  = { name="Adrenaline Rush", class="ROGUE",   spec="Outlaw",  duration=120, category="OFFENSIVE" },

    -- ===== PALADIN =====
    [642]    = { name="Divine Shield",   class="PALADIN", spec="ALL",     duration=300, category="DEFENSIVE" },
    [498]    = { name="Divine Protection",class="PALADIN",spec="ALL",     duration=120, category="DEFENSIVE" },
    [96231]  = { name="Rebuke",          class="PALADIN", spec="ALL",     duration=15,  category="INTERRUPT" },
    [31884]  = { name="Avenging Wrath",  class="PALADIN", spec="Ret",     duration=120, category="OFFENSIVE" },

    -- ===== PRIEST =====
    [8122]   = { name="Psychic Scream",  class="PRIEST",  spec="ALL",     duration=45,  category="CC"        },
    [47585]  = { name="Dispersion",      class="PRIEST",  spec="Shadow",  duration=120, category="DEFENSIVE" },
    [10060]  = { name="Power Infusion",  class="PRIEST",  spec="ALL",     duration=120, category="OFFENSIVE" },

    -- ===== DRUID =====
    [22812]  = { name="Barkskin",        class="DRUID",   spec="ALL",     duration=60,  category="DEFENSIVE" },
    [106951] = { name="Berserk",         class="DRUID",   spec="Feral",   duration=180, category="OFFENSIVE" },
    [78675]  = { name="Solar Beam",      class="DRUID",   spec="Balance", duration=60,  category="INTERRUPT" },

    -- ===== HUNTER =====
    [19574]  = { name="Bestial Wrath",   class="HUNTER",  spec="BM",      duration=90,  category="OFFENSIVE" },
    [147362] = { name="Counter Shot",    class="HUNTER",  spec="MM",      duration=24,  category="INTERRUPT" },
    [187707] = { name="Muzzle",          class="HUNTER",  spec="SV",      duration=15,  category="INTERRUPT" },

    -- ===== SHAMAN =====
    [108271] = { name="Astral Shift",    class="SHAMAN",  spec="ALL",     duration=120, category="DEFENSIVE" },
    [51514]  = { name="Hex",             class="SHAMAN",  spec="ALL",     duration=30,  category="CC"        },
    [57994]  = { name="Wind Shear",      class="SHAMAN",  spec="ALL",     duration=12,  category="INTERRUPT" },

    -- ===== WARLOCK =====
    [104773] = { name="Unending Resolve",class="WARLOCK", spec="ALL",     duration=180, category="DEFENSIVE" },
    [118699] = { name="Mortal Coil",     class="WARLOCK", spec="ALL",     duration=45,  category="CC"        },
    [19647]  = { name="Spell Lock",      class="WARLOCK", spec="ALL",     duration=24,  category="INTERRUPT" },

    -- ===== DEATH KNIGHT =====
    [48792]  = { name="Icebound Fortitude",class="DEATHKNIGHT",spec="ALL",duration=180,category="DEFENSIVE" },
    [47528]  = { name="Mind Freeze",     class="DEATHKNIGHT",spec="ALL",  duration=15,  category="INTERRUPT" },

    -- ===== DEMON HUNTER =====
    [196555] = { name="Netherwalk",      class="DEMONHUNTER",spec="Havoc",duration=180, category="DEFENSIVE" },
    [183752] = { name="Consume Magic",   class="DEMONHUNTER",spec="ALL",  duration=10,  category="INTERRUPT" },
    [191427] = { name="Metamorphosis",   class="DEMONHUNTER",spec="Havoc",duration=240, category="OFFENSIVE" },

    -- ===== EVOKER =====
    [357214] = { name="Time Spiral",     class="EVOKER",  spec="ALL",     duration=120, category="DEFENSIVE" },
    [351338] = { name="Quell",           class="EVOKER",  spec="ALL",     duration=20,  category="INTERRUPT" },

    -- ===== MONK =====
    [122783] = { name="Diffuse Magic",   class="MONK",    spec="ALL",     duration=90,  category="DEFENSIVE" },
    [116705] = { name="Spear Hand Strike",class="MONK",   spec="ALL",     duration=15,  category="INTERRUPT" },
    [137639] = { name="Storm, Earth & Fire",class="MONK", spec="WW",      duration=90,  category="OFFENSIVE" },

    -- ===== TRINKETS (PvP) =====
    [336126] = { name="Gladiator's Medallion", class="ALL", spec="ALL",   duration=120, category="TRINKET"   },
    [195710] = { name="Adaptation",            class="ALL", spec="ALL",   duration=60,  category="TRINKET"   },
    [208683] = { name="Gladiator's Insignia",  class="ALL", spec="ALL",   duration=120, category="TRINKET"   },

    -- ===== RACIALS =====
    [20549]  = { name="War Stomp",       class="ALL", spec="ALL", duration=90,  category="RACIAL" },
    [7744]   = { name="Will to Survive", class="ALL", spec="ALL", duration=180, category="RACIAL" },
    [20594]  = { name="Stoneform",       class="ALL", spec="ALL", duration=120, category="RACIAL" },
    [58984]  = { name="Shadowmeld",      class="ALL", spec="ALL", duration=120, category="RACIAL" },
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

-- Get best duration estimate for a spellID given known spec (or nil)
function NovAuras.PvPSpellDB.GetDuration(spellID, spec)
    local entry = DB[spellID]
    if not entry then return nil end

    local variants = SpecVariants[spellID]
    if variants and spec and variants[spec] then
        -- Default to shortest (safest assumption)
        return variants[spec].withTalent
    end

    return entry.duration
end
```

**Step 3: Run tests, commit**

```bash
busted tests/test_spelldb.lua
git add Modules/PvPSpellDB.lua tests/test_spelldb.lua
git commit -m "feat: add PvP spell database covering all classes, trinkets, racials"
```

---

## Task 12: PvP Tracker Module

**Files:**
- Modify: `Modules/PvPTracker.lua`
- Create: `tests/test_pvptracker.lua`

**Step 1: Write failing tests**

```lua
-- tests/test_pvptracker.lua
-- Mock WoW APIs
GetTime = function() return 100 end
C_Timer = { After = function(t, fn) fn() end }
CreateFrame = function() return {
    RegisterEvent = function() end,
    SetScript = function() end,
} end

dofile("Core/Init.lua")
dofile("Modules/PvPSpellDB.lua")
dofile("Modules/PvPTracker.lua")

describe("PvPTracker", function()
    it("tracks a cast and starts a timer", function()
        NovAuras.PvPTracker.HandleCast("enemy-realm", 190319) -- Combustion
        local timer = NovAuras.PvPTracker.GetTimer("enemy-realm", 190319)
        assert.is_not_nil(timer)
        assert.equals(100 + 120, timer.expiry) -- GetTime() + duration
    end)

    it("detects spec from first cast", function()
        NovAuras.PvPTracker.HandleCast("mage-realm", 190319) -- Combustion = Fire
        local profile = NovAuras.PvPTracker.GetProfile("mage-realm")
        assert.equals("Fire", profile.spec)
    end)

    it("self-calibrates if ability fires early", function()
        NovAuras.PvPTracker.HandleCast("rogue-realm", 1766) -- Kick, assume 15s
        -- Fire again after only 12s (talent reduced)
        GetTime = function() return 112 end
        NovAuras.PvPTracker.HandleCast("rogue-realm", 1766)
        local profile = NovAuras.PvPTracker.GetProfile("rogue-realm")
        assert.equals(12, profile.cooldowns[1766])
    end)
end)
```

**Step 2: Implement**

```lua
-- Modules/PvPTracker.lua
NovAuras = NovAuras or {}
NovAuras.PvPTracker = {}

local profiles = {}  -- [unitID] = { spec, cooldowns={[spellID]=duration} }
local timers = {}    -- [unitID..spellID] = { expiry }

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

    -- Self-calibrate: if timer exists and hasn't expired, update real duration
    if timers[key] and now < timers[key].expiry then
        local realDuration = now - timers[key].startTime
        if realDuration < timers[key].duration then
            profile.cooldowns[spellID] = realDuration
        end
    end

    -- Detect spec from this spell
    if not profile.spec then
        profile.spec = NovAuras.PvPSpellDB.SpecFromSpell(spellID)
    end

    -- Get best duration estimate
    local duration = profile.cooldowns[spellID]
        or NovAuras.PvPSpellDB.GetDuration(spellID, profile.spec)

    -- Start timer
    timers[key] = {
        spellID = spellID,
        unitID = unitID,
        startTime = now,
        duration = duration,
        expiry = now + duration,
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

-- Module lifecycle
function NovAuras.PvPTracker:Load()
    -- Listen for enemy casts
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "UNIT_SPELLCAST_SUCCEEDED",
        function(unit, _, spellID)
            -- Only track enemy units (not self/party)
            if unit and not UnitIsUnit(unit, "player") then
                local unitID = UnitGUID(unit) or unit
                NovAuras.PvPTracker.HandleCast(unitID, spellID)
            end
        end
    )
    print("NovAuras: PvP Tracker loaded")
end

NovAuras:RegisterModule("PvPTracker", NovAuras.PvPTracker)
```

**Step 3: Run tests, commit**

```bash
busted tests/test_pvptracker.lua
git add Modules/PvPTracker.lua tests/test_pvptracker.lua
git commit -m "feat: add PvP cooldown tracker with spec inference and self-calibration"
```

---

## Task 13: PvP Tracker Display

**Files:**
- Modify: `Modules/PvPTracker.lua`

**Step 1: Add display frame to PvPTracker**

```lua
-- Add to PvPTracker.lua, inside Load():

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

-- Refresh display every 0.1s
local refreshFrame = CreateFrame("Frame")
refreshFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.1 then return end
    self.elapsed = 0

    -- Hide all pooled icons
    for _, icon in ipairs(iconPool) do icon:Hide() end

    local now = GetTime()
    local yOffset = 0
    -- Sort by enemy unit, then category
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
```

**Step 2: In-game test**

/reload in an arena or use `/run` to fire fake casts:
```
/run NovAuras.PvPTracker.HandleCast("test", 190319)
```
Expected: Combustion icon appears top-right with countdown.

**Step 3: Commit**

```bash
git add Modules/PvPTracker.lua
git commit -m "feat: add PvP tracker display frame with icon pool"
```

---

## Task 14: Boss Timers Module

**Files:**
- Modify: `Modules/BossTimers.lua`

**Step 1: Implement using C_EncounterEvents**

```lua
-- Modules/BossTimers.lua
NovAuras = NovAuras or {}
NovAuras.BossTimers = {}

function NovAuras.BossTimers:Load()
    -- Main timeline frame
    local frame = CreateFrame("Frame", "NovAurasBossFrame", UIParent)
    frame:SetSize(300, 30)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local bars = {}

    local function RefreshTimeline(encounterID)
        -- Clear old bars
        for _, bar in ipairs(bars) do bar:Hide() end
        bars = {}

        local eventList = C_EncounterTimeline.GetSortedEventList(encounterID)
        if not eventList then return end

        for i, event in ipairs(eventList) do
            if i > 8 then break end -- Show next 8 events max
            local bar = NovAuras.DisplayEngine.NewBarRegion(frame)
            bar:SetSize(280, 22)
            bar:SetPosition(0, -(i-1) * 26)
            local info = C_EncounterEvents.GetEventInfo(event.eventID)
            if info then
                bar:SetLabel(info.name or "Unknown")
                bar:SetColor(info.r or 1, info.g or 0.5, info.b or 0, 1)
            end
            bar:Show()
            table.insert(bars, bar)
        end
    end

    -- Listen for encounter start
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "ENCOUNTER_START",
        function(encounterID, encounterName, difficultyID, groupSize)
            frame:Show()
            RefreshTimeline(encounterID)
        end
    )

    NovAuras.TriggerSystem.RegisterEventTrigger(
        "ENCOUNTER_END",
        function()
            frame:Hide()
            for _, bar in ipairs(bars) do bar:Hide() end
        end
    )

    -- Warning alerts
    NovAuras.TriggerSystem.RegisterEventTrigger(
        "ENCOUNTER_TIMELINE_VIEW_ACTIVATED",
        function()
            C_EncounterWarnings.SetWarningsShown(true)
        end
    )

    -- Update bar progress every tick
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        -- Timer text update per bar handled by SetTimer on each bar
    end)

    print("NovAuras: Boss Timers loaded")
end

NovAuras:RegisterModule("BossTimers", NovAuras.BossTimers)
```

**Step 2: In-game test**

Enter a raid/dungeon, /reload. Pull a boss.
Expected: Timeline bars appear at top of screen, labelled with boss ability names.

**Step 3: Commit**

```bash
git add Modules/BossTimers.lua
git commit -m "feat: add boss timers module using C_EncounterEvents"
```

---

## Task 15: Config GUI — AceGUI Setup

**Files:**
- Create: `Libs/AceGUI-3.0/` (download from CurseForge/WoWAce)
- Modify: `Core/ConfigGUI.lua`

**Step 1: Download AceGUI-3.0**

Get the latest AceGUI-3.0 from https://www.wowace.com/projects/ace3
Extract into `Libs/AceGUI-3.0/`
It includes its own `.xml` file — already referenced in .toc.

**Step 2: Basic config window**

```lua
-- Core/ConfigGUI.lua
NovAuras = NovAuras or {}
NovAuras.ConfigGUI = {}

local AceGUI = LibStub("AceGUI-3.0")

function NovAuras.ConfigGUI.Open()
    if NovAuras.ConfigGUI._frame then
        NovAuras.ConfigGUI._frame:Show()
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("NovAuras")
    frame:SetStatusText("v" .. NovAuras.version)
    frame:SetLayout("Flow")
    frame:SetWidth(700)
    frame:SetHeight(500)
    NovAuras.ConfigGUI._frame = frame

    -- Tab group: Auras | Boss Timers | PvP Tracker | Options
    local tabs = AceGUI:Create("TabGroup")
    tabs:SetLayout("Flow")
    tabs:SetTabs({
        { text = "Auras",       value = "auras"   },
        { text = "Boss Timers", value = "boss"    },
        { text = "PvP Tracker", value = "pvp"     },
        { text = "Options",     value = "options" },
    })
    tabs:SetCallback("OnGroupSelected", function(container, event, tab)
        container:ReleaseChildren()
        NovAuras.ConfigGUI.DrawTab(container, tab)
    end)
    tabs:SelectTab("auras")
    frame:AddChild(tabs)
end

function NovAuras.ConfigGUI.DrawTab(container, tab)
    if tab == "auras"   then NovAuras.ConfigGUI.DrawAurasTab(container) end
    if tab == "boss"    then NovAuras.ConfigGUI.DrawBossTab(container) end
    if tab == "pvp"     then NovAuras.ConfigGUI.DrawPvPTab(container) end
    if tab == "options" then NovAuras.ConfigGUI.DrawOptionsTab(container) end
end

-- Slash command to open
SLASH_NOVAURAS1 = "/nv"
SLASH_NOVAURAS2 = "/novauras"
SlashCmdList["NOVAURAS"] = function(msg)
    if msg == "" then
        NovAuras.ConfigGUI.Open()
    end
end
```

**Step 3: In-game test**

/reload, then `/nv` — config window should open with 4 tabs.

**Step 4: Commit**

```bash
git add Libs/ Core/ConfigGUI.lua
git commit -m "feat: add config GUI with AceGUI tab framework"
```

---

## Task 16: Config GUI — Auras Tab (Simple Mode)

**Files:**
- Modify: `Core/ConfigGUI.lua`

**Step 1: Implement DrawAurasTab**

```lua
function NovAuras.ConfigGUI.DrawAurasTab(container)
    -- Left: aura list
    local list = AceGUI:Create("ScrollFrame")
    list:SetLayout("List")
    list:SetWidth(200)
    list:SetFullHeight(true)
    container:AddChild(list)

    -- Right: aura editor
    local editor = AceGUI:Create("SimpleGroup")
    editor:SetLayout("Flow")
    editor:SetFullWidth(true)
    editor:SetFullHeight(true)
    container:AddChild(editor)

    -- Region type picker
    local regionPicker = AceGUI:Create("Dropdown")
    regionPicker:SetLabel("Region Type")
    regionPicker:SetList({ Icon="Icon", Bar="Bar", Text="Text", Progress="Progress" })
    regionPicker:SetValue("Icon")
    editor:AddChild(regionPicker)

    -- Trigger type picker
    local triggerPicker = AceGUI:Create("Dropdown")
    triggerPicker:SetLabel("Trigger")
    triggerPicker:SetList({ Aura="Aura", Cooldown="Cooldown", Custom="Custom Lua" })
    triggerPicker:SetValue("Aura")
    editor:AddChild(triggerPicker)

    -- Aura name field
    local auraName = AceGUI:Create("EditBox")
    auraName:SetLabel("Aura / Spell Name")
    auraName:SetWidth(200)
    editor:AddChild(auraName)

    -- Unit picker
    local unitPicker = AceGUI:Create("Dropdown")
    unitPicker:SetLabel("Unit")
    unitPicker:SetList({ player="Player", target="Target", focus="Focus" })
    unitPicker:SetValue("player")
    editor:AddChild(unitPicker)

    -- Advanced mode toggle
    local advToggle = AceGUI:Create("CheckBox")
    advToggle:SetLabel("Advanced (Custom Lua)")
    advToggle:SetCallback("OnValueChanged", function(widget, event, val)
        NovAuras.ConfigGUI.ToggleAdvancedMode(editor, val)
    end)
    editor:AddChild(advToggle)
end

function NovAuras.ConfigGUI.ToggleAdvancedMode(editor, enabled)
    editor:ReleaseChildren()
    if enabled then
        NovAuras.ConfigGUI.DrawAdvancedEditor(editor)
    else
        NovAuras.ConfigGUI.DrawSimpleEditor(editor)
    end
end

function NovAuras.ConfigGUI.DrawAdvancedEditor(container)
    local label = AceGUI:Create("Label")
    label:SetText("Custom Trigger Function:")
    container:AddChild(label)

    local codeBox = AceGUI:Create("MultiLineEditBox")
    codeBox:SetLabel("Lua")
    codeBox:SetFullWidth(true)
    codeBox:SetNumLines(12)
    codeBox:SetText(
        "-- state.show = true to display\n" ..
        "-- state.expirationTime = GetTime() + remaining\n" ..
        "-- state.stacks = count\n" ..
        "function(state)\n" ..
        "  return state\n" ..
        "end"
    )
    container:AddChild(codeBox)
end
```

**Step 2: In-game test**

`/nv` → Auras tab → toggle Advanced checkbox.
Expected: Editor switches between dropdown UI and Lua code box.

**Step 3: Commit**

```bash
git add Core/ConfigGUI.lua
git commit -m "feat: add auras tab with simple/advanced mode toggle"
```

---

## Task 17: Transmission System

**Files:**
- Modify: `Core/Transmission.lua`
- Create: `tests/test_transmission.lua`

**Step 1: Write failing test**

```lua
-- tests/test_transmission.lua
dofile("Core/Init.lua")
dofile("Core/Transmission.lua")

describe("Transmission", function()
    it("encodes and decodes an aura config round-trip", function()
        local original = {
            regionType = "Icon",
            triggerType = "Aura",
            auraName = "Combustion",
            unit = "player",
        }
        local encoded = NovAuras.Transmission.Encode(original)
        assert.is_string(encoded)
        local decoded = NovAuras.Transmission.Decode(encoded)
        assert.equals("Icon", decoded.regionType)
        assert.equals("Combustion", decoded.auraName)
    end)
end)
```

**Step 2: Implement (JSON-style via table serialisation)**

```lua
-- Core/Transmission.lua
NovAuras = NovAuras or {}
NovAuras.Transmission = {}

-- Simple table serialiser (no external deps)
local function Serialize(t, indent)
    indent = indent or ""
    if type(t) ~= "table" then return tostring(t) end
    local parts = {}
    for k, v in pairs(t) do
        local key = type(k) == "string" and k or ("["..k.."]")
        if type(v) == "table" then
            table.insert(parts, key .. "=" .. Serialize(v, indent.."  "))
        else
            local val = type(v) == "string" and ('"'..v..'"') or tostring(v)
            table.insert(parts, key .. "=" .. val)
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function Deserialize(str)
    local fn, err = loadstring("return " .. str)
    if not fn then return nil, err end
    local ok, result = pcall(fn)
    if not ok then return nil, result end
    return result
end

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function B64Encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data % 3 + 1])
end

local function B64Decode(data)
    data = data:gsub('[^'..b64chars..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b64chars:find(x)-1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d%d%d%d%d%d', function(x)
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function NovAuras.Transmission.Encode(auraConfig)
    local serialized = Serialize(auraConfig)
    return B64Encode(serialized)
end

function NovAuras.Transmission.Decode(encoded)
    local serialized = B64Decode(encoded)
    local result, err = Deserialize(serialized)
    return result
end

-- Share via chat
SLASH_NVSHARE1 = "/nvshare"
SlashCmdList["NVSHARE"] = function(msg)
    print("NovAuras: share system ready")
end
```

**Step 3: Run tests, commit**

```bash
busted tests/test_transmission.lua
git add Core/Transmission.lua tests/test_transmission.lua
git commit -m "feat: add aura transmission system with base64 encode/decode"
```

---

## Task 18: Integration & Final In-Game Testing

**Step 1: Full in-game smoke test checklist**

Copy addon to WoW AddOns folder, /reload:

```
[ ] /novdebug prints version with no errors
[ ] /nv opens config window
[ ] Auras tab: simple mode shows dropdowns
[ ] Auras tab: Advanced toggle shows Lua editor
[ ] Boss Timers tab opens
[ ] PvP Tracker tab opens
[ ] Enter arena: PvP tracker loads (check /novdebug)
[ ] Enter dungeon: Boss timers load (check /novdebug)
[ ] /run NovAuras.PvPTracker.HandleCast("test", 190319)
    → Combustion icon appears with 120s countdown
[ ] Icon disappears after 120s
```

**Step 2: Fix any errors found from smoke test**

Check the WoW Lua error frame or `/run print(debugstack())` for any issues.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete NovAuras v0.1.0 initial implementation"
git push origin main
```

---

## What's Next (v0.2.0)

- Aura save/load persistence (SavedVariables)
- Drag-to-reposition for all display frames
- Full condition builder UI
- Boss timer audio countdowns via C_EncounterEvents.PlayEventSound
- SpellDB expansion (community PRs)
- Aura sharing UI (import/export dialog)
