-- Core/ConditionSystem.lua
NovAuras = NovAuras or {}
NovAuras.ConditionSystem = {}

local function EvalOne(cond)
    if cond.type == "zone" then
        return cond.current == cond.zone
    elseif cond.type == "health" then
        local val = NovAuras.SafeGetValue(cond.current)
        if val == nil then return false end
        if cond.op == "lt" then return val < cond.threshold end
        if cond.op == "gt" then return val > cond.threshold end
        if cond.op == "eq" then return val == cond.threshold end
    elseif cond.type == "custom" then
        local ok, result = pcall(cond.fn)
        return ok and result
    end
    return false
end

function NovAuras.ConditionSystem.Evaluate(logic, conditions)
    if not conditions or #conditions == 0 then return true end
    if logic == "AND" then
        for _, cond in ipairs(conditions) do
            if not EvalOne(cond) then return false end
        end
        return true
    elseif logic == "OR" then
        for _, cond in ipairs(conditions) do
            if EvalOne(cond) then return true end
        end
        return false
    end
    return false
end
