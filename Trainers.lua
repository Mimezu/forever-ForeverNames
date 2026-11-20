local _, A = ...
-- Trainer icons: beside trainers of your own professions (first aid, cooking
-- and fishing included) and of your class. Read from the NPC's subtitle:
-- <Blacksmithing Trainer>, <Expert Blacksmith>, <Warrior Trainer>. Suppliers
-- (<Blacksmithing Supplies>) never match. The icon sits where your People
-- icons go. Your professions are read once, and again when you learn or
-- drop one.
A.defaults.iconsProfessionTrainer = false
A.defaults.iconsClassTrainer = false

local function Public(value) return not issecretvalue or not issecretvalue(value) end

-- By skill line: the glyph (shaped after the profession's WoW icon), its
-- color, and what its trainers are called besides "<Profession> Trainer".
local TRADES = {
    [164] = {"trade_anvil", {0.80, 0.88, 1.00}, "blacksmithing", {"blacksmith"}},
    [165] = {"trade_hide", {1.00, 0.72, 0.40}, "leatherworking", {"leatherworker"}},
    [171] = {"trade_flask", {0.45, 1.00, 0.55}, "alchemy", {"alchemist"}},
    [182] = {"trade_herb", {0.55, 1.00, 0.40}, "herbalism", {"herbalist"}},
    [185] = {"trade_pot", {1.00, 0.72, 0.30}, "cooking", {"cook", "chef"}},
    [186] = {"trade_pick", {1.00, 0.80, 0.50}, "mining", {"miner"}},
    [197] = {"trade_spool", {1.00, 0.75, 1.00}, "tailoring", {"tailor"}},
    [202] = {"trade_gear", {1.00, 0.80, 0.35}, "engineering", {"engineer"}},
    [333] = {"trade_wand", {0.80, 0.60, 1.00}, "enchanting", {"enchanter"}},
    [356] = {"trade_hook", {0.45, 0.80, 1.00}, "fishing", {"fisherman", "angler"}},
    [393] = {"trade_knife", {1.00, 0.65, 0.50}, "skinning", {"skinner"}},
    [129] = {"trade_cross", {1.00, 0.40, 0.40}, "first aid", {"physician", "trauma surgeon"}},
    [755] = {"trade_gem", {0.45, 1.00, 1.00}, "jewelcrafting", {"jewelcrafter"}},
    [773] = {"trade_quill", {1.00, 0.94, 0.75}, "inscription", {"scribe"}},
}
local RANKS = {"apprentice", "journeyman", "expert", "artisan", "master", "grand master"}
local CLASS_GLYPH = "trade_book"

-- Your professions: lowercase trainer subtitles -> {glyph, color}. Bare
-- trade names (<Miner>) count only on an NPC with the trainer cursor.
local professionTitles, bareTitles, classTitle, signature
local matches = {}
local function Add(titles, words, entry)
    for _, word in ipairs(words) do
        titles[word .. " trainer"] = entry
        for _, rank in ipairs(RANKS) do titles[rank .. " " .. word] = entry end
    end
end
local function Professions()
    local titles, lines = {}, {}
    bareTitles = {}
    signature = ""
    if not GetProfessions or not GetProfessionInfo then return titles end
    local ok, a, b, c, d, e = pcall(GetProfessions)
    if not ok then return titles end
    for _, index in pairs({a, b, c, d, e}) do
        local okInfo, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, index)
        if okInfo and Public(skillLine) and Public(name) then
            lines[#lines + 1] = tostring(skillLine)
            local trade = TRADES[skillLine]
            local entry = trade and {trade[1], trade[2]} or {"trade_book", {1, 0.82, 0.2}}
            local words = trade and {trade[3]} or {}
            -- The game's own (localized) name, as "<Name> Trainer".
            if type(name) == "string" and name ~= "" then words[#words + 1] = name:lower() end
            Add(titles, words, entry)
            if trade then
                Add(titles, trade[4], entry)
                for _, noun in ipairs(trade[4]) do bareTitles[noun] = entry end
            end
        end
    end
    table.sort(lines)
    signature = table.concat(lines, ",")
    return titles
end
local function ClassTitle()
    local ok, name, classFile = pcall(UnitClass, "player")
    if not ok or not Public(name) or type(name) ~= "string" then return nil end
    local class = RAID_CLASS_COLORS and Public(classFile) and RAID_CLASS_COLORS[classFile]
    -- Your class color, lightened a third toward white so the small book reads.
    local function Light(v) return v + (1 - v) * 0.35 end
    return {name:lower() .. " trainer", class and {Light(class.r), Light(class.g), Light(class.b)} or {1, 0.82, 0.2}}
end

-- The trainer icon for a subtitle (and the NPC wearing it): glyph and color, or nil.
function A.TrainerMatch(title, unit)
    local db = A.db
    if type(title) ~= "string" or not Public(title) or not (db.iconsProfessionTrainer or db.iconsClassTrainer) then return nil end
    local key = title:lower():gsub("^%s*<", ""):gsub(">%s*$", "")
    local found = matches[key]
    if found == nil then
        found = false
        professionTitles = professionTitles or Professions()
        if classTitle == nil then classTitle = ClassTitle() or false end
        local trade = professionTitles[key]
        if trade then found = {kind = "profession", glyph = trade[1], color = trade[2]}
        elseif classTitle and key == classTitle[1] then found = {kind = "class", glyph = CLASS_GLYPH, color = classTitle[2]} end
        matches[key] = found
    end
    if not found then
        -- <Miner>: a trainer only if the game shows the trainer cursor on it.
        local bare = db.iconsProfessionTrainer and bareTitles and bareTitles[key]
        if bare and unit and A.IsTrainerUnit and A.IsTrainerUnit(unit) then return bare[1], bare[2] end
        return nil
    end
    if found.kind == "profession" and not db.iconsProfessionTrainer then return nil end
    if found.kind == "class" and not db.iconsClassTrainer then return nil end
    return found.glyph, found.color
end

-- Adds the trainer icon to an NPC's icon list (after its People icon).
function A.TrainerIcons(title, icons, record, unit)
    if icons then
        for i = #icons, 1, -1 do if icons[i] == "trainer" then table.remove(icons, i) end end
    end
    local glyph, color = A.TrainerMatch(title, unit)
    if not glyph then return icons end
    if not icons then
        icons = record and record.trainerIcons or {}
        if record then record.trainerIcons = icons end
        for i = #icons, 1, -1 do icons[i] = nil end
        icons.person = nil
    end
    icons[#icons + 1] = "trainer"
    icons.trainerGlyph, icons.trainerColor = glyph, color
    return icons
end

-- Learning or dropping a profession: read them again, redraw if it matters.
-- (The event also fires on every skill point; those change nothing here.)
local events = CreateFrame("Frame")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:SetScript("OnEvent", function()
    if not professionTitles then return end
    local old = signature
    local titles = Professions()
    if signature == old then return end
    professionTitles, matches = titles, {}
    local db = A.db
    if db and db.enabled and db.iconsProfessionTrainer and A.Refresh then A.Refresh() end
end)
