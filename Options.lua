local _, A = ...
-- Setting actions used by the settings window (OptionsWindow.lua).
function A.SetOption(key, value)
    local db = A.db
    db[key] = value
    -- Unchecking returns every distance/size/fade value to Blizzard's default.
    if key == "customizeGlobalFade" and not db[key] then A.fadeResetAll = true end
    -- One color idea, two settings kept in step (1.10): the old checkboxes and
    -- the "Match name / Class / Custom" choice.
    if key == "targetHealthNameColor" then db.targetHealthColorMode = value and "name" or "custom" end
    if key == "targetHealthColorMode" then db.targetHealthNameColor = value == "name" end
    if key == "enemyLevelClassColor" then db.enemyLevelColorMode = value and "class" or "name" end
    if key == "enemyLevelColorMode" then db.enemyLevelClassColor = value == "class" end
    if key:match("^targetHealth") then
        if key == "targetHealthBar" then A.ApplyCVars() end
        A.RefreshTargetHealthAppearance(); A.RefreshOptions(); return
    end
    if (key == "playerShowLevel" or key == "enabled" or key:match("^wounded") or key:match("^playerLevel")) and A.UpdatePlayerEvents then A.UpdatePlayerEvents() end
    if (key:match("^icons") or key:match("^known") or key == "playerUnknownMode") and A.UpdateIconEvents then A.UpdateIconEvents() end
    if key:match("^enemy") then
        if key == "enemyEnabled" then A.ApplyCVars() end
        if A.UpdateWoundedEvents then A.UpdateWoundedEvents() end
        if A.UpdatePlayerEvents then A.UpdatePlayerEvents() end
    end
    if key == "enabled" or key == "hideNativeNames" or key == "hideNativeHostileNames" or key == "hideNativePlayerNames" or key == "customizeGlobalFade" or key == "showFriendlyPlayers" then A.ApplyCVars() end
    A.Refresh()
end
function A.SetTextSize(key, field, value)
    local db = A.db
    if type(db.textSizes) ~= "table" then db.textSizes = {} end
    if type(db.textSizes[key]) ~= "table" then db.textSizes[key] = {} end
    db.textSizes[key][field] = value
    A.Refresh()
end
function A.IsCustomTextSize(key, field)
    local sizes = type(A.db.textSizes) == "table" and A.db.textSizes[key]
    return type(sizes) == "table" and type(sizes[field]) == "number" and sizes[field] > 0
end
function A.StepTextSize(key, field, delta)
    local name, subtitle = A.GetTextSizes(key)
    local current = field == "name" and name or subtitle
    A.SetTextSize(key, field, math.max(8, math.min(40, math.floor(current + 0.5) + delta)))
end
function A.StepFade(setting, global, direction)
    local values = global and A.db.fadeValues or A.db
    values[setting.key] = math.max(setting.min, math.min(setting.max,
        math.floor((values[setting.key] + direction * setting.step) * 100 + 0.5) / 100))
    if global then A.ApplyCVars() end
    A.Refresh()
end
A.labelOpacityControls = {
    {key = "opacity", label = "Overall opacity"}, {key = "subtitleOpacity", label = "Subtitle opacity"},
    {key = "targetOpacity", label = "Targeted name opacity"}, {key = "otherOpacity", label = "Untargeted name opacity"},
    {key = "combatOpacity", label = "Opacity while you are in combat"},
}
for _, setting in ipairs(A.labelOpacityControls) do
    setting.min, setting.max, setting.step, setting.percent = 0, 1, 0.05, true
end
A.targetHealthControls = {
    {"targetHealthWidth", "Width", 40, 180, 2},
    {"targetHealthHeight", "Height", 2, 16, 1},
    {"targetHealthGap", "Gap below name", 0, 16, 1},
    {"targetHealthOpacity", "Bar opacity", 0, 1, 0.05},
}
function A.StepTargetHealth(i, direction)
    local row = A.targetHealthControls[i]
    local _, width, height, gap, opacity = A.GetTargetHealthSettings()
    local current = ({width, height, gap, opacity})[i]
    A.db[row[1]] = math.max(row[3], math.min(row[4], math.floor((current + direction * row[5]) * 100 + 0.5) / 100))
    A.RefreshTargetHealthAppearance(); A.RefreshOptions()
end
-- Colors use the addon's own palette (ColorPicker.lua), never Blizzard's
-- picker directly: that one is blocked for addons in the gamepad interface.
function A.PickRoleColor(key, anchor)
    local db = A.db
    local original = {unpack(db.colors[key])}
    A.PickColor(anchor, original[1], original[2], original[3],
        function(r, g, b) db.colors[key] = {r, g, b}; A.Refresh() end,
        function() db.colors[key] = original; A.Refresh() end)
end
function A.PickPlayerColor(anchor)
    local db = A.db
    local original, mode = {unpack(db.colors.friendlyPlayer)}, db.playerColorMode
    A.PickColor(anchor, original[1], original[2], original[3],
        function(r, g, b) db.colors.friendlyPlayer = {r, g, b}; db.playerColorMode = "custom"; A.Refresh() end,
        function() db.colors.friendlyPlayer, db.playerColorMode = original, mode; A.Refresh() end)
end
function A.PickTargetHealthColor(anchor)
    local db = A.db
    local r, g, b, matched, mode = db.targetHealthR, db.targetHealthG, db.targetHealthB, db.targetHealthNameColor, db.targetHealthColorMode
    local function Update() A.RefreshTargetHealthAppearance(); A.RefreshOptions() end
    A.PickColor(anchor, r, g, b,
        function(nr, ng, nb)
            db.targetHealthR, db.targetHealthG, db.targetHealthB = nr, ng, nb
            db.targetHealthNameColor, db.targetHealthColorMode = false, "custom"
            Update()
        end,
        function()
            db.targetHealthR, db.targetHealthG, db.targetHealthB, db.targetHealthNameColor = r, g, b, matched
            db.targetHealthColorMode = mode
            Update()
        end)
end
local styleColorKeys = {"vendor", "quest", "interactive", "oppositeFaction", "friendlyPlayer"}
function A.ResetRoleColors()
    for _, key in ipairs(styleColorKeys) do A.db.colors[key] = {unpack(A.defaults.colors[key])} end
    A.Refresh()
end
function A.ResetLabelOpacity()
    for _, setting in ipairs(A.labelOpacityControls) do A.db[setting.key] = A.defaults[setting.key] end
    A.Refresh()
end
function A.ResetTargetHealth()
    for key, value in pairs(A.defaults) do
        if key:match("^targetHealth") then A.db[key] = value end
    end
    A.db.targetHealthStyleSettings = nil -- every style back to its built-in size
    A.ApplyCVars()
    A.RefreshTargetHealthAppearance(); A.RefreshOptions()
end
