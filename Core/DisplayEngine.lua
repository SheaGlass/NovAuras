-- Core/DisplayEngine.lua
NovAuras = NovAuras or {}
NovAuras.DisplayEngine = {}

-- Base region metatable
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

-- IconRegion
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
    -- expiry is a future GetTime() value
    -- In test context GetTime may not exist; guard it
    local now = (GetTime and GetTime()) or 0
    local remaining = expiry - now
    if remaining > 0 then
        self.timerText:SetText(string.format("%.1f", remaining))
    else
        self.timerText:SetText("")
    end
end

-- BarRegion
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

-- TextRegion
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

-- ProgressRegion uses WoW CooldownFrame for circular sweep
-- Note: CooldownFrameTemplate requires in-game testing only
local ProgressRegion = setmetatable({}, { __index = BaseRegion })
ProgressRegion.__index = ProgressRegion

function NovAuras.DisplayEngine.NewProgressRegion(parent)
    local region = NovAuras.DisplayEngine.NewRegion("Progress", parent)
    setmetatable(region, ProgressRegion)
    region.cooldown = CreateFrame("Cooldown", nil, region.frame, "CooldownFrameTemplate")
    region.cooldown:SetAllPoints()
    return region
end

function ProgressRegion:SetCooldown(start, duration)
    self.cooldown:SetCooldown(start, duration)
end
