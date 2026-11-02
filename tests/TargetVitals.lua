-- Event delivery and recycled-frame regression tests; not an in-game FPS test.
local root = "Interface/AddOns/ForeverNames/"
local A = {db = {enabled = true, targetOnlyVitals = true}}
local frames, plates, units = {}, {}, {}
local assertions, healthReads, levelReads, combat = 0, 0, 0, false
local engineDispatch, addonHandlerCalls = false, 0
local function check(value, label) assertions = assertions + 1; assert(value, label) end
local function equal(a, b, label) check(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local secret = {}
function issecretvalue(value) return value == secret end
function InCombatLockdown() return combat end
Enum = {ForbiddenAspect = {EventRegistrations = 16, ScriptBindings = 2}}
function UnitExists(unit) return units[unit] ~= nil end
function UnitIsFriend(_, unit) return units[unit] and units[unit].friendly end
function UnitCanAttack(_, unit) return units[unit] and units[unit].hostile == true end
function UnitIsUnit(a, b) return units[a] ~= nil and units[a] == units[b] end
function UnitHealth(unit) healthReads = healthReads + 1; return units[unit].health end
function UnitLevel(unit) levelReads = levelReads + 1; return units[unit].level end
local M = {}; M.__index = M
local function object()
    local frame = setmetatable({events = {}, scripts = {}, alpha = 1}, M)
    frames[#frames + 1] = frame
    return frame
end
function M:RegisterEvent(event) self.events[event] = {} end
function M:RegisterUnitEvent(event, ...)
    if self.rejectRegister then return false end
    self.events[event] = {...}
end
function M:UnregisterEvent(event)
    if self.rejectUnregister == event then return false end
    self.events[event] = nil
end
function M:IsEventRegistered(event)
    local registration = self.events[event]
    if registration then return true, unpack(registration) end
    return false
end
function M:SetScript(script, callback) self.scripts[script] = callback end
function M:GetScript(script) return self.scripts[script] end
function M:IsForbidden() return self.forbidden or false end
function M:IsProtected() return self.protected or false end
function M:CanBeAccessedInContext() return not self.accessDenied end
function M:HasAnyForbiddenAspects(aspect)
    if aspect == Enum.ForbiddenAspect.EventRegistrations then return self.eventsForbidden or false end
    return false
end
function M:GetAlpha() return self.alpha end
function M:SetAlpha(value) self.alpha = value end
function CreateFrame() return object() end
function hooksecurefunc(objectOrName, key, callback)
    local owner = objectOrName
    if type(owner) == "string" then owner, key, callback = _G, owner, key end
    local original = assert(owner[key])
    owner[key] = function(...) original(...); callback(...) end
end
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plates[unit] end,
    GetNamePlates = function() return plates end,
}
local trackedEvents = {"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
    "UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "UNIT_LEVEL"}
function CompactUnitFrame_UpdateUnitEvents(frame)
    for _, event in ipairs(trackedEvents) do frame:RegisterUnitEvent(event, frame.unit, frame.alias) end
    frame:RegisterUnitEvent("UNIT_NAME_UPDATE", frame.unit)
    frame:RegisterUnitEvent("UNIT_FACTION", frame.unit, "player")
    frame:RegisterUnitEvent("UNIT_AURA", frame.unit)
end
NamePlateDriverFrame = {OnNamePlateAdded = function() end}
assert(loadfile(root .. "NativeRenderer.lua"))("ForeverNames", A)
assert(loadfile(arg[1] or (root .. "NativeVitals.lua")))("ForeverNames", A)
local driver = frames[#frames]
local function driverEvent(event, unit) driver.scripts.OnEvent(driver, event, unit) end
driverEvent("PLAYER_LOGIN")
local function handler(frame, event)
    -- A pcall can swallow a Lua error without preventing tainted execution or
    -- errors in nested native StatusBar callbacks. Count attempts independently.
    if not engineDispatch then
        addonHandlerCalls = addonHandlerCalls + 1
        error("native handler invoked from addon context; secret health is unsafe")
    end
    if event == "UNIT_MAXHEALTH" or event == "UNIT_HEALTH" then
        frame.value = UnitHealth(frame.unit)
    elseif event == "UNIT_LEVEL" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_LEVEL_CHANGED" then
        frame.level = UnitLevel(frame.unit)
    end
end
local function add(unit, data, existing)
    units[unit] = data
    local plate, frame = object(), existing or object()
    plate.UnitFrame = frame; plates[unit] = plate; frame.unit = unit
    plate.protected = data.protectedPlate or false
    if not existing then
        for _, key in ipairs({"HealthBarsContainer", "LevelFrame", "PlayerLevelDiffFrame", "name", "SoftTargetFrame", "WidgetContainer"}) do frame[key] = object() end
        function frame:OnUnitCleared() self.unit = nil; self:SetScript("OnEvent", nil) end
        frame:RegisterEvent("PLAYER_LEVEL_UP"); frame:RegisterEvent("PLAYER_LEVEL_CHANGED")
    end
    frame:SetScript("OnEvent", handler)
    CompactUnitFrame_UpdateUnitEvents(frame)
    NamePlateDriverFrame:OnNamePlateAdded(unit)
    driverEvent("NAME_PLATE_UNIT_ADDED", unit)
    return frame, plate
end
local function deliver(event, unit)
    for _, plate in pairs(plates) do
        local frame = plate.UnitFrame
        local registration = frame.events[event]
        local accepts = registration and #registration == 0
        for _, token in ipairs(registration or {}) do if token == unit then accepts = true end end
        if accepts and frame.scripts.OnEvent then
            engineDispatch = true
            frame.scripts.OnEvent(frame, event, unit)
            engineDispatch = false
        end
    end
end
local function selectUnit(unit)
    units.target = units[unit]
    driverEvent("PLAYER_TARGET_CHANGED")
end
local function subscriptions(frame, expected, label)
    for _, event in ipairs(trackedEvents) do equal(frame:IsEventRegistered(event), expected, label .. " " .. event) end
    for _, event in ipairs({"PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED"}) do equal(frame:IsEventRegistered(event), expected, label .. " " .. event) end
end
local npc = add("nameplate1", {friendly = true, health = 100, level = 10, protectedPlate = true})
local player = add("nameplate2", {friendly = true, player = true, health = 200, level = 20})
local enemy = add("nameplate3", {friendly = false, hostile = true, health = 300, level = 30})
subscriptions(npc, false, "friendly NPC paused")
subscriptions(player, false, "friendly player paused")
subscriptions(enemy, true, "enemy untouched")
-- Native plate containers may be layout-protected while their event APIs and
-- child alpha controls remain accessible. v1.3.0 rejected the whole plate.
plates.nameplate1.protected = true
driverEvent("PLAYER_TARGET_CHANGED")
subscriptions(npc, false, "protected outer plate does not block child event filtering")
equal(npc.HealthBarsContainer.alpha, 0, "unselected NPC bar hidden")
equal(player.LevelFrame.alpha, 0, "unselected player level hidden")
equal(enemy.HealthBarsContainer.alpha, 1, "enemy bar retained")
for _, region in ipairs({"name", "SoftTargetFrame", "WidgetContainer"}) do equal(npc[region].alpha, 1, region .. " retained") end
for _, event in ipairs({"UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_AURA"}) do equal(npc:IsEventRegistered(event), true, event .. " retained") end
local beforeHealth, beforeLevel = healthReads, levelReads
for i = 1, 200 do
    deliver("UNIT_HEALTH", "nameplate1"); deliver("UNIT_MAXHEALTH", "nameplate2")
    deliver("UNIT_LEVEL", "nameplate1"); deliver("UNIT_LEVEL", "nameplate2")
end
equal(healthReads, beforeHealth, "friendly event burst causes no health reads")
equal(levelReads, beforeLevel, "friendly event burst causes no level reads")
selectUnit("nameplate1")
subscriptions(npc, true, "selected NPC restored")
subscriptions(player, false, "other friendly player remains paused")
equal(addonHandlerCalls, 0, "selection must not call native handlers from addon context")
equal(healthReads, beforeHealth, "selection restoration does not run native health queries")
equal(levelReads, beforeLevel, "selection restoration does not run native level queries")
deliver("UNIT_MAXHEALTH", "nameplate1"); deliver("UNIT_LEVEL", "nameplate1")
equal(npc.value, 100, "engine event refreshes selected health")
equal(npc.level, 10, "engine event refreshes selected level")
equal(npc.HealthBarsContainer.alpha, 1, "selection restores native health visibility")
units.nameplate1.health = 45; deliver("UNIT_HEALTH", "nameplate1")
equal(npc.value, 45, "selected health changes delivered")
selectUnit("nameplate2")
subscriptions(npc, false, "previous target paused")
subscriptions(player, true, "selected friendly player restored")
equal(addonHandlerCalls, 0, "friendly player selection never synthesizes native events")
deliver("UNIT_HEALTH", "nameplate2")
equal(player.value, 200, "native dispatch refreshes selected player health")
units.nameplate2.health = secret
selectUnit(nil); selectUnit("nameplate2")
equal(addonHandlerCalls, 0, "secret-health target can be restored without entering native handler")
deliver("UNIT_HEALTH", "nameplate2")
equal(player.value, secret, "secret health stays on native engine-dispatch path")
units.nameplate2.health = 200
units.nameplate2.level = 21; deliver("UNIT_LEVEL", "nameplate2")
equal(player.level, 21, "selected player new level")
selectUnit(nil)
subscriptions(player, false, "target clear pauses former target")
CompactUnitFrame_UpdateUnitEvents(npc)
subscriptions(npc, false, "native registration refresh remains filtered")
units.nameplate1.friendly = false; units.nameplate1.hostile = true
driverEvent("UNIT_FACTION", "nameplate1")
subscriptions(npc, true, "friendly-to-hostile restores events")
equal(npc.HealthBarsContainer.alpha, 1, "friendly-to-hostile restores bar")
units.nameplate1.friendly = true; units.nameplate1.hostile = false
driverEvent("UNIT_FACTION", "nameplate1")
subscriptions(npc, false, "hostile-to-friendly reapplies filter")

-- Shared alpha ownership must work in both orders (compare mode, disable, reuse).
local renderer = {}
A.SuppressNativeRegion(renderer, npc.HealthBarsContainer)
selectUnit("nameplate1")
equal(npc.HealthBarsContainer.alpha, 0, "NPC renderer retains bar suppression on selection")
A.ReleaseNativeRegion(renderer, npc.HealthBarsContainer)
equal(npc.HealthBarsContainer.alpha, 1, "last owner restores original alpha")
A.SuppressNativeRegion(renderer, npc.HealthBarsContainer)
selectUnit(nil)
A.ReleaseNativeRegion(renderer, npc.HealthBarsContainer)
equal(npc.HealthBarsContainer.alpha, 0, "vitals retain suppression after renderer release")
selectUnit("nameplate1")
equal(npc.HealthBarsContainer.alpha, 1, "reverse ownership order restores original alpha")
selectUnit(nil)
A.nativePlateTest = true; A.RefreshVitals()
subscriptions(npc, true, "comparison is unmodified native baseline")
equal(npc.HealthBarsContainer.alpha, 1, "compare restores bars")
A.nativePlateTest = false; A.RefreshVitals()
subscriptions(npc, false, "leaving compare resumes filter")
A.db.targetOnlyVitals = false; A.RefreshVitals()
subscriptions(player, true, "off switch restores player events")
equal(player.LevelFrame.alpha, 1, "off restores player level")
A.db.targetOnlyVitals = true; A.RefreshVitals()

-- OnUnitCleared must release global events, without restoring stale unit tokens.
plates.nameplate1 = nil; npc:OnUnitCleared(); units.nameplate1 = nil
equal(npc:IsEventRegistered("PLAYER_LEVEL_UP"), true, "pooled global level event restored")
equal(npc:IsEventRegistered("UNIT_HEALTH"), false, "old unit event not resurrected after clear")
local reused = add("nameplate8", {friendly = false, hostile = true, health = 888, level = 80}, npc)
subscriptions(reused, true, "frame recycled for enemy restored")
deliver("UNIT_HEALTH", "nameplate8"); equal(reused.value, 888, "reused enemy receives new unit health")
equal(reused.events.UNIT_HEALTH[1], "nameplate8", "no old unit binding on reuse")

-- Event-first removal order is also valid, and original filters survive restore.
local friend = add("nameplate9", {friendly = true, health = 900, level = 90})
friend.alias = "focus"; CompactUnitFrame_UpdateUnitEvents(friend)
selectUnit("nameplate9")
equal(friend.events.UNIT_HEALTH[2], "focus", "second original event filter preserved")
selectUnit(nil); driverEvent("NAME_PLATE_UNIT_REMOVED", "nameplate9")
friend:OnUnitCleared(); plates.nameplate9 = nil; units.nameplate9 = nil
equal(friend.HealthBarsContainer.alpha, 1, "event-first removal restores alpha")

local protected = add("nameplate10", {friendly = true, health = 100, level = 1})
A.db.targetOnlyVitals = false; A.RefreshVitals(); protected.protected = true
A.db.targetOnlyVitals = true; A.RefreshVitals()
subscriptions(protected, false, "layout protection does not forbid permitted event updates")
protected.HealthBarsContainer.protected = true
combat = true; selectUnit("nameplate10")
subscriptions(protected, true, "permitted protected-frame events restore on selection in combat")
equal(protected.HealthBarsContainer.alpha, 1, "permitted alpha restores in combat")
selectUnit(nil)
subscriptions(protected, false, "permitted protected-frame events pause on deselection in combat")
combat = false
local forbidden = add("nameplate11", {friendly = true, health = 100, level = 1})
A.db.targetOnlyVitals = false; A.RefreshVitals(); forbidden.forbidden = true
A.db.targetOnlyVitals = true; A.RefreshVitals()
subscriptions(forbidden, true, "forbidden frame untouched")
local unreadable = add("nameplate12", {friendly = secret, health = 100, level = 1})
subscriptions(unreadable, true, "secret friendliness leaves native updates")
local personal = add("nameplate13", {friendly = true, health = 100, level = 1})
units.player = units.nameplate13; A.RefreshVitals()
subscriptions(personal, true, "personal resource display excluded")
local raid = object(); raid.unit = "party1"; CompactUnitFrame_UpdateUnitEvents(raid)
equal(raid:IsEventRegistered("UNIT_HEALTH"), true, "party frame untouched")
local selectedData = {friendly = true, health = 500, level = 50}
units.target = selectedData
local selectedArrival = add("nameplate14", selectedData)
subscriptions(selectedArrival, true, "already selected unit arriving remains native")
equal(selectedArrival.HealthBarsContainer.alpha, 1, "already selected arrival keeps health visible")
equal(selectedArrival:GetScript("OnEvent"), handler, "native event handler not replaced")
local writes = healthReads
driverEvent("PLAYER_TARGET_CHANGED"); driverEvent("PLAYER_TARGET_CHANGED")
equal(healthReads, writes, "repeated selection event does not refresh unchanged target")

-- Actual access restrictions still take precedence over layout protection.
local blocked = add("nameplate15", {friendly = true, health = 100, level = 1})
selectUnit("nameplate15"); blocked.eventsForbidden = true
selectUnit(nil)
subscriptions(blocked, true, "event-forbidden frame remains native")
equal(A.GetVitalsStatus().reasons["event access restricted"], 1, "specific event-permission reason reported")
local denied = add("nameplate16", {friendly = true, health = 100, level = 1})
selectUnit("nameplate16"); denied.accessDenied = true
selectUnit(nil)
subscriptions(denied, true, "context-inaccessible frame remains native")
local rejected = add("nameplate17", {friendly = true, health = 100, level = 1})
selectUnit("nameplate17"); rejected.rejectUnregister = "UNIT_LEVEL"
selectUnit(nil)
subscriptions(rejected, true, "failed pause rolls back already-unregistered events")
equal(rejected.HealthBarsContainer.alpha, 1, "failed pause does not hide a native bar")
equal(A.GetVitalsStatus().reasons["event operation rejected"], 1, "failed mutation reported")
local pending = add("nameplate18", {friendly = true, health = 100, level = 1})
pending.rejectRegister = true; selectUnit("nameplate18")
equal(A.GetVitalsStatus().pending, 1, "failed restoration retains ownership for retry")
pending.rejectRegister = nil; A.RefreshVitals()
equal(A.GetVitalsStatus().pending, 0, "restoration retried successfully")
subscriptions(pending, true, "target restored after temporary registration failure")
equal(pending.HealthBarsContainer.alpha, 1, "successful restoration restores visuals")
A.db.enabled = false; A.RefreshVitals()
subscriptions(player, true, "addon disable restores subscriptions")
equal(A.GetVitalsStatus().mode, "OFF", "off status reflects configuration")
equal(A.GetVitalsStatus().paused, 0, "off leaves no successfully paused plates")
A.db.enabled = true; A.RefreshVitals()
equal(A.GetVitalsStatus().mode, "ACTIVE", "active status requires actual paused plates")
local realPlates = plates; plates = {}
A.db.targetOnlyVitals = false; A.RefreshVitals()
A.db.targetOnlyVitals = true; A.RefreshVitals()
equal(A.GetVitalsStatus().mode, "ENABLED, INACTIVE", "enabled without changed subscriptions is not active")
plates = realPlates
for _, frame in ipairs(frames) do equal(frame.scripts.OnUpdate, nil, "no polling loop installed") end
equal(addonHandlerCalls, 0, "selection, compare, disable, rollback and recycling never call native handlers")
print("PASS: " .. assertions .. " target-only vitals assertions; subscriptions restored without addon-driven native handlers.")
