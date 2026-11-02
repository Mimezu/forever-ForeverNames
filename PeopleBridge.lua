local _, A = ...
-- Your People list lives in Companion Journal, its own addon since 1.10. When
-- it is installed, our labels ask it who someone is and draw their display
-- name and icon. Without it there are no People features here, and nothing
-- is looked up.
local function Public(value) return not issecretvalue or not issecretvalue(value) end

-- Companion Journal's API (version 1 or later), or nil.
function A.People()
    local api = CompanionJournalAPI
    if type(api) == "table" and type(api.version) == "number" and api.version >= 1 then return api end
    return nil
end
-- Any in-world People feature on (display names, icons, tooltip, last seen).
function A.PeopleActive()
    local people = A.People()
    return people ~= nil and people.Active() == true
end
-- A person's icon: texture path, color, color mode ("custom", "class" or
-- "name"), own size (nil = ours), own side ("left", "right" or nil).
function A.PersonIcon(person)
    local people = A.People()
    if not people or not person then return nil end
    local path, color, mode, size, side = people.Icon(person)
    if not path then return nil end
    -- Where it sits among our icons is ours ("same", "left", "right"); the first
    -- time, it starts from what Companion Journal had.
    local db = A.db
    if db and db.peopleIconSide == nil then
        local old = CompanionJournalDB and CompanionJournalDB.peopleIconPosition
        db.peopleIconSide = (old == "left" or old == "right") and old or "same"
    end
    if db and db.peopleIconSide then side = (db.peopleIconSide == "left" or db.peopleIconSide == "right") and db.peopleIconSide or nil end
    return path, color, mode, size, side
end
function A.PersonDisplayName(person)
    local people = A.People()
    return people and person and people.DisplayName(person) or nil
end

-- NPC plates: their People entry (if any), its icon list, and display name.
local currentNPC = {}
function A.NPCPerson(unit, record)
    local people = A.People()
    if not people or not people.Active() then currentNPC[unit] = nil; return nil end
    local person = people.Find(unit)
    currentNPC[unit] = person or nil
    if not person then return nil end
    people.Seen(person)
    local icons
    if A.PersonIcon(person) then
        icons = record and record.npcIcons or {}
        if record then record.npcIcons = icons end
        icons[1], icons.person = "people", person
    end
    return person, icons
end
function A.NPCDisplayName(unit, name)
    local person = currentNPC[unit]
    return person and A.PersonDisplayName(person) or name
end

-- What Companion Journal can ask us. Version 1.
local api = {version = 1}
-- True when our label replaces Blizzard's name on this unit's plate: the
-- People icon then goes on our label, not beside Blizzard's name.
function api.OwnsUnit(unit)
    local db = A.db
    if not db or not db.enabled or A.nativePlateTest then return false end
    local ok, player = pcall(UnitIsPlayer, unit)
    if not ok or not Public(player) then return false end
    if player == true then
        if A.IsEnemyPlayer and A.IsEnemyPlayer(unit) then
            return db.enemyEnabled and A.EnemyMode and A.EnemyMode() ~= "native" or false
        end
        return db.showFriendlyPlayers and true or false
    end
    return true -- NPCs from the list keep a label while People options are on
end
-- Opposite-faction players, as our Enemies tab sees them (its test included).
function api.IsEnemyPlayer(unit) return A.IsEnemyPlayer and A.IsEnemyPlayer(unit) or false end
-- Our automatic icon size (the name's height) for players or NPCs.
function api.IconSize(npc)
    if not A.db or not A.IconSize or not A.GetTextSizes then return nil end
    return A.IconSize((A.GetTextSizes(npc and "general" or "friendlyPlayer")))
end
-- People icons share our layout. The Journal's standalone nameplate setting
-- cannot move an icon drawn by Forever Names; route edits through our normal
-- option action so active labels and both settings windows refresh together.
function api.PeopleIconPosition()
    if not A.db then return "same" end
    local side = A.db.peopleIconSide
    if side == "left" or side == "right" or side == "same" then return side end
    local old = CompanionJournalDB and CompanionJournalDB.peopleIconPosition
    return (old == "left" or old == "right") and old or "same"
end
function api.SetPeopleIconPosition(side)
    if not A.db or not A.SetOption or (side ~= "left" and side ~= "right" and side ~= "same") then return false end
    A.SetOption("peopleIconSide", side)
    return true
end
function api.Open() if A.OpenOptions then A.OpenOptions() end end
-- Our window is open (for the "Names | Journal" switch in Companion Journal).
function api.IsOpen() return (A.options and A.options:IsShown()) or (A.optionsB and A.optionsB:IsShown()) or false end
ForeverNamesAPI = api
