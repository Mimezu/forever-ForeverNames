local _, A = ...
-- Friendly player label details. Everything here runs only when a player plate
-- is rendered (arrival or a specific event), and each read happens only while
-- its option is on: with every option off this is Blizzard's color and nothing
-- else. Identity-restricted values (secret) fall back to the plain label.
local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Read(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok and Public(value) then return value end
end
local function Text(value)
    return Public(value) and type(value) == "string" and value ~= "" and value or nil
end

local function ClassColor(unit, color)
    local ok, _, classFile = pcall(UnitClass, unit)
    local class = ok and Text(classFile) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not class then return false end
    color[1], color[2], color[3] = class.r, class.g, class.b
    return true
end

local currentPerson, currentStranger, currentTitle = {}, {}, {}

-- Known: in your People list, or (each optional) group, guild, friends.
function A.IsKnownPlayer(unit, person)
    local db = A.db
    if person then return true end
    if db.knownGroup and (Read(UnitInParty, unit) == true or Read(UnitInRaid, unit) ~= nil) then return true end
    if db.knownGuild and Read(UnitIsInMyGuild, unit) == true then return true end
    if db.knownFriends and A.IsFriendGUID and A.IsFriendGUID(Read(UnitGUID, unit)) then return true end
    return false
end
-- "Night Elf Druid", "Night Elf", or "Stranger".
function A.StrangerLabel(unit, style)
    style = style or A.db.playerStrangerStyle
    if style == "stranger" then return "Stranger" end
    local race = Text(Read(UnitRace, unit))
    local class = Text(Read(UnitClass, unit))
    if style == "race" then return race or "Stranger" end
    if race and class then return race .. " " .. class end
    return race or class or "Stranger"
end

function A.PlayerNameColor(unit, frame, color)
    local db = A.db
    color[1], color[2], color[3] = 1, 1, 1
    if db.playerColorMode == "custom" then
        local custom = db.colors.friendlyPlayer
        color[1], color[2], color[3] = custom[1], custom[2], custom[3]
        return color
    elseif db.playerColorMode == "class" and ClassColor(unit, color) then
        return color
    end
    -- Blizzard's own name color, read from the native name we replace.
    if frame.name and frame.name.GetTextColor then
        local ok, r, g, b = pcall(frame.name.GetTextColor, frame.name)
        if ok and Public(r) and Public(g) and Public(b)
            and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            color[1], color[2], color[3] = r, g, b
        end
    end
    return color
end

-- Returns color, subtitle, level text, whether the data is complete, and the
-- level's own color (nil = same as the name), then relationship icon keys.
-- Guild data can arrive shortly after the plate; incomplete labels get the
-- queue's bounded retries (at most three), never a repeating timer.
function A.PlayerLabel(unit, frame, record)
    local db = A.db
    -- One reusable color table per tracked unit instead of one per update.
    local color = record and record.playerColor or {}
    if record then record.playerColor = color end
    A.PlayerNameColor(unit, frame, color)
    -- Your people (Companion Journal): one lookup, only while one of its
    -- options or Immersion needs it.
    local unknownMode = db.playerUnknownMode
    local immersion = unknownMode == "stranger" or unknownMode == "hide"
    local people = A.People()
    local person = people and (people.Active() or immersion) and people.Find(unit) or nil
    currentPerson[unit] = person or nil
    if person then people.Seen(person, unit) end
    local hidden, stranger = nil, nil
    if immersion and not A.IsKnownPlayer(unit, person) then
        if unknownMode == "hide" then hidden = true else stranger = A.StrangerLabel(unit) end
    end
    currentStranger[unit] = stranger
    currentTitle[unit] = db.playerShowTitle
    local subtitle, level, complete, levelColor = nil, nil, true, nil
    if db.playerShowGuild then
        local ok, guild, rank = pcall(GetGuildInfo, unit)
        guild, rank = ok and Text(guild), ok and Text(rank)
        if guild then
            subtitle = (db.playerShowGuildRank and rank) and (rank .. " of <" .. guild .. ">") or ("<" .. guild .. ">")
        else
            complete = false
        end
    end
    -- The selected player's level pill already shows it; do not repeat it.
    if db.playerShowLevel and not (db.targetHealthBar and db.targetHealthLevel
        and Read(UnitIsUnit, unit, "target") == true) then
        local value = Read(UnitEffectiveLevel or UnitLevel, unit)
        if type(value) == "number" then level = value > 0 and tostring(value) or "??" end
        if level and db.playerLevelColorMode == "custom" then
            levelColor = db.colors.playerLevel
        elseif level and db.playerLevelColorMode == "class" then
            levelColor = record and record.levelColor or {}
            if record then record.levelColor = levelColor end
            if not ClassColor(unit, levelColor) then levelColor = nil end
        end
    end
    local icons = A.PlayerIcons and A.PlayerIcons(unit, record, person)
    return color, subtitle, level, complete, levelColor, icons, hidden
end

-- Quick fade for the level layer when it appears or disappears (not on a
-- plate's first paint). Without animation support it simply shows or hides.
function A.AttachLevelFade(holder)
    if not holder.CreateAnimationGroup then return end
    local function Fade(from, to, finished)
        local group = holder:CreateAnimationGroup()
        local alpha = group:CreateAnimation("Alpha")
        alpha:SetFromAlpha(from); alpha:SetToAlpha(to); alpha:SetDuration(0.2)
        group:SetScript("OnFinished", finished)
        return group
    end
    holder.fadeIn = Fade(0, 1, function() holder:SetAlpha(1) end)
    holder.fadeOut = Fade(1, 0, function() holder:Hide(); holder:SetAlpha(1) end)
end
function A.ShowLevel(holder, shown)
    if holder.wantShown == shown then return end
    local first = holder.wantShown == nil
    holder.wantShown = shown
    if first or not holder.fadeIn then holder:SetShown(shown); return end
    holder.fadeIn:Stop(); holder.fadeOut:Stop()
    if shown then
        holder:SetAlpha(0); holder:Show(); holder.fadeIn:Play()
    else
        holder.fadeOut:Play()
    end
end

-- Level badge: a few textures drawn behind the level text on the same frame
-- (a child frame would draw above the text). Created only for pill styles.
local badgeStyles = {
    minimal = {fill = {0.025, 0.025, 0.025, 0.85}},
    default = {fill = {0.03, 0.03, 0.03, 0.95}, border = {0.12, 0.12, 0.12}},
    classic = {fill = {0.03, 0.03, 0.03, 0.95}, border = {0.65, 0.5, 0.26}, native = true},
}
A.levelBadgeStyles = badgeStyles
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function Badge(owner)
    if owner.levelBadge then return owner.levelBadge end
    local badge = {}
    badge.art = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
    local atlas = "ui-hud-nameplates-levelindicator"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        badge.art:SetAtlas(atlas); badge.hasNativeArt = true
    end
    badge.rim = owner:CreateTexture(nil, "BACKGROUND", nil, 2)
    badge.rim:SetTexture("Interface\\Buttons\\WHITE8X8"); badge.rim:SetMask(MASK)
    badge.fill = owner:CreateTexture(nil, "BACKGROUND", nil, 3)
    badge.fill:SetTexture("Interface\\Buttons\\WHITE8X8"); badge.fill:SetMask(MASK)
    badge.textures = {badge.art, badge.rim, badge.fill}
    function badge:SetShown(shown)
        for _, texture in ipairs(self.textures) do texture:SetShown(shown and texture.wanted == true) end
    end
    function badge:SetAlpha(alpha)
        for _, texture in ipairs(self.textures) do texture:SetAlpha(alpha) end
    end
    owner.levelBadge = badge
    return badge
end
-- Styles the badge around `text` and returns the extra gap the level needs
-- next to the name (0 for the plain number).
function A.StyleLevelBadge(owner, text, height, style, value)
    local preset = badgeStyles[style]
    if not preset then
        if owner.levelBadge then
            for _, texture in ipairs(owner.levelBadge.textures) do texture.wanted = false; texture:Hide() end
        end
        return 0
    end
    local badge = Badge(owner)
    local digits = type(value) == "string" and #value or 2
    local h = math.floor(height + 5 + 0.5)
    local w = math.max(math.floor(h * 1.6 + 0.5), math.floor(digits * height * 0.62 + 10 + 0.5))
    local native = preset.native and badge.hasNativeArt
    badge.art.wanted, badge.rim.wanted, badge.fill.wanted = native, not native and preset.border ~= nil, not native
    for _, texture in ipairs(badge.textures) do
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", text, "CENTER", 0, 0)
        texture:SetSize(w, h)
    end
    local inset = preset.border and 2 or 0
    badge.fill:SetSize(w - inset, h - inset)
    badge.fill:SetVertexColor(unpack(preset.fill))
    if preset.border then badge.rim:SetVertexColor(preset.border[1], preset.border[2], preset.border[3], 1) end
    badge:SetShown(true)
    return math.max(0, math.floor((w - digits * height * 0.55) / 2 + 0.5))
end
-- Nearby-only levels: near = within the chosen interact range, or selected.
-- Unknown (the check can be blocked in combat) keeps the previous state.
-- Friendly players and enemies each have their own scope and range.
local RANGE_ITEM = 1251 -- Linen Bandage (15 yd)
function A.LevelScope(enemy)
    local scope = enemy and A.db.enemyLevelScope or A.db.playerLevelScope
    return (scope == "near" or scope == "target") and scope or "all"
end
function A.LevelNear(unit, previous, enemy)
    local db = A.db
    local scope = A.LevelScope(enemy)
    if scope == "all" then return true end
    if Read(UnitIsUnit, unit, "target") == true then return true end
    if scope == "target" then return false end
    local range = enemy and db.enemyLevelRange or db.playerLevelRange
    local ok, near
    if range == 15 then
        -- 15 yd: Linen Bandage's range, the usual item probe (not needed in bags).
        if not (C_Item and C_Item.IsItemInRange) then return true end
        -- The game blocks item-range checks on units during combat
        -- (ADDON_ACTION_BLOCKED seen 2026-09-27); keep the last answer until it ends.
        if InCombatLockdown and InCombatLockdown() then
            if previous == nil then return true end
            return previous
        end
        ok, near = pcall(C_Item.IsItemInRange, RANGE_ITEM, unit)
    else
        if not CheckInteractDistance then return true end
        ok, near = pcall(CheckInteractDistance, unit, range == 4 and 4 or 3)
    end
    if ok and Public(near) and type(near) == "boolean" then return near end
    if previous == nil then return true end
    return previous
end
-- Which levels need the distance check: friendly, enemy, or both.
local function LevelChecks()
    local db = A.db
    return db.playerShowLevel and A.LevelScope() == "near",
        db.enemyEnabled and db.enemyShowLevel and A.LevelScope(true) == "near"
end
-- While an option is on: every 0.75 s, requeue only plates whose level
-- crossed the range. Stops itself when the options or levels are off.
local generation = 0
local CHECK_INTERVAL = 0.75
local function CheckDistances(run)
    if run ~= generation then return end
    local db = A.db
    local friendly, enemy = LevelChecks()
    if not db.enabled or not (friendly or enemy) then return end
    for _, state in pairs(A.RenderStates or {}) do
        local level = state.overlay and state.overlay.level
        local isEnemy = state.sizeKey == "enemyPlayer"
        if ((state.sizeKey == "friendlyPlayer" and friendly) or (isEnemy and enemy))
            and state.visible and level and (level:GetText() or "") ~= "" then
            local near = A.LevelNear(state.unit, state.levelNear, isEnemy)
            if near ~= state.levelNear and A.RequeueUnit then A.RequeueUnit(state.unit) end
        end
    end
    C_Timer.After(CHECK_INTERVAL, function() CheckDistances(run) end)
end
local enemyGeneration = 0
local function CheckEnemyDistances(run)
    if run ~= enemyGeneration then return end
    local db = A.db
    if not db.enabled or not db.enemyEnabled or db.enemyScope ~= "near" then return end
    if not A.PlayerFlagged() then
        for _, state in pairs(A.RenderStates or {}) do
            if state.sizeKey == "enemyPlayer" and state.enemyShown ~= nil then
                local near = A.EnemyNear(state.unit, state.enemyShown)
                if near ~= state.enemyShown and A.RequeueUnit then A.RequeueUnit(state.unit) end
            end
        end
    end
    C_Timer.After(CHECK_INTERVAL, function() CheckEnemyDistances(run) end)
end
function A.UpdateEnemyDistance()
    local db = A.db
    enemyGeneration = enemyGeneration + 1
    if db.enabled and db.enemyEnabled and db.enemyScope == "near" then
        if db.enemyRange == 15 and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, 1251) end
        local run = enemyGeneration
        C_Timer.After(CHECK_INTERVAL, function() CheckEnemyDistances(run) end)
    end
end
function A.UpdateLevelDistance()
    local db = A.db
    generation = generation + 1
    local friendly, enemy = LevelChecks()
    if db.enabled and (friendly or enemy) then
        -- Range checks need the item's data loaded once.
        if ((friendly and db.playerLevelRange == 15) or (enemy and db.enemyLevelRange == 15))
            and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, RANGE_ITEM)
        end
        local run = generation
        C_Timer.After(CHECK_INTERVAL, function() CheckDistances(run) end)
    end
end

-- The level's text size: its own setting, or the subtitle's (automatic).
function A.LevelTextSize(subtitleSize, enemy)
    local size = enemy and A.db.enemyLevelSize or A.db.playerLevelSize
    if type(size) == "number" and size == size and size > 0 then return math.max(8, math.min(40, size)) end
    return subtitleSize
end

-- Opposite-faction players ---------------------------------------------------
-- Enemy = another player of the other faction (not you, not Neutral). Enemies
-- are untouched unless the Enemy tab is enabled.
A.defaults.enemyEnabled = false
A.defaults.enemyFlaggedStyle = "native"   -- flagged: "native" plates or "names" on native bars
A.defaults.enemyScope = "all"             -- not flagged: all/near/target/hidden
A.defaults.enemyRange = 3                 -- near: 3 = ~10 yd, 15 = 15 yd, 4 = ~28 yd
A.defaults.enemyColorMode = "faction"     -- blizzard/class/faction/custom
A.defaults.enemyShowLevel, A.defaults.enemyShowGuild, A.defaults.enemyShowTitle = false, false, false
A.defaults.enemyStranger, A.defaults.enemyStrangerStyle = false, "raceclass"
A.defaults.enemyFactionIcon, A.defaults.enemyPvpIcon = false, false
-- A mark around enemy names (Enemies tab). Font, opacity and emblem position
-- were tried in the 1.9.5 enemy lab; the emblem now always sits before the name.
A.defaults.enemyMark = "none"
local marks = {guillemets = {"\194\171 ", " \194\187"}, parens = {"(", ")"}}
function A.EnemyMark(name)
    local mark = marks[A.db.enemyMark]
    if not mark or not name then return name end
    return mark[1] .. name .. mark[2]
end
-- Class color for the faction emblem (flat silhouette, or tinted) and the level.
A.defaults.enemyFactionClassColor, A.defaults.enemyLevelClassColor = false, false
A.defaults.colors.enemyPlayer = {1, 0.45, 0.35}
A.defaults.colors.enemyPvp = {1, 0.3, 0.25}
-- 1.10: what enemies share with friendly players became their own settings
-- (Core.lua copies today's shared values across once). Level: side, size
-- (nil = automatic), color ("name", "class" or "custom"), and where it shows.
A.defaults.enemyLevelSide, A.defaults.enemyLevelColorMode = "right", "name"
A.defaults.enemyLevelScope, A.defaults.enemyLevelRange = "all", 3
A.defaults.colors.enemyLevel = {0.78, 0.78, 0.78}
A.defaults.enemyShowGuildRank = false
-- Icons: where the crossed swords go, and the icon size (nil = automatic).
A.defaults.enemySwordsPosition = "left"
A.defaults.colors.enemyBar = {1, 0.45, 0.35}
local factionColors = {Horde = {0.95, 0.3, 0.25}, Alliance = {0.35, 0.6, 1}}
A.factionColors = factionColors

local function RealEnemy(unit)
    local mine, theirs = Text(Read(UnitFactionGroup, "player")), Text(Read(UnitFactionGroup, unit))
    if mine and theirs then return theirs ~= mine and theirs ~= "Neutral" end
    return Read(UnitIsFriend, "player", unit) == false
end
function A.IsEnemyPlayer(unit)
    if Read(UnitIsPlayer, unit) ~= true or Read(UnitIsUnit, unit, "player") == true then return false end
    -- Test mode (session only): friendly players are drawn as enemies.
    return RealEnemy(unit) or A.enemyTest == true
end
function A.PlayerFlagged() return Read(UnitIsPVP, "player") == true end
-- The faction shown for an enemy: theirs, or (test mode) the other one.
local opposite = {Horde = "Alliance", Alliance = "Horde"}
function A.EnemyFaction(unit)
    local faction = Text(Read(UnitFactionGroup, unit))
    if A.enemyTest and not RealEnemy(unit) then
        return opposite[Text(Read(UnitFactionGroup, "player")) or ""] or "Horde"
    end
    return faction
end
-- Enemy test mode: not saved; off again after a reload.
function A.SetEnemyTest(preview)
    A.enemyTest = preview and true or nil
    if A.RequeuePlayers then A.RequeuePlayers() end
    if A.UpdateEnemyDistance then A.UpdateEnemyDistance() end
    if A.RefreshOptions then A.RefreshOptions() end
    print("Forever Names: enemy test " .. (A.enemyTest and "ON (friendly players shown as enemies)." or "off."))
    if A.enemyTest and not A.db.enemyEnabled then
        print("Forever Names: turn on \"Custom names for opposite-faction players\" on the Enemies tab to see them.")
    end
end
-- "native" (Blizzard's plate), "bars" (our name on Blizzard's bars),
-- "custom" (our label only) or "hidden" (no label).
function A.EnemyMode()
    local db = A.db
    if not db.enemyEnabled then return "native" end
    if A.PlayerFlagged() then return db.enemyFlaggedStyle == "names" and "bars" or "native" end
    return db.enemyScope == "hidden" and "hidden" or "custom"
end
-- Not flagged, "near"/"target" scope: is this enemy close enough (or selected)?
function A.EnemyNear(unit, previous)
    local db = A.db
    if A.PlayerFlagged() or (db.enemyScope ~= "near" and db.enemyScope ~= "target") then return true end
    if Read(UnitIsUnit, unit, "target") == true then return true end
    if db.enemyScope == "target" then return false end
    local ok, near
    if db.enemyRange == 15 then
        if not (C_Item and C_Item.IsItemInRange) then return true end
        ok, near = pcall(C_Item.IsItemInRange, 1251, unit)
    else
        if not CheckInteractDistance then return true end
        ok, near = pcall(CheckInteractDistance, unit, db.enemyRange == 4 and 4 or 3)
    end
    if ok and Public(near) and type(near) == "boolean" then return near end
    if previous == nil then return true end
    return previous
end
function A.FactionAtlas(unit)
    local faction = A.EnemyFaction(unit)
    if faction == "Horde" or faction == "Alliance" then
        return "UI-HUD-UnitFrame-Player-PVP-" .. faction .. "Icon", faction
    end
end

function A.EnemyLabel(unit, frame, record)
    local db = A.db
    local color = record and record.playerColor or {}
    if record then record.playerColor = color end
    local mode = db.enemyColorMode
    local faction = A.EnemyFaction(unit)
    local classColored = mode == "class" and ClassColor(unit, color)
    if mode == "custom" then
        local c = db.colors.enemyPlayer
        color[1], color[2], color[3] = c[1], c[2], c[3]
    elseif not classColored then
        local c = mode ~= "blizzard" and faction and factionColors[faction]
        if c then color[1], color[2], color[3] = c[1], c[2], c[3]
        else A.PlayerNameColor(unit, frame, color) end -- Blizzard's own (the native name color)
    end
    -- Rivals (Companion Journal): one lookup, only while one of its options or
    -- strangers need it.
    local people = A.People()
    local person = people and (people.Active() or db.enemyStranger) and people.Find(unit) or nil
    currentPerson[unit] = person
    if person then people.Seen(person) end
    currentStranger[unit] = db.enemyStranger and not person and A.StrangerLabel(unit, db.enemyStrangerStyle) or nil
    currentTitle[unit] = db.enemyShowTitle
    local subtitle, level, complete, levelColor = nil, nil, true, nil
    if db.enemyShowGuild then
        local ok, guild, rank = pcall(GetGuildInfo, unit)
        guild, rank = ok and Text(guild), ok and Text(rank)
        if guild then
            subtitle = (db.enemyShowGuildRank and rank) and (rank .. " of <" .. guild .. ">") or ("<" .. guild .. ">")
        else
            complete = false
        end
    end
    if db.enemyShowLevel then
        local value = Read(UnitEffectiveLevel or UnitLevel, unit)
        if type(value) == "number" then level = value > 0 and tostring(value) or "??" end
        if level and db.enemyLevelColorMode == "class" then
            levelColor = record and record.levelColor or {}
            if record then record.levelColor = levelColor end
            if not ClassColor(unit, levelColor) then levelColor = nil end
        elseif level and db.enemyLevelColorMode == "custom" then levelColor = db.colors.enemyLevel end
    end
    -- Icons: your Rival icon, the faction emblem, and crossed swords when
    -- their PvP flag is on. Each is its own toggle.
    local icons = record and record.enemyIcons or {}
    if record then record.enemyIcons = icons end
    for i = #icons, 1, -1 do icons[i] = nil end
    icons.person, icons.factionAtlas, icons.factionTint = nil, nil, nil
    if person and A.PersonIcon(person) then
        icons[#icons + 1], icons.person = "people", person
    end
    if db.enemyFactionIcon then
        local atlas = A.FactionAtlas(unit)
        if atlas then
            icons[#icons + 1], icons.factionAtlas = "faction", atlas
            if db.enemyFactionClassColor then
                local tint = record and record.factionTint or {}
                if record then record.factionTint = tint end
                if ClassColor(unit, tint) then icons.factionTint = tint end
            end
        end
    end
    if db.enemyPvpIcon and Read(UnitIsPVP, unit) == true then icons[#icons + 1] = "pvp" end
    -- Distance / target-only while you are not flagged.
    local near = A.EnemyNear(unit, record and record.enemyNear)
    if record then record.enemyNear = near end
    return color, subtitle, level, complete, levelColor, #icons > 0 and icons or nil, not near
end

-- Forever's UnitPVPName already includes the surname ("Sergeant Aldric
-- Stormwind"); use it as is. Only a titled short name ("Sergeant Aldric")
-- gets the full name inserted.
function A.PlayerDisplayName(unit, fullName, shortName)
    if currentStranger[unit] then return currentStranger[unit] end
    local person = currentPerson[unit]
    local display = person and A.PersonDisplayName(person)
    if display then return display end
    if not currentTitle[unit] or not fullName or not shortName then return fullName end
    local titled = Text(Read(UnitPVPName, unit))
    if not titled or titled == shortName or titled == fullName then return fullName end
    if titled:find(fullName, 1, true) then return titled end
    local first, last = titled:find(shortName, 1, true)
    if not first then return fullName end
    return titled:sub(1, first - 1) .. fullName .. titled:sub(last + 1)
end
