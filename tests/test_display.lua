-- tests/test_display.lua
-- Mock WoW CreateFrame and UIParent for unit testing
-- _G assignments are used so dofile('Core/DisplayEngine.lua') sees them.

_G.UIParent = {}

_G.CreateFrame = function(frameType, name, parent)
    local f = {
        frameType = frameType,
        _shown = false,
        _width = 0,
        _height = 0,
        _points = {},
        _scripts = {},
    }
    f.Show = function(self) self._shown = true end
    f.Hide = function(self) self._shown = false end
    f.IsShown = function(self) return self._shown end
    f.SetSize = function(self, w, h) self._width = w; self._height = h end
    f.GetWidth = function(self) return self._width end
    f.GetHeight = function(self) return self._height end
    f.ClearAllPoints = function(self) self._points = {} end
    f.SetPoint = function(self, ...) table.insert(self._points, {...}) end
    f.CreateTexture = function(self, name, layer)
        return {
            _texture = nil,
            _color = nil,
            SetTexture = function(self, t) self._texture = t end,
            GetTexture = function(self) return self._texture end,
            SetAllPoints = function(self) end,
            SetPoint = function(self, ...) end,
            SetSize = function(self, w, h) end,
            SetWidth = function(self, w) self._width = w end,
            SetColorTexture = function(self, r,g,b,a) self._color = {r,g,b,a} end,
            SetVertexColor = function(self, r,g,b,a) end,
        }
    end
    f.CreateFontString = function(self, name, layer)
        return {
            _text = "",
            _font = nil,
            SetText = function(self, t) self._text = t end,
            GetText = function(self) return self._text end,
            SetPoint = function(self, ...) end,
            SetFont = function(self, path, size, flags) self._font = {path, size, flags} end,
            SetAllPoints = function(self) end,
        }
    end
    f.SetScript = function(self, event, fn) self._scripts[event] = fn end
    return f
end

local testDir = debug.getinfo(1, "S").source:match("^@(.+[/\\])")
dofile(testDir .. "../Core/DisplayEngine.lua")

describe("BaseRegion", function()
    it("creates with correct region type", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        assert.equals("Icon", r.regionType)
    end)

    it("starts hidden", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        assert.is_false(r:IsShown())
    end)

    it("can be shown", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        r:Show()
        assert.is_true(r:IsShown())
    end)

    it("can be hidden after shown", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        r:Show()
        r:Hide()
        assert.is_false(r:IsShown())
    end)

    it("SetSize updates frame dimensions", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        r:SetSize(64, 64)
        assert.equals(64, r.frame._width)
        assert.equals(64, r.frame._height)
    end)

    it("SetPosition records anchor point on frame", function()
        local r = NovAuras.DisplayEngine.NewRegion("Icon")
        r:SetPosition(100, -50)
        local pt = r.frame._points[1]
        assert.equals("CENTER", pt[1])
        assert.equals(100, pt[4])
        assert.equals(-50, pt[5])
    end)
end)
