local _, A = ...

-- Pause only health/level event subscriptions on unselected friendly world
-- nameplates. Never replace Blizzard's handlers, unit fields or option tables.
-- Initial setup, pending work and general native refreshes still run normally.
local unitEvents = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
    "UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "UNIT_LEVEL",
}
local levelEvents = {"PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED"}
local regions = {"HealthBarsContainer", "LevelFrame", "PlayerLevelDiffFrame"}
local paused, hooked = {}, setmetatable({}, {__mode = "k"})
local installed = false
local failures = setmetatable({}, {__mode = "k"})

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Read(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok and Public(value) then return value end
end
local function Token(unit)
    return Public(unit) and type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end
local function Usable(frame)
    if not frame then return false, "missing frame" end
    if frame.IsForbidden and Read(frame.IsForbidden, frame) ~= false then return false, "forbidden frame" end
    if frame.CanBeAccessedInContext and Read(frame.CanBeAccessedInContext, frame) ~= true then return false, "object access restricted" end
    return true
end
local function Supported(frame)
    local usable, reason = Usable(frame)
    if not usable then return false, reason end
    if not frame.IsEventRegistered or not frame.UnregisterEvent
        or not frame.RegisterUnitEvent or not frame.RegisterEvent then return false, "event API missing" end
    local aspect = Enum and Enum.ForbiddenAspect and Enum.ForbiddenAspect.EventRegistrations
    if aspect and frame.HasAnyForbiddenAspects then
        if Read(frame.HasAnyForbiddenAspects, frame, aspect) ~= false then return false, "event access restricted" end
    elseif frame.IsProtected and Read(frame.IsProtected, frame) ~= false then
        return false, "event permissions unavailable"
    end
    return true
end
local function Enabled()
    return A.db and A.db.enabled and A.db.targetOnlyVitals and not A.nativePlateTest
end
local function ShouldPause(unit)
    if not Enabled() or not Token(unit) or Read(UnitExists, unit) ~= true then return false end
    if Read(UnitIsUnit, unit, "player") ~= false or Read(UnitIsUnit, unit, "target") ~= false then return false end
    -- Require readable friendliness and attackability; ambiguous/secret units
    -- retain native updates. Includes friendly NPCs and friendly players.
    return Read(UnitIsFriend, "player", unit) == true and Read(UnitCanAttack, "player", unit) == false
end
local function SaveAndPause(frame, state, event, isUnitEvent)
    local result = {pcall(frame.IsEventRegistered, frame, event)}
    if not result[1] or not Public(result[2]) then return false end
    if result[2] ~= true then return true end
    local units = {}
    for i = 3, #result do
        if not Public(result[i]) then return false end
        units[#units + 1] = result[i]
    end
    state.events[event] = {units = units, isUnitEvent = isUnitEvent}
    local ok = pcall(frame.UnregisterEvent, frame, event)
    return ok and Read(frame.IsEventRegistered, frame, event) == false
end
local function Release(frame)
    local state = paused[frame]
    if not state then return true end
    if not Supported(frame) then state.releasing = true; return false end
    state.releasing = true
    local sameUnit = Public(frame.unit) and frame.unit == state.unit
    for event, saved in pairs(state.events) do
        -- Never reattach a former unit's subscriptions to a recycled frame.
        -- OnUnitCleared restores the global level events; SetUnit registers
        -- the new unit's own subscriptions on its next acquisition.
        if saved.isUnitEvent and not sameUnit then
            state.events[event] = nil
        else
            if Read(frame.IsEventRegistered, frame, event) == false then
                if #saved.units > 0 then pcall(frame.RegisterUnitEvent, frame, event, unpack(saved.units))
                else pcall(frame.RegisterEvent, frame, event) end
            end
            if Read(frame.IsEventRegistered, frame, event) == true then state.events[event] = nil end
        end
    end
    if next(state.events) then return false end
    for i = #state.regions, 1, -1 do
        if A.ReleaseNativeRegion(state, state.regions[i]) then table.remove(state.regions, i) end
    end
    if #state.regions > 0 then return false end
    paused[frame] = nil
    -- Restore subscriptions only. Calling a native handler from addon Lua
    -- taints its execution; even pcall cannot make secret health comparisons
    -- safe in TextStatusBar callbacks invoked by that handler. Blizzard must
    -- dispatch its own updates. Our custom target bar initializes independently.
    return true
end
local Sync
Sync = function(frame, registration)
    if not Supported(frame) then return end
    local unit = frame.unit
    local state = paused[frame]
    if state and (state.releasing or not Public(unit) or unit ~= state.unit) then
        if not Release(frame) then return end
        state = nil
    end
    if not Token(unit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not Usable(plate) or plate.UnitFrame ~= frame then Release(frame); return end
    if not ShouldPause(unit) then
        Release(frame)
        return
    end
    if state and not registration then return end
    if failures[frame] then return end
    if not state then
        state = {unit = unit, events = {}, regions = {}}
        paused[frame] = state
    end
    for _, list in ipairs({unitEvents, levelEvents}) do
        for _, event in ipairs(list) do
            if not SaveAndPause(frame, state, event, list == unitEvents) then
                failures[frame] = "event operation rejected"
                Release(frame)
                return
            end
        end
    end
    -- Count a plate as paused only after subscriptions actually changed.
    if not next(state.events) then Release(frame); return end
    if #state.regions == 0 then
        for _, key in ipairs(regions) do
            if frame[key] then
                if not A.SuppressNativeRegion(state, frame[key]) then
                    failures[frame] = "visual access restricted"
                    Release(frame)
                    return
                end
                state.regions[#state.regions + 1] = frame[key]
            end
        end
    end
    if not hooked[frame] and frame.OnUnitCleared then
        hooked[frame] = true
        hooksecurefunc(frame, "OnUnitCleared", function(self) Release(self) end)
    end
end
function A.RefreshVitals()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    -- Also releases pooled/hidden states when disabling the feature.
    if not Enabled() then
        for frame in pairs(paused) do Release(frame) end
        return
    end
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        if Usable(plate) and plate.UnitFrame then Sync(plate.UnitFrame) end
    end
end
function A.GetVitalsStatus()
    local count, unavailable, pending, reasons = 0, 0, 0, {}
    for _, state in pairs(paused) do
        if state.releasing then pending = pending + 1
        elseif next(state.events) then count = count + 1 end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in pairs(C_NamePlate.GetNamePlates()) do
            local ok, reason = Usable(plate)
            if ok then ok, reason = Supported(plate.UnitFrame) end
            if ok and failures[plate.UnitFrame] then ok, reason = false, failures[plate.UnitFrame] end
            if not ok then unavailable = unavailable + 1; reasons[reason] = (reasons[reason] or 0) + 1 end
        end
    end
    local mode = "OFF"
    if A.db and A.db.enabled and A.db.targetOnlyVitals then
        if not installed then mode = "UNAVAILABLE"
        elseif A.nativePlateTest then mode = "SUSPENDED (compare)"
        elseif count > 0 then mode = "ACTIVE"
        else mode = "ENABLED, INACTIVE" end
    end
    return {mode = mode, paused = count, skipped = unavailable, pending = pending, reasons = reasons}
end
function A.PrintVitals()
    local status = A.GetVitalsStatus()
    print(string.format("Forever Names %s: target-only vitals %s; %d plates paused; %d skipped; %d restorations pending.", A.version or "", status.mode, status.paused, status.skipped, status.pending))
    local details = {}
    for reason, count in pairs(status.reasons) do details[#details + 1] = reason .. ": " .. count end
    table.sort(details)
    if #details > 0 then print("Forever Names: skipped - " .. table.concat(details, "; ") .. ".") end
    print("Forever Names: /fnames vitals reports status; /fnames vitals off disables; /fnames vitals on enables.")
end
local function Install()
    if installed or not CompactUnitFrame_UpdateUnitEvents then return end
    installed = true
    -- Reapply after Blizzard legitimately re-registers events (including Show).
    hooksecurefunc("CompactUnitFrame_UpdateUnitEvents", function(frame) Sync(frame, true) end)
    if NamePlateDriverFrame and NamePlateDriverFrame.OnNamePlateAdded then
        hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
            if not Token(unit) then return end
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if Usable(plate) and plate.UnitFrame then Sync(plate.UnitFrame) end
        end)
    end
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_FACTION"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == "Blizzard_NamePlates" then Install() end
    elseif event == "PLAYER_LOGIN" then
        Install(); A.RefreshVitals()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        for frame, state in pairs(paused) do
            if Public(unit) and state.unit == unit then Release(frame) end
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if not Token(unit) then return end
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if Usable(plate) and plate.UnitFrame then Sync(plate.UnitFrame) end
    elseif event == "UNIT_FACTION" then
        -- A burst of unit faction events must not repeatedly scan/register the
        -- whole crowd. Only a change to our own faction affects every plate.
        if not Public(unit) then return end
        if unit == "player" then A.RefreshVitals()
        elseif Token(unit) then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if Usable(plate) and plate.UnitFrame then Sync(plate.UnitFrame) end
        elseif type(unit) == "string" then
            for _, plate in pairs(C_NamePlate.GetNamePlates()) do
                if Usable(plate) and plate.UnitFrame and Supported(plate.UnitFrame)
                    and Token(plate.UnitFrame.unit) and Read(UnitIsUnit, plate.UnitFrame.unit, unit) == true then
                    Sync(plate.UnitFrame)
                end
            end
        end
    else
        A.RefreshVitals()
    end
end)
