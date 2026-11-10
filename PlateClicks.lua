local _, A = ...
-- Clicks on nameplates. Where a nameplate can be clicked, the game selects the
-- unit on the press and never starts a camera drag there (either button). That
-- clickable area belongs to the game: Blizzard sets it per plate, around the
-- name and the health bar, and it stays in place, invisible, when our label
-- replaces them. An addon cannot keep the click and also let the drag through;
-- it can only remove the area (the plate's hit-test points).
--   plateClicks = "all"   the game's behavior: nothing is read, changed or hooked
--               = "bars"  plates we turned into a plain name let the mouse through
--               = "none"  every nameplate lets the mouse through
-- In combat the game refuses addon changes except on the tick a unit arrives
-- and right after Blizzard's own update, so we act at those two moments, and
-- on every Core update (settings changes, and the retry when combat ends).
A.defaults.plateClicks = "all"

-- plate -> {frame = unit frame, points = Blizzard's area we removed}
local cleared, hooked = {}, {}

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Forbidden(frame) return frame.IsForbidden and frame:IsForbidden() end
local function Call(plate, method, ...)
    local func = plate[method]
    if type(func) ~= "function" then return false end
    return pcall(func, plate, ...)
end
local function CanChange(plate)
    local ok, allowed = Call(plate, "CanChangeHitTestPoints")
    return ok and Public(allowed) and allowed == true
end

local function Wanted(frame, unit)
    local db = A.db
    if not db or not db.enabled then return false end
    local mode = db.plateClicks
    if mode == "none" then return true end
    if mode ~= "bars" or not frame then return false end
    local state = A.RenderStates and A.RenderStates[frame]
    -- Our names drawn on Blizzard's health bar keep the bar's click.
    if state then return not state.keepBars end
    -- Arrival tick: Core has hidden Blizzard's regions, the label follows.
    return unit ~= nil and A.IsPrimedPlate ~= nil and A.IsPrimedPlate(frame, unit) or false
end

local function Apply(plate, frame, unit)
    local entry = cleared[plate]
    -- Unit frames are pooled: another one on this plate means Blizzard has set
    -- a fresh area since, and the points we kept belong to the old frame.
    if entry and entry.frame ~= frame then entry, cleared[plate] = nil, nil end
    if Wanted(frame, unit) then
        if entry or not CanChange(plate) then return end
        local ok, points = Call(plate, "GetHitTestPoints")
        if not Call(plate, "ClearAllHitTestPoints") then return end
        cleared[plate] = {frame = frame, points = ok and type(points) == "table" and points or {}}
    elseif entry then
        -- Blocked in combat: the plate stays click-through until combat ends.
        if #entry.points == 0 or (CanChange(plate) and Call(plate, "SetHitTestPoints", entry.points)) then
            cleared[plate] = nil
        end
    end
end

-- Blizzard sets the area again whenever a plate's options change; that is
-- also the one moment in combat when we may remove it again.
local function Hook(frame)
    if hooked[frame] or type(frame.UpdateHitTestArea) ~= "function" then return end
    hooked[frame] = true
    hooksecurefunc(frame, "UpdateHitTestArea", function(self)
        if Forbidden(self) or type(self.GetNamePlateFrame) ~= "function" then return end
        local ok, plate = pcall(self.GetNamePlateFrame, self)
        if not ok or not plate or Forbidden(plate) then return end
        cleared[plate] = nil
        local unit = self.unit
        Apply(plate, self, Public(unit) and unit or nil)
    end)
end

function A.UpdatePlateClicks(plate, unit)
    local db = A.db
    if not db or not plate then return end
    if db.plateClicks == "all" and next(cleared) == nil then return end
    if Forbidden(plate) then return end
    local frame = plate.UnitFrame
    if frame and Forbidden(frame) then return end
    if frame and db.plateClicks ~= "all" then Hook(frame) end
    Apply(plate, frame, unit)
end

-- The plate lost its unit: Blizzard sets a new area with the next one.
function A.ForgetPlateClicks(plate)
    if plate then cleared[plate] = nil end
end
