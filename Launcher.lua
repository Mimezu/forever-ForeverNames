local _, A = ...
-- Ways in: the minimap button and the page in Blizzard's Settings (Esc >
-- Options > AddOns). Both open the settings window (OptionsWindow.lua).
local ICON = "Interface\\Icons\\INV_Misc_Note_02"
local button, page

-- Minimap button -------------------------------------------------------------
local function Place()
    if not button then return end
    local angle = math.rad(tonumber(A.db.minimapAngle) or 200)
    local radius = (Minimap:GetWidth() or 140) / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end
-- Dragging: the button follows the cursor around the minimap's edge.
local function Follow()
    local mx, my = Minimap:GetCenter()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not (mx and x and scale) then return end
    local dx, dy = x / scale - mx, y / scale - my
    local angle = math.deg(math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx))
    A.db.minimapAngle = math.floor((angle % 360) * 10 + 0.5) / 10
    Place()
end
local function BuildButton()
    button = CreateFrame("Button", "ForeverNamesMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function() A.ToggleOptions() end)
    button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
    button:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", Follow)
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        icon:SetPoint("TOPLEFT", 7, -6)
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Forever Names", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    A.minimapButton = button
    Place()
end
function A.RefreshMinimapButton()
    if A.db.minimapIcon and not button and Minimap then BuildButton() end
    if button then button:SetShown(A.db.minimapIcon and true or false) end
end
function A.SetMinimapIcon(shown)
    A.db.minimapIcon = shown and true or false
    A.RefreshMinimapButton()
    if A.RefreshOptions then A.RefreshOptions() end
    if A.RefreshSettingsPage then A.RefreshSettingsPage() end
end

-- Page in Blizzard's Settings -----------------------------------------------
local function IsGamepadInterface()
    return C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and Enum and Enum.InputDeviceInterfaceType
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad or false
end
local function BuildPage()
    local panel = CreateFrame("Frame")
    local refreshers = {}
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText("Forever Names")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(140, 26)
    open:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    open:SetText("Open")
    open:SetScript("OnClick", function()
        -- Closing a Blizzard panel from addon code runs the gamepad window manager
        -- with addon taint, so in the gamepad interface Settings stays open behind.
        if SettingsPanel and SettingsPanel:IsShown() and not IsGamepadInterface() and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        A.OpenOptions()
    end)
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", open, "RIGHT", 12, 0)
    hint:SetText("/fnames")
    local minimap = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimap:SetSize(26, 26)
    minimap:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -4, -14)
    local minimapText = minimap.Text or minimap.text
    if minimapText then minimapText:SetFontObject("GameFontHighlight"); minimapText:SetText("Minimap icon") end
    minimap:SetScript("OnClick", function(box) A.SetMinimapIcon(box:GetChecked() == true) end)
    refreshers[#refreshers + 1] = function() minimap:SetChecked(A.db.minimapIcon and true or false) end
    local keysHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keysHeading:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 4, -18)
    keysHeading:SetText("Keys")
    local previous = keysHeading
    for _, entry in ipairs(A.keyActions or {}) do
        local action = entry[1]
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, previous == keysHeading and -12 or -14)
        label:SetWidth(150); label:SetJustifyH("LEFT")
        label:SetText(entry[2])
        local key = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        key:SetSize(120, 22)
        key:SetPoint("LEFT", label, "LEFT", 156, 0)
        key:SetScript("OnClick", function(self) A.ToggleKeyCapture(action, self) end)
        local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        clear:SetSize(60, 22)
        clear:SetPoint("LEFT", key, "RIGHT", 4, 0)
        clear:SetText("Clear")
        clear:SetScript("OnClick", function() if A.BindKey(action, nil) then A.RefreshSettingsPage(); A.RefreshOptions() end end)
        refreshers[#refreshers + 1] = function()
            key:SetText(A.KeyCapturing(action) and "Press a key" or A.KeyText(action))
        end
        previous = label
    end
    local function Refresh() for _, refresh in ipairs(refreshers) do refresh() end end
    panel:SetScript("OnShow", Refresh)
    return panel, Refresh
end
local function RegisterPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel, refresh = BuildPage()
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Forever Names")
    if not (ok and category) then return end
    pcall(Settings.RegisterAddOnCategory, category)
    page = panel
    A.settingsPage = panel
    function A.RefreshSettingsPage() if page:IsShown() then refresh() end end
end

-- Called at login (Core.lua); the settings window is built on first open.
function A.CreateLauncher()
    A.RefreshMinimapButton()
    pcall(RegisterPage)
end
