local _, A = ...
-- Never write native layout/visibility flags or call native update routines.
-- Those fields participate in secure health updates when frames are recycled.
local states, overlays, hooked = {}, {}, {}
local primed = {}
A.RenderStates = states
-- Keep the parent and SoftTargetFrame visible: Blizzard owns the gamepad
-- interaction prompt there. Hide only the visuals replaced by our labels.
-- Raid markers: Blizzard's RaidTargetFrame is anchored to its own (hidden)
-- health bar, which leaves it floating beside our label. Our own marker sits
-- above our name instead; the secret marker index goes straight to the
-- texture (SetSpriteSheetCell accepts it), so Lua never reads it.
local hiddenRegions = {
    "name", "HealthBarsContainer", "CastBarsContainer", "AurasFrame",
    "ClassificationFrame", "RaidTargetFrame", "LevelFrame", "PlayerLevelDiffFrame",
    "selectionHighlight", "behindCameraIcon", "aggroHighlight", "aggroHighlightBase",
    "aggroHighlightAdditive", "aggroHighlightMask", "aggroFlash",
}
-- Enemies while you are flagged ("our names on Blizzard's bars"): only the
-- native name is replaced; health, casts, debuffs and level stay Blizzard's.
local nameOnlyRegions = {"name"}
local function Usable(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and not (InCombatLockdown() and frame.IsProtected and frame:IsProtected())
end

function A.NativeOpacity(state)
    local db = A.db
    local alpha = 0
    if state.visible and not A.labelsHidden then
        local target = false
        if db.targetOpacity ~= db.otherOpacity then
            local ok, value = pcall(UnitIsUnit, state.unit, "target")
            if ok and (not issecretvalue or not issecretvalue(value)) then target = value == true end
        end
        alpha = db.opacity * (target and db.targetOpacity or db.otherOpacity)
        if db.combatOpacity ~= 1 and InCombatLockdown() then alpha = alpha * db.combatOpacity end
    end
    if state.nameAlpha ~= alpha then
        state.nameAlpha = alpha; state.name:SetAlpha(alpha)
        if state.overlay.level then state.overlay.level:SetAlpha(alpha) end
        local holder = state.overlay.levelHolder
        if holder and holder.levelBadge then holder.levelBadge:SetAlpha(alpha) end
        if state.overlay.icons then
            for _, texture in ipairs(state.overlay.icons) do texture:SetAlpha(alpha) end
        end
        if state.overlay.wounded then state.overlay.wounded:SetAlpha(alpha) end
        if state.overlay.enemyBar then state.overlay.enemyBar:SetAlpha(alpha) end
        if state.overlay.raidMarker then state.overlay.raidMarker:SetAlpha(alpha) end
        if A.UpdateTargetHealthOpacity then A.UpdateTargetHealthOpacity(state, alpha) end
    end
    local titleAlpha = alpha * db.subtitleOpacity
    if state.title and state.titleAlpha ~= titleAlpha then
        state.titleAlpha = titleAlpha
        state.title:SetAlpha(titleAlpha)
    end
end

function A.GetTextSizes(key)
    local sizes = A.db and A.db.textSizes
    local general = type(sizes) == "table" and sizes.general
    local specific = type(sizes) == "table" and sizes[key]
    local function Valid(row, field)
        local value = type(row) == "table" and row[field]
        if type(value) == "number" and value == value and value > 0 then
            return math.max(8, math.min(40, value))
        end
    end
    local native = NamePlateSetupOptions and NamePlateSetupOptions.healthBarFontHeight or 14
    local name = Valid(specific, "name") or Valid(general, "name") or native
    local subtitle = Valid(specific, "subtitle") or Valid(general, "subtitle") or name * 0.8
    return name, subtitle
end

-- The NPC renderer and target-only vitals can hide the same region. Restore
-- its original alpha only after both release it, regardless of release order.
local suppressed = {}
local function CanSetAlpha(region)
    if not region or not region.GetAlpha or not region.SetAlpha then return false end
    if region.IsForbidden then
        local ok, value = pcall(region.IsForbidden, region)
        if not ok or (issecretvalue and issecretvalue(value)) or value ~= false then return false end
    end
    if region.CanBeAccessedInContext then
        local ok, value = pcall(region.CanBeAccessedInContext, region)
        if not ok or (issecretvalue and issecretvalue(value)) or value ~= true then return false end
    end
    -- SetAlpha is not a protected layout operation in this client. Check actual
    -- object access instead of rejecting an accessible protected container.
    return true
end
function A.SuppressNativeRegion(owner, region)
    if not CanSetAlpha(region) then return false end
    local ok, alpha = pcall(region.GetAlpha, region)
    if not ok or (issecretvalue and issecretvalue(alpha)) then return false end
    local entry = suppressed[region]
    if not entry then
        entry = {alpha = alpha, owners = {}}
    end
    if alpha ~= 0 and not pcall(region.SetAlpha, region, 0) then return false end
    suppressed[region] = entry
    entry.owners[owner] = true
    return true
end
function A.ReleaseNativeRegion(owner, region)
    local entry = suppressed[region]
    if not entry or not entry.owners[owner] then return true end
    if not CanSetAlpha(region) then return false end
    entry.owners[owner] = nil
    if not next(entry.owners) then
        -- Preserve an explicit alpha change made by something else meanwhile.
        local ok, alpha = pcall(region.GetAlpha, region)
        if not ok or (issecretvalue and issecretvalue(alpha)) or (alpha == 0 and not pcall(region.SetAlpha, region, entry.alpha)) then
            entry.owners[owner] = true
            return false
        end
        suppressed[region] = nil
    end
    return true
end

-- Something put a region we hide back (its alpha): hide it again, or both
-- names show. Cheap: only regions this plate owns, only when visible again.
local function Reassert(state)
    for _, saved in ipairs(state.hiddenRegions) do
        local region = saved.region
        local ok, alpha = pcall(region.GetAlpha, region)
        if ok and not (issecretvalue and issecretvalue(alpha)) and alpha ~= 0 then A.SuppressNativeRegion(state, region) end
    end
end
A.ReassertPlate = Reassert

local function Style(state)
    -- Plate ownership is short-lived at the distance threshold, but these
    -- addon-owned font strings survive recycling. Retain their applied style
    -- with the overlay so reentry does not rebuild identical font resources.
    local style = state.overlay.appliedStyle
    if not style then style = {}; state.overlay.appliedStyle = style end
    local native = state.frame.name
    local font = native and native:GetFontObject()
    local height, titleHeight = A.GetTextSizes(state.sizeKey)
    if font ~= style.font or height ~= style.height or titleHeight ~= style.titleHeight then
        style.font, style.height, style.titleHeight = font, height, titleHeight
        if A.perf then A.perf.fontStyles = A.perf.fontStyles + 1 end
        if font then state.name:SetFontObject(font); state.title:SetFontObject(font) end
        state.name:SetTextHeight(height)
        state.title:SetTextHeight(titleHeight)
    end
    -- Match Blizzard's smoothScaling=true on its inherited SLUG font. Do not
    -- synthesize a font/flags combination or animate sizes from Lua.
    local smooth = A.db.nativeSmoothScaling == true
    if style.smooth ~= smooth then
        style.smooth = smooth
        if state.name.SetSmoothScaling then state.name:SetSmoothScaling(smooth) end
        if state.title.SetSmoothScaling then state.title:SetSmoothScaling(smooth) end
    end
    -- Optional player level: created only once the option is used.
    local level = state.overlay.level
    if level then
        local db = A.db
        local enemy = state.sizeKey == "enemyPlayer"
        local side = enemy and db.enemyLevelSide or db.playerLevelSide
        local size = A.LevelTextSize(titleHeight, enemy)
        local value = level:GetText() or ""
        local key = size .. ":" .. tostring(db.playerLevelStyle) .. ":" .. tostring(side) .. ":" .. #value
        if style.levelFont ~= font or style.levelKey ~= key or style.levelSmooth ~= smooth then
            style.levelFont, style.levelKey, style.levelSmooth = font, key, smooth
            if font then level:SetFontObject(font) end
            level:SetTextHeight(size)
            style.lr = nil -- a new font object resets the color; reapply below
            if level.SetSmoothScaling then level:SetSmoothScaling(smooth) end
            local gap = 3 + A.StyleLevelBadge(state.overlay.levelHolder, level, size, db.playerLevelStyle, value)
            style.levelGap = gap - 3
            level:ClearAllPoints()
            if side == "left" then level:SetPoint("RIGHT", state.name, "LEFT", -gap, 0)
            else level:SetPoint("LEFT", state.name, "RIGHT", gap, 0) end
        end
    end
    if state.color and (style.r ~= state.color[1] or style.g ~= state.color[2] or style.b ~= state.color[3]) then
        style.r, style.g, style.b = unpack(state.color)
        state.name:SetTextColor(style.r, style.g, style.b)
        state.title:SetTextColor(style.r, style.g, style.b)
    end
    -- The level uses its own color, or the name's.
    local levelText = state.overlay.level
    local levelColor = state.levelColor or state.color
    if levelText and levelColor and (style.lr ~= levelColor[1] or style.lg ~= levelColor[2] or style.lb ~= levelColor[3]) then
        style.lr, style.lg, style.lb = levelColor[1], levelColor[2], levelColor[3]
        levelText:SetTextColor(style.lr, style.lg, style.lb)
    end
end

local function ReleasePrime(frame)
    local pending = primed[frame]
    if not pending then return end
    for _, saved in ipairs(pending.hiddenRegions) do A.ReleaseNativeRegion(pending, saved.region) end
    primed[frame] = nil
end
function A.IsPrimedPlate(frame, unit)
    return primed[frame] and primed[frame].unit == unit
end
function A.RestorePlate(frame)
    if A.ReleaseTargetHealthPlate then A.ReleaseTargetHealthPlate(states[frame]) end
    if not Usable(frame) then return end
    ReleasePrime(frame)
    local state = states[frame]
    if not state then return end
    states[frame] = nil
    state.overlay:Hide()
    for _, saved in ipairs(state.hiddenRegions) do A.ReleaseNativeRegion(state, saved.region) end
end

local function HookFrame(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    if frame.OnUnitCleared then hooksecurefunc(frame, "OnUnitCleared", A.RestorePlate) end
    if frame.ApplyFrameOptions then
        hooksecurefunc(frame, "ApplyFrameOptions", function(self)
            local current = states[self]
            if current and Usable(self) then Style(current) end
            local owner = current or primed[self]
            if owner then
                for _, saved in ipairs(owner.hiddenRegions) do A.SuppressNativeRegion(owner, saved.region) end
            end
        end)
    end
end
function A.PrimePlate(frame, unit)
    if not Usable(frame) or not frame.name or not frame.name.GetFontObject then return false end
    local owner = primed[frame] or states[frame]
    if owner and owner.unit == unit then
        -- A completed native initialization may have reset alpha after an early
        -- unit event; never treat cached ownership alone as proof of invisibility.
        for _, saved in ipairs(owner.hiddenRegions) do
            if not A.SuppressNativeRegion(owner, saved.region) then return false end
        end
        return true
    end
    A.RestorePlate(frame)
    local pending = {unit = unit, hiddenRegions = {}}
    primed[frame] = pending
    for _, key in ipairs(hiddenRegions) do
        local region = frame[key]
        if region and region.GetAlpha and region.SetAlpha then
            if not A.SuppressNativeRegion(pending, region) then ReleasePrime(frame); return false end
            pending.hiddenRegions[#pending.hiddenRegions + 1] = {region = region}
        end
    end
    HookFrame(frame)
    return true
end

local MARKER_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
function A.UpdateRaidMarker(state)
    local overlay = state.overlay
    local marker = overlay.raidMarker
    -- "Our names on their bars" keeps Blizzard's marker; hidden labels have none.
    if state.keepBars or not state.visible then
        if marker then marker:Hide() end
        return
    end
    local ok, index = pcall(GetRaidTargetIndex, state.unit)
    local secret = ok and issecretvalue and issecretvalue(index)
    if not ok or (not secret and type(index) ~= "number") then
        if marker then marker:Hide() end
        return
    end
    if not marker then
        marker = overlay:CreateTexture(nil, "OVERLAY")
        marker:SetTexture(MARKER_SHEET)
        overlay.raidMarker = marker
    end
    local drawn
    if marker.SetSpriteSheetCell then drawn = pcall(marker.SetSpriteSheetCell, marker, index, 4, 4)
    elseif SetRaidTargetIconTexture then drawn = pcall(SetRaidTargetIconTexture, marker, index) end
    if not drawn then marker:Hide(); return end
    -- Blizzard's own size and gap (22 px, 10 px above the name); above any
    -- icons that sit above the name.
    local lift = 10
    local above = overlay.iconRows and overlay.iconRows.above
    if above and above[1] and above[1]:IsShown() then lift = 2 + above[1]:GetHeight() + 6 end
    marker:SetSize(22, 22)
    marker:ClearAllPoints()
    marker:SetPoint("BOTTOM", state.name, "TOP", 0, lift)
    marker:SetAlpha(state.nameAlpha or 0)
    marker:Show()
end
-- Markers change for everyone at once; update the drawn labels only.
local markerEvents = CreateFrame("Frame")
markerEvents:RegisterEvent("RAID_TARGET_UPDATE")
markerEvents:SetScript("OnEvent", function()
    for frame, state in pairs(states) do
        if frame.IsForbidden == nil or not frame:IsForbidden() then A.UpdateRaidMarker(state) end
    end
end)

function A.RenderPlate(plate, frame, unit, role, color, title, sizeKey, level, levelColor, icons, keepBars)
    if not Usable(frame) then return nil end
    if not frame.name or not frame.name.GetFontObject then return false end
    local overlay = overlays[plate]
    if not overlay then
        -- Sibling of the native unit frame: engine position/scale/fade are inherited
        -- from the nameplate, without invoking restricted native layout methods.
        overlay = CreateFrame("Frame", nil, plate)
        overlay:SetAllPoints(plate)
        overlay:EnableMouse(false)
        overlay.name = overlay:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
        overlay.title = overlay:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
        overlay.name:SetPoint("BOTTOM", overlay, "CENTER", 0, 2)
        overlay.title:SetPoint("TOP", overlay.name, "BOTTOM", 0, -1)
        for _, text in ipairs({overlay.name, overlay.title}) do
            text:SetJustifyH("CENTER")
            text:SetWordWrap(false)
        end
        overlays[plate] = overlay
    end
    keepBars = keepBars and true or false
    local state = states[frame]
    if state and (state.unit ~= unit or state.keepBars ~= keepBars) then A.RestorePlate(frame); state = nil end
    if not state then
        -- Promote the arrival owner itself. Its masks are already applied; no
        -- second region list, ownership transfer, or repeat alpha writes needed.
        if primed[frame] and (primed[frame].unit ~= unit or keepBars) then ReleasePrime(frame) end
        local pending = primed[frame]
        state = pending or {unit = unit, hiddenRegions = {}}
        primed[frame] = nil
        state.frame, state.plate, state.overlay = frame, plate, overlay
        state.name, state.title = overlay.name, overlay.title
        state.keepBars = keepBars
        states[frame] = state
        if not pending then
            for _, key in ipairs(keepBars and nameOnlyRegions or hiddenRegions) do
                local region = frame[key]
                if region and region.GetAlpha and region.SetAlpha and Usable(region) then
                    state.hiddenRegions[#state.hiddenRegions + 1] = {region = region}
                    A.SuppressNativeRegion(state, region)
                end
            end
        end
    end
    -- Release any separate pending owner only after rendered ownership exists.
    ReleasePrime(frame)
    Reassert(state)
    local anchorMode = keepBars and frame.HealthBarsContainer and "bars" or "center"
    if overlay.anchorMode ~= anchorMode then
        overlay.anchorMode = anchorMode
        overlay.name:ClearAllPoints()
        if anchorMode == "bars" then overlay.name:SetPoint("BOTTOM", frame.HealthBarsContainer, "TOP", 0, 3)
        else overlay.name:SetPoint("BOTTOM", overlay, "CENTER", 0, 2) end
    end
    state.visible, state.color, state.sizeKey = role ~= nil, color, sizeKey or role
    state.levelColor = levelColor
    local ok, name = pcall(UnitName, unit)
    if not ok or (issecretvalue and issecretvalue(name)) then name = nil end
    if state.sizeKey == "friendlyPlayer" or state.sizeKey == "enemyPlayer" then
        local shortName = name
        -- Forever's GetUnitName(unit, showSurname) formats the full display name.
        -- UnitName alone omits the surname. Never build one from tooltip scans.
        local fullOK, fullName = false, nil
        if GetUnitName then fullOK, fullName = pcall(GetUnitName, unit, true) end
        if not fullOK or (issecretvalue and issecretvalue(fullName)) or type(fullName) ~= "string" or fullName == "" then
            fullOK, fullName = pcall(frame.name.GetText, frame.name)
        end
        if fullOK and (not issecretvalue or not issecretvalue(fullName)) and type(fullName) == "string" and fullName ~= "" then name = fullName end
        if A.PlayerDisplayName then name = A.PlayerDisplayName(unit, name, shortName) end
        if state.sizeKey == "enemyPlayer" and A.EnemyMark then name = A.EnemyMark(name) end
    elseif A.NPCDisplayName then
        name = A.NPCDisplayName(unit, name)
    end
    local levelText = overlay.level
    if level and not levelText then
        -- Level text and its badge share one layer so they fade together.
        local holder = CreateFrame("Frame", nil, overlay)
        holder:SetAllPoints(overlay)
        holder:EnableMouse(false)
        if A.AttachLevelFade then A.AttachLevelFade(holder) end
        overlay.levelHolder = holder
        levelText = holder:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
        levelText:SetPoint("LEFT", overlay.name, "RIGHT", 3, 0)
        levelText:SetJustifyH("LEFT")
        levelText:SetWordWrap(false)
        levelText:SetAlpha(state.nameAlpha or 0)
        overlay.level = levelText
    end
    if levelText then
        if levelText:GetText() ~= (level or "") then levelText:SetText(level or "") end
        -- Nearby-only levels hide the number (not the plate) when far away.
        -- Friendly players and enemies each have their own range.
        if level and A.LevelNear then state.levelNear = A.LevelNear(unit, state.levelNear, state.sizeKey == "enemyPlayer")
        elseif state.sizeKey == "enemyPlayer" then state.levelNear = true end
        A.ShowLevel(overlay.levelHolder, level ~= nil and state.levelNear ~= false)
    end
    Style(state)
    if (icons or overlay.icons) and A.ApplyPlateIcons then A.ApplyPlateIcons(state, icons, (A.GetTextSizes(state.sizeKey))) end
    if state.name:GetText() ~= (name or "") then state.name:SetText(name or "") end
    if state.title:GetText() ~= (title or "") then state.title:SetText(title or "") end
    overlay:SetShown(state.visible and name ~= nil)
    state.title:SetShown(title ~= nil and title ~= "")
    A.NativeOpacity(state)
    if A.ApplyWounded then A.ApplyWounded(state) end
    if A.ApplyEnemyBar then A.ApplyEnemyBar(state) end
    A.UpdateRaidMarker(state)
    if A.OnTargetHealthPlateReady then A.OnTargetHealthPlateReady(state) end
    HookFrame(frame)
    return true
end
