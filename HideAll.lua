local _, A = ...
-- One key hides every name and nameplate (for screenshots), and the same key
-- puts back exactly what you had. Nothing else is hidden (this is not Alt+Z).
-- The values it turns off are saved per character, so a /reload or a
-- disconnect while hidden never strands them: they come back at login.
-- The game refuses nameplate settings in combat: our labels fade at once and
-- Blizzard's plates and names follow when combat ends.
local HIDE = {
    -- Nameplates
    "nameplateShowEnemies", "nameplateShowFriends", "nameplateShowFriendlyPlayers",
    "nameplateShowFriendlyNpcs", "nameplateShowSelf", "nameplateShowPersonal",
    -- Names over characters
    "UnitNameOwn", "UnitNameNPC", "UnitNameHostleNPC", "UnitNameInteractiveNPC",
    "UnitNameFriendlySpecialNPCName", "UnitNameNonCombatCreatureName",
    "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName",
    "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyMinionName", "UnitNameFriendlyTotemName",
    "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameEnemyMinionName", "UnitNameEnemyTotemName",
}
A.hideAllCVars = HIDE

local function Character()
    local ok, guid = pcall(UnitGUID, "player")
    if ok and type(guid) == "string" and (not issecretvalue or not issecretvalue(guid)) then return guid end
    return "unknown"
end
local function Saved()
    local db = A.db
    db.hideAllSaved = type(db.hideAllSaved) == "table" and db.hideAllSaved or {}
    return db.hideAllSaved
end
-- True while your values are stored away (or about to be).
function A.AllNamesHidden()
    return A.allHidden == true or (A.db and type(A.db.hideAllSaved) == "table" and A.db.hideAllSaved[Character()] ~= nil) or false
end

local waiter = CreateFrame("Frame")
-- Out of combat only: make the game settings match A.allHidden.
local function Apply()
    if InCombatLockdown() then waiter:RegisterEvent("PLAYER_REGEN_ENABLED"); return false end
    local all, key = Saved(), Character()
    if A.allHidden then
        if all[key] then return true end
        local saved = {}
        for _, name in ipairs(HIDE) do
            local current = GetCVar(name)
            if current ~= nil and current ~= "0" and pcall(SetCVar, name, "0") then saved[name] = current end
        end
        all[key] = saved
    else
        local saved = all[key]
        if not saved then return true end
        all[key] = nil
        if not next(all) then A.db.hideAllSaved = nil end
        for name, value in pairs(saved) do
            -- Something you changed meanwhile wins.
            if GetCVar(name) == "0" then pcall(SetCVar, name, value) end
        end
        -- Settings changed while hidden (enemy names, fade) apply now.
        A.ApplyCVars()
    end
    return true
end
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    Apply()
    if A.RefreshOptions then A.RefreshOptions() end
end)

-- Key "Hide or show all names and nameplates", /fnames hide, and the settings button.
function A.ToggleLabels(hidden)
    if not A.db then return end
    if hidden == nil then hidden = not A.allHidden end
    A.allHidden = hidden and true or nil
    A.FadeLabels(A.allHidden)
    Apply() -- silent; in combat Blizzard's plates follow when combat ends
    if A.RefreshOptions then A.RefreshOptions() end
end

-- Login: anything still stored away from last time comes back.
function A.RestoreHiddenNames()
    local all = A.db and A.db.hideAllSaved
    if type(all) ~= "table" or not all[Character()] then return end
    A.allHidden = nil
    Apply()
end
