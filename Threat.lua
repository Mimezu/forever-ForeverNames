local _, A = ...
-- Threat on enemy plates (Blizzard's own plates; we only add to them), for a
-- tank in a group:
--  * on you: a thin line under the health bar, as long as your lead over the
--    next one (full at 160 %), iron when safe, amber then ember as a DPS or
--    healer closes in;
--  * on someone else: a red halo round the bar, the line red showing how
--    close you are to taking it back, and who it hits, in their class color.
-- Mobs not fighting your group show nothing. Event-driven: threat, target and
-- plate events only, no OnUpdate.
-- Threat between you and a plate is not secret, Blizzard says, except
-- sometimes (bosses). Then the line still fills and the halo still shows,
-- through the widget calls that take secret values; only the colors and the
-- name wait.
A.defaults.threat = false
A.defaults.threatLine = true
A.defaults.threatGlow = true
A.defaults.threatWho = true
A.defaults.threatSolo = false

local GLOW = "Interface\\AddOns\\ForeverNames\\Media\\threat_glow.tga"
local BAR = "Interface\\Buttons\\WHITE8X8"
local FULL = 160 -- lead % that fills the line
local IRON, AMBER, EMBER = {0.70, 0.74, 0.80}, {1.00, 0.70, 0.22}, {1.00, 0.34, 0.12}
local LOOSE = {1.00, 0.16, 0.10}

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local marks = {} -- plate -> our frame
local tracked = {} -- unit -> plate

local function Wanted()
    local db = A.db
    if not db or not db.enabled or not db.threat then return false end
    return db.threatSolo or (IsInGroup and IsInGroup()) or false
end

local function Mark(plate)
    local mark = marks[plate]
    if mark then return mark end
    mark = CreateFrame("Frame", nil, plate)
    mark:EnableMouse(false)
    mark:SetAllPoints(plate)
    mark.glow = mark:CreateTexture(nil, "BACKGROUND")
    mark.glow:SetTexture(GLOW)
    mark.glow:SetBlendMode("ADD")
    mark.glow:SetVertexColor(LOOSE[1], LOOSE[2], LOOSE[3])
    mark.glow:Hide()
    -- A slow breath, not a flash.
    if mark.glow.CreateAnimationGroup then
        local breath = mark.glow:CreateAnimationGroup()
        breath:SetLooping("BOUNCE")
        local fade = breath:CreateAnimation("Alpha")
        fade:SetFromAlpha(1); fade:SetToAlpha(0.45); fade:SetDuration(0.9)
        if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
        mark.breath = breath
    end
    mark.line = CreateFrame("StatusBar", nil, mark)
    mark.line:SetStatusBarTexture(BAR)
    mark.line:SetMinMaxValues(100, FULL)
    mark.line.bg = mark.line:CreateTexture(nil, "BACKGROUND")
    mark.line.bg:SetAllPoints(mark.line)
    mark.line.bg:SetColorTexture(0, 0, 0, 0.55)
    mark.line:Hide()
    mark.who = mark:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
    if mark.who.SetTextHeight then mark.who:SetTextHeight(10) end
    mark.who:Hide()
    marks[plate] = mark
    return mark
end

-- Under Blizzard's health bar, or under the plate's middle without one.
local function Place(mark, frame)
    local bar = frame and frame.HealthBarsContainer
    if mark.anchor == bar and mark.anchor ~= nil then return end
    mark.anchor = bar
    local line, glow, who = mark.line, mark.glow, mark.who
    line:ClearAllPoints(); glow:ClearAllPoints(); who:ClearAllPoints()
    if bar then
        line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
        line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
        -- The halo texture holds the bar in its middle 160 x 16 of 256 x 64.
        local ok, w, h = pcall(function() return bar:GetWidth(), bar:GetHeight() end)
        if not ok or not Public(w) or not Public(h) or type(w) ~= "number" or w <= 0 then w, h = 100, 10 end
        glow:SetSize(w * 256 / 160, math.max(h, 6) * 64 / 16)
        glow:SetPoint("CENTER", bar, "CENTER", 0, 0)
    else
        line:SetSize(80, 2)
        line:SetPoint("TOP", mark, "CENTER", 0, -4)
        glow:SetSize(128, 40)
        glow:SetPoint("CENTER", mark, "CENTER", 0, 0)
    end
    line:SetHeight(2)
    who:SetPoint("TOP", line, "BOTTOM", 0, -2)
end

local function Clear(mark)
    if not mark then return end
    mark.glow:Hide(); mark.line:Hide(); mark.who:Hide()
    if mark.breath and mark.breath:IsPlaying() then mark.breath:Stop() end
end

local function Glow(mark, shown, alpha)
    local db = A.db
    if not db.threatGlow or shown == false then
        mark.glow:Hide()
        if mark.breath and mark.breath:IsPlaying() then mark.breath:Stop() end
        return
    end
    mark.glow:Show()
    -- A secret "is it on me": the halo's opacity follows it without Lua
    -- reading it (and without the breath, which would set it again).
    if alpha ~= nil then
        if mark.breath and mark.breath:IsPlaying() then mark.breath:Stop() end
        if not Call(mark.glow.SetAlphaFromBoolean, mark.glow, alpha, 0, 1) then mark.glow:Hide() end
        return
    end
    mark.glow:SetAlpha(1)
    if mark.breath and not mark.breath:IsPlaying() then mark.breath:Play() end
end

local function Who(mark, unit)
    if not A.db.threatWho then mark.who:Hide(); return end
    local target = unit .. "target"
    local ok, name = Call(UnitName, target)
    if not ok or type(name) ~= "string" or not Public(name) or name == "" then mark.who:Hide(); return end
    local r, g, b = 1, 1, 1
    local okClass, _, class = Call(UnitClass, target)
    if okClass and Public(class) and type(class) == "string" then
        local color = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        if color then r, g, b = color.r, color.g, color.b end
    end
    mark.who:SetText("\226\134\146 " .. name) -- "→ name"
    mark.who:SetTextColor(r, g, b)
    mark.who:Show()
end

-- It attacks one of you (not you): a mob you never touched is not on your
-- threat list, yet it is loose.
local function HitsGroup(unit)
    local target = unit .. "target"
    local okMe, me = Call(UnitIsUnit, target, "player")
    if not okMe or not Public(me) or me then return false end
    for _, fn in ipairs({UnitPlayerOrPetInParty, UnitPlayerOrPetInRaid}) do
        local ok, yes = Call(fn, target)
        if ok and Public(yes) and yes then return true end
    end
    return false
end

local function LineColor(lead, status)
    if status == 2 or lead < 110 then return EMBER end
    if lead < 130 then return AMBER end
    return IRON
end

function A.UpdateThreat(unit)
    local plate = tracked[unit]
    if not plate then return end
    if not Wanted() then Clear(marks[plate]); return end
    local frame = not (plate.IsForbidden and plate:IsForbidden()) and plate.UnitFrame or nil
    local ok, tanking, status, scaled = Call(UnitDetailedThreatSituation, "player", unit)
    local db = A.db
    -- Not on your threat list: loose if it attacks one of you, else nothing.
    if not ok or status == nil then
        if not HitsGroup(unit) then Clear(marks[plate]); return end
        local mark = Mark(plate)
        Place(mark, frame)
        Glow(mark, true); Who(mark, unit); mark.line:Hide()
        return
    end
    local mark = Mark(plate)
    Place(mark, frame)
    if not Public(tanking) or not Public(status) then
        -- Secret: the halo's opacity takes the answer, the line its value.
        Glow(mark, true, tanking)
        mark.who:Hide()
        if db.threatLine then
            local okLead, lead = Call(UnitThreatPercentageOfLead, "player", unit)
            mark.line:SetMinMaxValues(100, FULL)
            mark.line:SetStatusBarColor(IRON[1], IRON[2], IRON[3])
            if okLead and lead ~= nil and Call(mark.line.SetValue, mark.line, lead) then mark.line:Show() else mark.line:Hide() end
        else mark.line:Hide() end
        return
    end
    if tanking then
        Glow(mark, false)
        mark.who:Hide()
        if not db.threatLine then mark.line:Hide(); return end
        local okLead, lead = Call(UnitThreatPercentageOfLead, "player", unit)
        if not okLead or not Public(lead) or type(lead) ~= "number" or lead <= 0 then lead = FULL end -- nobody else on it
        local color = LineColor(lead, status)
        mark.line:SetMinMaxValues(100, FULL)
        mark.line:SetValue(math.min(lead, FULL))
        mark.line:SetStatusBarColor(color[1], color[2], color[3])
        mark.line:Show()
    else
        Glow(mark, true)
        Who(mark, unit)
        if db.threatLine and Public(scaled) and type(scaled) == "number" then
            -- How close you are to taking it back.
            mark.line:SetMinMaxValues(0, 100)
            mark.line:SetValue(math.max(0, math.min(100, scaled)))
            mark.line:SetStatusBarColor(LOOSE[1], LOOSE[2], LOOSE[3])
            mark.line:Show()
        else mark.line:Hide() end
    end
end

local function IsMob(unit)
    local okAttack, attack = Call(UnitCanAttack, "player", unit)
    local okPlayer, player = Call(UnitIsPlayer, unit)
    return okAttack and attack == true and okPlayer and player == false
end

local function Track(unit)
    if not Public(unit) or type(unit) ~= "string" then return end
    local ok, plate = Call(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or (plate.IsForbidden and plate:IsForbidden()) or not IsMob(unit) then
        tracked[unit] = nil
        if ok and plate then Clear(marks[plate]) end
        return
    end
    tracked[unit] = plate
    A.UpdateThreat(unit)
end
local function Untrack(unit)
    local plate = tracked[unit]
    tracked[unit] = nil
    if plate then Clear(marks[plate]) end
end
function A.RefreshThreat()
    for unit in pairs(tracked) do A.UpdateThreat(unit) end
end

local events = CreateFrame("Frame")
local registered = false
local LIVE = {"UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_TARGET", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED"}
-- Listen only while the option is on.
function A.UpdateThreatEvents()
    local want = A.db and A.db.enabled and A.db.threat or false
    if want == registered then A.RefreshThreat(); return end
    registered = want
    for _, event in ipairs(LIVE) do
        if want then pcall(events.RegisterEvent, events, event) else pcall(events.UnregisterEvent, events, event) end
    end
    if want then
        for i = 1, 40 do
            local unit = "nameplate" .. i
            local ok, exists = Call(UnitExists, unit)
            if ok and exists == true then Track(unit) end
        end
    else
        for unit in pairs(tracked) do Untrack(unit) end
    end
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then Track(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then Untrack(unit)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_ENABLED" then A.RefreshThreat()
    elseif Public(unit) and tracked[unit] then A.UpdateThreat(unit) end
end)
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function() A.UpdateThreatEvents() end)

-- /fnames threat: what the game says about your target.
function A.DebugThreat()
    local unit = "target"
    local ok, tanking, status, scaled, raw = Call(UnitDetailedThreatSituation, "player", unit)
    local okLead, lead = Call(UnitThreatPercentageOfLead, "player", unit)
    local okSit, situation = Call(UnitThreatLeadSituation, "player", unit)
    local function Show(v) if not Public(v) then return "secret" end return tostring(v) end
    print("Forever Names: threat on", Show(select(2, Call(UnitName, unit))),
        "on you:", ok and Show(tanking) or "error", "status:", Show(status), "your %:", Show(scaled), "raw %:", Show(raw),
        "lead %:", okLead and Show(lead) or "n/a", "lead state:", okSit and Show(situation) or "n/a",
        "it hits:", Show(select(2, Call(UnitName, unit .. "target"))), "in group:", tostring(IsInGroup and IsInGroup()),
        "option:", tostring(A.db and A.db.threat))
end
