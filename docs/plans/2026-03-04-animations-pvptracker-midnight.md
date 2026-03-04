# NovAuras — Animations Expansion & PvP Tracker Midnight API
**Date:** 2026-03-04

---

## 1. Animation System Expansion

Add 10 new animations to `Core/AnimationSystem.lua` using WoW's native AnimationGroup API.

### New Animations

| Function | WoW Type | Behaviour |
|---|---|---|
| `Grow(frame, duration)` | Scale | Scale 0→1 (aura appearing) |
| `Shrink(frame, duration, callback)` | Scale | Scale 1→0, fires callback on finish |
| `Flash(frame, times, interval)` | Alpha | Flicker N times (alert) |
| `Bounce(frame, height, duration)` | Translation | Hop up and return |
| `Shake(frame, intensity, duration)` | Translation | Rapid horizontal wobble |
| `Spin(frame, duration, loops)` | Rotation | Full 360° rotation, loops N times or repeating |
| `SlideIn(frame, direction, distance, duration)` | Translation | Translate in from edge |
| `SlideOut(frame, direction, distance, duration, callback)` | Translation | Translate out to edge, callback on finish |
| `GlowPulse(frame, minAlpha, maxAlpha, period)` | Alpha | Continuous looping alpha oscillation |
| `Wobble(frame, degrees, duration)` | Rotation | Oscillating rotation (CC indicator) |

Plus a utility:

| Function | Behaviour |
|---|---|
| `StopAll(frame)` | Stops and resets all animation groups on the frame |

### Implementation Notes
- `Shake`: chain four ordered Translation steps (+intensity, −2×, +2×, −intensity) to return to origin
- `Wobble`: chain two Rotation steps (±degrees) to oscillate and return
- `GlowPulse` and `Spin` with `loops = "REPEAT"`: use `ag:SetLooping("REPEAT")`
- `Shrink`, `SlideOut`, `FadeOut`: accept optional `callback` fired on `ag OnFinished`
- `StopAll`: iterate `frame:GetAnimationGroups()` and call `:Stop()` then `:Restart()` on each

---

## 2. PvP Tracker — Midnight API Compatibility

### Changes to `Modules/PvPTracker.lua`

#### Unit Token Handling
- Track `arena1`–`arena5` as canonical tokens
- Key timers/profiles by `UnitGUID` (wrapped in `SafeGetValue`) — stable across token reassignment
- Gate all cast handling with `UnitIsEnemy("player", unit)` (SafeGetValue-wrapped)
- On `ARENA_OPPONENT_UPDATE`: wipe timers for that unit's GUID

#### UNIT_AURA as Lifecycle Signal
- Listen to `UNIT_AURA(unit)` for enemy arena units
- Aura values are Secret Values — never attempt to read them
- Use event firing as a "state changed" signal on active CC/debuff timers
- Mark affected timer with `uncertain = true`; display fades the icon to 50% alpha as visual indication
- Does NOT hard-cancel the timer — inference is still the source of truth

#### Reset on Zone Change
- Listen to `PLAYER_ENTERING_WORLD`
- Wipe `profiles` and `timers` tables entirely on each call
- Prevents stale enemy data carrying over between arenas

### SafeGetValue Wrapping
Every unit API call that can theoretically return unexpected values gets wrapped:
- `UnitGUID(unit)` → `SafeGetValue(UnitGUID(unit))`
- `UnitIsEnemy("player", unit)` → `SafeGetValue(UnitIsEnemy("player", unit))`
- `UnitIsUnit(unit, "player")` → `SafeGetValue(UnitIsUnit(unit, "player"))`

---

## Testing
- Animations: WoW API only — verified in-game
- PvP Tracker: busted unit tests updated to cover:
  - SafeGetValue nil returns on unit calls
  - Timer wipe on zone change
  - `uncertain` flag set when UNIT_AURA fires for unit with active timer
