local _, A = ...
-- Settings window, layout B (1.10): organized by who a setting is about, not
-- by when it was added. Tabs: Players, Enemies, NPCs, All names. Players and
-- Enemies use the same cards in the same places, under a live preview.
-- Layout A (Options.lua) is the window as it was before 1.10 and stays as the
-- fallback: the footer switches between them. Both edit the same settings.
local W, H = 860, 580
local TAB_SCALE = 0.9
local GOLD, NOTE, DIM = {1, 0.82, 0}, {0.80, 0.77, 0.70}, {0.5, 0.5, 0.5}
local ROW, GAP = 24, 8
local PREVIEW_H = 80
local RANGES = {{"All", "all"}, {"10 yd", "near3"}, {"15 yd", "near15"}, {"28 yd", "near4"}, {"Target", "target"}}
local RANGE_OF = {near3 = 3, near15 = 15, near4 = 4}
local COLOR_MODES = {{"Match name", "name"}, {"Class", "class"}, {"Custom", "custom"}}

-- Kit: the few building blocks the pages use ------------------------------------
local function NewKit(frame)
    local skin = A.OptionsSkin
    local kit, updaters = {}, {}
    kit.updaters = updaters
    local function On(fn) updaters[#updaters + 1] = fn end
    kit.On = On
    -- Text widths: measured with real fonts in the game, estimated elsewhere.
    local probes = {}
    local function Width(template, text)
        local probe = probes[template]
        if not probe then probe = frame:CreateFontString(nil, "ARTWORK", template); probe:Hide(); probes[template] = probe end
        probe:SetText(text)
        if probe.GetStringWidth then return math.ceil(probe:GetStringWidth() or #text * 7) end
        return #text * 7
    end
    kit.Width = Width
    local function Line(parent, x, y, width, height, alpha)
        local line = parent:CreateTexture(nil, "BORDER")
        line:SetPoint("TOPLEFT", x, y)
        line:SetSize(width, height)
        line:SetColorTexture(0.68, 0.50, 0.26, alpha or 0.45)
        return line
    end
    kit.Line = Line
    local function Text(parent, text, x, y, template, width, color)
        local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y)
        label:SetJustifyH("LEFT")
        if width then label:SetWidth(width); label:SetWordWrap(true) end
        label:SetText(text)
        if color then label:SetTextColor(unpack(color)) end
        return label
    end
    kit.Text = Text
    local function Button(parent, text, x, y, width, onClick, height)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y)
        button:SetSize(width, height or 22)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        if skin then skin.Button(button) end
        return button
    end
    kit.Button = Button
    local function Tooltip(owner, text)
        owner:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(type(text) == "function" and text() or text, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        owner:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    kit.Tooltip = Tooltip
    local function Wash(button)
        button.wash = button:CreateTexture(nil, "ARTWORK")
        button.wash:SetPoint("TOPLEFT", 4, -4); button.wash:SetPoint("BOTTOMRIGHT", -4, 4)
        button.wash:SetColorTexture(1, 0.72, 0.2, 0.2)
    end
    local function ButtonWidth(text) return math.max(28, Width("GameFontNormal", text) + 18) end

    -- Cards: stacked in a column, each filled row by row ----------------------------
    local Card = {}
    Card.__index = Card
    -- The next control goes on a new row, unless o.same (to the right of the last).
    function Card:Slot(o, width)
        if not (o and o.same) then
            self.y = self.y + self.rowH
            self.rowH = 0
            self.x = 12 + (o and o.indent and 24 or 0)
        end
        local x = self.x
        if o and o.rightEdge then x = o.rightEdge - width end
        return x, self.y
    end
    function Card:Advance(width, height)
        self.x = self.x + width + 12
        self.rowH = math.max(self.rowH, height)
    end
    function Card:Enabled(o)
        return (not self.enabledFn or self.enabledFn()) and (not (o and o.when) or o.when()) and true or false
    end
    function Card:Check(label, get, set, o)
        o = o or {}
        local width = 24 + Width("GameFontHighlight", label)
        local x, y = self:Slot(o, width)
        local check = CreateFrame("CheckButton", nil, self.frame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x - 4, -y + 1)
        check:SetSize(24, 24)
        local text = check.Text or check.text
        text:SetFontObject("GameFontHighlight"); text:SetText(label)
        text:SetWidth(width - 20); text:SetJustifyH("LEFT")
        check:SetScript("OnClick", function(box) set(box:GetChecked() == true) end)
        if o.tip then Tooltip(check, o.tip) end
        self:Advance(width, ROW)
        On(function()
            check:SetChecked(get() and true or false)
            local enabled = self:Enabled(o)
            check:SetEnabled(enabled)
            if enabled then text:SetTextColor(1, 1, 1) else text:SetTextColor(unpack(DIM)) end
        end)
        return check
    end
    -- One of several choices: choices = {{text, value}, ...}
    function Card:Seg(label, choices, get, set, o)
        o = o or {}
        local labelWidth = label and (Width("GameFontHighlightSmall", label) + 8) or 0
        local total = labelWidth
        local widths = {}
        for i, choice in ipairs(choices) do widths[i] = choice[3] or ButtonWidth(choice[1]); total = total + widths[i] + 3 end
        local swatchWidth = o.swatch and 34 or 0
        -- Too wide for the card: the label gets its own line above the buttons.
        if label and not o.same and 12 + (o.indent and 24 or 0) + total + swatchWidth > self.width - 8 then
            local lx, ly = self:Slot(o, 0)
            Text(self.frame, label, lx, -ly - 2, "GameFontHighlightSmall", nil, o.labelColor)
            self:Advance(0, 18)
            total = total - labelWidth
            label, labelWidth = nil, 0
        end
        local x, y = self:Slot(o, total + swatchWidth)
        local start = x
        if label then Text(self.frame, label, x, -y - 5, "GameFontHighlightSmall", nil, o.labelColor) end
        x = x + labelWidth
        local buttons = {}
        for i, choice in ipairs(choices) do
            local button = Button(self.frame, choice[1], x, -y - 1, widths[i], function() set(choice[2]) end)
            Wash(button)
            buttons[i] = button
            x = x + widths[i] + 3
        end
        local swatch
        if o.swatch then
            swatch = Button(self.frame, "", x + 3, -y - 1, 30, function(button) o.swatch.pick(button) end)
            swatch.color = swatch:CreateTexture(nil, "ARTWORK")
            swatch.color:SetPoint("TOPLEFT", 6, -5); swatch.color:SetPoint("BOTTOMRIGHT", -6, 5)
            Tooltip(swatch, "Choose the color.")
        end
        self.x = start + total + swatchWidth
        self.rowH = math.max(self.rowH, ROW)
        self.x = self.x + 12
        On(function()
            local current, enabled = get(), self:Enabled(o)
            for i, choice in ipairs(choices) do
                local button, selected = buttons[i], choice[2] == current
                button.wash:SetShown(selected)
                button:SetEnabled(enabled)
                if selected then button:GetFontString():SetTextColor(unpack(GOLD)) else button:GetFontString():SetTextColor(0.9, 0.9, 0.9) end
            end
            if swatch then
                swatch:SetEnabled(enabled)
                swatch.color:SetColorTexture(unpack(o.swatch.color()))
                swatch.color:SetAlpha(enabled and (current == "custom" and 1 or 0.35) or 0.25)
            end
        end)
        return buttons, total + swatchWidth
    end
    -- Match name / Class / Custom (+ swatch): the one color control everywhere.
    function Card:Color(label, get, set, pick, color, o)
        o = o or {}
        o.swatch = {pick = pick, color = color}
        return self:Seg(label, o.choices or COLOR_MODES, get, set, o)
    end
    -- [-] value [+] and an optional Auto button (only sizes that can be automatic).
    function Card:Step(label, text, onStep, o)
        o = o or {}
        local labelWidth = o.labelWidth or (Width("GameFontHighlightSmall", label) + 8)
        local valueWidth = o.valueWidth or 44
        local total = labelWidth + 24 + valueWidth + 24 + (o.auto and 60 or 0)
        local x, y = self:Slot(o, total)
        Text(self.frame, label, x, -y - 5, "GameFontHighlightSmall")
        local stepper = {}
        stepper.minus = Button(self.frame, "-", x + labelWidth, -y - 1, 24, function() onStep(-1) end)
        stepper.value = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        stepper.value:SetPoint("TOPLEFT", x + labelWidth + 24, -y - 5)
        stepper.value:SetWidth(valueWidth); stepper.value:SetJustifyH("CENTER")
        stepper.plus = Button(self.frame, "+", x + labelWidth + 24 + valueWidth, -y - 1, 24, function() onStep(1) end)
        local auto
        if o.auto then
            auto = Button(self.frame, "Auto", x + labelWidth + 48 + valueWidth + 6, -y - 1, 50, o.auto.reset)
            Tooltip(auto, o.auto.tip or "Automatic size.")
        end
        self.x = x + total
        self:Advance(0, ROW)
        On(function()
            local enabled = self:Enabled(o)
            stepper.minus:SetEnabled(enabled); stepper.plus:SetEnabled(enabled)
            stepper.value:SetText(text())
            if enabled and (not o.auto or not o.auto.isAuto()) then stepper.value:SetTextColor(1, 1, 1) else stepper.value:SetTextColor(unpack(DIM)) end
            if auto then auto:SetEnabled(enabled and not o.auto.isAuto()) end
        end)
        return stepper
    end
    function Card:Note(text, o)
        o = o or {}
        local x, y = self:Slot(o, 0)
        local width = o.width or (self.width - x - 14)
        local note = Text(self.frame, text, x, -y - 2, "GameFontHighlightSmall", width, NOTE)
        local height = note.GetStringHeight and note:GetStringHeight() or 14
        self:Advance(width, math.max(14, height) + 4)
        if o.when then On(function() note:SetTextColor(unpack(o.when() and NOTE or DIM)) end) end
        return note
    end
    function Card:Button(text, onClick, o)
        o = o or {}
        local width = o.width or (ButtonWidth(text) + 10)
        local x, y = self:Slot(o, width)
        local button = Button(self.frame, text, x, -y - 1, width, onClick)
        if o.tip then Tooltip(button, o.tip) end
        self:Advance(width, ROW)
        On(function()
            button:SetEnabled(self:Enabled(o))
            if o.label then button:SetText(o.label()) end
        end)
        return button
    end
    function Card:End()
        local height = self.y + self.rowH + 10
        self.frame:SetHeight(height)
        local card, width = self.frame, self.width
        Line(card, 0, 0, width, 1, 0.55); Line(card, 0, -height + 1, width, 1, 0.3)
        Line(card, 0, 0, 1, height, 0.3); Line(card, width - 1, 0, 1, height, 0.3)
        self.col.y = self.col.y + height + GAP
        return height
    end
    function kit.Column(parent, x, width)
        local col = {parent = parent, x = x, width = width, y = 0}
        function col:Card(title, enabledFn, tip)
            local card = setmetatable({col = self, width = width, enabledFn = enabledFn, x = 12, rowH = 0}, Card)
            card.frame = CreateFrame("Frame", nil, parent)
            card.frame:SetPoint("TOPLEFT", x, -self.y)
            card.frame:SetWidth(width)
            local wash = card.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
            wash:SetAllPoints()
            wash:SetColorTexture(0.25, 0.17, 0.085, 0.16)
            card.y = 8
            if title then
                local heading = Text(card.frame, title, 12, -8, "GameFontNormal")
                Line(card.frame, 10, -27, width - 20, 1, 0.25)
                if tip then
                    -- Hover the title for what the card is about.
                    local hit = CreateFrame("Frame", nil, card.frame)
                    hit:SetPoint("TOPLEFT", 8, -4)
                    hit:SetSize(math.max(60, (heading.GetStringWidth and heading:GetStringWidth() or 60) + 10), 22)
                    hit:EnableMouse(true)
                    Tooltip(hit, tip)
                end
                card.y = 30
            end
            return card
        end
        return col
    end
    -- A row of controls without a card around it (page headers).
    function kit.Bare(parent, width)
        local bare = setmetatable({width = width, x = 0, y = 0, rowH = 0}, Card)
        bare.frame = parent
        return bare
    end
    -- A small stepper for table rows (NPC types).
    function kit.Stepper(parent, x, y, valueWidth, onStep)
        local stepper = {}
        stepper.minus = Button(parent, "-", x, y, 24, function() onStep(-1) end)
        stepper.value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        stepper.value:SetPoint("TOPLEFT", x + 24, y - 4)
        stepper.value:SetWidth(valueWidth); stepper.value:SetJustifyH("CENTER")
        stepper.plus = Button(parent, "+", x + 24 + valueWidth, y, 24, function() onStep(1) end)
        return stepper
    end
    return kit
end

-- Settings shared by the pages ---------------------------------------------------
local function ScopeValue(scope, range)
    if scope == "near" then return "near" .. ((range == 4 or range == 15) and range or 3) end
    return scope or "all"
end
local function SetScope(scopeKey, rangeKey, value)
    if RANGE_OF[value] then A.db[rangeKey] = RANGE_OF[value]; A.SetOption(scopeKey, "near")
    else A.SetOption(scopeKey, value) end
end
local function Percent(value) return math.floor(value * 100 + 0.5) .. "%" end
local function One(value) return string.format("%g", math.floor(value * 10 + 0.5) / 10) end
-- A custom color for a "Match name / Class / Custom" setting.
local function PickCustom(colorKey, modeKey, anchor)
    local db = A.db
    local original, mode = {unpack(db.colors[colorKey])}, db[modeKey]
    A.PickColor(anchor, original[1], original[2], original[3],
        function(r, g, b) db.colors[colorKey] = {r, g, b}; A.SetOption(modeKey, "custom") end,
        function() db.colors[colorKey] = original; A.SetOption(modeKey, mode) end)
end

-- Sample players for the live preview -------------------------------------------
local CLASS_COLOR = {WARLOCK = {0.53, 0.53, 0.93}, WARRIOR = {0.78, 0.61, 0.43}, MAGE = {0.25, 0.78, 0.92},
    HUNTER = {0.67, 0.83, 0.45}, PALADIN = {0.96, 0.55, 0.73}, PRIEST = {1, 1, 1}}
local function ClassRGB(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return {c.r, c.g, c.b} end
    return CLASS_COLOR[class] or {0.9, 0.9, 0.9}
end
local function InRange(scope, range, distance, target)
    if target or scope == "all" or scope == nil then return true end
    if scope == "target" or scope == "hidden" then return false end
    local yards = range == 15 and 15 or range == 4 and 28 or 10
    return distance <= yards
end

local function Strangers(style, race, class)
    local name = class:sub(1, 1) .. class:sub(2):lower()
    return style == "race" and race or style == "raceclass" and (race .. " " .. name) or "Stranger"
end

local function Bar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar.back = bar:CreateTexture(nil, "BACKGROUND")
    bar.back:SetAllPoints(); bar.back:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT"); bar.fill:SetPoint("BOTTOMLEFT")
    return bar
end
local function ShowBar(bar, parent, width, height, color, fill, y)
    bar:ClearAllPoints(); bar:SetPoint("TOP", parent, "TOP", 0, -y)
    bar:SetSize(width, height)
    bar.fill:SetWidth(math.max(1, width * fill))
    bar.fill:SetColorTexture(color[1], color[2], color[3], 1)
    bar:Show()
end

-- One sample slot: an icons row, the name (with level), a guild line, a bar and a caption.
local function NewSlot(parent, x, width)
    local slot = {}
    slot.frame = CreateFrame("Frame", nil, parent)
    slot.frame:SetPoint("TOPLEFT", x, 4) -- 4px up: names, icons, bars and captions together
    slot.frame:SetSize(width, PREVIEW_H)
    slot.name = slot.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slot.name:SetPoint("TOP", 0, -28)
    slot.level = slot.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slot.sub = slot.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slot.sub:SetPoint("TOP", 0, -44)
    slot.caption = slot.frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    slot.caption:SetPoint("BOTTOM", 0, 6)
    slot.bars = {Bar(slot.frame), Bar(slot.frame)}
    slot.pools = {left = {}, right = {}, above = {}}
    for _, pool in pairs(slot.pools) do
        for i = 1, 3 do pool[i] = slot.frame:CreateTexture(nil, "ARTWORK") end
    end
    return slot
end
local function Fonts(fs, height, color)
    fs:SetFontObject("SystemFont_NamePlate")
    fs:SetTextHeight(height)
    fs:SetTextColor(color[1], color[2], color[3])
end
-- p: name, color, size, sub, subSize, level, lsize, lcolor, side, icons = {position = {{path|atlas, color, ...}}},
--    iconSetting, bars = {{w, h, color, fill}}, caption; p.ghost = a line of muted text instead.
local function Paint(slot, p)
    slot.caption:SetText(p.caption or "")
    if p.ghost then
        Fonts(slot.name, 11, {0.6, 0.6, 0.6})
        slot.name:SetText(p.ghost)
        slot.level:SetText(""); A.StyleLevelBadge(slot.frame, slot.level, 12, "plain", "")
        slot.sub:SetText("")
        for _, pool in pairs(slot.pools) do for _, texture in ipairs(pool) do texture:Hide() end end
        for _, bar in ipairs(slot.bars) do bar:Hide() end
        return
    end
    Fonts(slot.name, p.size, p.color)
    slot.name:SetText(p.name)
    Fonts(slot.sub, p.subSize, {0.93, 0.9, 0.83})
    slot.sub:SetText(p.sub or "")
    local gap, levelFS = 3, nil
    if p.level then
        Fonts(slot.level, p.lsize, p.lcolor)
        slot.level:SetText(p.level)
        gap = 3 + A.StyleLevelBadge(slot.frame, slot.level, p.lsize, A.db.playerLevelStyle, p.level)
        slot.level:ClearAllPoints()
        if p.side == "left" then slot.level:SetPoint("RIGHT", slot.name, "LEFT", -gap, 0)
        else slot.level:SetPoint("LEFT", slot.name, "RIGHT", gap, 0) end
        slot.level:Show()
        levelFS = slot.level
    else
        slot.level:SetText("")
        A.StyleLevelBadge(slot.frame, slot.level, 12, "plain", "")
        slot.level:Hide()
    end
    for position, pool in pairs(slot.pools) do
        local items = p.icons and p.icons[position] or {}
        for i, texture in ipairs(pool) do
            local item = items[i]
            if item then
                if item.atlas then texture:SetAtlas(item.atlas) else texture:SetTexture(item.path); texture:SetTexCoord(0, 1, 0, 1) end
                texture:SetVertexColor(item.color[1], item.color[2], item.color[3])
                if texture.SetDesaturated then texture:SetDesaturated(item.gray == true) end
                texture:Show()
            else
                texture:Hide()
            end
        end
        if #items > 0 then A.LayoutIcons(pool, #items, slot.name, p.size, levelFS, p.side, gap - 3, position, p.iconSetting) end
    end
    -- Bars sit right under the last line shown: the guild line, or the name when there is none.
    -- The line's size is the text height set above; GetStringHeight can report the font's native
    -- height instead, which pushed the bars down into the caption.
    local barTop = (p.sub and p.sub ~= "") and (44 + (p.subSize or 9) + 1) or (28 + (p.size or 12) + 1)
    for i, bar in ipairs(slot.bars) do
        local spec = p.bars and p.bars[i]
        if spec then ShowBar(bar, slot.frame, spec[1], spec[2], spec[3], spec[4], math.floor(barTop + 3 + 0.5) + (i - 1) * 6) else bar:Hide() end
    end
end

local function Preview(parent, paint)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetPoint("TOPLEFT", 0, 0)
    strip:SetSize(810, PREVIEW_H)
    -- Frame Gambit's card leather, a shade darker than the window (an inset).
    if A.OptionsSkin and A.OptionsSkin.Leather then
        A.OptionsSkin.Leather(strip, 0.72)
    else
        local wash = strip:CreateTexture(nil, "BACKGROUND")
        wash:SetAllPoints(); wash:SetColorTexture(0.16, 0.11, 0.06, 0.9)
    end
    for _, edge in ipairs({{"TOPLEFT", "TOPRIGHT", 810, 1}, {"BOTTOMLEFT", "BOTTOMRIGHT", 810, 1}}) do
        local line = strip:CreateTexture(nil, "BORDER")
        line:SetPoint(edge[1]); line:SetPoint(edge[2]); line:SetHeight(1)
        line:SetColorTexture(0.68, 0.50, 0.26, 0.4)
    end
    local tag = strip:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    tag:SetPoint("TOPLEFT", 8, -4); tag:SetText("PREVIEW")
    local slots = {}
    for i = 1, 3 do slots[i] = NewSlot(strip, (i - 1) * 270, 270) end
    local off = strip:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    off:SetPoint("CENTER"); off:SetTextColor(0.75, 0.75, 0.68)
    return {frame = strip, slots = slots, off = off, paint = paint}
end
local function RefreshPreview(preview)
    local list, message = preview.paint()
    preview.off:SetText(message or "")
    for i, slot in ipairs(preview.slots) do
        slot.frame:SetShown(list ~= nil)
        if list and list[i] then Paint(slot, list[i]) end
    end
end

local function FriendlySamples()
    local db = A.db
    if not db.showFriendlyPlayers then return nil, "Custom names for friendly players are off: Blizzard's own names show." end
    local nameSize, subSize = A.GetTextSizes("friendlyPlayer")
    local levelSize = A.LevelTextSize(subSize)
    local samples = {
        {name = "Aerynwen", class = "WARLOCK", level = 16, guild = "Dawnwatch", rank = "Officer", dist = 8, party = true, guildmate = true, hurt = 0.62,
            caption = "In your group and guild, hurt · 8 yd"},
        {name = "Thorgrim", class = "WARRIOR", level = 18, guild = "Iron Pact", rank = "Member", dist = 20, race = "Orc",
            caption = "Someone you don't know · 20 yd"},
        {name = "Lysandre", class = "MAGE", level = 15, dist = 38, friend = true, target = true, hurt = 0.8, title = "the Patient",
            caption = "Your target, a friend · 38 yd"},
    }
    local out = {}
    for i, s in ipairs(samples) do
        local known = (s.party and db.knownGroup) or (s.guildmate and db.knownGuild) or (s.friend and db.knownFriends)
        local class = ClassRGB(s.class)
        local color = db.playerColorMode == "class" and class or db.playerColorMode == "custom" and db.colors.friendlyPlayer or {0.55, 0.8, 1}
        if not known and db.playerUnknownMode == "hide" then
            out[i] = {ghost = "no label", caption = s.caption}
        else
            local name = (not known and db.playerUnknownMode == "stranger") and Strangers(db.playerStrangerStyle, s.race or "Human", s.class) or s.name
            if db.playerShowTitle and s.title and name == s.name then name = name .. " " .. s.title end
            local p = {name = name, color = color, size = nameSize, subSize = subSize, caption = s.caption, side = db.playerLevelSide, iconSetting = nil}
            if s.guild and db.playerShowGuild then p.sub = "<" .. s.guild .. (db.playerShowGuildRank and (" · " .. s.rank) or "") .. ">" end
            if db.playerShowLevel and InRange(A.LevelScope(), db.playerLevelRange, s.dist, s.target) then
                p.level, p.lsize = tostring(s.level), levelSize
                p.lcolor = db.playerLevelColorMode == "class" and class or db.playerLevelColorMode == "custom" and db.colors.playerLevel or color
            end
            local shown = {}
            local function Add(key) shown[#shown + 1] = {path = A.GlyphPath(A.IconGlyph(key)), color = A.ResolveIconColor(key, nil, {color = color, unit = nil})} end
            if s.party and db.iconsParty then Add("party") end
            if s.friend and db.iconsFriend then Add("friend") end
            if s.guildmate and db.iconsGuild then Add("guild") end
            local limit = math.max(1, math.min(3, tonumber(db.iconMax) or 2))
            local trimmed = {}
            for k = 1, math.min(limit, #shown) do trimmed[k] = shown[k] end
            p.icons = {[db.iconPosition == "right" and "right" or db.iconPosition == "above" and "above" or "left"] = trimmed}
            local bars = {}
            local function BarColor(mode, custom)
                return mode == "class" and class or mode == "custom" and custom or color
            end
            -- As in the world: the selected player's own bar replaces the wounded bar.
            local ownBar = s.target and db.targetHealthBar
            if s.hurt and not ownBar and (db.woundedPlayers or (db.woundedParty and s.party)) then
                bars[#bars + 1] = {tonumber(db.woundedWidth) or 60, tonumber(db.woundedHeight) or 2, BarColor(db.woundedColorMode, db.colors.wounded), s.hurt}
            end
            if s.target and db.targetHealthBar then
                local _, width, height = A.GetTargetHealthSettings()
                local c = db.targetHealthColorMode == "class" and class or db.targetHealthColorMode == "name" and color
                    or {db.targetHealthR, db.targetHealthG, db.targetHealthB}
                bars[#bars + 1] = {width, height, c, s.hurt or 1}
            end
            p.bars = bars
            out[i] = p
        end
    end
    return out
end

local function EnemySamples()
    local db = A.db
    if not db.enemyEnabled then return nil, "Custom names for enemies are off: Blizzard's plates show." end
    local nameSize, subSize = A.GetTextSizes("enemyPlayer")
    local levelSize = A.LevelTextSize(subSize, true)
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    local theirs = mine == "Alliance" and "Horde" or "Alliance"
    local samples = {
        {name = "Kaelith", class = "HUNTER", level = 17, dist = 12, pvp = true, race = "Night Elf", guild = "Silver Hand", rank = "Sentinel", caption = "Their PvP flag is on · 12 yd"},
        {name = "Brannoc", class = "PALADIN", level = 14, dist = 35, race = "Human", guild = "Lionheart", rank = "Knight", caption = "Not flagged · 35 yd"},
        {name = "Merwyn", class = "PRIEST", level = 16, dist = 20, pvp = true, race = "Dwarf", flagged = true, caption = "While you are flagged · 20 yd"},
    }
    local out = {}
    for i, s in ipairs(samples) do
        local class = ClassRGB(s.class)
        local color = db.enemyColorMode == "class" and class or db.enemyColorMode == "custom" and db.colors.enemyPlayer
            or db.enemyColorMode == "faction" and (A.factionColors[theirs] or {1, 0.3, 0.25}) or {1, 0.29, 0.24}
        local ghost = not s.flagged and not InRange(db.enemyScope, db.enemyRange, s.dist, false)
        if s.flagged and db.enemyFlaggedStyle ~= "names" then
            out[i] = {name = s.name, color = {1, 0.29, 0.24}, size = 12, subSize = 10, caption = s.caption .. " (Blizzard's plate)",
                bars = {{110, 8, {0.85, 0.15, 0.1}, 0.9}}}
        elseif ghost then
            out[i] = {ghost = "no name at this range", caption = s.caption}
        else
            local name = db.enemyStranger and Strangers(db.enemyStrangerStyle, s.race, s.class) or s.name
            name = A.EnemyMark(name)
            local p = {name = name, color = color, size = nameSize, subSize = subSize, caption = s.caption, side = db.enemyLevelSide,
                iconSetting = db.enemyIconSize or false}
            if s.guild and db.enemyShowGuild then p.sub = "<" .. s.guild .. (db.enemyShowGuildRank and (" · " .. s.rank) or "") .. ">" end
            if db.enemyShowLevel and InRange(A.LevelScope(true), db.enemyLevelRange, s.dist, false) then
                p.level, p.lsize = tostring(s.level), levelSize
                p.lcolor = db.enemyLevelColorMode == "class" and class or db.enemyLevelColorMode == "custom" and db.colors.enemyLevel or color
            end
            local left, others = {}, {}
            if db.enemyFactionIcon then
                left[#left + 1] = {atlas = "UI-HUD-UnitFrame-Player-PVP-" .. theirs .. "Icon", color = db.enemyFactionClassColor and class or {1, 1, 1},
                    gray = db.enemyFactionClassColor}
            end
            if db.enemyPvpIcon and s.pvp then others[#others + 1] = {path = A.GlyphPath("swords"), color = db.colors.enemyPvp} end
            local position = db.enemySwordsPosition == "right" and "right" or db.enemySwordsPosition == "above" and "above" or "left"
            p.icons = {left = left}
            for _, item in ipairs(others) do
                p.icons[position] = p.icons[position] or {}
                table.insert(p.icons[position], item)
            end
            if db.enemyHealthBar and not s.flagged then
                p.bars = {{tonumber(db.enemyBarWidth) or 60, tonumber(db.enemyBarHeight) or 3,
                    db.enemyBarColorMode == "custom" and db.colors.enemyBar or db.enemyBarColorMode == "name" and color or class, 0.85}}
            end
            out[i] = p
        end
    end
    return out
end

-- Pages ------------------------------------------------------------------------
local function NameSizeControls(card, key, label, field, o)
    card:Step(label, function() local n, s = A.GetTextSizes(key); return One(field == "name" and n or s) end,
        function(delta) A.StepTextSize(key, field, delta) end,
        {when = o and o.when, auto = {reset = function() A.SetTextSize(key, field, nil) end, isAuto = function() return not A.IsCustomTextSize(key, field) end,
            tip = "Follow the automatic size."}, valueWidth = 40})
end
local function LevelCard(col, enemy, enabledFn)
    local db = A.db
    local p = enemy and "enemy" or "player"
    local card = col:Card("Level", enabledFn)
    local on = function() return db[enemy and "enemyShowLevel" or "playerShowLevel"] end
    card:Check("Show their level", on, function(v) A.SetOption(enemy and "enemyShowLevel" or "playerShowLevel", v) end,
        {tip = "?? when the game hides it. Your selected player also shows their health bar level, if that is on."})
    card:Step("Size", function() local _, s = A.GetTextSizes(enemy and "enemyPlayer" or "friendlyPlayer"); return One(A.LevelTextSize(s, enemy)) end,
        function(delta)
            local _, s = A.GetTextSizes(enemy and "enemyPlayer" or "friendlyPlayer")
            A.SetOption(p .. "LevelSize", math.max(8, math.min(40, math.floor(A.LevelTextSize(s, enemy) + 0.5) + delta)))
        end,
        {when = on, valueWidth = 40, auto = {reset = function() A.SetOption(p .. "LevelSize", nil) end,
            isAuto = function() return type(db[p .. "LevelSize"]) ~= "number" end, tip = "Follow the guild line's size."}})
    local scopeKey, rangeKey = p .. "LevelScope", p .. "LevelRange"
    card:Seg("Range", RANGES, function() return ScopeValue(db[scopeKey], db[rangeKey]) end,
        function(value) SetScope(scopeKey, rangeKey, value) end, {when = on})
    local colorKey = enemy and "enemyLevelColorMode" or "playerLevelColorMode"
    local colors = enemy and "enemyLevel" or "playerLevel"
    card:Color("Color", function() return db[colorKey] end, function(v) A.SetOption(colorKey, v) end,
        function(anchor) PickCustom(colors, colorKey, anchor) end, function() return db.colors[colors] end, {when = on})
    card:Seg("Side", {{"Before", "left"}, {"After", "right"}}, function() return db[p .. "LevelSide"] end,
        function(v) A.SetOption(p .. "LevelSide", v) end, {when = on})
    card:Note("Classic badge. Your target always shows its level.")
    card:Note(enemy and "Key: \"Show or hide enemy levels\" (Key Bindings > Forever Names)."
        or "Key: \"Show or hide friendly levels\" (Key Bindings > Forever Names).")
    card:End()
end
local function GuildCard(col, enemy, enabledFn)
    local db = A.db
    local card = col:Card("Guild and title", enabledFn)
    local guildKey = enemy and "enemyShowGuild" or "playerShowGuild"
    card:Check("Guild under the name", function() return db[guildKey] end, function(v) A.SetOption(guildKey, v) end)
    card:Check("Include their guild rank", function() return db[enemy and "enemyShowGuildRank" or "playerShowGuildRank"] end,
        function(v) A.SetOption(enemy and "enemyShowGuildRank" or "playerShowGuildRank", v) end,
        {indent = true, when = function() return db[guildKey] end})
    card:Check("Show their chosen title", function() return db[enemy and "enemyShowTitle" or "playerShowTitle"] end,
        function(v) A.SetOption(enemy and "enemyShowTitle" or "playerShowTitle", v) end)
    NameSizeControls(card, enemy and "enemyPlayer" or "friendlyPlayer", "Guild line size", "subtitle")
    card:End()
end

local function BuildPlayers(kit, view, index, enabled)
    local db = A.db
    local left, right = kit.Column(view, 0, 400), kit.Column(view, 410, 400)
    if index == 1 then
        local name = left:Card("Name", enabled)
        name:Check("Hide Blizzard player names", function() return db.hideNativePlayerNames end, function(v) A.SetOption("hideNativePlayerNames", v) end,
            {tip = "Also hides friendly pets, minions and guardians. Unchecking restores previous name settings."})
        name:Color("Color", function() return db.playerColorMode end, function(v) A.SetOption("playerColorMode", v) end,
            function(anchor) A.PickPlayerColor(anchor) end, function() return db.colors.friendlyPlayer end,
            {choices = {{"Blizzard", "blizzard"}, {"Class", "class"}, {"Custom", "custom"}}})
        NameSizeControls(name, "friendlyPlayer", "Name size", "name")
        name:End()
        local strangers = left:Card("Strangers", enabled,
            A.People() and "Players you don't know: not in your Companion Journal, your group, your guild or your friends."
                or "Players you don't know: not in your group, your guild or your friends.")
        strangers:Seg("People you don't know", {{"Their name", "name"}, {"A stranger", "stranger"}, {"No label", "hide"}},
            function() return db.playerUnknownMode end, function(v) A.SetOption("playerUnknownMode", v) end)
        strangers:Seg("A stranger reads as", {{"Race and class", "raceclass"}, {"Race", "race"}, {"\"Stranger\"", "stranger"}},
            function() return db.playerStrangerStyle end, function(v) A.SetOption("playerStrangerStyle", v) end,
            {when = function() return db.playerUnknownMode == "stranger" end})
        strangers:Note(A.People() and "Known: everyone in your Companion Journal list, plus:" or "Count as known:",
            {when = function() return db.playerUnknownMode ~= "name" end})
        local known = function() return db.playerUnknownMode ~= "name" end
        strangers:Check("Group", function() return db.knownGroup end, function(v) A.SetOption("knownGroup", v) end, {when = known})
        strangers:Check("Guild", function() return db.knownGuild end, function(v) A.SetOption("knownGuild", v) end, {same = true, when = known})
        strangers:Check("Friends and Battle.net friends", function() return db.knownFriends end, function(v) A.SetOption("knownFriends", v) end, {same = true, when = known})
        strangers:End()
        LevelCard(right, false, enabled)
        GuildCard(right, false, enabled)
    else
        local icons = left:Card("Icons", enabled)
        icons:Note("Who gets an icon, in priority order (the first matches show):")
        for _, relation in ipairs(A.relationships) do
            local x, y = icons:Slot({}, 0)
            local frame = icons.frame
            local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", x - 4, -y + 1); check:SetSize(24, 24)
            local text = check.Text or check.text
            text:SetFontObject("GameFontHighlight"); text:SetText(relation.label); text:SetWidth(170); text:SetJustifyH("LEFT")
            check:SetScript("OnClick", function(box) A.SetOption(relation.option, box:GetChecked() == true) end)
            local glyph = kit.Button(frame, "", x + 196, -y - 1, 40, function(button)
                A.PickGlyph(button, A.IconGlyph(relation.key), A.IconColor(relation.key), function(choice) db.iconGlyphs[relation.key] = choice; A.Refresh() end)
            end)
            glyph.icon = glyph:CreateTexture(nil, "ARTWORK")
            glyph.icon:SetPoint("CENTER"); glyph.icon:SetSize(16, 16)
            local color = kit.Button(frame, "", x + 242, -y - 1, 56, function(button) A.PickIconColor(relation.key, button) end)
            color.swatch = color:CreateTexture(nil, "ARTWORK")
            color.swatch:SetPoint("TOPLEFT", 8, -5); color.swatch:SetPoint("BOTTOMRIGHT", -8, 5)
            icons:Advance(300, ROW + 2)
            kit.On(function()
                check:SetChecked(db[relation.option] and true or false)
                local on = enabled()
                check:SetEnabled(on)
                if on then text:SetTextColor(1, 1, 1) else text:SetTextColor(unpack(DIM)) end
                local active = on and db[relation.option] and true or false
                glyph:SetEnabled(active); color:SetEnabled(active)
                glyph.icon:SetTexture(A.GlyphPath(A.IconGlyph(relation.key)))
                local tint = A.IconColor(relation.key)
                glyph.icon:SetVertexColor(tint[1], tint[2], tint[3]); glyph.icon:SetAlpha(active and 1 or 0.4)
                local mode = A.IconColorMode(relation.key)
                color:SetText(mode == "class" and "Class" or mode == "name" and "Name" or "")
                color.swatch:SetShown(mode == "custom")
                color.swatch:SetColorTexture(tint[1], tint[2], tint[3])
            end)
        end
        local anyOn = function() return enabled() and A.AnyIconsEnabled() end
        icons:Step("Size", function() return One(A.IconSize((A.GetTextSizes("friendlyPlayer")))) end,
            function(delta)
                local current = A.IconSize((A.GetTextSizes("friendlyPlayer")))
                A.SetOption("iconSize", math.max(6, math.min(40, math.floor(current + 0.5) + delta)))
            end,
            {when = anyOn, valueWidth = 40, auto = {reset = function() A.SetOption("iconSize", nil) end,
                isAuto = function() return type(db.iconSize) ~= "number" end, tip = "Match the name's text size."}})
        icons:Seg("Position", {{"Before", "left"}, {"After", "right"}, {"Above", "above"}}, function() return db.iconPosition end,
            function(v) A.SetOption("iconPosition", v) end, {when = anyOn})
        icons:Seg("Show up to", {{"1", 1}, {"2", 2}, {"3", 3}}, function() return db.iconMax end, function(v) A.SetOption("iconMax", v) end, {when = anyOn})
        if A.People() then
            icons:Seg("Your people", {{"Before", "left"}, {"After", "right"}, {"With the others", "same"}},
                function() return db.peopleIconSide or "same" end, function(v) A.SetOption("peopleIconSide", v) end, {when = anyOn})
            icons:Note("Who has which icon, and whether they show: Companion Journal.")
        end
        icons:End()

        local wounded = right:Card("Wounded player health bar", enabled)
        wounded:Check("Any friendly player", function() return db.woundedPlayers end, function(v) A.SetOption("woundedPlayers", v) end)
        wounded:Check("Group members", function() return db.woundedParty end, function(v) A.SetOption("woundedParty", v) end, {same = true})
        local active = function() return db.woundedPlayers or db.woundedParty end
        wounded:Step("Width", function() return tostring(tonumber(db.woundedWidth) or 60) end,
            function(delta) A.SetOption("woundedWidth", math.max(20, math.min(160, (tonumber(db.woundedWidth) or 60) + delta * 4))) end, {when = active, valueWidth = 36})
        wounded:Step("Height", function() return tostring(tonumber(db.woundedHeight) or 2) end,
            function(delta) A.SetOption("woundedHeight", math.max(1, math.min(8, (tonumber(db.woundedHeight) or 2) + delta))) end, {same = true, when = active, valueWidth = 30})
        wounded:Color("Color", function() return db.woundedColorMode or "custom" end, function(v) A.SetOption("woundedColorMode", v) end,
            function(anchor) A.PickWoundedColor(anchor) end, function() return db.colors.wounded end, {when = active})
        wounded:End()
        local bar = right:Card("Selected player's health bar")
        bar:Check("Show under the selected friendly player", function() return db.targetHealthBar end, function(v) A.SetOption("targetHealthBar", v) end)
        local barOn = function() return db.targetHealthBar end
        local styles = {}
        for i, key in ipairs({"minimal", "default", "classic"}) do styles[i] = {A.targetHealthPresets[key].label, key} end
        bar:Seg("Style", styles, function()
            local preset = A.GetTargetHealthSettings()
            for key, value in pairs(A.targetHealthPresets) do if value == preset then return key end end
        end, function(key) A.SetTargetHealthPreset(key) end, {when = barOn})
        local function Dim(i, label, o)
            bar:Step(label, function()
                local _, width, height, gap = A.GetTargetHealthSettings()
                return ({width, height, gap})[i] .. ""
            end, function(direction) A.StepTargetHealth(i, direction) end, {when = barOn, valueWidth = 32, same = o and o.same})
        end
        Dim(1, "Width"); Dim(2, "Height", {same = true}); Dim(3, "Gap", {same = true})
        bar:Color("Color", function() return db.targetHealthColorMode end, function(v) A.SetOption("targetHealthColorMode", v) end,
            function(anchor) A.PickTargetHealthColor(anchor) end,
            function() return {db.targetHealthR, db.targetHealthG, db.targetHealthB} end, {when = barOn})
        bar:Check("Show their level", function() return db.targetHealthLevel end, function(v) A.SetOption("targetHealthLevel", v) end, {when = barOn})
        bar:Button("Reset bar", function() A.ResetTargetHealth() end, {same = true, when = barOn})
        bar:End()
    end
end

local function BuildEnemies(kit, view, index, enabled)
    local db = A.db
    local left, right = kit.Column(view, 0, 400), kit.Column(view, 410, 400)
    if index == 1 then
        local name = left:Card("Name", enabled)
        name:Seg("While I'm flagged", {{"Blizzard's plates", "native"}, {"Our names on their bars", "names"}},
            function() return db.enemyFlaggedStyle end, function(v) A.SetOption("enemyFlaggedStyle", v) end)
        local names = {}
        for i, choice in ipairs(RANGES) do names[i] = choice end
        names[#names + 1] = {"None", "hidden"}
        name:Seg("Not flagged: names for", names, function() return ScopeValue(db.enemyScope, db.enemyRange) end,
            function(value) SetScope("enemyScope", "enemyRange", value) end)
        name:Color("Color", function() return db.enemyColorMode end, function(v) A.SetOption("enemyColorMode", v) end,
            function(anchor) PickCustom("enemyPlayer", "enemyColorMode", anchor) end, function() return db.colors.enemyPlayer end,
            {choices = {{"Blizzard", "blizzard"}, {"Class", "class"}, {"Faction", "faction"}, {"Custom", "custom"}}})
        NameSizeControls(name, "enemyPlayer", "Name size", "name")
        name:Seg("Mark", {{"None", "none"}, {"\194\171 Name \194\187", "guillemets"}, {"(Name)", "parens"}},
            function() return db.enemyMark end, function(v) A.SetOption("enemyMark", v) end)
        name:End()
        local strangers = left:Card("Strangers", enabled,
            A.People() and "Opposite-faction players you don't know. Rivals in your Companion Journal keep their names."
                or "Opposite-faction players you don't know.")
        strangers:Check("Show them as strangers", function() return db.enemyStranger end, function(v) A.SetOption("enemyStranger", v) end)
        strangers:Seg("A stranger reads as", {{"Race and class", "raceclass"}, {"Race", "race"}, {"\"Stranger\"", "stranger"}},
            function() return db.enemyStrangerStyle end, function(v) A.SetOption("enemyStrangerStyle", v) end,
            {when = function() return db.enemyStranger end})
        if A.People() then
            strangers:Note("Rivals (enemies in Companion Journal) keep their names.", {width = 250})
            strangers:Button("Open Rivals", function() local people = A.People(); if people then people.Open("rival") end end, {same = true})
        end
        strangers:End()
        LevelCard(right, true, enabled)
        GuildCard(right, true, enabled)
    else
        local icons = left:Card("Icons", enabled)
        icons:Check("Their faction emblem, before the name", function() return db.enemyFactionIcon end, function(v) A.SetOption("enemyFactionIcon", v) end)
        icons:Check("In their class color", function() return db.enemyFactionClassColor end, function(v) A.SetOption("enemyFactionClassColor", v) end,
            {indent = true, when = function() return db.enemyFactionIcon end})
        icons:Check("Crossed swords when their PvP flag is on", function() return db.enemyPvpIcon end, function(v) A.SetOption("enemyPvpIcon", v) end,
            {tip = "They can be attacked by flagged players."})
        local swords = icons:Button("", function(button) A.PickRoleColor("enemyPvp", button) end, {same = true, width = 40, when = function() return db.enemyPvpIcon end})
        swords.swatch = swords:CreateTexture(nil, "ARTWORK")
        swords.swatch:SetPoint("TOPLEFT", 8, -5); swords.swatch:SetPoint("BOTTOMRIGHT", -8, 5)
        kit.On(function() swords.swatch:SetColorTexture(unpack(db.colors.enemyPvp)) end)
        icons:Seg("Swords position", {{"Before", "left"}, {"After", "right"}, {"Above", "above"}}, function() return db.enemySwordsPosition end,
            function(v) A.SetOption("enemySwordsPosition", v) end, {indent = true, when = function() return db.enemyPvpIcon end})
        icons:Step("Size", function() return One(A.IconSize((A.GetTextSizes("enemyPlayer")), db.enemyIconSize or false)) end,
            function(delta)
                local current = A.IconSize((A.GetTextSizes("enemyPlayer")), db.enemyIconSize or false)
                A.SetOption("enemyIconSize", math.max(6, math.min(40, math.floor(current + 0.5) + delta)))
            end,
            {valueWidth = 40, auto = {reset = function() A.SetOption("enemyIconSize", nil) end,
                isAuto = function() return type(db.enemyIconSize) ~= "number" end, tip = "Match the name's text size."}})
        icons:End()
        local bar = right:Card("Health bar", enabled)
        bar:Check("Always show their health bar", function() return db.enemyHealthBar end, function(v) A.SetOption("enemyHealthBar", v) end)
        local barOn = function() return db.enemyHealthBar end
        bar:Step("Width", function() return tostring(tonumber(db.enemyBarWidth) or 60) end,
            function(delta) A.SetOption("enemyBarWidth", math.max(20, math.min(160, (tonumber(db.enemyBarWidth) or 60) + delta * 4))) end, {when = barOn, valueWidth = 36})
        bar:Step("Height", function() return tostring(tonumber(db.enemyBarHeight) or 3) end,
            function(delta) A.SetOption("enemyBarHeight", math.max(1, math.min(8, (tonumber(db.enemyBarHeight) or 3) + delta))) end, {same = true, when = barOn, valueWidth = 30})
        bar:Color("Color", function() return db.enemyBarColorMode end, function(v) A.SetOption("enemyBarColorMode", v) end,
            function(anchor) A.PickEnemyBarColor(anchor) end, function() return db.colors.enemyBar end, {when = barOn})
        bar:End()
        local test = right:Card("Try it in the world")
        test:Check("Show friendly players as enemies", function() return A.enemyTest == true end, function(v) A.SetEnemyTest(v) end,
            {tip = "Friendly players around you are drawn as opposite-faction players with these settings. Not saved. Also /fnames enemytest."})
        test:Note("Friendly players around you are drawn with these settings. Not saved.")
        test:End()
    end
end

local styleRows = {
    {"general", "All NPCs", "Any NPC name", "<Subtitle>", "Default for every type"},
    {"vendor", "Vendors", "Uualia Suncrest", "<General Goods>"},
    {"quest", "Quest givers", "Quest giver name", "<Actual NPC subtitle>"},
    {"interactive", "Dialogue / services", "Interactive NPC name", "<Actual NPC subtitle>"},
    {"oppositeFaction", "Opposite faction", "Windshaper Boro", "<Shaman Trainer>"},
}
local function BuildNPCTypes(kit, view)
    local db = A.db
    local card = kit.Column(view, 0, 810):Card(nil)
    for _, header in ipairs({{"Type", 14}, {"Preview", 170}, {"Color", 440}, {"Name size", 520}, {"Subtitle size", 642}}) do
        kit.Text(card.frame, header[1], header[2], -12, "GameFontNormalSmall")
    end
    kit.Line(card.frame, 10, -32, 790, 1, 0.3)
    for i, row in ipairs(styleRows) do
        local key, y = row[1], -38 - (i - 1) * 54
        local line = CreateFrame("Frame", nil, card.frame)
        line:SetPoint("TOPLEFT", 1, y); line:SetSize(808, 54)
        kit.Text(line, row[2], 13, -12, "GameFontHighlight", 150)
        if row[5] then kit.Text(line, row[5], 13, -30, "GameFontHighlightSmall", 150, NOTE) end
        local name = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        name:SetPoint("TOPLEFT", 169, -6); name:SetWidth(260); name:SetWordWrap(false); name:SetJustifyH("LEFT"); name:SetText(row[3])
        local subtitle = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        subtitle:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2); subtitle:SetWidth(260); subtitle:SetWordWrap(false); subtitle:SetJustifyH("LEFT"); subtitle:SetText(row[4])
        local swatch
        if key ~= "general" then
            swatch = kit.Button(line, "", 439, -16, 48, function(button) A.PickRoleColor(key, button) end)
            swatch.color = swatch:CreateTexture(nil, "ARTWORK")
            swatch.color:SetPoint("TOPLEFT", 7, -6); swatch.color:SetPoint("BOTTOMRIGHT", -7, 6)
        else
            kit.Text(line, "per type", 446, -20, "GameFontHighlightSmall", nil, NOTE)
        end
        local steppers = {}
        for f, field in ipairs({"name", "subtitle"}) do
            steppers[field] = kit.Stepper(line, f == 1 and 519 or 641, -16, 50, function(delta) A.StepTextSize(key, field, delta) end)
        end
        kit.Button(line, "Reset", 745, -16, 56, function() A.SetTextSize(key, "name", nil); A.SetTextSize(key, "subtitle", nil) end)
        kit.On(function()
            local nameSize, subtitleSize = A.GetTextSizes(key)
            local fit = math.min(1, 40 / (nameSize + subtitleSize + 2))
            local color = key == "general" and {0.92, 0.92, 0.92} or db.colors[key]
            for _, entry in ipairs({{name, nameSize}, {subtitle, subtitleSize}}) do
                entry[1]:SetFontObject("SystemFont_NamePlate"); entry[1]:SetTextHeight(entry[2] * fit)
                entry[1]:SetTextColor(unpack(color))
            end
            if swatch then swatch.color:SetColorTexture(unpack(color)) end
            for field, stepper in pairs(steppers) do
                stepper.value:SetText(One(field == "name" and nameSize or subtitleSize))
                if A.IsCustomTextSize(key, field) then stepper.value:SetTextColor(1, 1, 1) else stepper.value:SetTextColor(0.6, 0.6, 0.6) end
            end
            if key == "oppositeFaction" then line:SetAlpha(db.useOppositeFactionColor and 1 or 0.45) end
        end)
    end
    card.y = 38 + #styleRows * 54 + 8
    local col = kit.Column(view, 0, 810)
    col.y = card:End() + GAP
    local footer = col:Card(nil)
    footer:Check("Opposite faction overrides role colors and sizes", function() return db.useOppositeFactionColor end,
        function(v) A.SetOption("useOppositeFactionColor", v) end)
    footer:Button("Reset colors", function() A.ResetRoleColors() end, {same = true})
    footer:End()
end
local function BuildNPCs(kit, view, index)
    local db = A.db
    if index == 1 then return BuildNPCTypes(kit, view) end
    local left, right = kit.Column(view, 0, 400), kit.Column(view, 410, 400)
    local names = left:Card("Blizzard's own names")
    names:Check("Hide Blizzard NPC names", function() return db.hideNativeNames end, function(v) A.SetOption("hideNativeNames", v) end)
    names:Note("Forever controls the native-name distance; addons cannot change its cutoff.", {indent = true})
    names:Check("Label opposite-faction service NPCs", function() return db.includeOppositeFaction end, function(v) A.SetOption("includeOppositeFaction", v) end)
    names:Note("Trainers, vendors and other services of the other faction.", {indent = true})
    names:End()
    local fix = right:Card("Mislabeled NPC?")
    fix:Note("Target the NPC, then pick how it should be labeled. Auto returns it to automatic detection.")
    for i, entry in ipairs({{"Vendor", "vendor"}, {"Quest giver", "quest"}, {"Service", "interactive"}, {"Hide", "hide"}, {"Auto", "auto"}}) do
        fix:Button(entry[1], function() SlashCmdList.FOREVERNAMES(entry[2]) end,
            {same = i > 1, width = 68, tip = "Same as /fnames " .. entry[2] .. " with the NPC targeted."})
    end
    fix:Note("Labels go on friendly NPCs you can interact with. Other friendly NPC plates are hidden, and enemies keep Blizzard's plates. NPCs without a subtitle, and friendly players, show only their name.")
    fix:End()
end

local fadeLabels = {
    nameplateMaxDistance = "Maximum distance", nameplateMaxAlpha = "Near opacity", nameplateMinAlpha = "Far opacity",
    nameplateMaxAlphaDistance = "Start fading at", nameplateMinAlphaDistance = "End fade before max",
    nameplateOccludedAlphaMult = "Behind walls / terrain", nameplateMaxScale = "Near size", nameplateMinScale = "Far size",
    nameplateMaxScaleDistance = "Start shrinking at", nameplateMinScaleDistance = "End shrink before max",
}
local opacityNames = {opacity = "Overall", subtitleOpacity = "Subtitles", targetOpacity = "Targeted name",
    otherOpacity = "Untargeted names", combatOpacity = "While in combat"}
local function BuildAll(kit, view, index)
    local db = A.db
    local left, right = kit.Column(view, 0, 400), kit.Column(view, 410, 400)
    if index == 1 then
        local labels = left:Card("Opacity of our names")
        labels:Note("Multiplies the game's own distance fade. Only this addon's names.")
        for _, setting in ipairs(A.labelOpacityControls) do
            labels:Step(opacityNames[setting.key] or setting.label, function() return Percent(db[setting.key]) end,
                function(direction) A.StepFade(setting, false, direction) end, {labelWidth = 150, valueWidth = 50})
        end
        labels:Button("Reset opacity", function() A.ResetLabelOpacity() end)
        labels:End()
        local ranges = left:Card("What you will see")
        local summary = ranges:Note(" ", {})
        kit.On(function()
            summary:SetText(A.DistanceSummary() .. (A.pendingCVars and "\nPending: settings apply when combat ends." or A.fadeError and ("\n" .. A.fadeError) or ""))
        end)
        ranges:End()
        local global = right:Card("All nameplates (game-wide)")
        global:Check("Customize distance, fade and size", function() return db.customizeGlobalFade end, function(v) A.SetOption("customizeGlobalFade", v) end)
        global:Note("Also changes enemy and Blizzard plates. Unchecking restores Blizzard's defaults. Changes made in combat wait until it ends.")
        local settings = {}
        for _, setting in ipairs(A.fadeControls) do settings[setting.key] = setting end
        for _, group in ipairs({{"nameplateMaxDistance"},
            {"nameplateMaxAlpha", "nameplateMinAlpha", "nameplateMaxAlphaDistance", "nameplateMinAlphaDistance", "nameplateOccludedAlphaMult"},
            {"nameplateMaxScale", "nameplateMinScale", "nameplateMaxScaleDistance", "nameplateMinScaleDistance"}}) do
            for _, key in ipairs(group) do
                local setting = settings[key]
                if setting then
                    global:Step(fadeLabels[key] or setting.label, function()
                        if GetCVar(key) == nil then return "N/A" end
                        local value = db.fadeValues[key]
                        return setting.percent and Percent(value) or (value .. " yd")
                    end, function(direction) A.StepFade(setting, true, direction) end,
                        {labelWidth = 170, valueWidth = 56, when = function() return db.enabled and db.customizeGlobalFade and GetCVar(key) ~= nil end})
                end
            end
        end
        global:End()
    else
        local text = left:Card("Text")
        text:Check("Smooth scaling with Blizzard's font", function() return db.nativeSmoothScaling end, function(v) A.SetOption("nativeSmoothScaling", v) end,
            {tip = "Labels use Blizzard's nameplate font and engine scaling, and replace native health bars and levels."})
        text:Button("", function() SlashCmdList.FOREVERNAMES("compare"); A.RefreshOptions() end,
            {width = 190, label = function() return A.nativePlateTest and "Stop comparing" or "Compare with Blizzard" end,
            tip = "Temporarily shows Blizzard's plates with the same distance and size settings. Click again to return."})
        text:End()
        local perf = left:Card("Performance")
        perf:Check("Health and level updates only for my target", function() return db.targetOnlyVitals end, function(v) A.SetOption("targetOnlyVitals", v) end)
        perf:Note("Saves work in crowds. Friendly nameplates stay enabled while custom names or a health bar are on.")
        perf:End()
        local hide = right:Card("Hide every name")
        hide:Note("Fades all Forever Names labels (NPCs and players), and back again. Key binding: \"Hide or show names\" (Key Bindings > Forever Names), or /fnames hide.")
        hide:Button("", function() A.ToggleLabels(); A.RefreshOptions() end,
            {width = 170, label = function() return A.labelsHidden and "Show names" or "Hide names now" end})
        hide:End()
    end
end

-- The window -----------------------------------------------------------------
local PAGES = {
    {name = "Players", icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
        desc = "Friendly players: their name, level, guild and title, icons, health bars, and how strangers read.",
        views = {"Names", "Icons & health"}, build = BuildPlayers, preview = FriendlySamples,
        master = {"Custom names for friendly players", "showFriendlyPlayers"}},
    {name = "Enemies", icon = "Interface\\Icons\\INV_BannerPVP_01",
        desc = "Opposite-faction players in the world: their name, level, guild and title, icons, health bar, and what happens while you are flagged.",
        views = {"Names", "Icons & health"}, build = BuildEnemies, preview = EnemySamples,
        master = {"Custom names for opposite-faction players", "enemyEnabled"}},
    {name = "NPCs", icon = "Interface\\Icons\\INV_Misc_Coin_01", desc = "Which NPCs get names, and the color and size of each type.",
        views = {"Types", "Which NPCs"}, build = BuildNPCs},
    {name = "All names", icon = "Interface\\Icons\\Spell_Nature_Invisibilty",
        desc = "Settings for every name: opacity, distance and fade, text, the hide key and performance.",
        views = {"Visibility", "Text & tools"}, build = BuildAll},
}

function A.CreateOptionsB()
    local db, skin = A.db, A.OptionsSkin
    local frame = CreateFrame("Frame", "ForeverNamesOptionsB", UIParent, "BackdropTemplate")
    A.optionsB = frame
    frame:Hide()
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverNamesOptionsB") end
    local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetText("Forever Names")
    if skin then skin.Frame(frame, heading)
    else
        frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}})
        frame:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
        heading:SetPoint("TOP", 0, -12)
    end
    local border = frame.legacyBorder or frame
    local kit = NewKit(frame)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 26, -42)
    content:SetPoint("BOTTOMRIGHT", -22, 50)

    local pages, tabs = {}, {}
    local pageIndex = 1
    local function Select(index)
        pageIndex = pages[index] and index or 1
        db.optionsPageB = pageIndex
        for i, page in ipairs(pages) do
            page.frame:SetShown(i == pageIndex)
            tabs[i].selected:SetShown(i == pageIndex)
        end
        A.RefreshOptions()
    end
    A.SelectOptionsPageB = Select
    local tabInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-sidetab")
    local tabWidth, tabHeight = tabInfo and tabInfo.width or 43, tabInfo and (tabInfo.height - 5) or 55
    for i, info in ipairs(PAGES) do
        local page = {views = {}, viewIndex = 1}
        pages[i] = page
        page.frame = CreateFrame("Frame", nil, content)
        page.frame:SetAllPoints(content)
        page.frame:Hide()
        local enabled = info.master and function() return db[info.master[2]] and true or false end or function() return true end
        kit.Text(page.frame, info.name, 4, -2, "GameFontNormalLarge")
        kit.Text(page.frame, info.desc, 4, -26, "GameFontHighlightSmall", 470, NOTE)
        kit.Line(page.frame, 0, -56, W - 48, 1, 0.45)
        -- Header controls, right-aligned: the master switch, then the views.
        local headerFrame = CreateFrame("Frame", nil, page.frame)
        headerFrame:SetPoint("TOPLEFT", 0, -6)
        headerFrame:SetSize(810, 28)
        local header = kit.Bare(headerFrame, 810)
        page.select = function(view)
            page.viewIndex = view
            for j, entry in ipairs(page.views) do entry:SetShown(j == view) end
            A.RefreshOptions()
        end
        local viewsWidth = 0
        if #info.views > 1 then
            local choices = {}
            for j, label in ipairs(info.views) do choices[j] = {label, j} end
            local _, total = header:Seg(nil, choices, function() return page.viewIndex end, function(j) page.select(j) end, {rightEdge = 810})
            viewsWidth = total + 18
        end
        if info.master then
            header:Check(info.master[1], function() return db[info.master[2]] end, function(v) A.SetOption(info.master[2], v) end,
                {same = true, rightEdge = 810 - viewsWidth})
        end
        local top = 66
        if info.preview then
            page.preview = Preview(page.frame, info.preview)
            page.preview.frame:ClearAllPoints()
            page.preview.frame:SetPoint("TOPLEFT", 0, -top)
            top = top + PREVIEW_H + 8
        end
        for j = 1, #info.views do
            local view = CreateFrame("Frame", nil, page.frame)
            view:SetPoint("TOPLEFT", 0, -top)
            view:SetPoint("BOTTOMRIGHT")
            view:SetShown(j == 1)
            page.views[j] = view
            info.build(kit, view, j, enabled)
        end
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(tabWidth, tabHeight)
        tab:SetScale(TAB_SCALE)
        local background = tab:CreateTexture(nil, "BACKGROUND")
        background:SetAtlas("common-sidetab", true)
        background:SetPoint("CENTER")
        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(info.icon)
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
            Select(i)
        end)
        kit.Tooltip(tab, info.name)
        if i == 1 then tab:SetPoint("TOPLEFT", border, "TOPRIGHT", 0, -44 / TAB_SCALE)
        else tab:SetPoint("TOPLEFT", tabs[i - 1], "BOTTOMLEFT", 0, -2) end
        tabs[i] = tab
    end
    A.optionsBTabs, A.optionsBPages = tabs, pages

    -- Footer: enable, the layout switch, the link to Companion Journal, Close.
    local enableBox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enableBox:SetPoint("BOTTOMLEFT", 22, 14); enableBox:SetSize(26, 26)
    local enableText = enableBox.Text or enableBox.text
    enableText:SetFontObject("GameFontHighlight"); enableText:SetText("Enable Forever Names"); enableText:SetWidth(200); enableText:SetJustifyH("LEFT")
    enableBox:SetScript("OnClick", function(box) A.SetOption("enabled", box:GetChecked() == true) end)
    local close = kit.Button(frame, "Close", 0, 0, 100, function() frame:Hide() end, 24)
    close:ClearAllPoints(); close:SetPoint("BOTTOMRIGHT", -18, 14)
    A.optionsBClose = close
    -- "Names | Journal": the two windows of the suite, one switch (with both installed).
    local journal = kit.Button(frame, "Journal", 0, 0, 90, function()
        local people = A.People and A.People()
        if people then people.Open(); frame:Hide() end
    end, 24)
    journal:ClearAllPoints(); journal:SetPoint("BOTTOMRIGHT", -126, 14)
    kit.Tooltip(journal, "Your people and the journals, in their own window.")
    local namesHere = kit.Button(frame, "Names", 0, 0, 90, nil, 24)
    namesHere:ClearAllPoints(); namesHere:SetPoint("RIGHT", journal, "LEFT", -4, 0)
    namesHere:SetEnabled(false)
    journal:SetShown(A.People() ~= nil); namesHere:SetShown(A.People() ~= nil)
    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPRIGHT", -40, -13); status:SetJustifyH("RIGHT")

    function A.RefreshOptionsB()
        if not frame:IsShown() then return end
        enableBox:SetChecked(db.enabled and true or false)
        journal:SetShown(A.People and A.People() ~= nil); namesHere:SetShown(A.People and A.People() ~= nil)
        if not db.enabled then status:SetText("|cffff6040Forever Names is off|r")
        elseif A.nativePlateTest then status:SetText("|cffffd100Comparing with Blizzard plates|r")
        else status:SetText("|cff808080v" .. tostring(A.version) .. "|r") end
        for _, update in ipairs(kit.updaters) do update() end
        for _, page in ipairs(pages) do
            if page.preview and page.frame:IsShown() then RefreshPreview(page.preview) end
        end
    end
    frame:SetScript("OnShow", A.RefreshOptionsB)

    -- The layout switch lives in both windows; A keeps working as before.
    local function SetLayout(value)
        db.optionsLayout = value
        A.OpenOptions()
    end
    A.SetOptionsLayout = SetLayout
    for _, host in ipairs({A.options, frame}) do
        local label = host:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("BOTTOM", host, "BOTTOM", -60, 20); label:SetText("Layout")
        for i, value in ipairs({"a", "b"}) do
            local button = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
            button:SetSize(34, 22)
            button:SetPoint("BOTTOM", host, "BOTTOM", -20 + (i - 1) * 38, 16)
            button:SetText(value:upper())
            button:SetScript("OnClick", function() SetLayout(value) end)
            if skin then skin.Button(button) end
            kit.Tooltip(button, value == "a" and "The settings window as before 1.10." or "Organized by who a setting is about: Players, Enemies, NPCs, All names.")
            host["layout" .. value] = button
        end
    end

    -- Wrap layout A's entry points: one window shows at a time.
    local refreshA, openA = A.RefreshOptions, A.OpenOptions
    function A.RefreshOptions()
        refreshA()
        A.RefreshOptionsB()
        for _, host in ipairs({A.options, frame}) do
            for _, value in ipairs({"a", "b"}) do
                local button = host["layout" .. value]
                if button then button:SetEnabled(db.optionsLayout ~= value) end
            end
        end
    end
    function A.OpenOptions()
        if db.optionsLayout == "b" then
            A.options:Hide()
            if UIParent and UIParent.GetWidth and UIParent.GetHeight then
                frame:SetScale(math.max(0.4, math.min(1, (UIParent:GetWidth() - 40) / (W + 60), (UIParent:GetHeight() - 40) / H)))
            end
            Select(tonumber(db.optionsPageB) or 1)
            frame:Show()
            A.RefreshOptions()
        else
            frame:Hide()
            openA()
            A.RefreshOptions()
        end
    end
    Select(tonumber(db.optionsPageB) or 1)
end
