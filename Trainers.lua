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
    [164] = {"trade_anvil", {0.75, 0.78, 0.84}, "blacksmithing", {"blacksmith"}},
    [165] = {"trade_hide", {0.80, 0.55, 0.30}, "leatherworking", {"leatherworker"}},
    [171] = {"trade_flask", {0.40, 0.90, 0.50}, "alchemy", {"alchemist"}},
    [182] = {"trade_herb", {0.45, 0.85, 0.35}, "herbalism", {"herbalist"}},
    [185] = {"trade_pot", {1.00, 0.60, 0.25}, "cooking", {"cook", "chef"}},
    [186] = {"trade_pick", {0.85, 0.65, 0.40}, "mining", {"miner"}},
    [197] = {"trade_spool", {0.90, 0.75, 0.95}, "tailoring", {"tailor"}},
    [202] = {"trade_gear", {1.00, 0.70, 0.30}, "engineering", {"engineer"}},
    [333] = {"trade_wand", {0.70, 0.50, 1.00}, "enchanting", {"enchanter"}},
    [356] = {"trade_hook", {0.40, 0.70, 1.00}, "fishing", {"fisherman", "angler"}},
    [393] = {"trade_knife", {0.85, 0.55, 0.40}, "skinning", {"skinner"}},
    [129] = {"trade_cross", {1.00, 0.32, 0.32}, "first aid", {"physician", "trauma surgeon"}},
    [755] = {"trade_gem", {0.40, 0.90, 1.00}, "jewelcrafting", {"jewelcrafter"}},
    [773] = {"trade_quill", {0.90, 0.85, 0.70}, "inscription", {"scribe"}},
}
A.trainerTrades = TRADES
local RANKS = {"apprentice", "journeyman", "expert", "artisan", "master", "grand master"}
local CLASS_GLYPH = "trade_book"

-- Your professions: lowercase trainer subtitles -> {glyph, color}.
local professionTitles, classTitle, signature
local matches = {}
local function Add(titles, words, entry)
    for _, word in ipairs(words) do
        titles[word .. " trainer"] = entry
        for _, rank in ipairs(RANKS) do titles[rank .. " " .. word] = entry end
    end
end
local function Professions()
    local titles, lines = {}, {}
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
            if trade then Add(titles, trade[4], entry) end
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
    return {name:lower() .. " trainer", class and {class.r, class.g, class.b} or {1, 0.82, 0.2}}
end

-- The trainer icon for a subtitle: glyph and color, or nil.
function A.TrainerMatch(title)
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
    if not found then return nil end
    if found.kind == "profession" and not db.iconsProfessionTrainer then return nil end
    if found.kind == "class" and not db.iconsClassTrainer then return nil end
    return found.glyph, found.color
end

-- Adds the trainer icon to an NPC's icon list (after its People icon).
function A.TrainerIcons(title, icons, record)
    if icons then
        for i = #icons, 1, -1 do if icons[i] == "trainer" then table.remove(icons, i) end end
    end
    local glyph, color = A.TrainerMatch(title)
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
