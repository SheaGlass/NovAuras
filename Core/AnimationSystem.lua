-- Core/AnimationSystem.lua
NovAuras = NovAuras or {}
NovAuras.AnimationSystem = {}

-- Fade in a frame over `duration` seconds
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

-- Fade out a frame over `duration` seconds, then call callback if provided
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

-- Scale pulse: grow then shrink (entry animation)
function NovAuras.AnimationSystem.Pulse(frame, duration)
    duration = duration or 0.2
    local ag = frame:CreateAnimationGroup()
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetScale(1.3, 1.3)
    scaleUp:SetDuration(duration / 2)
    scaleUp:SetOrder(1)
    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetScale(1 / 1.3, 1 / 1.3)
    scaleDown:SetDuration(duration / 2)
    scaleDown:SetOrder(2)
    ag:Play()
    return ag
end
