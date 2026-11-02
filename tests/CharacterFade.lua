-- Run from the client root: lua Interface/AddOns/ForeverNames/tests/CharacterFade.lua
-- The client saves nameplate distance/alpha/scale CVars per character. The
-- "Customize distance / size / occlusion" restore record must be per character.
local root = "Interface/AddOns/ForeverNames/"
local assertions = 0
local function check(value, message) assertions = assertions + 1; assert(value, message) end

local defaults = { nameplateMaxDistance = "60", nameplateMaxAlpha = "1", nameplateMinAlpha = "0.6",
    nameplateMaxAlphaDistance = "40", nameplateMinAlphaDistance = "-100000", nameplateOccludedAlphaMult = "0.4",
    nameplateMaxScale = "1", nameplateMinScale = "1", nameplateMaxScaleDistance = "10", nameplateMinScaleDistance = "10" }
local custom = { nameplateMaxDistance = 100, nameplateMaxAlpha = 1, nameplateMinAlpha = 0.3,
    nameplateMaxAlphaDistance = 50, nameplateMinAlphaDistance = 0, nameplateOccludedAlphaMult = 0.2,
    nameplateMaxScale = 1, nameplateMinScale = 0.2, nameplateMaxScaleDistance = 30, nameplateMinScaleDistance = 0 }

-- Each character has its own CVar store, like config-cache.wtf.
local characters, player = {}, nil
local function Character(guid, values)
    local store = {}
    for key, value in pairs(defaults) do store[key] = value end
    for key, value in pairs(values or {}) do store[key] = tostring(value) end
    characters[guid] = store
end
local function Login(guid) player = guid end
function UnitGUID(unit) return unit == "player" and player or nil end
function GetCVar(key) return player and characters[player][key] end
local writes = 0
function SetCVar(key, value) writes = writes + 1; characters[player][key] = tostring(value) end
C_CVar = { GetCVarDefault = function(key) return defaults[key] end }

local A = {}
assert(loadfile(root .. "Fading.lua"))("ForeverNames", A)
local function Load(db)
    A.db = db
    A.InitFading()
end
local function Apply(customize)
    A.db.customizeGlobalFade = customize
    A.ApplyFadeCVars()
end
local function Matches(guid, expected)
    for key, value in pairs(expected) do
        if tonumber(characters[guid][key]) ~= tonumber(value) then return false, key end
    end
    return true
end

-- 1. The reported state: the old shared record was overwritten with the custom
-- values themselves, and this character still carries them.
local legacyCustom = {}
for key, value in pairs(custom) do legacyCustom[key] = tostring(value) end
Character("Player-Alberich", custom)
Login("Player-Alberich")
local fadeValues = {}
for key, value in pairs(custom) do fadeValues[key] = value end
Load({ enabled = true, customizeGlobalFade = true, fadeValues = fadeValues,
    fadePreviousCVars = legacyCustom, fadeAppliedCVars = legacyCustom })
check(A.db.fadePreviousCVars == nil and A.db.fadeLegacy, "old shared record is retired into a read-only legacy copy")
Apply(true)
check(Matches("Player-Alberich", custom), "enabled: character keeps the custom values")
Apply(false)
check(Matches("Player-Alberich", defaults), "unchecking restores the game defaults, not the custom values")

-- 2. A character first seen now, with its own natives, customizes and restores independently.
local nativesB = { nameplateMaxDistance = 41, nameplateMinScale = 0.8, nameplateMinAlpha = 0.5 }
Character("Player-Neige", nativesB)
Login("Player-Neige")
Apply(true)
check(Matches("Player-Neige", custom), "second character receives the custom values")
Login("Player-Alberich")
Apply(true)
check(Matches("Player-Alberich", custom), "first character customized again")
Apply(false)
check(Matches("Player-Alberich", defaults), "restoring the first character")
Login("Player-Neige")
check(Matches("Player-Neige", custom), "restoring one character leaves the other's CVars alone")
Apply(false)
check(Matches("Player-Neige", defaults), "unchecking uses Blizzard defaults, not the recorded natives")

-- 3. Repeat toggles keep landing on Blizzard defaults.
Apply(true); Apply(false)
check(Matches("Player-Neige", defaults), "repeat toggle returns to defaults")

-- 4. A character that never used the feature is untouched while it is off.
Character("Player-Fresh", { nameplateMinScale = 0.9 })
Login("Player-Fresh")
local before = writes
Apply(false)
check(writes == before and characters["Player-Fresh"].nameplateMinScale == "0.9", "unused character: no writes")

-- 5. A change made elsewhere after customizing wins over the restore.
Apply(true)
characters["Player-Fresh"].nameplateMinScale = "0.7"
Apply(false)
check(characters["Player-Fresh"].nameplateMinScale == "0.7", "a separate later change is not overwritten")
check(characters["Player-Fresh"].nameplateMaxDistance == defaults.nameplateMaxDistance, "other keys still restore")

-- 6. Before the character is known (no GUID yet), nothing is recorded or written.
Login(nil)
before = writes
Apply(true)
check(writes == before, "no character yet: no writes")

-- 7. The live Alberich state: record already migrated but empty, option off,
-- CVars still holding the addon's values. Off must still give Blizzard defaults.
Character("Player-Stuck", custom)
Login("Player-Stuck")
A.db.fadeCharacters["Player-Stuck"] = { migrated = true, previous = {}, applied = {} }
A.db.fadeValues = fadeValues
Apply(false)
check(Matches("Player-Stuck", defaults), "stuck addon values reset to defaults while the option is off")
before = writes; Apply(false)
check(writes == before, "defaults are not rewritten on every apply")

-- 8. Unchecking resets every key, even one set to another value since.
Apply(true)
characters["Player-Stuck"].nameplateMinScale = "0.5"
A.fadeResetAll = true; Apply(false)
check(Matches("Player-Stuck", defaults) and A.fadeResetAll == nil, "explicit uncheck resets all keys to defaults")
characters["Player-Stuck"].nameplateMinScale = "0.5"
Apply(false)
check(characters["Player-Stuck"].nameplateMinScale == "0.5", "later native change kept once the reset was consumed")

print("PASS: " .. assertions .. " per-character nameplate fade / Blizzard-default reset assertions")
