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
