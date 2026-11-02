local _, A = ...
-- Local label opacity always inherits the engine's distance/occlusion alpha.
-- Engine distance controls are explicitly opt-in because they affect all plates.
A.fadeControls = {
    {key = "nameplateMaxDistance", label = "Maximum nameplate distance", min = 5, max = 200, step = 5, fallback = 0},
    {key = "nameplateMaxAlpha", label = "Near opacity", min = 0, max = 1, step = 0.05, percent = true, fallback = 1},
    {key = "nameplateMinAlpha", label = "Far opacity", min = 0, max = 1, step = 0.05, percent = true, fallback = 0.6},
    {key = "nameplateMaxAlphaDistance", label = "Start fading at", min = 0, max = 200, step = 5, fallback = 40},
    {key = "nameplateMinAlphaDistance", label = "Finish fading this far before maximum", min = 0, max = 200, step = 5, fallback = 10},
    {key = "nameplateOccludedAlphaMult", label = "Behind walls / terrain opacity", min = 0, max = 1, step = 0.05, percent = true, fallback = 0.4},
    {key = "nameplateMaxScale", label = "Near nameplate size", min = 0.1, max = 2, step = 0.05, percent = true, fallback = 1},
    {key = "nameplateMinScale", label = "Far nameplate size", min = 0.1, max = 2, step = 0.05, percent = true, fallback = 0.8},
    {key = "nameplateMaxScaleDistance", label = "Start shrinking at", min = 0, max = 200, step = 5, fallback = 10},
    {key = "nameplateMinScaleDistance", label = "Finish shrinking this far before maximum", min = 0, max = 200, step = 5, fallback = 10},
}
function A.DistanceSummary()
    local values = A.db.fadeValues
    local function Value(key)
        if A.pendingCVars and A.db.enabled and A.db.customizeGlobalFade then return values[key] end
        return tonumber(GetCVar(key))
    end
    local maximum = Value("nameplateMaxDistance")
    if not maximum or maximum <= 0 then
        return "Maximum distance is unavailable on this client; fade endpoints cannot be calculated."
    end
    local lines = {string.format("%smaximum nameplate distance: %g yd (the client may impose a further limit).",
        A.pendingCVars and "Pending " or "Configured ", maximum)}
    for _, pair in ipairs({{"Fading", "Alpha"}, {"Shrinking", "Scale"}}) do
        local start = Value("nameplateMax" .. pair[2] .. "Distance")
        local offset = Value("nameplateMin" .. pair[2] .. "Distance")
        if start and offset then
            local finish = maximum - offset
            if start >= finish or finish <= 0 or start >= maximum then
                lines[#lines + 1] = pair[1] .. ": start must be below finish. Lower the start or the 'before maximum' value."
            else
                lines[#lines + 1] = string.format("%s: near value until %g yd; changes to far value by %g yd.", pair[1], start, finish)
            end
        end
    end
    return table.concat(lines, "\n")
end
-- These nameplate CVars are saved per character by the client, so the values to
-- restore must be recorded per character too. Before 1.5.6 one account-wide
-- record was shared: restoring on one character erased it for the others, which
-- kept their custom values when unchecked, and re-checking there captured the
-- custom values as the "previous" ones.
-- Since 1.5.7, turning the option off returns to Blizzard's defaults instead
-- of any recorded previous value (a stuck record left Alberich-Noir customized).
function A.InitFading()
    local db = A.db
    db.fadeValues = db.fadeValues or {}
    db.fadeCharacters = type(db.fadeCharacters) == "table" and db.fadeCharacters or {}
    if db.fadePreviousCVars or db.fadeAppliedCVars then
        -- Keep the old shared record read-only; each character migrates from it once.
        db.fadeLegacy = db.fadeLegacy or { previous = db.fadePreviousCVars or {}, applied = db.fadeAppliedCVars or {} }
        db.fadePreviousCVars, db.fadeAppliedCVars = nil, nil
    end
    for _, setting in ipairs(A.fadeControls) do
        if db.fadeValues[setting.key] == nil then
            db.fadeValues[setting.key] = tonumber(GetCVar(setting.key)) or setting.fallback
        end
    end
end
local function Same(a, b)
    if a == b then return true end
    local x, y = tonumber(a), tonumber(b)
    return x ~= nil and y ~= nil and math.abs(x - y) < 1e-6
end
local function DefaultValue(key)
    local getter = (C_CVar and C_CVar.GetCVarDefault) or GetCVarDefault
    if not getter then return nil end
    local ok, value = pcall(getter, key)
    if ok and value ~= nil then return value end
end
local function CharacterState()
    local ok, guid = pcall(UnitGUID, "player")
    if not ok or type(guid) ~= "string" or (issecretvalue and issecretvalue(guid)) then return nil end
    local db = A.db
    local state = db.fadeCharacters[guid]
    if type(state) ~= "table" then
        state = {previous = {}, applied = {}}
        db.fadeCharacters[guid] = state
    end
    state.previous = type(state.previous) == "table" and state.previous or {}
    state.applied = type(state.applied) == "table" and state.applied or {}
    return state
end
-- First visit to a character since per-character records: a CVar still holding
-- the value the addon wrote under the old shared record is the addon's own.
-- Record it as applied; its previous value is the old record's, unless that was
-- lost or overwritten with the custom value itself, then the game default.
local function MigrateCharacter(state)
    if state.migrated then return end
    state.migrated = true
    local legacy = A.db.fadeLegacy
    if type(legacy) ~= "table" or type(legacy.applied) ~= "table" then return end
    local previous = type(legacy.previous) == "table" and legacy.previous or {}
    for _, setting in ipairs(A.fadeControls) do
        local key = setting.key
        local written, current = legacy.applied[key], GetCVar(key)
        if written ~= nil and current ~= nil and state.previous[key] == nil and Same(current, written) then
            local original = previous[key]
            if original == nil or Same(original, written) then original = DefaultValue(key) end
            -- Nothing to restore when the value already is the original.
            if original ~= nil and not Same(original, current) then
                state.previous[key], state.applied[key] = original, current
            end
        end
    end
end
A.FadeCharacterState = CharacterState
function A.IsFadeCVar(name)
    for _, setting in ipairs(A.fadeControls) do
        if setting.key:lower() == name:lower() then return true end
    end
    return false
end
function A.ApplyFadeCVars()
    local db = A.db
    if not db or not db.fadeValues then return end
    A.fadeError = nil
    -- The character is known from PLAYER_LOGIN on; ApplyCVars runs again then.
    local state = CharacterState()
    if not state then return end
    MigrateCharacter(state)
    local resetAll = A.fadeResetAll and not (db.enabled and db.customizeGlobalFade)
    for _, setting in ipairs(A.fadeControls) do
        local key = setting.key
        local current = GetCVar(key)
        if db.enabled and db.customizeGlobalFade and current ~= nil then
            if state.previous[key] == nil then state.previous[key] = current end
            local desired = db.fadeValues[key]
            if tonumber(current) ~= desired then
                local ok = pcall(SetCVar, key, desired)
                local actual = GetCVar(key)
                if not ok or tonumber(actual) ~= desired then
                    A.fadeError = "The client restricted one or more values; its accepted values are shown."
                    db.fadeValues[key] = tonumber(actual) or desired
                end
            end
            state.applied[key] = GetCVar(key)
        elseif current ~= nil then
            -- Off means Blizzard's default, not a recorded "previous" value: those
            -- records could capture the custom values themselves. Reset what the
            -- addon owns (recorded or still equal to its configured value), or
            -- every key right after the user unchecks the option. A value
            -- changed elsewhere since is left alone.
            local owned = (state.applied[key] ~= nil and Same(current, state.applied[key]))
                or Same(current, db.fadeValues[key])
            local default = DefaultValue(key)
            if (resetAll or owned) and default ~= nil and not Same(current, default) then
                local ok = pcall(SetCVar, key, default)
                if not ok or not Same(GetCVar(key), default) then
                    A.fadeError = "The client could not restore a default. Try again after combat."
                else
                    state.previous[key], state.applied[key] = nil, nil
                end
            else
                state.previous[key], state.applied[key] = nil, nil
            end
        end
    end
    A.fadeResetAll = nil
end
