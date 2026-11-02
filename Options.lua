local _, A = ...
-- Setting actions used by the settings window below.
function A.SetOption(key, value)
    local db = A.db
    db[key] = value
    -- Unchecking returns every distance/size/fade value to Blizzard's default.
    if key == "customizeGlobalFade" and not db[key] then A.fadeResetAll = true end
    -- Layout A (the settings window as before 1.10) shares these between
    -- friendly players and enemies: its controls write both. Layout B keeps
    -- them separate.
    if db.optionsLayout ~= "b" then
        if key == "iconPosition" then db.enemySwordsPosition = value end
        if key == "iconSize" then db.enemyIconSize = value end
        if key == "playerLevelSide" then db.enemyLevelSide = value end
        if key == "playerLevelSize" then db.enemyLevelSize = value end
        if key == "playerLevelColorMode" and db.enemyLevelColorMode ~= "class" then
            db.enemyLevelColorMode = value == "custom" and "custom" or "name"
        end
    end
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
    if key == "enabled" or key == "hideNativeNames" or key == "hideNativePlayerNames" or key == "customizeGlobalFade" or key == "showFriendlyPlayers" then A.ApplyCVars() end
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
function A.PickLevelColor(anchor)
    local db = A.db
    local original, mode = {unpack(db.colors.playerLevel)}, db.playerLevelColorMode
    A.PickColor(anchor, original[1], original[2], original[3],
        function(r, g, b)
            db.colors.playerLevel = {r, g, b}; db.playerLevelColorMode = "custom"
            if db.optionsLayout ~= "b" then
                db.colors.enemyLevel = {r, g, b}
                if db.enemyLevelColorMode ~= "class" then db.enemyLevelColorMode = "custom" end
            end
            A.Refresh()
        end,
        function() db.colors.playerLevel, db.playerLevelColorMode = original, mode; A.Refresh() end)
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
-- Settings window: Legacy-style side tabs (as in Forever's Legacy menu), one
-- page per topic, and two-column cards.
local W, H = 860, 580
local TAB_SCALE = 0.9
local GOLD, NOTE, DIM = {1, 0.82, 0}, {0.80, 0.77, 0.70}, {0.5, 0.5, 0.5}

local fadeLabels = {
    nameplateMaxDistance = "Maximum distance",
    nameplateMaxAlpha = "Near opacity", nameplateMinAlpha = "Far opacity",
    nameplateMaxAlphaDistance = "Start fading at", nameplateMinAlphaDistance = "End fade before max",
    nameplateOccludedAlphaMult = "Behind walls / terrain",
    nameplateMaxScale = "Near size", nameplateMinScale = "Far size",
    nameplateMaxScaleDistance = "Start shrinking at", nameplateMinScaleDistance = "End shrink before max",
}
local fadeGroups = {
    {"Distance", {"nameplateMaxDistance"}},
    {"Fade", {"nameplateMaxAlpha", "nameplateMinAlpha", "nameplateMaxAlphaDistance", "nameplateMinAlphaDistance", "nameplateOccludedAlphaMult"}},
    {"Size", {"nameplateMaxScale", "nameplateMinScale", "nameplateMaxScaleDistance", "nameplateMinScaleDistance"}},
}
local labelOpacityNames = {
    opacity = "Overall", subtitleOpacity = "Subtitles", targetOpacity = "Targeted name",
    otherOpacity = "Untargeted names", combatOpacity = "While in combat",
}
local styleRows = {
    {"general", "All NPCs", "Any NPC name", "<Subtitle>", "Default for every type"},
    {"vendor", "Vendors", "Uualia Suncrest", "<General Goods>"},
    {"quest", "Quest givers", "Quest giver name", "<Actual NPC subtitle>"},
    {"interactive", "Dialogue / services", "Interactive NPC name", "<Actual NPC subtitle>"},
    {"oppositeFaction", "Opposite faction", "Windshaper Boro", "<Shaman Trainer>"},
    {"friendlyPlayer", "Friendly players", "Aldric Stormwind", "<Silver Hand>"},
}
local pages = {
    {"General", "Interface\\Icons\\UI_Chat", "What the addon replaces, and fixes for mislabeled NPCs."},
    {"Styles", "Interface\\Icons\\INV_Misc_Coin_01", "Color and text size for each kind of NPC and for friendly players, with live previews."},
    {"Visibility", "Interface\\Icons\\Spell_Nature_Invisibilty", "Label opacity, and optional game-wide distance, fade and size."},
    {"Players", "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend", "Friendly player names: color, level, guild and title. Every extra is optional."},
    {"Icons", "Interface\\Icons\\INV_Misc_Gem_Pearl_04", "Small glyphs next to the names of people you know. Needs custom friendly player names."},
    {"People", "Interface\\Icons\\INV_Misc_Book_09", "Your People list and journal: now in Companion Journal, its own addon and window."},
    {"Immersion", "Interface\\Icons\\INV_Misc_Spyglass_03", "Names only for people you know, strangers described by what you see, and a key to hide every name."},
    {"Health bars", "Interface\\Icons\\Spell_Holy_Renew", "Thin bars on wounded friendly players, and a health bar under the player you select."},
    {"Enemies", "Interface\\Icons\\INV_BannerPVP_01", "Names of opposite-faction players in the world. While you are flagged for PvP, Blizzard's plates by default."},
}

function A.CreateOptions()
    local db, skin = A.db, A.OptionsSkin
    local frame = CreateFrame("Frame", "ForeverNamesOptions", UIParent, "BackdropTemplate")
    A.options = frame
    frame:Hide()
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverNamesOptions") end
    local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetText("Forever Names")
    if skin then
        skin.Frame(frame, heading)
    else
        frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}})
        frame:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
        heading:SetPoint("TOP", 0, -12)
    end
    local border = frame.legacyBorder or frame
    local updaters = {}
    local PlayerPreviewColor, IconPreviewColor, ShowColorChoice
    local function OnRefresh(fn) updaters[#updaters + 1] = fn end

    -- Building blocks ------------------------------------------------------
    local function Text(parent, text, x, y, template, width, color)
        local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        if width then label:SetWidth(width); label:SetWordWrap(true) end
        if color then label:SetTextColor(unpack(color)) end
        return label
    end
    local function Note(parent, text, x, y, width)
        return Text(parent, text, x, y, "GameFontHighlightSmall", width, NOTE)
    end
    local function Line(parent, x, y, width, height, alpha)
        local line = parent:CreateTexture(nil, "BORDER")
        line:SetPoint("TOPLEFT", x, y)
        line:SetSize(width, height)
        line:SetColorTexture(0.68, 0.50, 0.26, alpha or 0.45)
        return line
    end
    local function Card(parent, title, x, y, width, height)
        local card = CreateFrame("Frame", nil, parent)
        card:SetPoint("TOPLEFT", x, y)
        card:SetSize(width, height)
        local wash = card:CreateTexture(nil, "BACKGROUND", nil, -2)
        wash:SetAllPoints()
        wash:SetColorTexture(0.25, 0.17, 0.085, 0.16)
        Line(card, 0, 0, width, 1, 0.55); Line(card, 0, -height + 1, width, 1, 0.3)
        Line(card, 0, 0, 1, height, 0.3); Line(card, width - 1, 0, 1, height, 0.3)
        if title then
            Text(card, title, 14, -11, "GameFontNormal")
            Line(card, 10, -30, width - 20, 1, 0.25)
        end
        return card
    end
    local function Button(parent, text, x, y, width, onClick, height)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y)
        button:SetSize(width, height or 22)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        if skin then skin.Button(button) end
        return button
    end
    local checks = {}
    local function Check(parent, key, text, x, y, width)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x, y)
        check:SetSize(26, 26)
        local label = check.Text or check.text
        label:SetFontObject("GameFontHighlight")
        label:SetText(text)
        label:SetWidth(width or 320)
        label:SetJustifyH("LEFT")
        check:SetScript("OnClick", function(self) A.SetOption(key, self:GetChecked() == true) end)
        check.label = label
        checks[#checks + 1] = {key = key, check = check}
        return check
    end
    local function SetCheckEnabled(check, enabled)
        check:SetEnabled(enabled)
        if enabled then check.label:SetTextColor(1, 1, 1) else check.label:SetTextColor(unpack(DIM)) end
    end
    -- [-] value [+]
    local function Stepper(parent, x, y, valueWidth, onStep)
        local stepper = {}
        stepper.minus = Button(parent, "-", x, y, 24, function() onStep(-1) end)
        stepper.value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        stepper.value:SetPoint("TOPLEFT", x + 24, y - 4)
        stepper.value:SetWidth(valueWidth)
        stepper.value:SetJustifyH("CENTER")
        stepper.plus = Button(parent, "+", x + 24 + valueWidth, y, 24, function() onStep(1) end)
        function stepper:SetEnabled(enabled)
            self.minus:SetEnabled(enabled); self.plus:SetEnabled(enabled)
            if enabled then self.value:SetTextColor(1, 1, 1) else self.value:SetTextColor(unpack(DIM)) end
        end
        return stepper
    end
    local function Tooltip(owner, text)
        owner:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(type(text) == "function" and text() or text, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        owner:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    local function Percent(value) return math.floor(value * 100 + 0.5) .. "%" end
    -- Sample colors for previews (no unit is read by the settings window).
    PlayerPreviewColor = function()
        if db.playerColorMode == "custom" then return db.colors.friendlyPlayer end
        if db.playerColorMode == "class" then
            local class = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
            return class and {class.r, class.g, class.b} or {0.96, 0.55, 0.73}
        end
        return {0.4, 0.7, 1}
    end
    -- The sample player is a Paladin.
    local function SampleClassColor()
        local class = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
        return class and {class.r, class.g, class.b} or {0.96, 0.55, 0.73}
    end
    -- Icon color as it would look on the sample player.
    IconPreviewColor = function(key)
        local mode = A.IconColorMode(key)
        if mode == "name" then return PlayerPreviewColor() end
        if mode == "class" then return SampleClassColor() end
        return A.IconColor(key)
    end
    -- A color button shows the swatch, or "Class" / "Name" for follow modes.
    ShowColorChoice = function(button, mode, color, enabled)
        local follow = mode == "class" and "Class" or mode == "name" and "Name" or ""
        button:SetText(follow)
        button.swatch:SetShown(follow == "")
        button.swatch:SetColorTexture(color[1], color[2], color[3])
        button.swatch:SetAlpha(enabled and 1 or 0.4)
    end
    -- One-of-several buttons: the selected one is washed gold.
    local function Segmented(parent, x, y, width, choices, get, set)
        local buttons, left = {}, x
        for i, choice in ipairs(choices) do
            local button = Button(parent, choice[1], left, y, choice[3] or width, function() set(choice[2]) end)
            left = left + (choice[3] or width) + 6
            button.wash = button:CreateTexture(nil, "ARTWORK")
            button.wash:SetPoint("TOPLEFT", 4, -4); button.wash:SetPoint("BOTTOMRIGHT", -4, 4)
            button.wash:SetColorTexture(1, 0.72, 0.2, 0.2)
            buttons[i] = button
        end
        function buttons:Update(enabled)
            local current = get()
            for i, choice in ipairs(choices) do
                local button, selected = self[i], choice[2] == current
                button.wash:SetShown(selected)
                button:SetEnabled(enabled ~= false) -- before coloring: disabling swaps the font object
                if selected then button:GetFontString():SetTextColor(unpack(GOLD)) else button:GetFontString():SetTextColor(0.9, 0.9, 0.9) end
            end
        end
        return buttons
    end

    -- Header, content and footer ------------------------------------------
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 26, -42)
    content:SetPoint("BOTTOMRIGHT", -22, 50)
    local pageTitle = Text(content, "", 4, -2, "GameFontNormalLarge")
    local pageDescription = Note(content, "", 4, -26, 600)
    local status = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPRIGHT", -4, -6)
    status:SetJustifyH("RIGHT")
    Line(content, 0, -46, W - 48, 1, 0.45)
    OnRefresh(function()
        if not db.enabled then status:SetText("|cffff6040Forever Names is off|r")
        elseif A.nativePlateTest then status:SetText("|cffffd100Comparing with Blizzard plates|r")
        else status:SetText("|cff808080v" .. tostring(A.version) .. "|r") end
    end)

    local enable = Check(frame, "enabled", "Enable Forever Names", 22, -(H - 44), 220)
    enable:ClearAllPoints(); enable:SetPoint("BOTTOMLEFT", 22, 14)
    local close = Button(frame, "Close", 0, 0, 100, function() frame:Hide() end, 24)
    close:ClearAllPoints(); close:SetPoint("BOTTOMRIGHT", -18, 14)
    A.optionsCloseButton = close
    -- "Names | Journal": the two windows of the suite, one switch (with both installed).
    local journal = Button(frame, "Journal", 0, 0, 90, function()
        local people = A.People and A.People()
        if people then people.Open(); frame:Hide() end
    end, 24)
    journal:ClearAllPoints(); journal:SetPoint("BOTTOMRIGHT", -126, 14)
    Tooltip(journal, "Your people and the journals, in their own window.")
    local namesHere = Button(frame, "Names", 0, 0, 90, nil, 24)
    namesHere:ClearAllPoints(); namesHere:SetPoint("RIGHT", journal, "LEFT", -4, 0)
    namesHere:SetEnabled(false)
    OnRefresh(function()
        local has = A.People and A.People() ~= nil
        journal:SetShown(has); namesHere:SetShown(has)
    end)

    -- Pages and Legacy side tabs ------------------------------------------
    local pageFrames, tabs = {}, {}
    local function SelectPage(index)
        index = pageFrames[index] and index or 1
        db.optionsPage = index
        for i, page in ipairs(pageFrames) do
            page:SetShown(i == index)
            tabs[i].selected:SetShown(i == index)
        end
        pageTitle:SetText(pages[index][1])
        pageDescription:SetText(pages[index][3])
    end
    A.SelectOptionsPage = SelectPage
    local tabInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-sidetab")
    local tabWidth, tabHeight = tabInfo and tabInfo.width or 43, tabInfo and (tabInfo.height - 5) or 55
    for i, info in ipairs(pages) do
        local page = CreateFrame("Frame", nil, content)
        page:SetPoint("TOPLEFT", 0, -56)
        page:SetPoint("BOTTOMRIGHT", 0, 0)
        page:Hide()
        pageFrames[i] = page
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(tabWidth, tabHeight)
        -- 90% of Blizzard's size: nine tabs stay well inside the window's height.
        -- Offsets are in the tab's own (scaled) units, so the first keeps its place.
        tab:SetScale(TAB_SCALE)
        local background = tab:CreateTexture(nil, "BACKGROUND")
        background:SetAtlas("common-sidetab", true)
        background:SetPoint("CENTER")
        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(info[2])
        icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
        icon:SetPoint("CENTER", -4, 0)
        if tab.CreateMaskTexture and icon.AddMaskTexture then
            icon:SetSize(50, 50)
            local mask = tab:CreateMaskTexture()
            mask:SetAtlas("common-sidetab-mask", true)
            mask:SetPoint("CENTER")
            icon:AddMaskTexture(mask)
        else
            icon:SetSize(34, 34)
        end
        tab.selected = tab:CreateTexture(nil, "OVERLAY")
        tab.selected:SetAtlas("common-sidetab-selected", true)
        tab.selected:SetPoint("CENTER")
        local hover = tab:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAtlas("common-sidetab-hover", true)
        hover:SetPoint("CENTER")
        tab:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", -3, -1) end)
        tab:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", -4, 0) end)
        tab:SetScript("OnClick", function()
            if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
            SelectPage(i)
        end)
        Tooltip(tab, info[1])
        tabs[i] = tab
    end
    -- Display order of the side tabs (page numbers stay the same). People (a
    -- link to Companion Journal) comes last.
    -- Without Companion Journal there is no People tab.
    local tabOrder = {1, 2, 3, 4, 5, 9, 7, 8, 6}
    if not A.People() then tabOrder[#tabOrder] = nil; tabs[6]:Hide() end
    for position, index in ipairs(tabOrder) do
        local tab = tabs[index]
        -- Same placement as LegacySystemFrame's tabs: outside the right edge.
        if position == 1 then tab:SetPoint("TOPLEFT", border, "TOPRIGHT", 0, -44 / TAB_SCALE)
        else tab:SetPoint("TOPLEFT", tabs[tabOrder[position - 1]], "BOTTOMLEFT", 0, -2) end
    end

    -- Page 1: General -------------------------------------------------------
    do
        local page = pageFrames[1]
        local names = Card(page, "Blizzard's own names", 0, 0, 400, 250)
        Check(names, "hideNativeNames", "Hide Blizzard NPC names", 12, -40)
        Note(names, "Both factions. Forever controls the native-name distance; addons cannot change its cutoff.", 44, -66, 340)
        Check(names, "includeOppositeFaction", "Label opposite-faction service NPCs", 12, -104)
        Note(names, "Non-attackable trainers, vendors and other services of the other faction.", 44, -130, 340)
        Note(names, "Unchecking restores your game's own NPC-name settings.", 14, -218, 370)

        local text = Card(page, "Label text", 410, 0, 400, 250)
        Check(text, "nativeSmoothScaling", "Smooth scaling with Blizzard's font", 12, -40)
        Note(text, "Labels use Blizzard's nameplate font and engine scaling, and replace native health bars and levels. Sizes are set per NPC type on the NPC styles page.", 44, -66, 340)
        local compare = Button(text, "Compare with Blizzard", 14, -130, 190, function()
            SlashCmdList.FOREVERNAMES("compare")
            A.RefreshOptions()
        end)
        Note(text, "Temporarily shows Blizzard's plates with the same distance and size settings. Click again to return.", 14, -162, 370)
        OnRefresh(function() compare:SetText(A.nativePlateTest and "Stop comparing" or "Compare with Blizzard") end)

        local fix = Card(page, "Mislabeled NPC?", 0, -262, 810, 170)
        Note(fix, "Target the NPC, then pick how it should be labeled. Auto returns it to automatic detection.", 14, -40, 780)
        for i, entry in ipairs({{"Vendor", "vendor"}, {"Quest giver", "quest"}, {"Service", "interactive"}, {"Hide", "hidenpc"}, {"Auto", "auto"}}) do
            local button = Button(fix, entry[1], 14 + (i - 1) * 124, -64, 114, function() SlashCmdList.FOREVERNAMES(entry[2]) end)
            Tooltip(button, "Same as /fnames " .. entry[2] .. " with the NPC targeted.")
        end
        Note(fix, "Labels go on friendly NPCs you can interact with. Other friendly NPC plates are hidden, and enemies keep Blizzard's plates. NPCs without a subtitle, and friendly players, show only their name.", 14, -104, 780)
    end

    -- Page 2: NPC styles ----------------------------------------------------
    do
        local page = pageFrames[2]
        local card = Card(page, nil, 0, 0, 810, 366)
        for _, header in ipairs({{"Type", 14}, {"Preview", 170}, {"Color", 440}, {"Name size", 520}, {"Subtitle size", 642}}) do
            Text(card, header[1], header[2], -12, "GameFontNormalSmall")
        end
        Line(card, 10, -32, 790, 1, 0.3)
        for i, row in ipairs(styleRows) do
            local key, y = row[1], -38 - (i - 1) * 54
            local line = CreateFrame("Frame", nil, card)
            line:SetPoint("TOPLEFT", 1, y)
            line:SetSize(808, 54)
            if i % 2 == 0 then
                local stripe = line:CreateTexture(nil, "BACKGROUND", nil, -1)
                stripe:SetAllPoints()
                stripe:SetColorTexture(0, 0, 0, 0.12)
            end
            Text(line, row[2], 13, -12, "GameFontHighlight", 150)
            if row[5] then Note(line, row[5], 13, -30, 150) end
            local name = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            name:SetPoint("TOPLEFT", 169, -6)
            name:SetWidth(260); name:SetWordWrap(false); name:SetJustifyH("LEFT")
            name:SetText(row[3])
            local subtitle = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            subtitle:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
            subtitle:SetWidth(260); subtitle:SetWordWrap(false); subtitle:SetJustifyH("LEFT")
            subtitle:SetText(row[4])
            local swatch
            if key == "friendlyPlayer" then
                local link = Button(line, "Players", 437, -16, 64, function() SelectPage(4) end)
                Tooltip(link, "Friendly player colors are chosen on the Players page.")
            elseif key ~= "general" then
                swatch = Button(line, "", 439, -16, 48, function(self) A.PickRoleColor(key, self) end)
                swatch.color = swatch:CreateTexture(nil, "ARTWORK")
                swatch.color:SetPoint("TOPLEFT", 7, -6); swatch.color:SetPoint("BOTTOMRIGHT", -7, 6)
                swatch.color:SetColorTexture(1, 1, 1)
                Tooltip(swatch, "Choose this type's label color.")
            else
                Note(line, "per type", 446, -20)
            end
            local steppers = {}
            for f, field in ipairs({"name", "subtitle"}) do
                local stepper = Stepper(line, f == 1 and 519 or 641, -16, 50, function(delta) A.StepTextSize(key, field, delta) end)
                -- The number itself resets a custom size back to inherited.
                local hit = CreateFrame("Button", nil, line)
                hit:SetPoint("TOPLEFT", stepper.value, "TOPLEFT", 0, 4)
                hit:SetSize(50, 20)
                hit:SetScript("OnClick", function()
                    if A.IsCustomTextSize(key, field) then A.SetTextSize(key, field, nil) end
                end)
                Tooltip(hit, function()
                    if not A.IsCustomTextSize(key, field) then
                        return key == "general" and "Automatic: follows the game's nameplate size." or "Inherited from All NPCs."
                    end
                    return key == "general" and "Custom size. Click to return to automatic." or "Custom size. Click to inherit from All NPCs."
                end)
                steppers[field] = stepper
            end
            Button(line, "Reset", 745, -16, 56, function()
                A.SetTextSize(key, "name", nil); A.SetTextSize(key, "subtitle", nil)
            end)
            OnRefresh(function()
                local nameSize, subtitleSize = A.GetTextSizes(key)
                -- Keep big sizes readable inside the row; the in-game size is unchanged.
                local fit = math.min(1, 40 / (nameSize + subtitleSize + 2))
                local color = key == "general" and {0.92, 0.92, 0.92} or key == "friendlyPlayer" and PlayerPreviewColor() or db.colors[key]
                for _, entry in ipairs({{name, nameSize}, {subtitle, subtitleSize}}) do
                    entry[1]:SetFontObject("SystemFont_NamePlate")
                    entry[1]:SetTextHeight(entry[2] * fit)
                    entry[1]:SetTextColor(unpack(color))
                end
                if swatch then swatch.color:SetColorTexture(unpack(color)) end
                for field, stepper in pairs(steppers) do
                    local value = field == "name" and nameSize or subtitleSize
                    stepper.value:SetText(string.format("%g", math.floor(value * 10 + 0.5) / 10))
                    if A.IsCustomTextSize(key, field) then stepper.value:SetTextColor(1, 1, 1)
                    else stepper.value:SetTextColor(0.6, 0.6, 0.6) end
                end
                if key == "oppositeFaction" then line:SetAlpha(db.useOppositeFactionColor and 1 or 0.45) end
            end)
        end
        Check(page, "useOppositeFactionColor", "Opposite faction overrides role colors and sizes", 0, -374, 420)
        Note(page, "Sizes are 8-40 px before engine scaling. Gray values are inherited (All NPCs: automatic); click a white value to inherit again.", 30, -400, 600)
        Button(page, "Reset colors", 690, -378, 120, A.ResetRoleColors)
    end

    -- Page 3: Visibility ----------------------------------------------------
    do
        local page = pageFrames[3]
        local labels = Card(page, "Custom label opacity", 0, 0, 390, 232)
        Note(labels, "Multiplies the game's own distance fade. Only affects this addon's NPC and player labels.", 14, -38, 362)
        local opacity = {}
        for i, setting in ipairs(A.labelOpacityControls) do
            local y = -72 - (i - 1) * 28
            Text(labels, labelOpacityNames[setting.key] or setting.label, 14, y - 4, "GameFontHighlight", 200)
            opacity[i] = Stepper(labels, 250, y, 56, function(direction) A.StepFade(setting, false, direction) end)
        end
        Button(labels, "Reset opacity", 14, -204, 130, A.ResetLabelOpacity)
        OnRefresh(function()
            for i, setting in ipairs(A.labelOpacityControls) do opacity[i].value:SetText(Percent(db[setting.key])) end
        end)

        local ranges = Card(page, "What you will see", 0, -242, 390, 190)
        local summary = Note(ranges, "", 14, -40, 362)
        local pending = Text(ranges, "", 14, -150, "GameFontHighlightSmall", 362, GOLD)
        OnRefresh(function()
            summary:SetText(A.DistanceSummary() .. "\n\nTip: for smaller distant names, lower Far size (try 50%).")
            pending:SetText(A.pendingCVars and "Pending: settings apply when combat ends." or A.fadeError or "")
        end)

        local global = Card(page, "All nameplates (game-wide)", 400, 0, 410, 432)
        Check(global, "customizeGlobalFade", "Customize distance, fade and size", 12, -38, 340)
        Note(global, "Also changes enemy and player plates. Unchecking restores Blizzard's defaults. Changes made in combat wait until it ends.", 44, -64, 350)
        local settings = {}
        for _, setting in ipairs(A.fadeControls) do settings[setting.key] = setting end
        local rows, y = {}, -104
        for _, group in ipairs(fadeGroups) do
            Text(global, group[1], 14, y, "GameFontNormalSmall")
            y = y - 18
            for _, key in ipairs(group[2]) do
                local setting = settings[key]
                if setting then
                    Text(global, fadeLabels[key] or setting.label, 14, y - 4, "GameFontHighlight", 220)
                    rows[#rows + 1] = {setting = setting, stepper = Stepper(global, 262, y, 64, function(direction) A.StepFade(setting, true, direction) end)}
                    y = y - 24
                end
            end
            y = y - 10
        end
        OnRefresh(function()
            for _, row in ipairs(rows) do
                local setting = row.setting
                local available = GetCVar(setting.key) ~= nil
                row.stepper:SetEnabled(available and db.enabled and db.customizeGlobalFade)
                local value = db.fadeValues[setting.key]
                row.stepper.value:SetText(not available and "N/A" or setting.percent and Percent(value) or (value .. " yd"))
            end
        end)
    end

    -- Page 4: Players ----------------------------------------------------------
    do
        local page = pageFrames[4]
        local names = Card(page, "Player names", 0, 0, 390, 196)
        Check(names, "showFriendlyPlayers", "Custom names for friendly players", 12, -38, 340)
        Note(names, "Full names with surnames. Needed for the extras on this page.", 44, -62, 330)
        Check(names, "hideNativePlayerNames", "Hide Blizzard player names", 12, -96, 340)
        Note(names, "Also hides friendly pets, minions and guardians. Unchecking restores previous name settings.", 44, -120, 330)

        local colorCard = Card(page, "Colors", 0, -206, 390, 226)
        local function ColorButton(y, onClick)
            local button = Button(colorCard, "Choose custom color", 70, y, 170, onClick)
            button.color = button:CreateTexture(nil, "ARTWORK")
            button.color:SetPoint("RIGHT", -8, 0); button.color:SetSize(18, 10)
            return button
        end
        Text(colorCard, "Name", 14, -46, "GameFontHighlight")
        local colorModes = Segmented(colorCard, 70, -42, 96, {{"Blizzard", "blizzard"}, {"Class", "class"}, {"Custom", "custom"}},
            function() return db.playerColorMode end, function(mode) A.SetOption("playerColorMode", mode) end)
        local pick = ColorButton(-72, A.PickPlayerColor)
        Text(colorCard, "Level", 14, -118, "GameFontHighlight")
        local levelModes = Segmented(colorCard, 70, -114, 96, {{"Match name", "name"}, {"Class", "class"}, {"Custom", "custom"}},
            function() return db.playerLevelColorMode end, function(mode) A.SetOption("playerLevelColorMode", mode) end)
        local pickLevel = ColorButton(-144, A.PickLevelColor)
        Note(colorCard, "Blizzard keeps the game's own name colors; Class uses the player's class color; Custom uses one color for everyone.", 14, -180, 362)

        local details = Card(page, "Details (custom names only)", 400, 0, 410, 432)
        local level = Check(details, "playerShowLevel", "Show their level", 12, -36, 340)
        Tooltip(level, "?? when the game hides it. Its color is set under Colors. Skipped on your target while its health-bar level pill is shown.")
        Text(details, "Style", 44, -68, "GameFontHighlightSmall")
        local levelStyles = Segmented(details, 110, -64, 68, {{"Plain", "plain"}, {"Minimal", "minimal"}, {"Default", "default"}, {"Classic", "classic"}},
            function() return db.playerLevelStyle end, function(value) A.SetOption("playerLevelStyle", value) end)
        Text(details, "Size", 44, -98, "GameFontHighlightSmall")
        local levelSize = Stepper(details, 110, -94, 44, function(delta)
            local _, subtitle = A.GetTextSizes("friendlyPlayer")
            local current = A.LevelTextSize(subtitle)
            A.SetOption("playerLevelSize", math.max(8, math.min(40, math.floor(current + 0.5) + delta)))
        end)
        local levelAuto = Button(details, "Auto", 208, -94, 56, function() A.SetOption("playerLevelSize", nil) end)
        Tooltip(levelAuto, "Follow the friendly players' subtitle size.")
        local levelSides = Segmented(details, 272, -94, 60, {{"Before", "left"}, {"After", "right"}},
            function() return db.playerLevelSide end, function(value) A.SetOption("playerLevelSide", value) end)
        local showFor = Text(details, "Show for", 44, -128, "GameFontHighlightSmall")
        local rangeKeys = {near3 = 3, near15 = 15, near4 = 4}
        local scopes = Segmented(details, 110, -124, 52, {{"All", "all", 44}, {"10 yd", "near3", 52}, {"15 yd", "near15", 52},
            {"28 yd", "near4", 52}, {"Target", "target", 64}},
            function()
                local scope = A.LevelScope()
                local range = (db.playerLevelRange == 4 or db.playerLevelRange == 15) and db.playerLevelRange or 3
                return scope == "near" and ("near" .. range) or scope
            end,
            function(value)
                if rangeKeys[value] then
                    db.playerLevelRange = rangeKeys[value]
                    A.SetOption("playerLevelScope", "near")
                else
                    A.SetOption("playerLevelScope", value)
                end
            end)
        for _, button in ipairs(scopes) do
            Tooltip(button, "All players, only players within about 10, 15 or 28 yards (checked every 0.75 seconds while chosen), or only your target. Your target always shows theirs.")
        end
        local guild = Check(details, "playerShowGuild", "Guild under the name", 12, -156, 340)
        local rank = Check(details, "playerShowGuildRank", "Include their guild rank", 40, -182, 320)
        local title = Check(details, "playerShowTitle", "Show their chosen title", 12, -210, 340)
        Note(details, "Titles such as \"Sergeant\" or \"the Explorer\", with the full name kept.", 44, -234, 350)
        Line(details, 10, -258, 390, 1, 0.25)
        Text(details, "Preview", 14, -268, "GameFontNormalSmall")
        local sampleName = details:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sampleName:SetPoint("TOP", 0, -320)
        local sampleLevel = details:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sampleLevel:SetPoint("LEFT", sampleName, "RIGHT", 3, 0)
        local sampleGuild = details:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sampleGuild:SetPoint("TOP", sampleName, "BOTTOM", 0, -1)
        local sampleNote = Note(details, "", 14, -396, 382)
        OnRefresh(function()
            local on = db.showFriendlyPlayers and true or false
            colorModes:Update(on)
            pick:SetEnabled(on)
            pick.color:SetColorTexture(unpack(db.colors.friendlyPlayer))
            local levelOn = on and db.playerShowLevel and true or false
            levelModes:Update(levelOn)
            pickLevel:SetEnabled(levelOn)
            pickLevel.color:SetColorTexture(unpack(db.colors.playerLevel))
            SetCheckEnabled(level, on); SetCheckEnabled(guild, on); SetCheckEnabled(title, on)
            SetCheckEnabled(rank, on and db.playerShowGuild)
            local levelOptions = on and db.playerShowLevel and true or false
            levelStyles:Update(levelOptions); levelSides:Update(levelOptions)
            scopes:Update(levelOptions)
            if levelOptions then showFor:SetTextColor(1, 1, 1) else showFor:SetTextColor(0.5, 0.5, 0.5) end
            levelSize:SetEnabled(levelOptions); levelAuto:SetEnabled(levelOptions)
            local nameSize, subtitleSize = A.GetTextSizes("friendlyPlayer")
            local color = PlayerPreviewColor()
            for _, entry in ipairs({{sampleName, nameSize}, {sampleGuild, subtitleSize}, {sampleLevel, subtitleSize}}) do
                entry[1]:SetFontObject("SystemFont_NamePlate")
                entry[1]:SetTextHeight(entry[2])
                entry[1]:SetTextColor(unpack(color))
            end
            sampleName:SetText((db.playerShowTitle and "Sergeant " or "") .. "Aldric Stormwind")
            sampleLevel:SetText(db.playerShowLevel and "60" or "")
            local levelHeight = A.LevelTextSize(subtitleSize)
            sampleLevel:SetTextHeight(levelHeight)
            levelSize.value:SetText(string.format("%g", math.floor(levelHeight * 10 + 0.5) / 10))
            if type(db.playerLevelSize) == "number" then levelSize.value:SetTextColor(1, 1, 1) else levelSize.value:SetTextColor(0.6, 0.6, 0.6) end
            local gap = 3 + A.StyleLevelBadge(details, sampleLevel, levelHeight, db.playerShowLevel and db.playerLevelStyle or "plain", "60")
            sampleLevel:ClearAllPoints()
            if db.playerLevelSide == "left" then sampleLevel:SetPoint("RIGHT", sampleName, "LEFT", -gap, 0)
            else sampleLevel:SetPoint("LEFT", sampleName, "RIGHT", gap, 0) end
            if db.playerLevelColorMode == "custom" then sampleLevel:SetTextColor(unpack(db.colors.playerLevel))
            elseif db.playerLevelColorMode == "class" then
                local class = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
                sampleLevel:SetTextColor(class and class.r or 0.96, class and class.g or 0.55, class and class.b or 0.73)
            end
            sampleGuild:SetText(db.playerShowGuild and ((db.playerShowGuildRank and "Officer of " or "") .. "<Silver Hand>") or "")
            sampleNote:SetText(on and "Sizes come from the Friendly players row on the Styles page."
                or "Turn on custom names for friendly players to use these details.")
        end)
    end

    -- Page 5: Icons ------------------------------------------------------------
    do
        local page = pageFrames[5]
        local who = Card(page, "Who gets an icon", 0, 0, 390, 432)
        Text(who, "Icon", 240, -40, "GameFontNormalSmall")
        Text(who, "Color", 290, -40, "GameFontNormalSmall")
        local rows = {}
        for i, relation in ipairs(A.relationships) do
            local y = -60 - (i - 1) * 44
            local check = Check(who, relation.option, relation.label, 12, y, 190)
            local glyph = Button(who, "", 232, y, 44, nil, 26)
            glyph.icon = glyph:CreateTexture(nil, "ARTWORK")
            glyph.icon:SetPoint("CENTER"); glyph.icon:SetSize(18, 18)
            glyph:SetScript("OnClick", function(self)
                A.PickGlyph(self, A.IconGlyph(relation.key), A.IconColor(relation.key), function(name)
                    db.iconGlyphs[relation.key] = name
                    A.Refresh()
                end)
            end)
            Tooltip(glyph, "Choose the icon.")
            local color = Button(who, "", 284, y, 60, function(self) A.PickIconColor(relation.key, self) end, 26)
            color.swatch = color:CreateTexture(nil, "ARTWORK")
            color.swatch:SetPoint("TOPLEFT", 8, -7); color.swatch:SetPoint("BOTTOMRIGHT", -8, 7)
            Tooltip(color, "Choose the icon color.")
            rows[i] = {relation = relation, check = check, glyph = glyph, color = color}
        end
        Note(who, "Checked from top to bottom: when fewer icons are allowed, the first matches are shown. Friends need the game to identify the player, so icons can be missing where names are hidden (such as in instances).", 14, -244, 362)
        Button(who, "Reset icon colors", 14, -396, 150, function()
            for _, relation in ipairs(A.relationships) do
                db.colors["icon_" .. relation.key] = {unpack(relation.color)}
                db.iconGlyphs[relation.key] = relation.glyph
            end
            A.Refresh()
        end)

        local look = Card(page, "Look", 400, 0, 410, 432)
        Text(look, "Size", 14, -44, "GameFontHighlight")
        local size = Stepper(look, 110, -40, 44, function(delta)
            local current = A.IconSize((A.GetTextSizes("friendlyPlayer")))
            A.SetOption("iconSize", math.max(6, math.min(40, math.floor(current + 0.5) + delta)))
        end)
        local auto = Button(look, "Auto", 208, -40, 56, function() A.SetOption("iconSize", nil) end)
        Tooltip(auto, "Match the name's text size.")
        Text(look, "Position", 14, -80, "GameFontHighlight")
        local positions = Segmented(look, 110, -76, 78, {{"Before", "left"}, {"After", "right"}, {"Above", "above"}},
            function() return db.iconPosition end, function(value) A.SetOption("iconPosition", value) end)
        Text(look, "Show up to", 14, -116, "GameFontHighlight")
        local limits = Segmented(look, 110, -112, 50, {{"1", 1}, {"2", 2}, {"3", 3}},
            function() return db.iconMax end, function(value) A.SetOption("iconMax", value) end)
        -- Your people's icon (Companion Journal decides who has which): its place among ours.
        local peopleLabel = Text(look, "Your people", 14, -152, "GameFontHighlight")
        local peopleSide = Segmented(look, 110, -148, 78, {{"Before", "left"}, {"After", "right"}, {"With others", "same"}},
            function() return db.peopleIconSide or "same" end, function(value) A.SetOption("peopleIconSide", value) end)
        OnRefresh(function()
            local has = A.People() ~= nil
            peopleLabel:SetShown(has)
            for _, button in ipairs(peopleSide) do button:SetShown(has) end
            peopleSide:Update(db.showFriendlyPlayers and true or false)
        end)
        Line(look, 10, -192, 390, 1, 0.25)
        Text(look, "Preview", 14, -202, "GameFontNormalSmall")
        local sampleName = look:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sampleName:SetPoint("TOP", 0, -286)
        sampleName:SetText("Aldric Stormwind")
        local samplePool = {}
        for i = 1, 3 do samplePool[i] = look:CreateTexture(nil, "ARTWORK") end
        local sampleNote = Note(look, "", 14, -410, 382)
        OnRefresh(function()
            local on = db.showFriendlyPlayers and true or false
            for _, row in ipairs(rows) do
                SetCheckEnabled(row.check, on)
                local enabled = on and db[row.relation.option] and true or false
                row.glyph:SetEnabled(enabled); row.color:SetEnabled(enabled)
                local color = IconPreviewColor(row.relation.key)
                row.glyph.icon:SetTexture(A.GlyphPath(A.IconGlyph(row.relation.key)))
                row.glyph.icon:SetVertexColor(color[1], color[2], color[3])
                row.glyph.icon:SetAlpha(enabled and 1 or 0.4)
                ShowColorChoice(row.color, A.IconColorMode(row.relation.key), A.IconColor(row.relation.key), enabled)
            end
            local anyOn = on and A.AnyIconsEnabled()
            positions:Update(anyOn); limits:Update(anyOn)
            size:SetEnabled(anyOn); auto:SetEnabled(anyOn)
            local nameSize = A.GetTextSizes("friendlyPlayer")
            local iconSize = A.IconSize(nameSize)
            size.value:SetText(string.format("%g", math.floor(iconSize * 10 + 0.5) / 10))
            if type(db.iconSize) == "number" then size.value:SetTextColor(1, 1, 1) else size.value:SetTextColor(0.6, 0.6, 0.6) end
            sampleName:SetFontObject("SystemFont_NamePlate")
            sampleName:SetTextHeight(nameSize)
            sampleName:SetTextColor(unpack(PlayerPreviewColor()))
            local shown = {}
            for _, relation in ipairs(A.relationships) do
                if db[relation.option] and #shown < math.max(1, math.min(3, tonumber(db.iconMax) or 2)) then shown[#shown + 1] = relation.key end
            end
            for i, texture in ipairs(samplePool) do
                local key = shown[i]
                if key then
                    texture:SetTexture(A.GlyphPath(A.IconGlyph(key)))
                    texture:SetVertexColor(unpack(IconPreviewColor(key)))
                end
                texture:SetShown(key ~= nil)
            end
            A.LayoutIcons(samplePool, #shown, sampleName, nameSize)
            sampleNote:SetText(not on and "Turn on custom names for friendly players (Players page) to use icons."
                or #shown == 0 and "Turn on a relationship on the left to see it here."
                or "The preview shows every enabled icon; in the world each player shows only the ones that apply.")
        end)
    end

    -- Page 6: People, now Companion Journal (its own addon and window) ---------
    -- Only when it is installed (the tab is hidden otherwise).
    if A.People() then
        local page = pageFrames[6]
        local card = Card(page, "Companion Journal", 0, 0, 810, 190)
        Note(card, "Your People list, their journal, and how people are added (groups, the group popup, the campfire, right-click menus) now live in Companion Journal, its own addon and window. Forever Names still draws your people's display names and icons on its labels, and counts them as known.", 14, -38, 780)
        local open = Button(card, "Open Companion Journal", 14, -110, 220, function()
            local people = A.People()
            if people then people.Open() end
        end)
        local missing = Note(card, "", 250, -114, 540)
        Note(card, "Also /cj, or /fnames people.", 14, -148, 780)
        OnRefresh(function()
            local people = A.People()
            open:SetEnabled(people ~= nil)
            missing:SetText(people and "" or "Companion Journal is not installed or is turned off.")
        end)
    end

    -- Page 7: Immersion --------------------------------------------------------
    do
        local page = pageFrames[7]
        local unknown = Card(page, "People you don't know", 0, 0, 390, 432)
        Note(unknown, "Their label in the world. Needs custom friendly player names.", 14, -38, 362)
        local modes = Segmented(unknown, 14, -60, 114, {{"Their name", "name"}, {"A stranger", "stranger"}, {"No label", "hide"}},
            function() return db.playerUnknownMode end, function(value) A.SetOption("playerUnknownMode", value) end)
        Text(unknown, "A stranger is shown as", 14, -104, "GameFontHighlight")
        local styles = Segmented(unknown, 14, -126, 114, {{"Race and class", "raceclass"}, {"Race", "race"}, {"\"Stranger\"", "stranger"}},
            function() return db.playerStrangerStyle end, function(value) A.SetOption("playerStrangerStyle", value) end)
        Line(unknown, 10, -166, 370, 1, 0.25)
        Text(unknown, "Who counts as known", 14, -178, "GameFontNormalSmall")
        Note(unknown, A.People() and "Everyone in your Companion Journal list, plus:" or "These count as known:", 14, -198, 362)
        local knownChecks = {
            Check(unknown, "knownGroup", "Group and raid members", 12, -218, 340),
            Check(unknown, "knownGuild", "Guild members", 12, -244, 340),
            Check(unknown, "knownFriends", "Friends and Battle.net friends", 12, -270, 340),
        }
        local example = Text(unknown, "", 14, -320, "GameFontHighlight", 362)
        if A.People() then
            Note(unknown, "Tip: add someone to Companion Journal (/cj tag, or the key binding) the moment you meet them.", 14, -380, 362)
        end

        local keyCard = Card(page, "Hide every name", 400, 0, 410, 140)
        Note(keyCard, "Fades out all Forever Names labels (NPCs and players), and back again. Key binding: \"Hide or show names\" (Key Bindings > Forever Names), or /fnames hide.", 14, -38, 382)
        local hideNow = Button(keyCard, "Hide names now", 14, -104, 160, function() A.ToggleLabels(); A.RefreshOptions() end)

        -- Your people live in Companion Journal (its own addon and window).
        if A.People() then
            local knownCard = Card(page, "Your people (Companion Journal)", 400, -150, 410, 282)
            Note(knownCard, "Everyone in your Companion Journal list counts as known. The list, the journal, and how people are added live in Companion Journal, its own addon and window; Forever Names draws their display names and icons on its labels.", 14, -38, 382)
            Button(knownCard, "Open Companion Journal", 14, -118, 220, function()
                local people = A.People()
                if people then people.Open() end
            end)
        end
        OnRefresh(function()
            local on = db.showFriendlyPlayers and true or false
            modes:Update(on)
            local active = on and db.playerUnknownMode ~= "name"
            styles:Update(active and db.playerUnknownMode == "stranger")
            for _, check in ipairs(knownChecks) do SetCheckEnabled(check, active and true or false) end
            local sample = db.playerStrangerStyle == "stranger" and "Stranger" or db.playerStrangerStyle == "race" and "Night Elf" or "Night Elf Druid"
            example:SetText(not active and "Everyone keeps their name."
                or db.playerUnknownMode == "hide" and "Unknown players show no label at all."
                or ("Unknown players read as: |cffffffff" .. sample .. "|r"))
            hideNow:SetText(A.labelsHidden and "Show names" or "Hide names now")
        end)
    end

    -- Page 8: Health bar -------------------------------------------------------
    do
        local page = pageFrames[8]
        local wounded = Card(page, "Wounded player health bar", 0, 0, 390, 212)
        local everyone = Check(wounded, "woundedPlayers", "Bar on wounded friendly players", 12, -36, 340)
        local group = Check(wounded, "woundedParty", "Bar on wounded group members", 12, -62, 340)
        Note(wounded, "Shown only while someone is hurt, to spot who could use help. Needs custom friendly player names.", 44, -90, 330)
        Text(wounded, "Width", 14, -128, "GameFontHighlight")
        local widthStep = Stepper(wounded, 80, -124, 44, function(delta)
            A.SetOption("woundedWidth", math.max(20, math.min(160, (tonumber(db.woundedWidth) or 60) + delta * 4)))
        end)
        Text(wounded, "Height", 14, -158, "GameFontHighlight")
        local heightStep = Stepper(wounded, 80, -154, 44, function(delta)
            A.SetOption("woundedHeight", math.max(1, math.min(8, (tonumber(db.woundedHeight) or 2) + delta)))
        end)
        local woundedColor = Button(wounded, "Bar color", 236, -124, 140, function(self) A.PickWoundedColor(self) end)
        woundedColor.swatch = woundedColor:CreateTexture(nil, "ARTWORK")
        woundedColor.swatch:SetPoint("RIGHT", -8, 0); woundedColor.swatch:SetSize(18, 10)
        local sample = A.WoundedHolder(wounded)
        sample.bar:SetMinMaxValues(0, 100); sample.bar:SetValue(60)
        local woundedNote = Text(wounded, "", 14, -190, "GameFontHighlightSmall", 362, GOLD)

        local vitals = Card(page, "Friendly nameplates", 0, -222, 390, 96)
        Check(vitals, "targetOnlyVitals", "Health and level updates only for my target", 12, -34, 340)
        Note(vitals, "Saves work in crowds. Friendly nameplates stay enabled while custom names or a health bar are on.", 44, -58, 330)

        local previewCard = Card(page, "Selected player preview", 0, -328, 390, 104)
        local previewName = previewCard:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        previewName:SetPoint("TOP", 0, -40)
        previewName:SetWidth(180); previewName:SetJustifyH("CENTER")
        previewName:SetText("Friendly player")
        local preview = A.CreateTargetHealthBar(previewCard)
        preview:SetMinMaxValues(0, 100); preview:SetValue(65)
        Note(previewCard, "Sample: 65% health, level 60.", 14, -84, 362)
        OnRefresh(function()
            local on = db.showFriendlyPlayers and true or false
            SetCheckEnabled(everyone, on); SetCheckEnabled(group, on)
            local active = on and (db.woundedPlayers or db.woundedParty) and true or false
            widthStep:SetEnabled(active); heightStep:SetEnabled(active); woundedColor:SetEnabled(active)
            widthStep.value:SetText((tonumber(db.woundedWidth) or 60) .. " px")
            heightStep.value:SetText((tonumber(db.woundedHeight) or 2) .. " px")
            local barMode = db.woundedColorMode or "custom"
            local barSample = barMode == "name" and PlayerPreviewColor()
                or barMode == "class" and SampleClassColor() or db.colors.wounded
            woundedColor:SetText(barMode == "class" and "Bar color: class" or barMode == "name" and "Bar color: name" or "Bar color")
            woundedColor.swatch:SetShown(barMode == "custom")
            woundedColor.swatch:SetColorTexture(unpack(db.colors.wounded))
            sample:SetSize(tonumber(db.woundedWidth) or 60, tonumber(db.woundedHeight) or 2)
            sample:ClearAllPoints(); sample:SetPoint("TOP", woundedColor, "BOTTOM", 0, -16)
            sample.bar:SetStatusBarColor(unpack(barSample))
            sample:SetAlpha(active and 1 or 0.4)
            sample:Show()
            woundedNote:SetText(A.WoundedAvailable() and "" or "This client does not offer the health curve these bars need.")
        end)

        local bar = Card(page, "Selected player's health bar", 400, 0, 410, 432)
        Check(bar, "targetHealthBar", "Show under the selected friendly player", 12, -38, 350)
        Note(bar, "Only your current friendly target; works with custom or Blizzard names.", 44, -62, 350)
        Text(bar, "Style", 14, -98, "GameFontHighlight")
        local styles = {}
        for i, key in ipairs({"minimal", "default", "classic"}) do
            local button = Button(bar, A.targetHealthPresets[key].label, 110 + (i - 1) * 98, -94, 92, function() A.SetTargetHealthPreset(key) end)
            button.wash = button:CreateTexture(nil, "ARTWORK")
            button.wash:SetPoint("TOPLEFT", 4, -4); button.wash:SetPoint("BOTTOMRIGHT", -4, 4)
            button.wash:SetColorTexture(1, 0.72, 0.2, 0.2)
            button.key = key
            styles[i] = button
        end
        local sizeRows = {}
        for i, row in ipairs(A.targetHealthControls) do
            local y = -134 - (i - 1) * 30
            Text(bar, row[2], 14, y - 4, "GameFontHighlight", 200)
            sizeRows[i] = Stepper(bar, 262, y, 64, function(direction) A.StepTargetHealth(i, direction) end)
        end
        local nameColor = Check(bar, "targetHealthNameColor", "Match the player's name color", 12, -258, 220)
        local custom = Button(bar, "Custom color", 262, -260, 136, A.PickTargetHealthColor)
        local level = Check(bar, "targetHealthLevel", "Show the player's level", 12, -294, 340)
        Note(bar, "In a small pill attached to the right of the bar.", 44, -318, 350)
        Button(bar, "Reset bar", 14, -396, 120, A.ResetTargetHealth)
        OnRefresh(function()
            local preset, width, height, gap, opacity = A.GetTargetHealthSettings()
            local on = db.targetHealthBar and true or false
            for _, button in ipairs(styles) do
                local selected = A.targetHealthPresets[button.key] == preset
                button.wash:SetShown(selected)
                button:SetEnabled(on) -- before coloring: disabling swaps the font object
                if selected then button:GetFontString():SetTextColor(unpack(GOLD)) else button:GetFontString():SetTextColor(0.9, 0.9, 0.9) end
            end
            for i, value in ipairs({width .. " px", height .. " px", gap .. " px", Percent(opacity)}) do
                sizeRows[i].value:SetText(value)
                sizeRows[i]:SetEnabled(on)
            end
            SetCheckEnabled(nameColor, on); SetCheckEnabled(level, on)
            custom:SetEnabled(on)
            if on then custom:GetFontString():SetTextColor(db.targetHealthR, db.targetHealthG, db.targetHealthB) end
            A.StyleTargetHealthBar(preview, {1, 1, 1})
            A.AnchorTargetHealthBar(preview, previewName)
            A.SetTargetHealthLevelDisplay(preview, 60)
            preview:Show()
        end)
    end

    -- Page 9: Enemies -----------------------------------------------------------
    do
        local page = pageFrames[9]
        local card = Card(page, "Opposite-faction players", 0, 0, 400, 432)
        Check(card, "enemyEnabled", "Custom names for opposite-faction players", 12, -34, 360)
        Note(card, "In the world. Where the game hides names (battlegrounds, instances), Blizzard's plates stay.", 44, -58, 340)
        Text(card, "When I'm flagged for PvP", 14, -92, "GameFontNormalSmall")
        local flagged = Segmented(card, 14, -108, 60, {{"Blizzard's plates", "native", 136}, {"Our names on their bars", "names", 180}},
            function() return db.enemyFlaggedStyle == "names" and "names" or "native" end,
            function(value) A.SetOption("enemyFlaggedStyle", value) end)
        Text(card, "When I'm not flagged: show names for", 14, -144, "GameFontNormalSmall")
        local rangeKeys = {near3 = 3, near15 = 15, near4 = 4}
        local scopes = Segmented(card, 14, -160, 52, {{"All", "all", 44}, {"10 yd", "near3", 52}, {"15 yd", "near15", 52},
            {"28 yd", "near4", 52}, {"Target", "target", 60}, {"None", "hidden", 52}},
            function()
                if db.enemyScope == "near" then return "near" .. ((db.enemyRange == 4 or db.enemyRange == 15) and db.enemyRange or 3) end
                return db.enemyScope or "all"
            end,
            function(value)
                if rangeKeys[value] then db.enemyRange = rangeKeys[value]; A.SetOption("enemyScope", "near")
                else A.SetOption("enemyScope", value) end
            end)
        Note(card, "Blizzard's health bars are hidden while you are not flagged. Your target always shows its name.", 14, -188, 372)
        Text(card, "Name color", 14, -222, "GameFontNormalSmall")
        local colors = Segmented(card, 14, -238, 60, {{"Blizzard", "blizzard", 74}, {"Class", "class", 58}, {"Faction", "faction", 66}, {"Custom", "custom", 64}},
            function() return db.enemyColorMode or "faction" end, function(value) A.SetOption("enemyColorMode", value) end)
        local custom = Button(card, "Color", 304, -238, 82, function(self) A.PickRoleColor("enemyPlayer", self) end)
        custom.swatch = custom:CreateTexture(nil, "ARTWORK")
        custom.swatch:SetPoint("RIGHT", -8, 0); custom.swatch:SetSize(16, 10)
        Text(card, "Name size", 14, -278, "GameFontHighlightSmall")
        local nameSize = Stepper(card, 86, -274, 40, function(delta) A.StepTextSize("enemyPlayer", "name", delta) end)
        Text(card, "Subtitle", 204, -278, "GameFontHighlightSmall")
        local subSize = Stepper(card, 262, -274, 40, function(delta) A.StepTextSize("enemyPlayer", "subtitle", delta) end)
        Button(card, "Auto", 356, -274, 34, function()
            A.SetTextSize("enemyPlayer", "name", nil); A.SetTextSize("enemyPlayer", "subtitle", nil)
        end)
        local showLevel = Check(card, "enemyShowLevel", "Level", 12, -306, 90)
        local showGuild = Check(card, "enemyShowGuild", "Guild", 120, -306, 90)
        local showTitle = Check(card, "enemyShowTitle", "Title", 228, -306, 90)
        Tooltip(showLevel, "Uses the level style, size and position from the Players page.")
        local stranger = Check(card, "enemyStranger", "Show them as strangers", 12, -338, 360)
        if A.People() then Tooltip(stranger, "Rivals in your Companion Journal list keep their names.") end
        local strangerStyles = Segmented(card, 44, -364, 60, {{"Race and class", "raceclass", 116}, {"Race", "race", 60}, {"\"Stranger\"", "stranger", 90}},
            function() return db.enemyStrangerStyle or "raceclass" end, function(value) A.SetOption("enemyStrangerStyle", value) end)
        Text(card, "Mark", 14, -398, "GameFontHighlightSmall")
        local marksRow = Segmented(card, 60, -394, 50, {{"None", "none", 56}, {"\194\171 Name \194\187", "guillemets", 96}, {"(Name)", "parens", 76}},
            function() return db.enemyMark or "none" end, function(value) A.SetOption("enemyMark", value) end)
        for _, button in ipairs(marksRow) do Tooltip(button, "A quiet mark around enemy names, so they read differently from friendly ones.") end

        local iconCard = Card(page, "Icons and colors", 410, 0, 400, 150)
        local faction = Check(iconCard, "enemyFactionIcon", "Their faction emblem", 12, -34, 200)
        Tooltip(faction, "Blizzard's small Horde or Alliance emblem. Size and position follow the Icons page.")
        local factionClass = Check(iconCard, "enemyFactionClassColor", "In their class color", 212, -34, 170)
        Check(iconCard, "enemyPvpIcon", "Crossed swords when their PvP flag is on", 12, -64, 360)
        Note(iconCard, "They can be attacked by flagged players.", 44, -88, 200)
        local pvpColor = Button(iconCard, "Swords color", 256, -84, 130, function(self) A.PickRoleColor("enemyPvp", self) end)
        pvpColor.swatch = pvpColor:CreateTexture(nil, "ARTWORK")
        pvpColor.swatch:SetPoint("RIGHT", -8, 0); pvpColor.swatch:SetSize(16, 10)
        local levelClass = Check(iconCard, "enemyLevelClassColor", "Their level in their class color", 12, -114, 360)

        local barCard = Card(page, "Health bar", 410, -160, 400, 110)
        local barCheck = Check(barCard, "enemyHealthBar", "Always show their health bar, in their class color", 12, -34, 370)
        Tooltip(barCheck, "Under their name while you are not flagged. With \"Our names on their bars\", Blizzard's bar is shown instead.")
        Text(barCard, "Width", 14, -74, "GameFontHighlightSmall")
        local barWidth = Stepper(barCard, 60, -70, 44, function(delta)
            A.SetOption("enemyBarWidth", math.max(20, math.min(160, (tonumber(db.enemyBarWidth) or 60) + delta * 4)))
        end)
        Text(barCard, "Height", 200, -74, "GameFontHighlightSmall")
        local barHeight = Stepper(barCard, 250, -70, 44, function(delta)
            A.SetOption("enemyBarHeight", math.max(1, math.min(8, (tonumber(db.enemyBarHeight) or 3) + delta)))
        end)

        if A.People() then
            local rivals = Card(page, "Rivals", 410, -280, 400, 66)
            Note(rivals, "Enemies you add go to Companion Journal > Rivals.", 14, -38, 250)
            Button(rivals, "Open Rivals", 270, -34, 116, function()
                local people = A.People()
                if people then people.Open("rival") end
            end)
        end

        -- Test switch (not saved, off after a reload).
        local test = Card(page, "Test (not saved)", 410, -356, 400, 76)
        local testPreview = CreateFrame("CheckButton", nil, test, "UICheckButtonTemplate")
        testPreview:SetPoint("TOPLEFT", 12, -36); testPreview:SetSize(26, 26)
        local testLabel = testPreview.Text or testPreview.text
        testLabel:SetFontObject("GameFontHighlight"); testLabel:SetText("Show friendly players as enemies")
        testLabel:SetWidth(340); testLabel:SetJustifyH("LEFT")
        testPreview:SetScript("OnClick", function(self) A.SetEnemyTest(self:GetChecked() == true) end)
        Tooltip(testPreview, "Friendly players around you are drawn as opposite-faction players with these settings. Also /fnames enemytest.")

        OnRefresh(function()
            local on = db.enemyEnabled and true or false
            flagged:Update(on); scopes:Update(on); colors:Update(on); strangerStyles:Update(on and db.enemyStranger and true or false)
            custom:SetEnabled(on and db.enemyColorMode == "custom")
            custom.swatch:SetColorTexture(unpack(db.colors.enemyPlayer))
            pvpColor:SetEnabled(on and db.enemyPvpIcon and true or false)
            pvpColor.swatch:SetColorTexture(unpack(db.colors.enemyPvp))
            nameSize:SetEnabled(on); subSize:SetEnabled(on)
            local n, t = A.GetTextSizes("enemyPlayer")
            nameSize.value:SetText(string.format("%g", math.floor(n * 10 + 0.5) / 10))
            subSize.value:SetText(string.format("%g", math.floor(t * 10 + 0.5) / 10))
            for _, check in ipairs({showLevel, showGuild, showTitle, stranger}) do SetCheckEnabled(check, on) end
            testPreview:SetChecked(A.enemyTest == true)
            marksRow:Update(on)
            SetCheckEnabled(factionClass, on and db.enemyFactionIcon and true or false)
            SetCheckEnabled(levelClass, on and db.enemyShowLevel and true or false)
            SetCheckEnabled(barCheck, on)
            local barOn = on and db.enemyHealthBar and true or false
            barWidth:SetEnabled(barOn); barHeight:SetEnabled(barOn)
            barWidth.value:SetText((tonumber(db.enemyBarWidth) or 60) .. " px")
            barHeight.value:SetText((tonumber(db.enemyBarHeight) or 3) .. " px")
        end)
    end

    function A.RefreshOptions()
        -- Closed window: nothing to redraw (OnShow refreshes it when opened).
        if not frame:IsShown() then return end
        for _, entry in ipairs(checks) do entry.check:SetChecked(db[entry.key]) end
        for _, update in ipairs(updaters) do update() end
    end
    if frame.HookScript then frame:HookScript("OnShow", A.RefreshOptions)
    else frame:SetScript("OnShow", A.RefreshOptions) end
    function A.OpenOptions()
        if UIParent and UIParent.GetWidth and UIParent.GetHeight then
            -- The side tabs sit outside the frame's right edge.
            frame:SetScale(math.max(0.4, math.min(1, (UIParent:GetWidth() - 40) / (W + 60), (UIParent:GetHeight() - 40) / H)))
        end
        A.RefreshOptions()
        frame:Show()
    end
    -- The last page you used (People moved to Companion Journal: Players).
    SelectPage(db.optionsPage == 6 and 4 or db.optionsPage or 1)
    A.RefreshOptions()
end
