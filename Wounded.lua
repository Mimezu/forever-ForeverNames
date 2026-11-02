local _, A = ...
-- Wounded-player bars: a thin bar under friendly players who are hurt, so you
-- can spot someone to help. Two toggles (everyone / group members), both off.
--
-- Health is a secret value for addons: Lua may not compare it. The bar never
-- decides "wounded" itself. It hands the secret values to the StatusBar, and
-- its visibility comes from UnitHealthPercent evaluated through a curve that
-- is 1 below full health and 0 at full health; SetAlpha accepts that secret
-- result. The bar sits in a holder that carries the label's normal fading.
local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Read(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok and Public(value) then return value end
end

A.defaults.woundedPlayers, A.defaults.woundedParty = false, false
A.defaults.woundedWidth, A.defaults.woundedHeight = 60, 2
A.defaults.colors.wounded = {0.4, 0.82, 0.35}
-- "custom" (the color above), "class", or "name" (the name's current color).
A.defaults.woundedColorMode = "custom"
local function BarColor(state)
    local mode = A.db.woundedColorMode
    if mode == "name" and state.color then return state.color end
    if mode == "class" then
        local class = A.UnitClassColor and A.UnitClassColor(state.unit)
        if class then return class end
        if state.color then return state.color end
    end
    return A.db.colors.wounded
end
function A.PickWoundedColor(anchor)
    local db = A.db
    local mode = db.woundedColorMode or "custom"
    local original = {unpack(db.colors.wounded)}
    A.PickColor(anchor, original[1], original[2], original[3],
        function(r, g, b) db.colors.wounded = {r, g, b}; db.woundedColorMode = "custom"; A.Refresh() end,
        function() db.colors.wounded, db.woundedColorMode = original, mode; A.Refresh() end,
        {current = mode, set = function(value) db.woundedColorMode = value; A.Refresh() end})
end

local curve
local function Curve()
    if curve then return curve end
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, created = pcall(C_CurveUtil.CreateCurve)
        if ok and created then
            created:AddPoint(0, 1)
            created:AddPoint(0.999, 1)
            created:AddPoint(1, 0)
            curve = created
        end
    end
    return curve
end
function A.WoundedAvailable() return Curve() ~= nil and UnitHealthPercent ~= nil end
function A.WoundedEnabled()
    local db = A.db
    return db.enabled and (db.woundedPlayers or db.woundedParty) and true or false
end

local tracked = {} -- unit token -> render state
local function Wanted(state)
    local db = A.db
    if state.sizeKey ~= "friendlyPlayer" or not state.visible or not A.WoundedEnabled() or A.nativePlateTest then return false end
    -- The selected player's own health bar already covers them.
    if db.targetHealthBar and Read(UnitIsUnit, state.unit, "target") == true then return false end
    if db.woundedPlayers then return true end
    return Read(UnitInParty, state.unit) == true or Read(UnitInRaid, state.unit) ~= nil
end

local function Holder(overlay, field)
    field = field or "wounded"
    if overlay[field] then return overlay[field] end
    local holder = CreateFrame("Frame", nil, overlay)
    holder:EnableMouse(false)
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetAllPoints(holder)
    bar:EnableMouse(false)
    -- A thin, subtle rim in Forever's bronze, then a dark track. Both belong
    -- to the bar: its (secret) alpha must hide everything at full health.
    bar.rim = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bar.rim:SetPoint("TOPLEFT", -1, 1); bar.rim:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.rim:SetColorTexture(0.45, 0.34, 0.17, 0.55)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints(bar)
    bar.track:SetColorTexture(0.03, 0.03, 0.03, 0.8)
    holder.bar = bar
    overlay[field] = holder
    return holder
end
A.WoundedHolder = Holder -- also used by the settings preview

-- always = true: shown at any health (enemy bar), no curve.
local function UpdateHealth(holder, unit, always)
    local bar = holder.bar
    local okMax, maximum = pcall(UnitHealthMax, unit)
    local okHealth, current = pcall(UnitHealth, unit)
    local okAlpha, alpha = false, nil
    if always then
        okAlpha, alpha = true, 1
    else
        local shape = Curve()
        if shape and UnitHealthPercent then okAlpha, alpha = pcall(UnitHealthPercent, unit, true, shape) end
    end
    if not okMax or not okHealth or not okAlpha
        or (Public(maximum) and (type(maximum) ~= "number" or maximum <= 0)) then
        holder:Hide()
        return
    end
    -- Secret values go straight to the widget; never compared or formatted.
    if not pcall(bar.SetMinMaxValues, bar, 0, maximum) or not pcall(bar.SetValue, bar, current)
        or not pcall(bar.SetAlpha, bar, alpha) then
        holder:Hide()
        return
    end
    holder:Show()
end

-- Called for every rendered plate; cheap no-op when the option is off.
function A.ApplyWounded(state)
    local overlay = state.overlay
    if not Wanted(state) then
        if overlay.wounded then overlay.wounded:Hide() end
        if tracked[state.unit] == state then tracked[state.unit] = nil end
        return
    end
    local db = A.db
    local holder = Holder(overlay)
    holder:SetSize(math.max(20, math.min(160, tonumber(db.woundedWidth) or 60)),
        math.max(1, math.min(8, tonumber(db.woundedHeight) or 2)))
    holder.bar:SetStatusBarColor(unpack(BarColor(state)))
    local title = state.title
    local below = title and title:IsShown() and (title:GetText() or "") ~= "" and title or state.name
    holder:ClearAllPoints()
    holder:SetPoint("TOP", below, "BOTTOM", 0, -3)
    holder:SetAlpha(state.nameAlpha or 0)
    tracked[state.unit] = state
    UpdateHealth(holder, state.unit)
end

-- Enemy health bar (Enemy tab): always shown under our enemy label, in their
-- class color. Not in "our names on their bars" mode (Blizzard's bar is there).
A.defaults.enemyHealthBar = false
A.defaults.enemyBarWidth, A.defaults.enemyBarHeight = 60, 3
-- "class" (default), "name" (the name's color) or "custom" (colors.enemyBar).
A.defaults.enemyBarColorMode = "class"
function A.EnemyBarColor(state)
    local db = A.db
    local mode = db.enemyBarColorMode
    if mode == "custom" then return db.colors.enemyBar end
    if mode == "name" and state.color then return state.color end
    return A.UnitClassColor and A.UnitClassColor(state.unit) or state.color or {1, 1, 1}
end
function A.PickEnemyBarColor(anchor)
    local db = A.db
    local mode = db.enemyBarColorMode or "class"
    local original = {unpack(db.colors.enemyBar)}
    A.PickColor(anchor, original[1], original[2], original[3],
        function(r, g, b) db.colors.enemyBar = {r, g, b}; db.enemyBarColorMode = "custom"; A.Refresh() end,
        function() db.colors.enemyBar, db.enemyBarColorMode = original, mode; A.Refresh() end,
        {current = mode, set = function(value) db.enemyBarColorMode = value; A.Refresh() end})
end
local enemyTracked = {}
function A.EnemyBarEnabled()
    local db = A.db
    return db.enabled and db.enemyEnabled and db.enemyHealthBar and true or false
end
function A.ApplyEnemyBar(state)
    local overlay = state.overlay
    local wanted = state.sizeKey == "enemyPlayer" and state.visible and not state.keepBars
        and A.EnemyBarEnabled() and not A.nativePlateTest
    if not wanted then
        if overlay.enemyBar then overlay.enemyBar:Hide() end
        if enemyTracked[state.unit] == state then enemyTracked[state.unit] = nil end
        return
    end
    local db = A.db
    local holder = Holder(overlay, "enemyBar")
    holder:SetSize(math.max(20, math.min(160, tonumber(db.enemyBarWidth) or 60)),
        math.max(1, math.min(8, tonumber(db.enemyBarHeight) or 3)))
    holder.bar:SetStatusBarColor(unpack(A.EnemyBarColor(state)))
    local title = state.title
    local below = title and title:IsShown() and (title:GetText() or "") ~= "" and title or state.name
    holder:ClearAllPoints()
    holder:SetPoint("TOP", below, "BOTTOM", 0, -3)
    holder:SetAlpha(state.nameAlpha or 0)
    enemyTracked[state.unit] = state
    UpdateHealth(holder, state.unit, true)
end

local events = CreateFrame("Frame")
local rosterPending = false
events:SetScript("OnEvent", function(_, event, unit)
    if event == "GROUP_ROSTER_UPDATE" then
        if rosterPending then return end
        rosterPending = true
        C_Timer.After(0.3, function()
            rosterPending = false
            if A.RequeuePlayers then A.RequeuePlayers() end
        end)
        return
    end
    if not Public(unit) then return end
    local enemy = enemyTracked[unit]
    if enemy then
        local holder = enemy.overlay.enemyBar
        if holder and A.RenderStates[enemy.frame] == enemy and enemy.unit == unit then UpdateHealth(holder, unit, true)
        else enemyTracked[unit] = nil end
    end
    local state = tracked[unit]
    if not state then return end
    local holder = state.overlay.wounded
    if not holder or A.RenderStates[state.frame] ~= state or state.unit ~= unit then
        tracked[unit] = nil
        return
    end
    UpdateHealth(holder, unit)
end)
function A.UpdateWoundedEvents()
    local on = A.WoundedEnabled()
    local listen = on or A.EnemyBarEnabled()
    for _, event in ipairs({"UNIT_HEALTH", "UNIT_MAXHEALTH"}) do
        if listen then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
    if not A.EnemyBarEnabled() then enemyTracked = {} end
    if on and A.db.woundedParty and not A.db.woundedPlayers then events:RegisterEvent("GROUP_ROSTER_UPDATE")
    else events:UnregisterEvent("GROUP_ROSTER_UPDATE") end
    if not on then tracked = {} end
end
