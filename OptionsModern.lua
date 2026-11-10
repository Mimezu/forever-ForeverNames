local _, A = ...
-- How the settings window is drawn. The pages and their Card calls are in
-- OptionsWindow.lua; here:
--   * every card has one label column and one control column,
--   * a group of choices, or a stepper, sits in one frame instead of one per button,
--   * a row that depends on a switch shows only while that switch is on,
--   * reference notes move into the row's tooltip.
local GOLD, NOTE, DIM, PLAIN = {1, 0.82, 0}, {0.80, 0.77, 0.70}, {0.5, 0.5, 0.5}, {0.82, 0.82, 0.82}
local ROW, GAP, PAD, INDENT = 28, 10, 14, 22
local CONTROL_X = 150
local PLATE = "common-button-list-collapseExpand"

-- Adds the cards and controls to the kit of shared helpers (OptionsWindow.lua).
function A.ModernKit(kit)
    local skin = A.OptionsSkin
    local On, Width, Text, Button, Tooltip = kit.On, kit.Width, kit.Text, kit.Button, kit.Tooltip
    local columns = {}

    -- One frame around a group of cells ---------------------------------------------
    local function Group(parent, width)
        local group = CreateFrame("Frame", nil, parent)
        group:SetSize(width, 22)
        if skin and skin.Plate then
            local art = skin.Plate(group, PLATE)
            group:HookScript("OnSizeChanged", function() art:Update() end)
        else
            local fill = group:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            fill:SetColorTexture(0, 0, 0, 0.4)
        end
        group.x = 0
        return group
    end
    local function Divider(group, x)
        local divider = group:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", x, -4)
        divider:SetSize(1, 14)
        divider:SetColorTexture(0.68, 0.50, 0.26, 0.4)
    end
    local function Cell(group, text, width, onClick)
        local cell = CreateFrame("Button", nil, group)
        cell:SetPoint("TOPLEFT", group.x, 0)
        cell:SetSize(width, 22)
        if group.x > 0 then Divider(group, group.x) end
        group.x = group.x + width
        cell.wash = cell:CreateTexture(nil, "ARTWORK")
        cell.wash:SetPoint("TOPLEFT", 3, -3); cell.wash:SetPoint("BOTTOMRIGHT", -3, 3)
        cell.wash:SetColorTexture(1, 0.72, 0.2, 0.22)
        cell.wash:Hide()
        local hover = cell:CreateTexture(nil, "HIGHLIGHT")
        hover:SetPoint("TOPLEFT", 3, -3); hover:SetPoint("BOTTOMRIGHT", -3, 3)
        hover:SetColorTexture(1, 0.72, 0.2, 0.12)
        cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cell.label:SetPoint("CENTER", 0, 0)
        cell.label:SetText(text)
        cell:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.label:SetPoint("CENTER", 1, -1) end end)
        cell:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
        cell:SetScript("OnDisable", function(self) self.label:SetAlpha(0.4) end)
        cell:SetScript("OnEnable", function(self) self.label:SetAlpha(1) end)
        cell:SetScript("OnClick", onClick)
        return cell
    end
    -- Natural widths, plus an equal share of the spare room (avail nil: natural).
    -- Returns nil when the choices do not fit, unless force (then they shrink).
    local function CellWidths(choices, avail, force)
        local widths, total = {}, 0
        for i, choice in ipairs(choices) do
            widths[i] = math.max(30, Width("GameFontHighlight", choice[1]) + 14)
            total = total + widths[i]
        end
        if not avail then return widths, total end
        if total > avail and not force then return nil end
        local used = 0
        for i = 1, #choices do
            widths[i] = total > avail and math.floor(widths[i] * avail / total) or widths[i] + math.floor((avail - total) / #choices)
            used = used + widths[i]
        end
        widths[#choices] = widths[#choices] + avail - used
        return widths, avail
    end
    local function Paint(cell, selected)
        cell.wash:SetShown(selected)
        cell.label:SetTextColor(unpack(selected and GOLD or PLAIN))
    end
    local function StepGroup(parent, x, y, valueWidth, onStep)
        local group = Group(parent, 48 + valueWidth)
        group:SetPoint("TOPLEFT", x, y)
        local stepper = {}
        stepper.minus = Cell(group, "-", 24, function() onStep(-1) end)
        Divider(group, 24)
        group.x = 24 + valueWidth
        stepper.plus = Cell(group, "+", 24, function() onStep(1) end)
        stepper.value = group:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        stepper.value:SetPoint("CENTER", 0, 0)
        stepper.value:SetWidth(valueWidth); stepper.value:SetJustifyH("CENTER")
        return stepper
    end
    kit.Stepper = StepGroup
    -- A plate that holds a color or an icon (at most one short word) and opens its picker.
    function kit.Well(parent, x, y, width, onClick)
        local group = Group(parent, width)
        group:SetPoint("TOPLEFT", x, y)
        local cell = Cell(group, "", width, onClick)
        cell.label:SetFontObject("GameFontHighlightSmall")
        function cell:SetText(text) self.label:SetText(text) end
        cell:HookScript("OnDisable", function() group:SetAlpha(0.5) end)
        cell:HookScript("OnEnable", function() group:SetAlpha(1) end)
        return cell
    end

    -- Free-standing controls (window header and footer) -----------------------------
    function kit.Choice(parent, choices, get, set)
        local widths, total = CellWidths(choices)
        local group = Group(parent, total)
        group.cells = {}
        for i, choice in ipairs(choices) do group.cells[i] = Cell(group, choice[1], widths[i], function() set(choice[2]) end) end
        On(function()
            local current = get()
            for i, choice in ipairs(choices) do Paint(group.cells[i], choice[2] == current) end
        end)
        return group
    end
    -- Text tabs: the selected one is gold, on a gold underline.
    function kit.Tabs(parent, x, y, labels, get, set)
        local tabs = {}
        local function Color(tab)
            if tab.index == get() then tab.label:SetTextColor(unpack(GOLD))
            elseif tab.over then tab.label:SetTextColor(1, 1, 1)
            else tab.label:SetTextColor(0.62, 0.60, 0.55) end
        end
        for i, label in ipairs(labels) do
            local width = Width("GameFontNormal", label) + 16
            local tab = CreateFrame("Button", nil, parent)
            tab.index = i
            tab:SetPoint("TOPLEFT", x, y)
            tab:SetSize(width, 30)
            tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            tab.label:SetPoint("CENTER", 0, 1)
            tab.label:SetText(label)
            tab.line = tab:CreateTexture(nil, "OVERLAY")
            tab.line:SetPoint("BOTTOMLEFT", 4, 0); tab.line:SetPoint("BOTTOMRIGHT", -4, 0)
            tab.line:SetHeight(2)
            tab.line:SetColorTexture(1, 0.82, 0, 0.9)
            tab:SetScript("OnEnter", function(self) self.over = true; Color(self) end)
            tab:SetScript("OnLeave", function(self) self.over = nil; Color(self) end)
            tab:SetScript("OnClick", function()
                if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
                set(i)
            end)
            tabs[i] = tab
            x = x + width + 4
        end
        On(function()
            for i, tab in ipairs(tabs) do tab.line:SetShown(i == get()); Color(tab) end
        end)
        return tabs
    end

    -- Cards: a stack of rows -------------------------------------------------------
    local Card = {}
    Card.__index = Card
    function Card:Enabled(o)
        return (not self.enabledFn or self.enabledFn()) and (not (o and o.when) or o.when()) and true or false
    end
    function Card:Row(o, height)
        local row = {frame = CreateFrame("Frame", nil, self.frame), height = height or ROW, min = height or ROW, whens = {},
            next = PAD + (o and o.indent and INDENT or 0), gap = self.gap}
        self.gap = nil
        row.frame:SetPoint("TOPLEFT", 0, 0)
        row.frame:SetSize(self.width, row.height)
        self.rows[#self.rows + 1] = row
        self.row = row
        return row
    end
    -- The row an item goes on: the last one when o.same and it fits, else a new one.
    function Card:RowFor(o, width)
        local row = self.row
        if o.same and row and row.next + width <= self.width - PAD then return row end
        return self:Row(o)
    end
    -- A row shows while any of its items applies.
    local function Join(row, o)
        if o and o.when then row.whens[#row.whens + 1] = o.when else row.always = true end
    end
    local function TipOf(o)
        if o.tip and o.more then return o.tip .. "\n\n" .. o.more end
        return o.tip or o.more
    end
    local function Label(row, text, x, template, color)
        local label = row.frame:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
        label:SetPoint("LEFT", row.frame, "LEFT", x, 0)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        if color then label:SetTextColor(unpack(color)) end
        return label
    end
    -- Hovering anywhere on the row explains it.
    local function RowTip(row, o)
        local tip = TipOf(o)
        if not tip then return end
        row.frame:EnableMouse(true)
        Tooltip(row.frame, tip)
    end

    function Card:Check(label, get, set, o)
        o = o or {}
        local labelWidth = Width("GameFontHighlight", label)
        local width = 24 + labelWidth
        local row = self:RowFor(o, width)
        local x = row.next
        local check = CreateFrame("CheckButton", nil, row.frame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x - 4, -2)
        check:SetSize(24, 24)
        local text = check.Text or check.text
        text:SetFontObject("GameFontHighlight"); text:SetText(label)
        text:SetWidth(labelWidth + 4); text:SetJustifyH("LEFT")
        -- The label is part of the click target.
        if check.SetHitRectInsets then check:SetHitRectInsets(0, -labelWidth, 0, 0) end
        check:SetScript("OnClick", function(box) set(box:GetChecked() == true) end)
        local tip = TipOf(o)
        if tip then Tooltip(check, tip) end
        row.next = x + width + 14
        Join(row, o)
        On(function()
            check:SetChecked(get() and true or false)
            check:SetEnabled(self:Enabled(o))
            if not o.when or o.when() then text:SetTextColor(1, 1, 1) else text:SetTextColor(unpack(DIM)) end
        end)
        return check
    end
    -- One of several choices: choices = {{text, value}, ...}
    function Card:Seg(label, choices, get, set, o)
        o = o or {}
        local left = PAD + (o.indent and INDENT or 0)
        local swatchWidth = o.swatch and 32 or 0
        local avail = self.width - PAD - CONTROL_X - swatchWidth
        -- o.wide: always on two lines (long labels or choices).
        local widths = label and not o.wide and Width("GameFontHighlight", label) <= CONTROL_X - left - 6 and CellWidths(choices, avail)
        local row, x, y
        if widths then
            row, x, y = self:Row(o), CONTROL_X, -3
            Label(row, label, left)
        else
            -- Too wide for the control column: the label gets its own line.
            avail = self.width - PAD - left - swatchWidth
            widths = CellWidths(choices, avail, true)
            row, x, y = self:Row(o, label and ROW + 18 or ROW), left, label and -21 or -3
            if label then Text(row.frame, label, left, -5, "GameFontHighlight") end
        end
        row.next = self.width
        local group = Group(row.frame, avail)
        group:SetPoint("TOPLEFT", x, y)
        local cells = {}
        for i, choice in ipairs(choices) do cells[i] = Cell(group, choice[1], widths[i], function() set(choice[2]) end) end
        local swatch
        if o.swatch then
            local holder = Group(row.frame, 28)
            holder:SetPoint("TOPLEFT", x + avail + 4, y)
            swatch = Cell(holder, "", 28, function(cell) o.swatch.pick(cell) end)
            swatch.color = swatch:CreateTexture(nil, "ARTWORK", nil, 1)
            swatch.color:SetPoint("TOPLEFT", 5, -5); swatch.color:SetPoint("BOTTOMRIGHT", -5, 5)
            Tooltip(swatch, "Choose the color.")
        end
        Join(row, o)
        RowTip(row, o)
        On(function()
            local current, enabled = get(), self:Enabled(o)
            for i, choice in ipairs(choices) do
                Paint(cells[i], choice[2] == current)
                cells[i]:SetEnabled(enabled)
            end
            if swatch then
                swatch:SetEnabled(enabled)
                swatch.color:SetColorTexture(unpack(o.swatch.color()))
                swatch.color:SetAlpha(current == "custom" and 1 or 0.35)
            end
        end)
        return cells, avail + swatchWidth
    end
    function Card:Color(label, get, set, pick, color, o)
        o = o or {}
        o.swatch = {pick = pick, color = color}
        return self:Seg(label, o.choices or kit.colorModes, get, set, o)
    end
    -- [ - value + ] and, for sizes that can be automatic, [ Auto ]: lit while automatic.
    function Card:Step(label, text, onStep, o)
        o = o or {}
        local valueWidth = o.valueWidth or 44
        local stepWidth = 48 + valueWidth
        local row, x = self.row
        local small = Width("GameFontHighlightSmall", label)
        if o.same and row and row.next + small + 6 + stepWidth <= self.width - PAD then
            -- Beside the last stepper, under a small label of its own.
            Label(row, label, row.next, "GameFontHighlightSmall", NOTE)
            x = row.next + small + 6
        else
            row = self:Row(o)
            local left = row.next
            Label(row, label, left)
            x = math.max(CONTROL_X, PAD + (o.labelWidth or 0), left + Width("GameFontHighlight", label) + 8)
        end
        local stepper = StepGroup(row.frame, x, -3, valueWidth, onStep)
        row.next = x + stepWidth + 12
        local auto
        if o.auto then
            local holder = Group(row.frame, 46)
            holder:SetPoint("TOPLEFT", x + stepWidth + 6, -3)
            auto = Cell(holder, "Auto", 46, function() o.auto.reset() end)
            Tooltip(auto, o.auto.tip or "Automatic size.")
            row.next = row.next + 52
        end
        Join(row, o)
        RowTip(row, o)
        On(function()
            local enabled = self:Enabled(o)
            local automatic = o.auto and o.auto.isAuto() or false
            stepper.minus:SetEnabled(enabled); stepper.plus:SetEnabled(enabled)
            stepper.value:SetText(text())
            stepper.value:SetTextColor(unpack(automatic and NOTE or {1, 1, 1}))
            if auto then
                auto:SetEnabled(enabled)
                Paint(auto, automatic)
            end
        end)
        return stepper
    end
    -- o.asLabel: the text is the row's label, and what follows starts at the controls.
    function Card:Note(text, o)
        o = o or {}
        local row = self:Row(o, 22)
        Join(row, o)
        if o.asLabel then
            row.height, row.min = ROW, ROW
            row.frame:SetHeight(ROW)
            local label = Label(row, text, row.next)
            row.next = CONTROL_X
            return label
        end
        local x = row.next
        local width = o.width or (self.width - x - PAD)
        local note = Text(row.frame, text, x, -4, "GameFontHighlightSmall", width, NOTE)
        row.note, row.min = note, 0
        row.next = x + width + 10
        return note
    end
    function Card:Button(text, onClick, o)
        o = o or {}
        local width = o.width or (math.max(28, Width("GameFontNormal", text) + 18) + 10)
        local row = self:RowFor(o, width)
        local x = row.next
        local button = o.well and kit.Well(row.frame, x, -3, width, onClick) or Button(row.frame, text, x, -3, width, onClick)
        if o.tip then Tooltip(button, o.tip) end
        row.next = x + width + 6
        row.min = math.max(row.min, ROW)
        Join(row, o)
        On(function()
            button:SetEnabled(self:Enabled(o))
            if o.label then button:SetText(o.label()) end
        end)
        return button
    end
    -- A row the page fills itself: returns its frame, and where a first control goes.
    function Card:Custom(_, height)
        local row = self:Row(nil, math.max(height, ROW))
        row.always = true
        return row.frame, PAD, 2
    end
    -- Extra room above the next row.
    function Card:Gap(height) self.gap = (self.gap or 0) + height end
    function Card.End() return 0 end

    function kit.Column(parent, x, width)
        local col = {x = x, cards = {}}
        columns[#columns + 1] = col
        function col:Card(title, enabledFn, tip)
            local card = setmetatable({col = self, width = width, enabledFn = enabledFn, rows = {}, top = 8}, Card)
            self.cards[#self.cards + 1] = card
            card.frame = CreateFrame("Frame", nil, parent)
            card.frame:SetPoint("TOPLEFT", x, 0)
            card.frame:SetSize(width, 40)
            local wash = card.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
            wash:SetAllPoints()
            wash:SetColorTexture(0.25, 0.17, 0.085, 0.16)
            -- Edges follow the card as its rows come and go.
            local function Edge(from, to, alpha, vertical)
                local line = card.frame:CreateTexture(nil, "BORDER")
                line:SetPoint(from, 0, 0); line:SetPoint(to, 0, 0)
                if vertical then line:SetWidth(1) else line:SetHeight(1) end
                line:SetColorTexture(0.68, 0.50, 0.26, alpha)
            end
            Edge("TOPLEFT", "TOPRIGHT", 0.55); Edge("BOTTOMLEFT", "BOTTOMRIGHT", 0.3)
            Edge("TOPLEFT", "BOTTOMLEFT", 0.3, true); Edge("TOPRIGHT", "BOTTOMRIGHT", 0.3, true)
            if title then
                local heading = Text(card.frame, title, PAD, -11, "GameFontNormal")
                if tip then
                    local hit = CreateFrame("Frame", nil, card.frame)
                    hit:SetPoint("TOPLEFT", PAD - 4, -6)
                    hit:SetSize(math.max(60, (heading.GetStringWidth and heading:GetStringWidth() or 60) + 10), 22)
                    hit:EnableMouse(true)
                    Tooltip(hit, tip)
                end
                card.top = 32
            end
            return card
        end
        return col
    end

    -- Run on every refresh: rows that do not apply fold away, and the cards of a
    -- column close up under each other.
    function kit.Layout()
        for _, col in ipairs(columns) do
            local top = 0
            for _, card in ipairs(col.cards) do
                local y = card.top
                for _, row in ipairs(card.rows) do
                    local shown = row.always or false
                    if not shown then
                        for _, when in ipairs(row.whens) do
                            if when() then shown = true; break end
                        end
                    end
                    row.frame:SetShown(shown)
                    if shown then
                        if row.note then
                            local height = row.note.GetStringHeight and row.note:GetStringHeight() or 14
                            row.height = math.max(row.min, math.max(14, height) + 8)
                        end
                        y = y + (row.gap or 0)
                        row.frame:SetPoint("TOPLEFT", 0, -y)
                        row.frame:SetHeight(row.height)
                        y = y + row.height
                    end
                end
                card.frame:SetPoint("TOPLEFT", col.x, -top)
                card.frame:SetHeight(y + 8)
                card.frame:SetAlpha((not card.enabledFn or card.enabledFn()) and 1 or 0.5)
                top = top + y + 8 + GAP
            end
        end
    end
    return kit
end
