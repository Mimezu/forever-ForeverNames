local _, A = ...
-- Vendor coins: a small gold coin beside a merchant whose shop holds items
-- worth buying to resell on the auction house, only while it is worth it.
-- Ten Minute Goblin decides (TenMinuteGoblin.VendorMark(npcID), and its
-- OnMarksChanged callback when the answer changes). Without that addon
-- nothing is read, created or shown. The coin is one more icon in the plate's
-- icon row, beside the trainer icon, so the two never overlap.
A.defaults.vendorCoins = true

local COIN = "Interface\\MoneyFrame\\UI-GoldIcon"
local COIN_COLOR = {1, 1, 1}

local function Public(value) return not issecretvalue or not issecretvalue(value) end

-- Ten Minute Goblin's answer for an NPC id: nil, or {gain = copper, items = n, why = "..."}.
function A.VendorMark(id)
    local goblin = TenMinuteGoblin
    if type(goblin) ~= "table" or type(goblin.VendorMark) ~= "function" then return nil end
    local npcID = tonumber(id) or id
    if npcID == nil then return nil end
    local ok, mark = pcall(goblin.VendorMark, npcID)
    if ok and type(mark) == "table" and Public(mark.gain) then return mark end
    return nil
end

-- "+2g 10s", "+47s 75c", "+8c"; nil for nothing to gain.
function A.VendorGainText(copper)
    copper = tonumber(copper)
    if not copper or copper <= 0 then return nil end
    copper = math.floor(copper + 0.5)
    local gold, silver, bronze = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    if gold > 0 then return "+" .. gold .. "g" .. (silver > 0 and (" " .. silver .. "s") or "") end
    if silver > 0 then return "+" .. silver .. "s" .. (bronze > 0 and (" " .. bronze .. "c") or "") end
    return "+" .. bronze .. "c"
end

-- Adds the coin to an NPC's icon list (after its People and trainer icons).
function A.VendorIcons(id, icons, record)
    if icons then
        for i = #icons, 1, -1 do if icons[i] == "coin" then table.remove(icons, i) end end
    end
    local db = A.db
    if not (db and db.vendorCoins) or not id or not A.VendorMark(id) then return icons end
    if not icons then
        icons = record and record.coinIcons or {}
        if record then record.coinIcons = icons end
        for i = #icons, 1, -1 do icons[i] = nil end
        icons.person = nil
    end
    icons[#icons + 1] = "coin"
    icons.coinPath, icons.coinColor = COIN, COIN_COLOR
    return icons
end

-- Tooltip: one line on a marked merchant, "Resell +2g 10s". Hooked once,
-- when Ten Minute Goblin is there (nothing to say without it).
local function HookTooltip()
    if not TooltipDataProcessor or not Enum or not Enum.TooltipDataType then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        local db = A.db
        if not (db and db.enabled and db.vendorCoins) or not tooltip.GetUnit then return end
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if not ok or not Public(unit) or type(unit) ~= "string" then return end
        local mark = A.VendorMark(A.NPCID(unit))
        local text = mark and A.VendorGainText(mark.gain)
        if text then tooltip:AddLine("Resell " .. text, 1, 0.82, 0) end
    end)
end

-- Marks changed (a new scan, prices moved): redraw the NPC plates once.
local connected, redrawQueued = false, false
local function Redraw()
    if redrawQueued then return end
    redrawQueued = true
    C_Timer.After(0.2, function()
        redrawQueued = false
        local db = A.db
        if db and db.enabled and db.vendorCoins and A.RequeueNPCs then A.RequeueNPCs() end
    end)
end
local function Connect()
    if connected then return true end
    local goblin = TenMinuteGoblin
    if type(goblin) ~= "table" or type(goblin.OnMarksChanged) ~= "function" then return false end
    connected = pcall(goblin.OnMarksChanged, Redraw) and true or false
    if connected then HookTooltip(); Redraw() end
    return connected
end

-- Ten Minute Goblin may load before or after us: hook up when it is there.
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if Connect() then self:UnregisterEvent("ADDON_LOADED") end
    if event == "PLAYER_LOGIN" then self:UnregisterEvent("PLAYER_LOGIN") end
end)
