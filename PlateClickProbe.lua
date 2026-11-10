local _, A = ...
-- TEMPORARY probe for the camera-drag bug. The 1.16.0 setting (PlateClicks.lua)
-- changed nothing in game, so this measures instead of guessing. It does
-- nothing until /fnames clicks is typed, and it is gone after a reload.
--   /fnames clicks      what the game reports for the nameplate under the mouse
--   /fnames clicks 1    test: clear every plate's clickable area
--   /fnames clicks 2    test: move every plate's clickable area off the plate
--   /fnames clicks 3    test: shrink the clickable area with the game-wide insets
--   /fnames clicks 0    stop the test, the game's own areas come back
-- After the first command every left/right press is recorded too (what was
-- under the mouse, and half a second later whether the camera took the drag).
-- Everything goes to chat and to ForeverNamesDB.clickProbe, which is written
-- to disk on /reload. Remove this file once the cause is known.
local armed, test, hooked = false, 0, {}
local METHODS = {"CanChangeHitTestPoints", "GetHitTestPoints", "ClearAllHitTestPoints", "SetHitTestPoints", "SetAllHitTestPoints"}
local KINDS = {{"Friendly", 0}, {"Enemy", 1}} -- Enum.NamePlateType
local LABEL = {"clickable areas cleared", "clickable areas moved off the plates", "clickable areas shrunk to nothing with the insets"}

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) end
local function S(value) if Secret(value) then return "<secret>" end return tostring(value) end
local function N(value)
    if Secret(value) or type(value) ~= "number" then return S(value) end
    return string.format("%.1f", value)
end
local function Try(func, ...)
    if type(func) ~= "function" then return false, "no such function" end
    return pcall(func, ...)
end
local function Flag(object, method)
    local ok, value = Try(object[method], object)
    return ok and S(value) or "?"
end
local function Name(region)
    if region == nil then return "nil" end
    if Secret(region) then return "<secret>" end
    if type(region) ~= "table" then return tostring(region) end
    local ok, name = pcall(function()
        if region.IsForbidden and region:IsForbidden() then return "<forbidden>" end
        return region.GetDebugName and region:GetDebugName() or region.GetName and region:GetName()
    end)
    return ok and name and S(name) or "<unnamed>"
end
local function Rect(region)
    if type(region) ~= "table" or type(region.GetRect) ~= "function" then return "" end
    local ok, left, bottom, width, height = pcall(region.GetRect, region)
    if not ok then return " rect=?" end
    return " rect=" .. N(left) .. "," .. N(bottom) .. " " .. N(width) .. "x" .. N(height)
end

local function Log(text, quiet)
    local db = A.db
    if db then
        local lines = type(db.clickProbe) == "table" and db.clickProbe or {}
        db.clickProbe = lines
        lines[#lines + 1] = (date and date("%H:%M:%S ") or "") .. text
        while #lines > 400 do table.remove(lines, 1) end
    end
    if not quiet then print("|cff7fd4ffFN probe|r " .. text) end
end
local function Safe(func, ...)
    local ok, err = pcall(func, ...)
    if not ok then Log("probe error: " .. S(err)) end
end

local function Plates()
    local ok, list = Try(C_NamePlate and C_NamePlate.GetNamePlates)
    return ok and type(list) == "table" and list or {}
end
local function Over(region)
    if type(region) ~= "table" or type(region.IsMouseOver) ~= "function" then return false end
    local ok, over = pcall(region.IsMouseOver, region)
    return ok and not Secret(over) and over == true
end
local function Points(plate)
    local ok, points = Try(plate.GetHitTestPoints, plate)
    if not ok or Secret(points) or type(points) ~= "table" then return nil, S(points) end
    return points
end
local function Unit(plate)
    local token = plate.namePlateUnitToken
    if token == nil and plate.UnitFrame then token = plate.UnitFrame.unit end
    return S(token)
end
local function Foci()
    local ok, list = false, nil
    if GetMouseFoci then ok, list = pcall(GetMouseFoci)
    elseif GetMouseFocus then ok, list = pcall(GetMouseFocus); list = {list} end
    if not ok or type(list) ~= "table" then return "?" end
    local names = {}
    for index, frame in ipairs(list) do names[index] = Name(frame) end
    return #names > 0 and table.concat(names, ", ") or "nothing"
end

local function Describe(plate)
    local frame = plate.UnitFrame
    local state = frame and A.RenderStates and A.RenderStates[frame]
    Log(("plate %s unit=%s ours=%s%s mouse=%s frameMouse=%s onlyName=%s widgetsOnly=%s"):format(
        Name(plate), Unit(plate), state and (state.keepBars and "bars" or "label") or "no", Rect(plate),
        Flag(plate, "IsMouseEnabled"), frame and Flag(frame, "IsMouseEnabled") or "-",
        frame and Flag(frame, "IsShowOnlyName") or "-", S(frame and frame.widgetsOnlyMode)))
    local missing = {}
    for _, method in ipairs(METHODS) do
        if type(plate[method]) ~= "function" then missing[#missing + 1] = method end
    end
    if #missing > 0 then Log("  missing on this plate: " .. table.concat(missing, ", ")) end
    local ok, can = Try(plate.CanChangeHitTestPoints, plate)
    local points, err = Points(plate)
    Log("  can change=" .. (ok and S(can) or "error " .. S(can)) .. " hit points=" .. (points and #points or "error " .. err))
    for _, point in ipairs(points or {}) do
        Log(("  %s -> %s %s (%s, %s)%s"):format(S(point.point), Name(point.relativeTo), S(point.relativePoint),
            N(point.offsetX), N(point.offsetY), Rect(point.relativeTo)))
    end
end

local function Report()
    local db = A.db
    local count, under = 0, {}
    for _, plate in pairs(Plates()) do
        count = count + 1
        if Over(plate) then under[#under + 1] = plate end
    end
    Log(("Forever Names %s setting=%s enabled=%s test=%d combat=%s plates=%d"):format(
        S(A.version), S(db.plateClicks), S(db.enabled), test, S(InCombatLockdown and InCombatLockdown()), count))
    local manager, insets = C_NamePlateManager, {}
    for _, kind in ipairs(KINDS) do
        local value = Enum and Enum.NamePlateType and Enum.NamePlateType[kind[1]] or kind[2]
        local ok, left, right, top, bottom = Try(manager and manager.GetNamePlateHitTestInsets, value)
        insets[#insets + 1] = kind[1] .. "=" .. (ok and table.concat({N(left), N(right), N(top), N(bottom)}, ",") or "error " .. S(left))
    end
    Log("insets " .. table.concat(insets, " ") .. " set=" .. type(manager and manager.SetNamePlateHitTestInsets))
    Log("under the mouse: " .. Foci() .. "; mouseover unit=" .. S(UnitExists and UnitExists("mouseover")))
    if #under == 0 then
        Log("no nameplate under the mouse; the first plates instead:")
        for _, plate in pairs(Plates()) do
            if #under == 2 then break end
            under[#under + 1] = plate
        end
    end
    for _, plate in ipairs(under) do Safe(Describe, plate) end
end

-- Test 2: an area above the plate. The game clamps hit testing to the plate.
local function Away(plate)
    return {
        {point = "TOPLEFT", relativeTo = plate, relativePoint = "TOPLEFT", offsetX = 0, offsetY = 5001},
        {point = "BOTTOMRIGHT", relativeTo = plate, relativePoint = "TOPRIGHT", offsetX = 0, offsetY = 5000},
    }
end
local function Remove(plate)
    if test == 1 then return Try(plate.ClearAllHitTestPoints, plate) end
    if test == 2 then return Try(plate.SetHitTestPoints, plate, Away(plate)) end
    return true
end
-- Blizzard sets its area again whenever a plate's options change.
local function Hook(frame)
    if not frame or hooked[frame] or type(frame.UpdateHitTestArea) ~= "function" then return end
    hooked[frame] = true
    hooksecurefunc(frame, "UpdateHitTestArea", function(self)
        if test ~= 1 and test ~= 2 then return end
        local ok, plate = Try(self.GetNamePlateFrame, self)
        if ok and plate then Remove(plate) end
    end)
end
local function ApplyAll(report)
    local done, failed, reasons, left = 0, 0, {}, 0
    for _, plate in pairs(Plates()) do
        Hook(plate.UnitFrame)
        local ok, err = Remove(plate)
        if ok then
            done = done + 1
        else
            failed = failed + 1
            err = S(err)
            if not reasons[err] then reasons[err] = true; reasons[#reasons + 1] = err end
        end
        local points = Points(plate)
        if test == 1 and points and #points > 0 then left = left + 1 end
    end
    if report or failed > 0 then
        Log(("  %d plates changed, %d refused%s%s"):format(done, failed,
            failed > 0 and " (" .. table.concat(reasons, "; ") .. ")" or "",
            test == 1 and "; " .. left .. " still report an area" or ""), not report)
    end
end

local function Insets(on)
    local db, manager = A.db, C_NamePlateManager
    if not manager or type(manager.SetNamePlateHitTestInsets) ~= "function" then
        if on then Log("  this game has no SetNamePlateHitTestInsets") end
        return
    end
    for _, kind in ipairs(KINDS) do
        local name = kind[1]
        local value = Enum and Enum.NamePlateType and Enum.NamePlateType[name] or kind[2]
        if on then
            db.clickProbeInsets = db.clickProbeInsets or {}
            if not db.clickProbeInsets[name] then
                local ok, left, right, top, bottom = Try(manager.GetNamePlateHitTestInsets, value)
                local known = ok and type(left) == "number" and not Secret(left)
                db.clickProbeInsets[name] = known and {left, right, top, bottom} or {0, 0, 0, 0}
            end
            local ok, err = Try(manager.SetNamePlateHitTestInsets, value, 10000, 10000, 10000, 10000)
            Log("  " .. name .. " insets: " .. (ok and "accepted" or "REFUSED " .. S(err)))
        elseif db.clickProbeInsets and db.clickProbeInsets[name] then
            local saved = db.clickProbeInsets[name]
            local ok, err = Try(manager.SetNamePlateHitTestInsets, value, saved[1], saved[2], saved[3], saved[4])
            if ok then db.clickProbeInsets[name] = nil else Log("  " .. name .. " insets not restored: " .. S(err)) end
        end
    end
    if not on and db.clickProbeInsets and next(db.clickProbeInsets) == nil then db.clickProbeInsets = nil end
end

local function Restore()
    local was = test
    test = 0
    if A.db.clickProbeInsets then Insets(false) end
    if was ~= 1 and was ~= 2 then return end
    local failed, firstError = 0, nil
    for _, plate in pairs(Plates()) do
        local frame = plate.UnitFrame
        if frame then
            local ok, err = Try(frame.UpdateHitTestArea, frame, NamePlateSetupOptions)
            if not ok then failed = failed + 1; firstError = firstError or S(err) end
        end
    end
    if failed > 0 then Log(("  %d plates did not get their area back (%s)"):format(failed, firstError)) end
end

local function Begin(number)
    Restore()
    test = number
    Log("test " .. number .. ": " .. LABEL[number])
    if number == 3 then Insets(true) else ApplyAll(true) end
    Log("now drag the camera, starting on a nameplate")
end
local function Start(number)
    if number == 0 then
        Restore()
        Log("test off: the nameplates are as the game sets them")
    elseif A.db.plateClicks ~= "all" and A.SetOption then
        -- PlateClicks.lua would put areas back while the plates refresh.
        A.SetOption("plateClicks", "all")
        Log('"Click to select" put back to "Names and bars" for the test; starting in a second')
        C_Timer.After(1, function() Safe(Begin, number) end)
    else
        Begin(number)
    end
end

local function Cursor()
    if not GetCursorPosition then return 0, 0 end
    local ok, x, y = pcall(GetCursorPosition)
    if not ok or type(x) ~= "number" or type(y) ~= "number" or Secret(x) or Secret(y) then return 0, 0 end
    return x, y
end
local function Press(button)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    local x, y = Cursor()
    local under = {}
    for _, plate in pairs(Plates()) do
        if Over(plate) then
            local frame, points = plate.UnitFrame, Points(plate)
            local bar = frame and frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar
            under[#under + 1] = Unit(plate) .. " points=" .. (points and #points or "?")
                .. (frame and Over(frame.name) and " on-name" or "") .. (Over(bar) and " on-bar" or "")
        end
    end
    local where = (#under > 0 and "plate " .. table.concat(under, " + ") or "no plate")
        .. "; foci " .. Foci() .. "; unit=" .. S(UnitExists and UnitExists("mouseover"))
    C_Timer.After(0.5, function()
        Safe(function()
            local held = IsMouseButtonDown and IsMouseButtonDown(button)
            local x2, y2 = Cursor()
            local moved = math.abs(x2 - x) + math.abs(y2 - y) > 3
            local looking = IsMouselooking and IsMouselooking()
            Log(("%s test=%d on %s -> held=%s cursor moved=%s mouselook=%s"):format(
                button == "LeftButton" and "LEFT" or "RIGHT", test, where, S(held), S(moved), S(looking)))
        end)
    end)
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, argument)
    if event == "GLOBAL_MOUSE_DOWN" then
        Safe(Press, argument)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if test == 1 or test == 2 then C_Timer.After(0, function() Safe(ApplyAll) end) end
    elseif event == "PLAYER_LOGIN" then
        -- A reload in the middle of test 3: put the game's insets back.
        if A.db and A.db.clickProbeInsets then Safe(Insets, false) end
    end
end)
pcall(watcher.RegisterEvent, watcher, "PLAYER_LOGIN")
local function Arm()
    if armed then return end
    armed = true
    A.db.clickProbe = nil -- one session per log
    pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN")
    pcall(watcher.RegisterEvent, watcher, "NAME_PLATE_UNIT_ADDED")
end

function A.PlateClickProbe(argument)
    if not A.db then return end
    Arm()
    argument = argument and argument:lower() or ""
    if argument == "" then
        Safe(Report)
    elseif argument == "0" or argument == "1" or argument == "2" or argument == "3" then
        Safe(Start, tonumber(argument))
    else
        print("Forever Names: /fnames clicks (report), /fnames clicks 1, 2 or 3 (tests), /fnames clicks 0 (stop the test).")
    end
end
