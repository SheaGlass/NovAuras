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
