local _, A = ...
-- Addon-owned color palette. Blizzard's ColorPickerFrame activates gamepad
-- bindings when shown; opened from addon code in the gamepad UI, that step is
-- blocked ("action only available to the Blizzard UI"). This popover uses only
-- addon-owned controls, so it works with mouse and the gamepad cursor alike.
local palette = {
    {1, 1, 1}, {0.85, 0.85, 0.85}, {1, 0.95, 0.75}, {1, 0.82, 0.2}, {1, 0.6, 0.1}, {1, 0.5, 0.15},
    {0.35, 0.9, 0.55}, {0.6, 1, 0.4}, {0.25, 0.85, 0.4}, {0.55, 0.85, 0.75}, {0.3, 0.9, 0.85}, {0.4, 0.8, 1},
    {0.55, 0.8, 1}, {0.65, 0.85, 1}, {0.4, 0.55, 1}, {0.7, 0.6, 1}, {0.85, 0.55, 1}, {1, 0.55, 0.85},
    {1, 0.4, 0.4}, {1, 0.25, 0.25}, {0.96, 0.55, 0.73}, {0.8, 0.6, 0.4}, {0.75, 0.7, 0.6}, {0.55, 0.55, 0.55},
}
A.colorPalette = palette
local popover

local function Attach(frame, anchor)
    local owner = anchor
    while owner and owner:GetParent() and owner:GetParent() ~= UIParent do owner = owner:GetParent() end
    owner = owner or A.options or UIParent
    frame:SetParent(owner)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(owner:GetFrameLevel() + 30)
end

-- A plain ColorSelect owns only its wheel/value textures. It does not inherit
-- Blizzard's ColorPickerFrame mixin or activate protected gamepad bindings.
-- Keep a continuous RGB fallback for clients without the native widget APIs.
local function CreateWheel(parent, name, skin)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(320, 270)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(parent:GetFrameLevel() + 10)
    frame:EnableMouse(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
    local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetText("Choose any color")
    if skin then skin.Frame(frame, heading) else
        frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}})
        frame:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
        heading:SetPoint("TOP", 0, -10)
    end
    local function Changed(r, g, b)
        if frame.syncing or not frame.original or not parent:IsShown() then return end
        frame.changing = true
        parent:Set(r, g, b)
        frame.changing = nil
    end
    local ok, selector = pcall(CreateFrame, "ColorSelect", nil, frame)
    local native = ok and selector
    for _, method in ipairs({"SetColorRGB", "GetColorRGB", "SetColorWheelTexture", "SetColorValueTexture",
        "SetColorWheelThumbTexture", "GetColorWheelThumbTexture", "SetColorValueThumbTexture", "GetColorValueThumbTexture"}) do
        if not native or type(selector[method]) ~= "function" then native = false end
    end
    if native then
        selector:SetPoint("TOPLEFT", 24, -42)
        selector:SetSize(236, 160)
        selector:EnableMouse(true)
        local wheel = selector:CreateTexture(nil, "ARTWORK")
        wheel:SetPoint("TOPLEFT"); wheel:SetSize(160, 160)
        selector:SetColorWheelTexture(wheel)
        local value = selector:CreateTexture(nil, "ARTWORK")
        value:SetPoint("LEFT", wheel, "RIGHT", 24, 0); value:SetSize(24, 160)
        selector:SetColorValueTexture(value)
        local thumbAsset = "Interface\\Buttons\\UI-ColorPicker-Buttons"
        selector:SetColorWheelThumbTexture(thumbAsset)
        local wheelThumb = selector:GetColorWheelThumbTexture()
        wheelThumb:SetSize(10, 10); wheelThumb:SetTexCoord(0, 0.15625, 0, 0.625)
        selector:SetColorValueThumbTexture(thumbAsset)
        local valueThumb = selector:GetColorValueThumbTexture()
        valueThumb:SetSize(36, 14); valueThumb:SetTexCoord(0.25, 1, 0, 0.875)
        selector:SetScript("OnColorSelect", function(_, r, g, b) Changed(r, g, b) end)
        frame.selector = selector
    else
        if ok and selector then selector:Hide() end
        frame.sliders = {}
        for c, label in ipairs({"Red", "Green", "Blue"}) do
            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            text:SetPoint("TOPLEFT", 30, -42 - (c - 1) * 52); text:SetText(label)
            local slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
            slider:SetPoint("TOPLEFT", 30, -62 - (c - 1) * 52); slider:SetSize(250, 18)
            slider:SetMinMaxValues(0, 1); slider:SetValueStep(0.001)
            if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
            slider:SetScript("OnValueChanged", function(_, value)
                local color = {parent.r, parent.g, parent.b}
                color[c] = value
                Changed(color[1], color[2], color[3])
            end)
            frame.sliders[c] = slider
        end
    end
    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOP", 0, -208)
    hint:SetText(native and "Drag the wheel and brightness bar." or "Drag the sliders to choose any color.")
    local function Button(text, x, callback)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, -232); button:SetSize(112, 22)
        button:SetText(text); button:SetScript("OnClick", callback)
        if skin then skin.Button(button) end
        return button
    end
    function frame:SetColor(r, g, b)
        self.syncing = true
        if self.selector then self.selector:SetColorRGB(r, g, b)
        else for c, value in ipairs({r, g, b}) do self.sliders[c]:SetValue(value) end end
        self.syncing = nil
    end
    function frame:Close(commit)
        local original = self.original
        self.original = nil
        self:Hide()
        -- An ancestor hiding cancels the whole popover; its own cancel callback
        -- restores the original setting, so do not apply a stale wheel preview.
        if not commit and original and parent:IsShown() and (not parent.IsVisible or parent:IsVisible()) then
            parent:Set(original[1], original[2], original[3])
        end
    end
    function frame:Open()
        self:Close(false)
        self.original = {parent.r, parent.g, parent.b}
        self:SetColor(parent.r, parent.g, parent.b)
        self:SetFrameLevel(parent:GetFrameLevel() + 10)
        self:Show()
    end
    frame.cancelButton = Button("Cancel", 38, function() frame:Close(false) end)
    frame.done = Button("Done", 170, function() frame:Close(true) end)
    frame:SetScript("OnHide", function(self) self:Close(false) end)
    return frame
end

local function Create()
    local skin = A.OptionsSkin
    local frame = CreateFrame("Frame", "ForeverNamesColorPopover", A.options or UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(340, 274)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverNamesColorPopover") end
    local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetText("Choose a color")
    if skin then
        skin.Frame(frame, heading)
    else
        frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}})
        frame:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
        heading:SetPoint("TOP", 0, -10)
    end
    local function Button(text, x, y, width, onClick)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y)
        button:SetSize(width, 22)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        if skin then skin.Button(button) end
        return button
    end
    local function Fill(button, inset)
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("TOPLEFT", inset, -inset); texture:SetPoint("BOTTOMRIGHT", -inset, inset)
        return texture
    end

    frame.swatches = {}
    for i, color in ipairs(palette) do
        local column, row = (i - 1) % 6, math.floor((i - 1) / 6)
        local swatch = Button("", 22 + column * 50, -42 - row * 30, 44, function() frame:Set(color[1], color[2], color[3]) end)
        Fill(swatch, 6):SetColorTexture(color[1], color[2], color[3])
        frame.swatches[i] = swatch
    end
    -- Fine tuning in 5% steps.
    frame.channels = {}
    for c, label in ipairs({"R", "G", "B"}) do
        local x = 22 + (c - 1) * 100
        local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", x, -168); text:SetText(label)
        local value = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        value:SetPoint("TOPLEFT", x + 36, -168); value:SetWidth(32); value:SetJustifyH("CENTER")
        local function Step(direction)
            local current = {frame.r, frame.g, frame.b}
            current[c] = math.max(0, math.min(1, math.floor(current[c] * 20 + 0.5 + direction) / 20))
            frame:Set(current[1], current[2], current[3])
        end
        Button("-", x + 12, -163, 24, function() Step(-1) end)
        Button("+", x + 68, -163, 24, function() Step(1) end)
        frame.channels[c] = value
    end
    frame.preview = frame:CreateTexture(nil, "ARTWORK")
    frame.preview:SetPoint("TOPLEFT", 24, -204); frame.preview:SetSize(40, 20)
    frame.wheel = Button("Wheel...", 76, -202, 78, function()
        frame.wheelPicker = frame.wheelPicker or CreateWheel(frame, "ForeverNamesColorWheel", skin)
        frame.wheelPicker:Open()
    end)
    frame.wheel:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open the picker to choose any color.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.wheel:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame.cancelButton = Button("Cancel", 162, -202, 76, function() frame:Cancel() end)
    frame.done = Button("Done", 244, -202, 76, function() frame.committed = true; frame:Hide() end)
    -- Optional follow-the-player colors (icons): chosen instead of a fixed color.
    frame.modeLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.modeLabel:SetPoint("TOPLEFT", 24, -204); frame.modeLabel:SetText("Or use")
    frame.modeButtons = {}
    for i, choice in ipairs({{"Class color", "class"}, {"Name color", "name"}}) do
        local button = Button(choice[1], 76 + (i - 1) * 124, -198, 118, function()
            local set = frame.modes and frame.modes.set
            -- Clicking the selected choice again returns to the custom color.
            local value = frame.modes and frame.modes.current == choice[2] and "custom" or choice[2]
            frame.committed = true
            frame:Hide()
            if set then set(value) end
        end)
        button.mode = choice[2]
        button.wash = button:CreateTexture(nil, "ARTWORK")
        button.wash:SetPoint("TOPLEFT", 4, -4); button.wash:SetPoint("BOTTOMRIGHT", -4, 4)
        button.wash:SetColorTexture(1, 0.72, 0.2, 0.2)
        frame.modeButtons[i] = button
    end

    function frame:Set(r, g, b)
        self.r, self.g, self.b = r, g, b
        self.preview:SetColorTexture(r, g, b)
        for c, value in ipairs({r, g, b}) do self.channels[c]:SetText(math.floor(value * 100 + 0.5)) end
        if self.wheelPicker and self.wheelPicker:IsShown() and not self.wheelPicker.changing then
            self.wheelPicker:SetColor(r, g, b)
        end
        if self.apply then self.apply(r, g, b) end
    end
    function frame:Cancel()
        local cancel = self.cancel
        self.apply, self.cancel = nil, nil
        self:Hide()
        if cancel then cancel() end
    end
    frame:SetScript("OnHide", function(self)
        if self.wheelPicker then self.wheelPicker:Close(true) end
        -- Escape, the close button, or closing the settings window all cancel.
        if not self.committed and self.cancel then self:Cancel() end
        self.apply, self.cancel, self.committed = nil, nil, nil
        if self:IsShown() then self:Hide() end
    end)
    return frame
end

-- Glyph grid: click one to choose it (applies immediately and closes).
local glyphPopover
-- allowNone adds a "None" tile (People: tracked without an icon).
function A.PickGlyph(anchor, current, color, apply, allowNone)
    if popover and popover:IsShown() then popover:Cancel() end
    if not glyphPopover then
        local skin = A.OptionsSkin
        local frame = CreateFrame("Frame", "ForeverNamesGlyphPopover", A.options or UIParent, "BackdropTemplate")
        frame:Hide()
        frame:SetSize(340, 176)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableMouse(true)
        if UISpecialFrames then table.insert(UISpecialFrames, "ForeverNamesGlyphPopover") end
        local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        heading:SetText("Choose an icon")
        if skin then skin.Frame(frame, heading) else heading:SetPoint("TOP", 0, -10) end
        frame.buttons = {}
        for i, glyph in ipairs(A.glyphs) do
            local column, row = (i - 1) % 7, math.floor((i - 1) / 7)
            local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            button:SetPoint("TOPLEFT", 22 + column * 43, -42 - row * 40)
            button:SetSize(38, 34)
            button:SetText("")
            if skin then skin.Button(button) end
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("CENTER"); button.icon:SetSize(20, 20)
            button.icon:SetTexture(A.GlyphPath(glyph))
            button.glyph = glyph
            button:SetScript("OnClick", function()
                local done = frame.apply
                frame.apply = nil
                frame:Hide()
                if done then done(glyph) end
            end)
            frame.buttons[i] = button
        end
        local none = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        none:SetPoint("TOPLEFT", 22 + 4 * 43, -42 - 2 * 40)
        none:SetSize(124, 34)
        none:SetText("None")
        if skin then skin.Button(none) end
        none.wash = none:CreateTexture(nil, "ARTWORK")
        none.wash:SetPoint("TOPLEFT", 4, -4); none.wash:SetPoint("BOTTOMRIGHT", -4, 4)
        none.wash:SetColorTexture(1, 0.72, 0.2, 0.2)
        none:SetScript("OnClick", function()
            local done = frame.apply
            frame.apply = nil
            frame:Hide()
            if done then done("none") end
        end)
        frame.none = none
        glyphPopover = frame
    end
    local frame = glyphPopover
    frame.apply = apply
    for _, button in ipairs(frame.buttons) do
        local selected = button.glyph == current
        if selected then button.icon:SetVertexColor(color[1], color[2], color[3]) else button.icon:SetVertexColor(0.85, 0.85, 0.85) end
        button.icon:SetAlpha(selected and 1 or 0.8)
    end
    frame.none:SetShown(allowNone == true)
    frame.none.wash:SetShown(current == "none")
    frame:ClearAllPoints()
    if anchor then frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4) else frame:SetPoint("CENTER") end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:Show()
    return frame
end

-- apply(r, g, b) runs live on every change; cancel() restores the original.
-- modes (optional) = {current = "custom"|"class"|"name", set = function(mode)}
-- adds "Class color" / "Name color" choices.
function A.PickColor(anchor, r, g, b, apply, cancel, modes)
    if glyphPopover then glyphPopover:Hide() end
    popover = popover or Create()
    if popover:IsShown() then popover:Cancel() end
    Attach(popover, anchor)
    popover.apply, popover.cancel, popover.committed = nil, nil, nil
    popover:ClearAllPoints()
    if anchor then popover:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    else popover:SetPoint("CENTER") end
    if popover.SetClampedToScreen then popover:SetClampedToScreen(true) end
    popover:Set(r, g, b) -- shows the starting color without applying it
    popover.apply, popover.cancel, popover.modes = apply, cancel, modes
    popover.wheel:SetEnabled(true)
    -- The follow-the-player row sits under R/G/B; actions stay at the bottom.
    local bottom = modes and -236 or -202
    popover.preview:ClearAllPoints(); popover.preview:SetPoint("TOPLEFT", 24, bottom - 2)
    for _, entry in ipairs({{popover.wheel, 76}, {popover.cancelButton, 162}, {popover.done, 244}}) do
        entry[1]:ClearAllPoints(); entry[1]:SetPoint("TOPLEFT", entry[2], bottom)
    end
    popover:SetHeight(modes and 274 or 240)
    popover.modeLabel:SetShown(modes ~= nil)
    for _, button in ipairs(popover.modeButtons) do
        button:SetShown(modes ~= nil)
        local selected = modes and modes.current == button.mode
        button.wash:SetShown(selected and true or false)
        if selected then button:GetFontString():SetTextColor(1, 0.82, 0) else button:GetFontString():SetTextColor(0.9, 0.9, 0.9) end
    end
    popover:Show()
    return popover
end
