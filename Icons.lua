local _, A = ...
-- Relationship icons: small single-color glyphs next to friendly player names.
-- Every relationship is its own toggle (all off by default). Checks run only
-- when a player plate renders; roster/friend-list events refresh the visible
-- player plates once, coalesced, and are subscribed only while needed.
local GLYPH_PATH = "Interface\\AddOns\\ForeverNames\\Media\\Glyphs\\"
A.glyphs = {"heart", "star", "sparkle", "diamond", "dot", "ring", "crown", "shield", "person",
    "party", "flower", "moon", "sun", "leaf", "flag", "check", "note", "fire", "swords"}
function A.GlyphPath(name) return GLYPH_PATH .. (name or "dot") end

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Read(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok and Public(value) then return value end
end

-- Priority order: the first matches win when fewer icons are allowed.
A.relationships = {
    {key = "party", option = "iconsParty", label = "Group members", glyph = "party", color = {0.55, 0.8, 1}},
    {key = "friend", option = "iconsFriend", label = "Friends", glyph = "star", color = {1, 0.82, 0.2}},
    {key = "bnet", option = "iconsBnet", label = "Battle.net friends", glyph = "sparkle", color = {0.3, 0.75, 1}},
    {key = "guild", option = "iconsGuild", label = "Guild members", glyph = "flag", color = {0.25, 0.85, 0.4}},
}
local byKey = {}
for _, relation in ipairs(A.relationships) do
    byKey[relation.key] = relation
    A.defaults[relation.option] = true
    A.defaults.colors["icon_" .. relation.key] = relation.color
end
A.defaults.iconPosition, A.defaults.iconMax = "above", 2 -- iconSize: nil = name height

function A.InitIcons()
    local db = A.db
    db.iconGlyphs = type(db.iconGlyphs) == "table" and db.iconGlyphs or {}
    -- "custom" (default), "class", or "name" per relationship.
    db.iconColorModes = type(db.iconColorModes) == "table" and db.iconColorModes or {}
    for _, relation in ipairs(A.relationships) do
        if type(db.iconGlyphs[relation.key]) ~= "string" then db.iconGlyphs[relation.key] = relation.glyph end
    end
end
-- Relationship icons and the PvP swords (your people's icons come from
-- Companion Journal: A.PersonIcon).
function A.IconGlyph(key)
    if key == "pvp" then return "swords" end
    return A.db.iconGlyphs and A.db.iconGlyphs[key] or (byKey[key] and byKey[key].glyph)
end
function A.IconColor(key)
    if key == "pvp" then return A.db.colors.enemyPvp end
    return A.db.colors["icon_" .. key] or {1, 1, 1}
end
function A.IconColorMode(key)
    return A.db.iconColorModes and A.db.iconColorModes[key] or "custom"
end
-- Class colors for players only (NPC "classes" say nothing useful).
local classColors = {}
function A.UnitClassColor(unit)
    if Read(UnitIsPlayer, unit) ~= true then return nil end
    local ok, _, classFile = pcall(UnitClass, unit)
    if not ok or not Public(classFile) or type(classFile) ~= "string" then return nil end
    local cached = classColors[classFile]
    if cached == nil then
        local class = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        cached = class and {class.r, class.g, class.b} or false
        classColors[classFile] = cached
    end
    return cached or nil
end
-- The color an icon is drawn in on a plate: its own, the class, or the name's
-- current color (which already includes a custom name color).
local function Resolve(mode, own, state)
    if mode == "name" and state and state.color then return state.color end
    if mode == "class" and state then return A.UnitClassColor(state.unit) or state.color or own end
    return own
end
function A.ResolveIconColor(key, _, state)
    return Resolve(A.IconColorMode(key), A.IconColor(key), state)
end
-- Palette with the two follow-the-player choices, for a relationship icon.
function A.PickIconColor(key, anchor)
    local db = A.db
    local mode = A.IconColorMode(key)
    local original = A.IconColor(key)
    original = {original[1], original[2], original[3]}
    local function SetMode(value) db.iconColorModes[key] = value end
    A.PickColor(anchor, original[1], original[2], original[3],
        function(r, g, b) db.colors["icon_" .. key] = {r, g, b}; SetMode("custom"); A.Refresh() end,
        function() db.colors["icon_" .. key] = original; SetMode(mode); A.Refresh() end,
        {current = mode, set = function(value) SetMode(value); A.Refresh() end})
end

-- Friend lookups need a GUID; cache them until the friend lists change.
local friendCache, bnetCache = {}, {}
local function Friend(guid)
    local known = friendCache[guid]
    if known == nil then
        known = C_FriendList and C_FriendList.IsFriend and Read(C_FriendList.IsFriend, guid) == true or false
        friendCache[guid] = known
    end
    return known
end
local function BattleNet(guid)
    local known = bnetCache[guid]
    if known == nil then
        known = C_BattleNet and C_BattleNet.GetAccountInfoByGUID and Read(C_BattleNet.GetAccountInfoByGUID, guid) ~= nil or false
        bnetCache[guid] = known
    end
    return known
end
function A.IsFriendGUID(guid)
    return guid ~= nil and (Friend(guid) or BattleNet(guid))
end
local tests = {
    party = function(unit) return Read(UnitInParty, unit) == true or Read(UnitInRaid, unit) ~= nil end,
    guild = function(unit) return Read(UnitIsInMyGuild, unit) == true end,
    friend = function(_, guid) return guid ~= nil and Friend(guid) end,
    bnet = function(_, guid) return guid ~= nil and BattleNet(guid) end,
}

function A.AnyIconsEnabled()
    local db = A.db
    for _, relation in ipairs(A.relationships) do if db[relation.option] then return true end end
    return false
end

-- Returns the matching relationship keys (a table reused per unit), or nil.
function A.PlayerIcons(unit, record, person)
    local db = A.db
    -- Companion Journal's icon switch shows them at all; each person may have none.
    local personIcon = person and A.PersonIcon(person) ~= nil
    if not personIcon and not A.AnyIconsEnabled() then return nil end
    local list = record and record.icons or {}
    if record then record.icons = list end
    for i = #list, 1, -1 do list[i] = nil end
    -- Your own People icon always comes first.
    list.person = personIcon and person or nil
    if personIcon then list[1] = "people" end
    local guid = (db.iconsFriend or db.iconsBnet) and Read(UnitGUID, unit) or nil
    local limit = math.max(1, math.min(3, tonumber(db.iconMax) or 2))
    for _, relation in ipairs(A.relationships) do
        if #list >= limit then break end
        if db[relation.option] and tests[relation.key](unit, guid) then list[#list + 1] = relation.key end
    end
    return #list > 0 and list or nil
end

-- setting: nil = the friendly icon size, false = automatic, a number = that size
function A.IconSize(nameHeight, setting)
    local size = setting == nil and A.db.iconSize or setting
    if type(size) == "number" and size == size and size > 0 then return math.max(6, math.min(40, size)) end
    return nameHeight
end

-- Places icon textures in `pool` around `name` (and outside `level` when it
-- shares the side). Used by plates and the settings preview.
function A.LayoutIcons(pool, count, name, nameHeight, level, levelSide, levelGap, position, sizeSetting)
    local db = A.db
    local size = A.IconSize(nameHeight, sizeSetting)
    position = position or db.iconPosition
    for i = 1, count do
        local texture = pool[i]
        -- A person can have their own icon size (People > selected person).
        local own = texture.ownSize or size
        texture:SetSize(own, own)
        texture:ClearAllPoints()
        if position == "above" then
            local x = ((i - 1) - (count - 1) / 2) * (size + 2)
            texture:SetPoint("BOTTOM", name, "TOP", x, 2)
        elseif position == "right" then
            if i > 1 then texture:SetPoint("LEFT", pool[i - 1], "RIGHT", 2, 0)
            elseif level and levelSide == "right" then texture:SetPoint("LEFT", level, "RIGHT", 3 + (levelGap or 0), 0)
            else texture:SetPoint("LEFT", name, "RIGHT", 3, 0) end
        else
            if i > 1 then texture:SetPoint("RIGHT", pool[i - 1], "LEFT", -2, 0)
            elseif level and levelSide == "left" then texture:SetPoint("RIGHT", level, "LEFT", -3 - (levelGap or 0), 0)
            else texture:SetPoint("RIGHT", name, "LEFT", -3, 0) end
        end
    end
end

-- Shows `icons` on a plate overlay; textures are created on first use.
function A.ApplyPlateIcons(state, icons, nameHeight)
    local overlay = state.overlay
    local count = icons and #icons or 0
    local pool = overlay.icons
    if count == 0 and not pool then return end
    if not pool then pool = {}; overlay.icons = pool end
    for i = 1, math.max(count, #pool) do
        local texture = pool[i]
        if i <= count then
            if not texture then
                texture = overlay:CreateTexture(nil, "OVERLAY")
                texture:SetAlpha(state.nameAlpha or 0)
                pool[i] = texture
            end
            local key = icons[i]
            local mask = texture.flatMask
            if key == "faction" then
                local atlas = icons.factionAtlas
                local tint = icons.factionTint
                local hasAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
                if tint and hasAtlas and texture.AddMaskTexture and overlay.CreateMaskTexture then
                    -- Flat: a solid class color cut to the emblem's outline.
                    if not mask then
                        mask = overlay:CreateMaskTexture()
                        mask:SetAllPoints(texture)
                        texture.flatMask = mask
                    end
                    if texture.path ~= "flat:" .. atlas then
                        texture.path = "flat:" .. atlas
                        mask:SetAtlas(atlas)
                        texture:SetTexCoord(0, 1, 0, 1)
                        if not texture.masked then texture:AddMaskTexture(mask); texture.masked = true end
                    end
                    if texture.SetDesaturated then texture:SetDesaturated(false) end
                    texture:SetColorTexture(tint[1], tint[2], tint[3])
                    texture:SetVertexColor(1, 1, 1)
                else
                    if texture.masked then texture:RemoveMaskTexture(mask); texture.masked = nil end
                    -- Blizzard's faction emblem, in its own colors.
                    if texture.path ~= atlas then
                        texture.path = atlas
                        if hasAtlas then
                            texture:SetAtlas(atlas)
                        else
                            texture:SetTexture(atlas:find("Horde") and "Interface\\TargetingFrame\\UI-PVP-Horde" or "Interface\\TargetingFrame\\UI-PVP-Alliance")
                            texture:SetTexCoord(0.05, 0.6, 0.05, 0.6)
                        end
                    end
                    -- Without mask support: the emblem made gray, then tinted.
                    if texture.SetDesaturated then texture:SetDesaturated(tint ~= nil) end
                    if tint then texture:SetVertexColor(tint[1], tint[2], tint[3]) else texture:SetVertexColor(1, 1, 1) end
                end
            else
                if texture.masked then texture:RemoveMaskTexture(mask); texture.masked = nil end
                if texture.SetDesaturated then texture:SetDesaturated(false) end
                local path, tint, own
                if key == "people" then
                    local personPath, color, mode, size = A.PersonIcon(icons.person)
                    path, tint, own = personPath or A.GlyphPath("dot"), Resolve(mode, color or {1, 1, 1}, state), tonumber(size)
                else
                    path, tint = A.GlyphPath(A.IconGlyph(key)), A.ResolveIconColor(key, nil, state)
                end
                if texture.path ~= path then texture.path = path; texture:SetTexture(path); texture:SetTexCoord(0, 1, 0, 1) end
                texture:SetVertexColor(unpack(tint))
                -- A person can have their own icon size (Companion Journal).
                texture.ownSize = own and math.max(6, math.min(48, own)) or nil
            end
            if key == "faction" then texture.ownSize = nil end
            texture:Show()
        elseif texture then
            texture:Hide()
        end
    end
    local level = overlay.level
    local levelShown = level and overlay.levelHolder and overlay.levelHolder.wantShown
    local style = overlay.appliedStyle
    local enemy = state.sizeKey == "enemyPlayer"
    local levelArg, side, gap = levelShown and level or nil, enemy and A.db.enemyLevelSide or A.db.playerLevelSide, style and style.levelGap
    -- Each icon has a side: your people's icon and the faction emblem may have
    -- their own (Before / After), the rest follow the Icons page. Each side is
    -- laid out as its own row, in list order.
    local db = A.db
    local rows = overlay.iconRows or {}
    overlay.iconRows = rows
    for _, position in ipairs({"left", "right", "above"}) do
        local row = rows[position] or {}
        rows[position] = row
        for i = #row, 1, -1 do row[i] = nil end
    end
    for i = 1, count do
        local key = icons[i]
        local own = key == "people" and select(5, A.PersonIcon(icons.person)) or key == "faction" and "left" or nil
        local position = (own == "left" or own == "right") and own or (enemy and db.enemySwordsPosition or db.iconPosition)
        local row = rows[position] or rows.left
        row[#row + 1] = pool[i]
    end
    for position, row in pairs(rows) do
        if #row > 0 then
            A.LayoutIcons(row, #row, state.name, nameHeight, levelArg, side, gap, position, enemy and (db.enemyIconSize or false) or nil)
        end
    end
end

-- The character a Battle.net friend is playing right now, if any.
local function FriendGUID(index)
    local info = type(index) == "number" and C_BattleNet and C_BattleNet.GetFriendAccountInfo and Read(C_BattleNet.GetFriendAccountInfo, index)
    local game = type(info) == "table" and info.gameAccountInfo
    local guid = type(game) == "table" and game.playerGuid
    return type(guid) == "string" and Public(guid) and guid or nil
end

-- Roster and friend-list changes: refresh visible player plates once.
local events = CreateFrame("Frame")
local pending = false
events:SetScript("OnEvent", function(_, event, index)
    if event == "FRIENDLIST_UPDATE" then friendCache = {} end
    if event == "BN_FRIEND_INFO_CHANGED" then
        -- A friend's game presence arrives a moment after they log in: forget
        -- a "not a friend" answer given for their character before it did.
        -- Other presence changes (zones, status) refresh nothing.
        local guid = FriendGUID(index)
        if index ~= nil and not (guid and bnetCache[guid] == false) then return end
        if guid then bnetCache[guid] = nil else bnetCache = {} end
    elseif event:match("^BN_") then
        bnetCache = {}
    end
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        if A.RequeuePlayers then A.RequeuePlayers() end
    end)
end)
function A.UpdateIconEvents()
    local db = A.db
    -- Immersion's "who counts as known" needs the same updates.
    local unknown = db.playerUnknownMode == "stranger" or db.playerUnknownMode == "hide"
    local wanted = {
        GROUP_ROSTER_UPDATE = db.iconsParty or (unknown and db.knownGroup),
        FRIENDLIST_UPDATE = db.iconsFriend or (unknown and db.knownFriends),
        BN_FRIEND_LIST_SIZE_CHANGED = db.iconsBnet or (unknown and db.knownFriends),
        BN_FRIEND_INFO_CHANGED = db.iconsBnet or (unknown and db.knownFriends),
        BN_CONNECTED = db.iconsBnet or (unknown and db.knownFriends),
        PLAYER_GUILD_UPDATE = db.iconsGuild or (unknown and db.knownGuild),
    }
    for event, on in pairs(wanted) do
        if on and db.enabled then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
end
