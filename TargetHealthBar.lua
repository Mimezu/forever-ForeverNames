local _, A = ...
-- One live StatusBar for the selected friendly player, not one per nameplate.
-- Native visuals stay suppressed. No OnUpdate, animation, or crowd vitals reads.
local bar, bound
local nativeHost
local nativeHooked = setmetatable({}, {__mode = "k"})
local events = CreateFrame("Frame")
local healthEvents = {"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION"}
local listening = false
local levelListening = false
local presets = {
    minimal = {label = "Minimal", width = 82, height = 4, texture = "Interface\\Buttons\\WHITE8X8", levelText = {0.95, 0.95, 0.95}},
    default = {label = "Default", width = 100, height = 7, texture = "Interface\\TargetingFrame\\UI-StatusBar", border = {0.12, 0.12, 0.12}, levelText = {0.95, 0.95, 0.95}},
    classic = {label = "Classic", width = 110, height = 9, texture = "Interface\\TargetingFrame\\UI-StatusBar", border = {0.65, 0.5, 0.26}, levelText = {1, 0.82, 0.25}, nativeLevelArt = true},
}
A.targetHealthPresets = presets
local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Read(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok and Public(value) then return value end
end
local function Clamp(value, low, high, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(low, math.min(high, value))
end
function A.GetTargetHealthSettings()
    local db = A.db or A.defaults
    return presets[db.targetHealthStyle] or presets.minimal,
        Clamp(db.targetHealthWidth, 40, 180, 82), Clamp(db.targetHealthHeight, 2, 16, 4),
        Clamp(db.targetHealthGap, 0, 16, 3), Clamp(db.targetHealthOpacity, 0, 1, 1)
end
-- Each style keeps its own width, height, gap and opacity: switching saves the
-- current style's values and restores the new style's (or its built-in size).
local styleFields = {"targetHealthWidth", "targetHealthHeight", "targetHealthGap", "targetHealthOpacity"}
function A.SetTargetHealthPreset(key)
    local preset = presets[key]
    if not preset then return end
    local db = A.db
    db.targetHealthStyleSettings = type(db.targetHealthStyleSettings) == "table" and db.targetHealthStyleSettings or {}
    local saved = db.targetHealthStyleSettings
    local old = presets[db.targetHealthStyle] and db.targetHealthStyle
    if old and old ~= key then
        local values = {}
        for _, field in ipairs(styleFields) do values[field] = db[field] end
        saved[old] = values
    end
    db.targetHealthStyle = key
    local restore = saved[key]
    if type(restore) == "table" then
        for _, field in ipairs(styleFields) do
            if type(restore[field]) == "number" then db[field] = restore[field] end
        end
    elseif old ~= key then
        db.targetHealthWidth, db.targetHealthHeight = preset.width, preset.height
    end
    A.RefreshTargetHealthAppearance()
    if A.RefreshOptions then A.RefreshOptions() end
end
function A.CreateTargetHealthBar(parent)
    local widget = CreateFrame("StatusBar", nil, parent)
    widget:EnableMouse(false)
    widget.background = widget:CreateTexture(nil, "BACKGROUND")
    widget.background:SetAllPoints(widget)
    widget.background:SetColorTexture(0.025, 0.025, 0.025, 0.85)
    widget.edges = {}
    for i = 1, 4 do widget.edges[i] = widget:CreateTexture(nil, "OVERLAY") end
    widget.edges[1]:SetPoint("BOTTOMLEFT", widget, "TOPLEFT", -1, 0)
    widget.edges[2]:SetPoint("TOPLEFT", widget, "BOTTOMLEFT", -1, 0)
    widget.edges[3]:SetPoint("TOPRIGHT", widget, "TOPLEFT", 0, 0)
    widget.edges[4]:SetPoint("TOPLEFT", widget, "TOPRIGHT", 0, 0)
    widget:Hide()
    return widget
end
local function LevelPill(widget)
    if widget.levelPill then return widget.levelPill end
    -- Reuse Blizzard artwork, not the native frame's mixin or subscriptions.
    -- These few regions persist with the one target bar through style changes.
    local pill = CreateFrame("Frame", nil, widget)
    pill:EnableMouse(false)
    pill:SetPoint("LEFT", widget, "RIGHT", -2, 0)
    pill.art = pill:CreateTexture(nil, "BACKGROUND")
    pill.art:SetAllPoints(pill)
    local atlas = "ui-hud-nameplates-levelindicator"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        pill.art:SetAtlas(atlas)
        pill.hasNativeArt = true
    end
    -- Minimal/Default use the bar's own texture, rounded with Blizzard's
    -- portrait mask. Classic uses this same shell if its native atlas is absent.
    pill.rim = pill:CreateTexture(nil, "BACKGROUND")
    pill.rim:SetAllPoints(pill)
    pill.rim:SetTexture("Interface\\Buttons\\WHITE8X8")
    pill.rim:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    pill.fill = pill:CreateTexture(nil, "BORDER")
    pill.fill:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    pill.text = pill:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlateLevel")
    pill.text:SetPoint("CENTER", pill, "CENTER", 0, 0)
    pill.text:SetJustifyH("CENTER")
    pill.text:SetWordWrap(false)
    pill.text:SetText("?")
    widget.levelPill = pill
    return pill
end
local function StyleLevelPill(widget, height, preset, r, g, b)
    if not A.db.targetHealthLevel then
        if widget.levelPill then widget.levelPill:Hide() end
        return
    end
    local pill = LevelPill(widget)
    local pillHeight = math.max(14, height + 4)
    pill:SetSize(math.max(28, math.floor(pillHeight * 1.8 + 0.5)), pillHeight)
    local nativeArt = preset.nativeLevelArt == true and pill.hasNativeArt == true
    pill.art:SetShown(nativeArt)
    pill.rim:SetShown(not nativeArt and preset.border ~= nil)
    pill.fill:SetShown(not nativeArt)
    if not nativeArt then
        local inset = preset.border and 1 or 0
        pill.fill:ClearAllPoints()
        pill.fill:SetPoint("TOPLEFT", pill, "TOPLEFT", inset, -inset)
        pill.fill:SetPoint("BOTTOMRIGHT", pill, "BOTTOMRIGHT", -inset, inset)
        pill.fill:SetTexture(preset.texture)
        if preset.border then
            pill.rim:SetVertexColor(preset.border[1], preset.border[2], preset.border[3], 1)
            if not preset.nativeLevelArt then
                -- A restrained tint ties the shaded pill to the chosen bar color
                -- while the light level number remains legible at small sizes.
                pill.fill:SetVertexColor(0.025 + r * 0.18, 0.025 + g * 0.18, 0.025 + b * 0.18, 0.95)
            else pill.fill:SetVertexColor(0.025, 0.025, 0.025, 0.95) end
        else pill.fill:SetVertexColor(0.025, 0.025, 0.025, 0.85) end
    end
    pill.text:SetTextColor(preset.levelText[1], preset.levelText[2], preset.levelText[3])
    pill.text:SetTextHeight(math.min(12, pillHeight - 4))
    if pill.text.SetSmoothScaling then pill.text:SetSmoothScaling(A.db.nativeSmoothScaling == true) end
    pill:Show()
end
function A.SetTargetHealthLevelDisplay(widget, level)
    if not A.db.targetHealthLevel then return end
    local pill = LevelPill(widget)
    -- Unknown or restricted levels never become Lua text or comparisons.
    local text = "?"
    if Public(level) and type(level) == "number" and level > 0 and level < 1000 then
        text = tostring(math.floor(level))
    end
    if pill.text:GetText() ~= text then pill.text:SetText(text) end
end
function A.AnchorTargetHealthBar(widget, name)
    local _, _, height, gap = A.GetTargetHealthSettings()
    -- Center the pill on the bar, but keep its upper rim below the name even
    -- with a 2px bar. The configured gap measures the tallest visible part.
    local extra = A.db.targetHealthLevel and (math.max(14, height + 4) - height) / 2 or 0
    widget:ClearAllPoints()
    widget:SetPoint("TOP", name, "BOTTOM", 0, -gap - extra)
end
-- unit: the selected player (for the class color); nil in the settings preview.
function A.StyleTargetHealthBar(widget, nameColor, unit)
    local preset, width, height, _, opacity = A.GetTargetHealthSettings()
    widget:SetSize(width, height)
    widget:SetStatusBarTexture(preset.texture)
    for i, edge in ipairs(widget.edges) do
        edge:SetSize(i <= 2 and width + 2 or 1, i <= 2 and 1 or height)
        edge:SetShown(preset.border ~= nil)
        if preset.border then edge:SetColorTexture(preset.border[1], preset.border[2], preset.border[3], 1) end
    end
    local db = A.db
    local r, g, b
    local mode = db.targetHealthColorMode
    local class = mode == "class" and (unit and A.UnitClassColor and A.UnitClassColor(unit) or nameColor)
    if class then
        r, g, b = class[1], class[2], class[3]
    elseif mode == "name" and nameColor then
        r, g, b = nameColor[1], nameColor[2], nameColor[3]
    else
        r, g, b = Clamp(db.targetHealthR, 0, 1, 0.25),
            Clamp(db.targetHealthG, 0, 1, 0.85), Clamp(db.targetHealthB, 0, 1, 0.4)
    end
    widget:SetStatusBarColor(r, g, b)
    widget:SetAlpha(opacity)
    StyleLevelPill(widget, height, preset, r, g, b)
end
local function Enabled()
    local db = A.db
    return db and db.enabled and db.targetHealthBar and not A.nativePlateTest
end
local function FriendlyTarget()
    return Read(UnitExists, "target") == true and Read(UnitIsPlayer, "target") == true
        and Read(UnitIsFriend, "player", "target") == true
        and Read(UnitCanAttack, "player", "target") == false
        and Read(UnitIsUnit, "target", "player") == false
end
local function Valid(state)
    if state and state.native then
        return not A.db.showFriendlyPlayers and state.plate.UnitFrame == state.frame
            and Public(state.frame.unit) and state.frame.unit == state.unit
            and (not state.frame.IsForbidden or Read(state.frame.IsForbidden, state.frame) == false)
            and Read(UnitIsUnit, state.unit, "target") == true
    end
    return A.db.showFriendlyPlayers and state and state.sizeKey == "friendlyPlayer" and state.visible
        and A.RenderStates[state.frame] == state and state.plate.UnitFrame == state.frame
        and state.overlay:IsShown() and Read(UnitIsUnit, state.unit, "target") == true
end
local function StopLevel()
    if levelListening then events:UnregisterEvent("UNIT_LEVEL"); levelListening = false end
    if bar and bar.levelPill then bar.levelPill:Hide(); bar.levelPill.text:SetText("?") end
end
local function Stop()
    local old = bound
    bound = nil
    StopLevel()
    if bar then bar:Hide() end
    if old and old.native then
        old.overlay:Hide()
        for _, region in ipairs(old.hiddenRegions or {}) do A.ReleaseNativeRegion(old, region) end
    end
    if listening then
        for _, event in ipairs(healthEvents) do events:UnregisterEvent(event) end
        listening = false
    end
end
function A.ReleaseTargetHealthPlate(state)
    if state and bound == state then Stop() end
end
function A.UpdateTargetHealthOpacity(state, alpha)
    if bound ~= state or not bar then return end
    local opacity = Clamp(A.db.targetHealthOpacity, 0, 1, 1)
    bar:SetAlpha(alpha * opacity)
end
local function Appearance()
    if bound.native then
        local ok, r, g, b = pcall(bound.name.GetTextColor, bound.name)
        if ok and Public(r) and Public(g) and Public(b)
            and type(r) == "number" and type(g) == "number" and type(b) == "number" then bound.color = {r, g, b} end
        bound.nameAlpha = A.db.opacity * A.db.targetOpacity * (InCombatLockdown() and A.db.combatOpacity or 1)
    end
    A.StyleTargetHealthBar(bar, bound.color, bound.unit)
    -- Below the guild line when one is shown, otherwise below the name.
    local title = not bound.native and bound.title
    local below = title and title:IsShown() and (title:GetText() or "") ~= "" and title or bound.name
    A.AnchorTargetHealthBar(bar, below)
    A.UpdateTargetHealthOpacity(bound, bound.nameAlpha or 1)
end
local function UpdateHealth()
    if not Enabled() or not Valid(bound) or not FriendlyTarget() then Stop(); return end
    -- Restricted health values are valid StatusBar inputs. Do not compare,
    -- divide, format, or cache them between events; pass to the native widget.
    local okMax, maximum = pcall(UnitHealthMax, "target")
    local okHealth, current = pcall(UnitHealth, "target")
    if not okMax or not okHealth
        or (Public(maximum) and (type(maximum) ~= "number" or maximum <= 0))
        or (Public(current) and type(current) ~= "number") then bar:Hide(); return end
    local okRange = pcall(bar.SetMinMaxValues, bar, 0, maximum)
    local okValue = okRange and pcall(bar.SetValue, bar, current)
    bar:SetShown(okValue == true)
end
local function SyncLevel(refresh)
    if not Enabled() or not Valid(bound) or not FriendlyTarget() then Stop(); return end
    if not A.db.targetHealthLevel then StopLevel(); return end
    local newlyListening = not levelListening
    if newlyListening then events:RegisterUnitEvent("UNIT_LEVEL", "target"); levelListening = true end
    if refresh or newlyListening then
        -- Match the level Blizzard displays, including level scaling. Read only
        -- on selection/enable/level events, never on ordinary health updates.
        A.SetTargetHealthLevelDisplay(bar, Read(UnitEffectiveLevel or UnitLevel, "target"))
    end
end
local function Bind(state)
    if bound and bound ~= state then Stop() end
    if not bar then bar = A.CreateTargetHealthBar(state.overlay); A.targetHealthBar = bar end
    if bound ~= state then
        bar:Hide()
        bound = state
        bar:SetParent(state.overlay)
        bar:SetFrameLevel(state.overlay:GetFrameLevel() + 1)
    end
    if state.native and not state.hiddenRegions then
        state.hiddenRegions = {}
        for _, key in ipairs({"HealthBarsContainer", "LevelFrame", "PlayerLevelDiffFrame"}) do
            local region = state.frame[key]
            if region then
                if not A.SuppressNativeRegion(state, region) then Stop(); return end
                state.hiddenRegions[#state.hiddenRegions + 1] = region
            end
        end
        if not nativeHooked[state.frame] then
            nativeHooked[state.frame] = true
            if state.frame.OnUnitCleared then
                hooksecurefunc(state.frame, "OnUnitCleared", function(frame)
                    if bound and bound.native and bound.frame == frame then Stop() end
                end)
            end
            if state.frame.ApplyFrameOptions then
                hooksecurefunc(state.frame, "ApplyFrameOptions", function(frame)
                    if bound and bound.native and bound.frame == frame then
                        for _, region in ipairs(bound.hiddenRegions) do A.SuppressNativeRegion(bound, region) end
                    end
                end)
            end
        end
    end
    Appearance()
    if not listening then
        for _, event in ipairs(healthEvents) do events:RegisterUnitEvent(event, "target") end
        listening = true
    end
    UpdateHealth()
    if bound then SyncLevel(true) end
end
function A.OnNativeTargetPlateReady(plate, frame, unit)
    if not Enabled() or A.db.showFriendlyPlayers or not Public(unit) or type(unit) ~= "string"
        or not unit:match("^nameplate%d+$") or Read(UnitIsUnit, unit, "target") ~= true
        or not FriendlyTarget() or not frame or not frame.name or not frame.name.GetTextColor
        or (frame.IsForbidden and Read(frame.IsForbidden, frame) ~= false) then return end
    if bound and bound.native and bound.frame == frame and Valid(bound) then Appearance(); return end
    Stop()
    if not nativeHost then nativeHost = CreateFrame("Frame"); nativeHost:EnableMouse(false) end
    nativeHost:SetParent(plate)
    nativeHost:ClearAllPoints(); nativeHost:SetAllPoints(plate); nativeHost:Show()
    Bind({native = true, frame = frame, plate = plate, unit = unit,
        overlay = nativeHost, name = frame.name, color = {1, 1, 1}})
end
function A.RefreshTargetHealth()
    if not Enabled() or not FriendlyTarget() then Stop(); return end
    if Valid(bound) then Bind(bound); return end
    Stop()
    if not A.db.showFriendlyPlayers then
        for _, plate in pairs(C_NamePlate.GetNamePlates()) do
            if (not plate.IsForbidden or Read(plate.IsForbidden, plate) == false) and plate.UnitFrame then
                A.OnNativeTargetPlateReady(plate, plate.UnitFrame, plate.UnitFrame.unit)
                if bound then return end
            end
        end
        return
    end
    for _, state in pairs(A.RenderStates) do
        if Valid(state) then Bind(state); return end
    end
end
function A.RefreshTargetHealthAppearance()
    if not Enabled() then Stop()
    elseif Valid(bound) then Appearance(); SyncLevel(false)
    else A.RefreshTargetHealth() end
end
function A.OnTargetHealthPlateReady(state)
    if bound == state then
        if not Enabled() or not Valid(state) or not FriendlyTarget() then Stop() else Appearance() end
    elseif state.sizeKey == "friendlyPlayer" and Enabled() and Valid(state) and FriendlyTarget() then
        Bind(state)
    end
end
for _, event in ipairs({"PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "NAME_PLATE_UNIT_REMOVED"}) do events:RegisterEvent(event) end
events:RegisterUnitEvent("UNIT_FACTION", "target", "player")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        if bound and Public(unit) and bound.unit == unit then Stop() end
    elseif event == "UNIT_LEVEL" then
        if unit == "target" and bound then SyncLevel(true) end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then
        if unit == "target" and bound then UpdateHealth() end
        if event == "UNIT_CONNECTION" and unit == "target" and bound then SyncLevel(true) end
    else
        A.RefreshTargetHealth()
    end
end)
