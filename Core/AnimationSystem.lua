-- Core/AnimationSystem.lua
NovAuras = NovAuras or {}
NovAuras.AnimationSystem = {}

-- ============================================================
-- Utility
-- ============================================================

-- Stop and reset all animation groups on a frame.
function NovAuras.AnimationSystem.StopAll(frame)
    local groups = frame:GetAnimationGroups and frame:GetAnimationGroups()
    if not groups then return end
    for _, ag in ipairs(groups) do
        ag:Stop()
    end
end

-- ============================================================
-- Alpha Animations
-- ============================================================

-- Fade frame from invisible to visible.
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

-- Fade frame from visible to invisible.  Optional callback fires on finish.
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

-- Flicker the frame's alpha N times — useful for alerts.
-- Each flicker = one full on/off cycle of `interval` seconds.
function NovAuras.AnimationSystem.Flash(frame, times, interval)
    times    = times    or 3
    interval = interval or 0.15
    local ag = frame:CreateAnimationGroup()
    local half = interval / 2
    for i = 1, times do
        local off = ag:CreateAnimation("Alpha")
        off:SetFromAlpha(1)
        off:SetToAlpha(0)
        off:SetDuration(half)
        off:SetOrder(i * 2 - 1)

        local on = ag:CreateAnimation("Alpha")
        on:SetFromAlpha(0)
        on:SetToAlpha(1)
        on:SetDuration(half)
        on:SetOrder(i * 2)
    end
    ag:Play()
    return ag
end

-- Continuous alpha oscillation between minAlpha and maxAlpha.
-- Loops indefinitely until StopAll is called.
function NovAuras.AnimationSystem.GlowPulse(frame, minAlpha, maxAlpha, period)
    minAlpha = minAlpha or 0.3
    maxAlpha = maxAlpha or 1.0
    period   = period   or 1.0
    local half = period / 2
    local ag = frame:CreateAnimationGroup()
    ag:SetLooping("REPEAT")

    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(maxAlpha)
    fadeOut:SetToAlpha(minAlpha)
    fadeOut:SetDuration(half)
    fadeOut:SetOrder(1)

    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(minAlpha)
    fadeIn:SetToAlpha(maxAlpha)
    fadeIn:SetDuration(half)
    fadeIn:SetOrder(2)

    ag:Play()
    return ag
end

-- ============================================================
-- Scale Animations
-- ============================================================

-- Scale pulse: grow then shrink back (proc / entry pop).
function NovAuras.AnimationSystem.Pulse(frame, duration)
    duration = duration or 0.2
    local half = duration / 2
    local ag = frame:CreateAnimationGroup()

    local up = ag:CreateAnimation("Scale")
    up:SetScale(1.3, 1.3)
    up:SetDuration(half)
    up:SetOrder(1)

    local down = ag:CreateAnimation("Scale")
    down:SetScale(1 / 1.3, 1 / 1.3)
    down:SetDuration(half)
    down:SetOrder(2)

    ag:Play()
    return ag
end

-- Scale from zero to full size (aura appearing).
function NovAuras.AnimationSystem.Grow(frame, duration)
    duration = duration or 0.25
    local ag = frame:CreateAnimationGroup()
    local scale = ag:CreateAnimation("Scale")
    scale:SetScale(0.01, 0.01) -- avoid exact 0 which can glitch
    scale:SetDuration(0)       -- instant to tiny
    scale:SetOrder(1)

    local expand = ag:CreateAnimation("Scale")
    expand:SetScale(100, 100)  -- inverse: from 0.01 back to 1.0
    expand:SetDuration(duration)
    expand:SetOrder(2)

    ag:Play()
    return ag
end

-- Scale from full size to zero (aura expiring). Optional callback on finish.
function NovAuras.AnimationSystem.Shrink(frame, duration, callback)
    duration = duration or 0.2
    local ag = frame:CreateAnimationGroup()
    local shrink = ag:CreateAnimation("Scale")
    shrink:SetScale(0.01, 0.01)
    shrink:SetDuration(duration)
    shrink:SetOrder(1)

    if callback then
        ag:SetScript("OnFinished", callback)
    end
    ag:Play()
    return ag
end

-- ============================================================
-- Translation Animations
-- ============================================================

-- Hop the frame upward by `height` pixels and return (proc notification).
function NovAuras.AnimationSystem.Bounce(frame, height, duration)
    height   = height   or 20
    duration = duration or 0.3
    local half = duration / 2
    local ag = frame:CreateAnimationGroup()

    local up = ag:CreateAnimation("Translation")
    up:SetOffset(0, height)
    up:SetDuration(half)
    up:SetOrder(1)

    local down = ag:CreateAnimation("Translation")
    down:SetOffset(0, -height)
    down:SetDuration(half)
    down:SetOrder(2)

    ag:Play()
    return ag
end

-- Rapid horizontal shake (interrupt landed, dispel, etc.).
-- Steps: +i, -2i, +2i, -i  → returns to origin.
function NovAuras.AnimationSystem.Shake(frame, intensity, duration)
    intensity = intensity or 6
    duration  = duration  or 0.3
    local step = duration / 4
    local ag = frame:CreateAnimationGroup()

    local offsets = { intensity, -2 * intensity, 2 * intensity, -intensity }
    for i, dx in ipairs(offsets) do
        local t = ag:CreateAnimation("Translation")
        t:SetOffset(dx, 0)
        t:SetDuration(step)
        t:SetOrder(i)
    end

    ag:Play()
    return ag
end

-- Slide a frame in from a direction to its current position.
-- direction: "LEFT" | "RIGHT" | "UP" | "DOWN"
function NovAuras.AnimationSystem.SlideIn(frame, direction, distance, duration)
    distance  = distance  or 100
    duration  = duration  or 0.25
    direction = direction or "LEFT"

    local dx, dy = 0, 0
    if direction == "LEFT"  then dx = -distance
    elseif direction == "RIGHT" then dx =  distance
    elseif direction == "UP"    then dy =  distance
    elseif direction == "DOWN"  then dy = -distance
    end

    local ag = frame:CreateAnimationGroup()
    -- Start offset
    local start = ag:CreateAnimation("Translation")
    start:SetOffset(dx, dy)
    start:SetDuration(0)
    start:SetOrder(1)
    -- Slide back to origin
    local slide = ag:CreateAnimation("Translation")
    slide:SetOffset(-dx, -dy)
    slide:SetDuration(duration)
    slide:SetOrder(2)

    ag:Play()
    return ag
end

-- Slide a frame out to a direction. Optional callback on finish.
function NovAuras.AnimationSystem.SlideOut(frame, direction, distance, duration, callback)
    distance  = distance  or 100
    duration  = duration  or 0.25
    direction = direction or "LEFT"

    local dx, dy = 0, 0
    if direction == "LEFT"  then dx = -distance
    elseif direction == "RIGHT" then dx =  distance
    elseif direction == "UP"    then dy =  distance
    elseif direction == "DOWN"  then dy = -distance
    end

    local ag = frame:CreateAnimationGroup()
    local slide = ag:CreateAnimation("Translation")
    slide:SetOffset(dx, dy)
    slide:SetDuration(duration)

    if callback then
        ag:SetScript("OnFinished", callback)
    end
    ag:Play()
    return ag
end

-- ============================================================
-- Rotation Animations
-- ============================================================

-- Full 360° spin. loops = number of rotations, or "REPEAT" for infinite.
function NovAuras.AnimationSystem.Spin(frame, duration, loops)
    duration = duration or 1.0
    loops    = loops    or 1

    local ag = frame:CreateAnimationGroup()
    if loops == "REPEAT" then
        ag:SetLooping("REPEAT")
    end

    local rot = ag:CreateAnimation("Rotation")
    rot:SetDegrees(360)
    rot:SetDuration(duration)
    if type(loops) == "number" and loops > 1 then
        -- Chain extra rotations via SetOrder
        for i = 2, loops do
            local r = ag:CreateAnimation("Rotation")
            r:SetDegrees(360)
            r:SetDuration(duration)
            r:SetOrder(i)
        end
    end

    ag:Play()
    return ag
end

-- Oscillating rotation — CC / disoriented indicator.
-- Rotates +degrees then -degrees and returns to origin.
function NovAuras.AnimationSystem.Wobble(frame, degrees, duration)
    degrees  = degrees  or 15
    duration = duration or 0.4
    local quarter = duration / 4
    local ag = frame:CreateAnimationGroup()

    local steps = { degrees, -2 * degrees, 2 * degrees, -degrees }
    for i, deg in ipairs(steps) do
        local r = ag:CreateAnimation("Rotation")
        r:SetDegrees(deg)
        r:SetDuration(quarter)
        r:SetOrder(i)
    end

    ag:Play()
    return ag
end
