-- tests/test_display.lua
-- Mock WoW CreateFrame and UIParent for unit testing
-- _G assignments are used so dofile('Core/DisplayEngine.lua') sees them.

_G.UIParent = {}
_G.GetTime = function() return 100 end

_G.CreateFrame = function(frameType, name, parent, template)
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
    f.SetAllPoints = function(self) end
    f.SetCooldown = function(self, start, duration)
        self._cooldown = { start = start, duration = duration }
    end
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

describe("IconRegion", function()
    it("sets spell texture", function()
        local icon = NovAuras.DisplayEngine.NewIconRegion()
        icon:SetSpellTexture(136243)
        assert.equals(136243, icon.texture:GetTexture())
    end)

    it("shows stack count when > 1", function()
        local icon = NovAuras.DisplayEngine.NewIconRegion()
        icon:SetStacks(5)
        assert.equals("5", icon.stackText:GetText())
    end)

    it("clears stack text when count is 1", function()
        local icon = NovAuras.DisplayEngine.NewIconRegion()
        icon:SetStacks(1)
        assert.equals("", icon.stackText:GetText())
    end)

    it("shows countdown timer text", function()
        local icon = NovAuras.DisplayEngine.NewIconRegion()
        icon:SetTimer(115)  -- GetTime()=100, so 15s remaining
        assert.equals("15.0", icon.timerText:GetText())
    end)

    it("clears timer text when expired", function()
        local icon = NovAuras.DisplayEngine.NewIconRegion()
        icon:SetTimer(90)  -- GetTime()=100, already expired
        assert.equals("", icon.timerText:GetText())
    end)
end)

describe("BarRegion", function()
    it("sets fill percentage", function()
        local bar = NovAuras.DisplayEngine.NewBarRegion()
        bar:SetValue(0.75)
        assert.equals(0.75, bar.fill)
    end)

    it("clamps fill above 1.0 to 1.0", function()
        local bar = NovAuras.DisplayEngine.NewBarRegion()
        bar:SetValue(1.5)
        assert.equals(1.0, bar.fill)
    end)

    it("clamps fill below 0 to 0.0", function()
        local bar = NovAuras.DisplayEngine.NewBarRegion()
        bar:SetValue(-0.5)
        assert.equals(0.0, bar.fill)
    end)

    it("sets label text", function()
        local bar = NovAuras.DisplayEngine.NewBarRegion()
        bar:SetLabel("Combustion")
        assert.equals("Combustion", bar.label:GetText())
    end)

    it("clears label when nil passed", function()
        local bar = NovAuras.DisplayEngine.NewBarRegion()
        bar:SetLabel(nil)
        assert.equals("", bar.label:GetText())
    end)
end)

describe("TextRegion", function()
    it("sets text content", function()
        local t = NovAuras.DisplayEngine.NewTextRegion()
        t:SetText("Hello")
        assert.equals("Hello", t.text:GetText())
    end)

    it("sets empty string when nil passed", function()
        local t = NovAuras.DisplayEngine.NewTextRegion()
        t:SetText(nil)
        assert.equals("", t.text:GetText())
    end)
end)

describe("ProgressRegion", function()
    it("creates with a cooldown frame", function()
        local p = NovAuras.DisplayEngine.NewProgressRegion()
        assert.is_not_nil(p.cooldown)
    end)

    it("SetCooldown records start and duration", function()
        local p = NovAuras.DisplayEngine.NewProgressRegion()
        p:SetCooldown(100, 60)
        assert.equals(100, p.cooldown._cooldown.start)
        assert.equals(60, p.cooldown._cooldown.duration)
    end)
end)
