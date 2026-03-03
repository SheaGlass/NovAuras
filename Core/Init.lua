NovAuras = NovAuras or {}
NovAuras.version = "0.1.0"
NovAuras.modules = {}

function NovAuras:RegisterModule(name, module)
    self.modules[name] = module
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, isLogin, isReload)
    local inInstance, instanceType = IsInInstance()

    if inInstance and (instanceType == "raid" or instanceType == "party") then
        local mod = NovAuras.modules["BossTimers"]
        if mod and not mod._loaded then
            mod:Load()
            mod._loaded = true
        end
    end

    local pvpType = C_PvP.GetZonePvpInfo and C_PvP.GetZonePvpInfo()
    if pvpType == "arena" or pvpType == "battleground" then
        local mod = NovAuras.modules["PvPTracker"]
        if mod and not mod._loaded then
            mod:Load()
            mod._loaded = true
        end
    end
end)

function NovAuras.SafeGetValue(val)
    if type(val) == "userdata" then
        return nil
    end
    return val
end

SLASH_NOVDEBUG1 = "/novdebug"
SlashCmdList["NOVDEBUG"] = function()
    print("NovAuras v" .. NovAuras.version .. " loaded.")
    local count = 0
    for _ in pairs(NovAuras.modules) do count = count + 1 end
    print("Modules:", count)
end
