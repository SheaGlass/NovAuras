-- tests/test_secrets.lua
-- Standalone busted test — no WoW API needed

-- Define the function under test locally (mirrors Core/Init.lua)
local function SafeGetValue(val)
    if type(val) == "userdata" then
        return nil
    end
    return val
end

describe("SafeGetValue", function()
    it("returns number values unchanged", function()
        assert.equals(42, SafeGetValue(42))
    end)

    it("returns string values unchanged", function()
        assert.equals("hello", SafeGetValue("hello"))
    end)

    it("returns nil for nil input", function()
        assert.is_nil(SafeGetValue(nil))
    end)

    it("returns nil for userdata (secret value)", function()
        local fakeSecret = io.tmpfile()  -- io.tmpfile() returns a file userdata in Lua 5.4
        assert.is_nil(SafeGetValue(fakeSecret))
    end)

    it("returns boolean true unchanged", function()
        assert.is_true(SafeGetValue(true))
    end)

    it("returns table unchanged", function()
        local t = { x = 1 }
        assert.equals(t, SafeGetValue(t))
    end)
end)
