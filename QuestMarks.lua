local _, A = ...
-- Quest enemies (off by default): a "!" to the left of hostile and neutral NPCs
-- that belong to one of your active quests (kill targets, mobs that drop quest
-- items). Blizzard keeps these plates; the mark is our own layer on top of the
-- plate and never touches Blizzard's regions.
-- Work happens only on plate arrival and quest-log updates, both already
-- queued by Core. With the option off, nothing is read or created.
A.defaults.questMark = false
A.defaults.colors.questMark = {1, 0.82, 0.2}

local GLYPH = "Interface\\AddOns\\ForeverNames\\Media\\Glyphs\\exclaim"
local marks = {} -- plate -> {holder, texture, anchor}

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Read(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok and Public(value) then return value end
end

-- Attackable NPCs only: these are the plates Blizzard keeps (Core never labels them).
local function IsQuestCandidate(unit)
    if not Read(UnitExists, unit) or Read(UnitIsPlayer, unit) == true then return false end
    if Read(UnitPlayerControlled, unit) or Read(UnitIsDeadOrGhost, unit) then return false end
    return Read(UnitCanAttack, "player", unit) == true
end

-- Fallback when the client has no quest-unit API: unfinished objective lines
-- in the unit's tooltip data (type QuestObjective).
local function TooltipRelated(unit)
    local getter = C_TooltipInfo and C_TooltipInfo.GetUnit
    if not getter then return false end
    local ok, data = pcall(getter, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    local objective = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8
    for _, line in ipairs(data.lines) do
        local kind = type(line) == "table" and line.type
        if Public(kind) and kind == objective and line.completed ~= true then return true end
    end
    return false
end

-- true, false, or a secret boolean (only usable with SetAlphaFromBoolean).
function A.IsQuestEnemy(unit)
    local api = C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
    if api then
        local ok, value = pcall(api, unit)
        if ok then
            if not Public(value) then return value end
            return value == true
        end
    end
    return TooltipRelated(unit)
end

local function Hide(plate)
    local mark = plate and marks[plate]
    if mark then mark.holder:Hide() end
end
A.HideQuestMark = Hide

local function Anchor(mark, frame)
    -- Left of Blizzard's health bar (its name spans the bar, centered), or of
    -- the name when the plate shows only a name.
    local target = frame.HealthBarsContainer or frame.name
    local size = math.floor((A.GetTextSizes and A.GetTextSizes("general") or 14) * 1.15 + 0.5)
    if mark.target == target and mark.size == size then return end
    if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
    mark.target, mark.size = target, size
    mark.texture:SetSize(size, size)
    mark.texture:ClearAllPoints()
    mark.texture:SetPoint("RIGHT", target, "LEFT", -2, 0)
end

function A.UpdateQuestMark(unit, plate)
    local db = A.db
    if not plate then return end
    if not (db and db.enabled and db.questMark) or (plate.IsForbidden and plate:IsForbidden()) then return Hide(plate) end
    local frame = plate.UnitFrame
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or not (frame.HealthBarsContainer or frame.name)
        or not IsQuestCandidate(unit) then
        return Hide(plate)
    end
    local related = A.IsQuestEnemy(unit)
    local secret = not Public(related)
    if not secret and not related then return Hide(plate) end
    local mark = marks[plate]
    if not mark then
        local holder = CreateFrame("Frame", nil, plate)
        holder:SetAllPoints(plate)
        holder:EnableMouse(false)
        local texture = holder:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(GLYPH)
        mark = {holder = holder, texture = texture}
        marks[plate] = mark
    end
    Anchor(mark, frame)
    local color = db.colors.questMark or A.defaults.colors.questMark
    mark.texture:SetVertexColor(color[1], color[2], color[3])
    if secret then
        -- The game decides without telling us: let it set the alpha directly.
        if not mark.texture.SetAlphaFromBoolean or not pcall(mark.texture.SetAlphaFromBoolean, mark.texture, related, 1, 0) then
            return Hide(plate)
        end
    else
        mark.texture:SetAlpha(1)
    end
    mark.holder:Show()
end
