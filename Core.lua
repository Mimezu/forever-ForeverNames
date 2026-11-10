local addonName, A = ...
A.version = "1.17.0"
A.defaults = {
    enabled = true,
    hideNativeNames = true, includeOppositeFaction = true, useOppositeFactionColor = true,
    hideNativeHostileNames = true,
    hideNativePlayerNames = true,
    nativeSmoothScaling = true,
    targetOnlyVitals = true,
    showFriendlyPlayers = true,
    targetHealthBar = true, targetHealthStyle = "minimal",
    targetHealthLevel = false,
    targetHealthWidth = 82, targetHealthHeight = 4, targetHealthGap = 3,
    targetHealthOpacity = 1, targetHealthNameColor = true,
    targetHealthColorMode = "name", -- "name", "class" or "custom" (1.10; the checkbox above is kept in step)
    targetHealthR = 0.25, targetHealthG = 0.85, targetHealthB = 0.4,
    opacity = 1, subtitleOpacity = 1, targetOpacity = 1, otherOpacity = 1, combatOpacity = 1,
    customizeGlobalFade = false,
    -- Player label extras: all off, so the default look is unchanged.
    playerShowLevel = false, playerShowGuild = false, playerShowGuildRank = false,
    playerShowTitle = false, playerColorMode = "blizzard", playerLevelColorMode = "name",
    playerLevelStyle = "plain", playerLevelSide = "right", -- playerLevelSize: nil = automatic
    -- Level shown for "all", "near" (range 3 = ~10 yd, 15 = 15 yd item check, 4 = ~28 yd)
    -- or "target" (the selected player only).
    playerLevelScope = "all", playerLevelRange = 3,
    -- Immersion: how players you don't know are labeled ("name" = unchanged).
    playerUnknownMode = "name", playerStrangerStyle = "raceclass",
    knownGroup = true, knownGuild = true, knownFriends = true,
    optionsPage = 1,
    colors = { vendor = {0.35, 0.9, 0.55}, quest = {1, 0.82, 0.2}, interactive = {0.65, 0.85, 1}, oppositeFaction = {1, 0.5, 0.15}, friendlyPlayer = {0.55, 0.8, 1}, playerLevel = {0.78, 0.78, 0.78} },
}
local active, db, scanTexture, lookupTexture = {}, nil, nil, nil
local QueueUnit
local function Now() return GetTime and GetTime() or 0 end
local cursorRoles = {}
local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Read(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok and Public(value) then return value end
end
local function Clean(text)
    if type(text) ~= "string" or not Public(text) then return nil end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end
function A.NPCID(unit)
    local guid = Read(UnitGUID, unit)
    if type(guid) ~= "string" then return nil end
    return guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
end
local function IsFriendly(unit)
    return Read(UnitIsFriend, "player", unit) == true or (Read(UnitReaction, unit, "player") or 0) >= 4
end
function A.IsNPC(unit)
    if not Read(UnitExists, unit) or Read(UnitIsPlayer, unit) or Read(UnitPlayerControlled, unit) then return false end
    if Read(UnitIsDeadOrGhost, unit) or Read(UnitCanAttack, "player", unit) ~= false then return false end
    return IsFriendly(unit) or (db and db.includeOppositeFaction == true) or false
end
local function BuildCursorMap()
    local root = CreateFrame("Frame")
    root:Hide()
    scanTexture, lookupTexture = root:CreateTexture(), root:CreateTexture()
    local groups = {
        vendor = {"Buy", "RepairNPC", "Repair"},
        quest = {"Quest", "QuestRepeatable", "QuestTurnIn", "QuestLegendary", "QuestLegendaryTurnIn", "QuestImportant", "QuestImportantTurnIn", "QuestCampaign", "QuestCampaignTurnIn", "CampaignQuest", "CampaignQuestTurnIn", "QuestMeta", "QuestMetaTurnIn", "QuestRecurring", "QuestRecurringTurnIn"},
        interactive = {"Speak", "Interact", "Taxi", "Trainer", "Innkeeper", "Banker", "StableMaster"},
    }
    for role, names in pairs(groups) do
        for _, name in ipairs(names) do
            local path = "Interface\\CURSOR\\" .. name
            lookupTexture:SetTexture(path)
            local id = lookupTexture:GetTexture()
            if id and id ~= 0 then cursorRoles[id] = role end
            cursorRoles[path:lower()] = role
        end
    end
end
function A.CursorRole(unit)
    if not scanTexture or not SetUnitCursorTexture then return nil end
    scanTexture:SetTexture(nil)
    local ok, hasCursor = pcall(SetUnitCursorTexture, scanTexture, unit, 0, true, false)
    if not ok or not Public(hasCursor) or not hasCursor then return nil end
    local texture, atlas = Read(scanTexture.GetTexture, scanTexture), Read(scanTexture.GetAtlas, scanTexture)
    local role = cursorRoles[texture]
    local label = type(atlas) == "string" and atlas:lower() or type(texture) == "string" and texture:lower() or ""
    role = role or cursorRoles[label]
    if label:find("quest", 1, true) then role = "quest"
    elseif label:find("buy", 1, true) or label:find("repair", 1, true) then role = "vendor" end
    return role, texture, atlas
end
local titleScanner
local titleCache = {}
local titleOrder, titleNext, titleCount = {}, 1, 0
local function ClearTitleCache()
    titleCache, titleOrder, titleNext, titleCount = {}, {}, 1, 0
end
local function LineField(line, key)
    if not line then return nil end
    if line[key] ~= nil and Public(line[key]) then return line[key] end
    -- Some client versions retain tooltip fields in the argument array.
    for _, arg in ipairs(line.args or {}) do
        if Public(arg.field) and arg.field == key then
            local value = arg.stringVal or arg.intVal or arg.floatVal
            if Public(value) then return value end
        end
    end
end
local function IsLevelLine(line)
    if not line then return false end
    local kind = LineField(line, "type")
    local types = Enum and Enum.TooltipDataLineType or {}
    if kind ~= nil and (kind == types.UnitLevel or kind == types.UnitType) then return true end
    -- Forever can return ordinary (type 0) lines for level and subtitle.
    local text = Clean(LineField(line, "leftText"))
    local level = LEVEL or "Level"
    return text and text:sub(1, #level) == level and text:sub(#level + 1):match("^%s+[%d%?]") ~= nil
end
local function Subtitle(lines)
    local second, third = lines and lines[2], lines and lines[3]
    if not second or IsLevelLine(second) then return nil end
    local kind = LineField(second, "type")
    if kind ~= nil and kind ~= 0 then return nil end
    local text = Clean(LineField(second, "leftText"))
    if not text or text == "" then return nil end
    if text:match("^<.+>$") then return text end
    -- Require the level line immediately after the subtitle, so faction and
    -- quest text beneath the level cannot be mistaken for a job/title.
    if IsLevelLine(third) then return "<" .. text .. ">" end
end
function A.Title(unit)
    local data = Read(C_TooltipInfo and C_TooltipInfo.GetUnit, unit)
    local title = type(data) == "table" and Subtitle(data.lines)
    if title then return title, true end
    -- A complete structured level line already proves there is no subtitle.
    -- Avoid rendering a hidden tooltip just to rediscover that absence.
    if type(data) == "table" and data.lines and IsLevelLine(data.lines[2]) then return nil, true end
    -- The legacy renderer is available even when GetUnit has no structured
    -- tooltip data for nameplate tokens. Never modify the visible GameTooltip.
    if not titleScanner then
        titleScanner = CreateFrame("GameTooltip", "ForeverNamesTitleScanner", UIParent, "GameTooltipTemplate")
        titleScanner:Hide()
    end
    titleScanner:SetOwner(UIParent, "ANCHOR_NONE")
    titleScanner:ClearLines()
    local ok = pcall(titleScanner.SetUnit, titleScanner, unit)
    local lines = {}
    if ok then
        for i = 1, math.min(titleScanner:NumLines(), 4) do
            local text = _G["ForeverNamesTitleScannerTextLeft" .. i]
            lines[i] = {leftText = text and Read(text.GetText, text)}
        end
    end
    titleScanner:Hide()
    local subtitle = Subtitle(lines)
    return subtitle, subtitle ~= nil or IsLevelLine(lines[2]) == true
end
local function CachedTitle(unit)
    local guid = Read(UnitGUID, unit)
    local now = Now()
    -- Cache by identity, not recycled nameplate token. Keep a bounded session
    -- cache across departures so walking back into range does not rescan titles.
    if type(guid) ~= "string" then return A.Title(unit) end
    local cached = titleCache[guid]
    if cached and now < cached.expires then return cached.title, cached.complete end
    local title, complete = A.Title(unit)
    local misses = cached and cached.misses or 0
    if not cached then
        if titleCount == 256 then titleCache[titleOrder[titleNext]] = nil
        else titleCount = titleCount + 1 end
        titleOrder[titleNext] = guid
        titleNext = titleNext % 256 + 1
    end
    titleCache[guid] = {title = title, complete = complete, misses = misses + 1,
        expires = now + ((title or complete) and 300 or (misses < 2 and 1 or 30))}
    return title, complete
end
function A.Classify(unit)
    if not A.IsNPC(unit) then return nil end
    local id = A.NPCID(unit)
    local override = id and db.overrides[id]
    if override then return override ~= "hide" and override or nil end
    local role = A.CursorRole(unit)
    local learned = id and db.learned[id]
    -- Only the live cursor proves a quest is available now. A learned quest
    -- role would keep an NPC quest-colored after its quests are finished.
    if role == "quest" then return role end
    if role == "vendor" then return role end
    if learned and learned ~= "quest" then return learned end
    if role then return role end
    if Read(UnitIsInteractable, unit) then return "interactive" end
    -- Opposite-faction trainers may expose no service cursor to this player.
    -- Use their actual service subtitle as a narrow fallback, never their name.
    if not IsFriendly(unit) then
        local title = CachedTitle(unit)
        if title then
            title = title:lower():gsub("^<", ""):gsub(">$", "")
            if title == "trainer" or title:match(" trainer$") or title == "innkeeper"
                or title == "banker" or title == "flight master" or title == "stable master" then
                return "interactive"
            elseif title == "vendor" or title:match(" vendor$") or title == "merchant"
                or title:match(" merchant$") or title == "general goods" then
                return "vendor"
            end
        end
    end
end
local function Restore(frame)
    if A.RestorePlate then A.RestorePlate(frame) end
end
local function IsWorldPlateToken(unit)
    return Public(unit) and type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end
local function UpdatePlate(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if active[unit] then active[unit].plate = plate end
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local frame = plate.UnitFrame
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if A.nativePlateTest or not db.enabled then
        Restore(frame)
        return true
    end
    -- Opposite-faction players (Enemy tab; untouched while it is off).
    -- Checked first: the Enemy test mode draws friendly players as enemies.
    if db.enemyEnabled and A.IsEnemyPlayer and A.IsEnemyPlayer(unit) then
        local mode = A.EnemyMode()
        -- Where the game hides their name from addons, Blizzard's plate stays.
        if mode == "native" or Read(UnitName, unit) == nil then Restore(frame); return true end
        local color, subtitle, level, complete, levelColor, icons, hidden = A.EnemyLabel(unit, frame, active[unit])
        local shown = mode ~= "hidden" and not hidden
        local rendered = A.RenderPlate(plate, frame, unit, shown and "enemyPlayer" or nil, color, subtitle, "enemyPlayer",
            level, levelColor, icons, mode == "bars")
        if rendered == false then return true end
        local state = A.RenderStates[frame]
        if state then state.enemyShown = not hidden end
        return rendered and Read(UnitName, unit) ~= nil and complete
    end
    if db.showFriendlyPlayers and Read(UnitIsPlayer, unit) == true
        and Read(UnitIsFriend, "player", unit) == true
        and Read(UnitCanAttack, "player", unit) == false
        and Read(UnitIsUnit, unit, "player") == false then
        -- Friendly players use the same pooled overlay/font path, without NPC
        -- classification, cursor probes, or tooltip scans (Players.lua).
        local color, subtitle, level, complete, levelColor, icons, hidden = A.PlayerLabel(unit, frame, active[unit])
        -- A hidden unknown player keeps the owned (empty) plate: no label at all.
        local rendered = A.RenderPlate(plate, frame, unit, not hidden and "friendlyPlayer" or nil, color, subtitle, "friendlyPlayer", level, levelColor, icons)
        if rendered == false then return true end
        if A.perf then A.perf.players = A.perf.players + 1 end
        return rendered and Read(UnitName, unit) ~= nil and complete
    end
    if not A.IsNPC(unit) then
        Restore(frame)
        if A.OnNativeTargetPlateReady then A.OnNativeTargetPlateReady(plate, frame, unit) end
        return true
    end
    local role = A.Classify(unit)
    local id = A.NPCID(unit)
    -- NPCs in your People list (only while a People option is on).
    local person, npcIcons
    if A.NPCPerson then person, npcIcons = A.NPCPerson(unit, active[unit]) end
    -- Do not hide unrelated unfriendly NPCs just because they are temporarily
    -- unattackable. Only identified services, explicit overrides, or People qualify.
    if not IsFriendly(unit) and not role and not person and not (id and db.overrides[id] == "hide") then
        Restore(frame)
        return true
    end
    local colorKey = role and (db.useOppositeFactionColor and not IsFriendly(unit) and "oppositeFaction" or role)
    local color = colorKey and db.colors[colorKey]
    -- A People NPC stays labeled even when it has no service role.
    if person and not role then color = db.colors.interactive end
    local title, titleComplete
    if role then title, titleComplete = CachedTitle(unit) end
    local rendered = A.RenderPlate(plate, frame, unit, role or (person and "person") or nil, color, title, colorKey, nil, nil, npcIcons)
    if rendered == false then return true end -- unsupported layout: do not mutate it
    if not rendered then return nil end
    if person and not role then return Read(UnitName, unit) ~= nil end
    -- Retry incomplete data a few times, then wait for an actual game event.
    return role ~= nil and Read(UnitName, unit) ~= nil and (title ~= nil or titleComplete)
end
function A.Update(unit)
    if not db or not IsWorldPlateToken(unit) then return end
    local complete = UpdatePlate(unit)
    -- Quest enemies' "!" (QuestMarks.lua): Blizzard's plates, our own layer.
    if A.UpdateQuestMark and active[unit] then A.UpdateQuestMark(unit, active[unit].plate) end
    return complete
end
function A.Refresh()
    -- Full refresh is reserved for explicit settings/override changes.
    ClearTitleCache()
    for unit in pairs(active) do A.Update(unit) end
    if A.RefreshVitals then A.RefreshVitals() end
    if A.RefreshTargetHealth then A.RefreshTargetHealth() end
    if A.RefreshOptions then A.RefreshOptions() end
    -- Companion Journal's icons beside Blizzard's names follow our settings.
    local people = A.People and A.People()
    if people and people.RefreshPlates then people.RefreshPlates() end
end
local queue, head, tail, scheduled = {}, 1, 0, false
local function Drain()
    scheduled = false
    local count = 0
    while head <= tail and count < 2 do
        local item = queue[head]
        queue[head] = nil
        head = head + 1
        count = count + 1
        local state = active[item.unit]
        if state == item.state then
            state.queued = false
            if db and db.enabled then
                local started = A.perf and debugprofilestop and debugprofilestop()
                local complete = A.Update(item.unit)
                if A.perf then
                    A.perf.updates = A.perf.updates + 1
                    local elapsed = started and (debugprofilestop() - started) or 0
                    A.perf.totalMs = A.perf.totalMs + elapsed
                    A.perf.maxMs = math.max(A.perf.maxMs, elapsed)
                end
                if not complete and state.retries < 3 then
                    state.retries = state.retries + 1
                    local generation = state.generation
                    C_Timer.After(state.retries * 0.5, function()
                        if active[item.unit] == state and state.generation == generation then
                            QueueUnit(item.unit, false)
                        end
                    end)
                end
            end
        end
    end
    if head > tail then queue, head, tail = {}, 1, 0
    else scheduled = true; C_Timer.After(0, Drain) end
end
QueueUnit = function(unit, fresh)
    local state = active[unit]
    if not state then return end
    if fresh then
        state.retries = 0
        state.generation = state.generation + 1
    end
    if state.queued then return end
    state.queued = true
    tail = tail + 1
    queue[tail] = {unit = unit, state = state}
    if not scheduled then scheduled = true; C_Timer.After(0, Drain) end
end
local function TrackPlate(unit, initialized)
    if not IsWorldPlateToken(unit) then return end
    local state = active[unit]
    local fresh = not state
    if fresh then
        if A.perf then A.perf.added = A.perf.added + 1 end
        state = {retries = 0, generation = 0}
        active[unit] = state
    end
    -- Suppress the native visuals before the first paint, without doing any
    -- cursor/tooltip classification or constructing font strings here. The
    -- driver post-hook retries this if the unit event preceded frame creation.
    if (initialized or not A.nativeArrivalHook) and (initialized or not state.primed)
        and db and db.enabled and not A.nativePlateTest and A.PrimePlate then
        local friendlyPlayer = db.showFriendlyPlayers and Read(UnitIsPlayer, unit) == true
            and Read(UnitIsFriend, "player", unit) == true and Read(UnitCanAttack, "player", unit) == false
            and Read(UnitIsUnit, unit, "player") == false
        local enemyMode = db.enemyEnabled and A.IsEnemyPlayer and A.IsEnemyPlayer(unit)
            and Read(UnitName, unit) ~= nil and A.EnemyMode()
        local enemyLabel = enemyMode == "custom" or enemyMode == "hidden"
        if friendlyPlayer or enemyLabel or (A.IsNPC(unit) and IsFriendly(unit)) then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if plate and not (plate.IsForbidden and plate:IsForbidden()) and plate.UnitFrame
                and Public(plate.UnitFrame.unit) and plate.UnitFrame.unit == unit then
                if A.PrimePlate(plate.UnitFrame, unit) then state.plate, state.primed = plate, true end
            end
        end
    end
    if fresh then QueueUnit(unit, true) end
end
local function ScheduleAll()
    for unit in pairs(active) do QueueUnit(unit, true) end
end
-- Units with a tracked world nameplate (for short, bounded scans).
function A.EachTrackedUnit(callback)
    for unit in pairs(active) do callback(unit) end
end
-- Relationship changes (roster, friend lists) affect only player plates.
function A.RequeueUnit(unit)
    if active[unit] then QueueUnit(unit, true) end
end
function A.RequeuePlayers()
    for unit in pairs(active) do
        if Read(UnitIsPlayer, unit) == true then QueueUnit(unit, true) end
    end
end
-- Quest progress (every quest kill) changes only NPC quest markers. Coalesce a
-- burst into one pass, and leave friendly-player plates alone.
local questRefreshQueued = false
local function ScheduleQuestRefresh()
    if questRefreshQueued then return end
    questRefreshQueued = true
    C_Timer.After(0.5, function()
        questRefreshQueued = false
        for unit in pairs(active) do
            if Read(UnitIsPlayer, unit) ~= true then QueueUnit(unit, true) end
        end
    end)
end
local RefreshOpacity
-- Fade every label out and back in (the hide-everything key, HideAll.lua).
function A.FadeLabels(hidden)
    A.labelsHidden = hidden and true or nil
    RefreshOpacity()
end
function RefreshOpacity()
    for _, record in pairs(active) do
        local plate = record.plate
        if plate and not (plate.IsForbidden and plate:IsForbidden()) then
            local frame = plate.UnitFrame
            local state = frame and A.RenderStates[frame]
            if state then A.NativeOpacity(state) end
        end
    end
end
local playerNameCVars = {UnitNameFriendlyPlayerName = true, UnitNameEnemyPlayerName = true,
    UnitNameFriendlyPetName = true, UnitNameFriendlyMinionName = true, UnitNameFriendlyGuardianName = true}
-- "Hostle" is Blizzard's actual CVar spelling, also used by its NPC-name dropdown.
local cvars = {nameplateShowFriendlyNpcs = "1", nameplateShowFriends = "1", nameplateShowEnemies = "1", UnitNameNPC = "0", UnitNameInteractiveNPC = "0", UnitNameFriendlySpecialNPCName = "0", UnitNameHostleNPC = "0",
    UnitNameFriendlyPlayerName = "0", UnitNameEnemyPlayerName = "0",
    UnitNameFriendlyPetName = "0", UnitNameFriendlyMinionName = "0", UnitNameFriendlyGuardianName = "0"}
function A.ApplyCVars()
    if InCombatLockdown() then A.pendingCVars = true; return end
    A.pendingCVars = nil
    -- Everything hidden (HideAll.lua): it puts your values back, then calls this.
    if A.AllNamesHidden and A.AllNamesHidden() then return end
    db.previousCVars = db.previousCVars or {}
    for name, value in pairs(cvars) do
        local current = GetCVar(name)
        local manage
        if name == "nameplateShowFriendlyNpcs" then manage = true
        elseif name == "nameplateShowFriends" then manage = db.showFriendlyPlayers or db.targetHealthBar
        elseif name == "nameplateShowEnemies" then manage = db.enemyEnabled
        -- Enemy player names: never managed. Blizzard's plate shows an enemy
        -- name only if UnitShouldDisplayName allows it, which follows this CVar;
        -- turning it off blanked Blizzard's enemy plates (flagged mode, locked
        -- plates). Our labels hide the plate's own name region instead. A value
        -- recorded by 1.9.0-1.9.12 is restored here.
        elseif name == "UnitNameEnemyPlayerName" then manage = false
        elseif playerNameCVars[name] then manage = db.hideNativePlayerNames
        elseif name == "UnitNameHostleNPC" then manage = db.hideNativeHostileNames
        else manage = db.hideNativeNames end
        if db.enabled and manage then
            if db.previousCVars[name] == nil then db.previousCVars[name] = current end
            if current ~= nil and current ~= value then SetCVar(name, value) end
        elseif db.previousCVars[name] ~= nil then
            -- Do not overwrite a setting the player changed separately.
            if current == value then SetCVar(name, db.previousCVars[name]) end
            db.previousCVars[name] = nil
        end
    end
    -- You chose to show enemy names (key or checkbox): enemy players' names
    -- too, so every enemy reads from afar. Only on that choice, so a game
    -- setting made elsewhere is kept otherwise. Never zeroed when hidden
    -- (that blanks Blizzard's enemy plates).
    if A.enemyPlayerNamesWanted then
        A.enemyPlayerNamesWanted = nil
        if db.enabled and not db.hideNativeHostileNames and GetCVar("UnitNameEnemyPlayerName") == "0" then
            SetCVar("UnitNameEnemyPlayerName", "1")
        end
    end
    A.ApplyFadeCVars()
end
local function Learn(role)
    if not A.IsNPC("npc") then return end
    local id = A.NPCID("npc")
    if not id then return end
    -- Quest availability is read live from the cursor; remember a quest NPC
    -- only as someone to talk to. A vendor role outranks interaction.
    if role == "quest" then role = "interactive" end
    local old = db.learned[id]
    if not old or old == "quest" or role == "vendor" then db.learned[id] = role end
    ScheduleAll()
end
local lastTargetUnit -- the plate that was your target at the last target change
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= addonName then return end
        ForeverNamesDB = type(ForeverNamesDB) == "table" and ForeverNamesDB or {}
        db = ForeverNamesDB
        -- Left behind by the 1.16.0 click setting and the 1.16.1 probe.
        db.plateClicks, db.clickProbe, db.clickProbeInsets = nil, nil, nil
        db.optionsLayout = nil -- the A | B window switch of 1.15.0
        for key, value in pairs(A.defaults) do
            if key ~= "colors" and db[key] == nil then db[key] = value end
        end
        db.colors = db.colors or {}
        for key, value in pairs(A.defaults.colors) do
            if not db.colors[key] then db.colors[key] = {unpack(value)} end
        end
        -- 1.10: enemies get their own level, icon and bar settings. They start
        -- at what you had (the friendly values they used to share), once.
        if not db.enemySplit then
            db.enemySplit = true
            db.enemyLevelSide = db.playerLevelSide
            db.enemyLevelSize = db.playerLevelSize
            db.enemyLevelRange = db.playerLevelRange
            db.enemyLevelColorMode = db.enemyLevelClassColor and "class" or (db.playerLevelColorMode == "custom" and "custom" or "name")
            if db.colors.playerLevel then db.colors.enemyLevel = {unpack(db.colors.playerLevel)} end
            db.enemySwordsPosition = db.iconPosition
            db.enemyIconSize = db.iconSize
            db.targetHealthColorMode = db.targetHealthNameColor and "name" or "custom"
        end
        db.overrides, db.learned = db.overrides or {}, db.learned or {}
        A.db = db
        A.InitFading()
        if A.InitIcons then A.InitIcons() end
        BuildCursorMap()
        function A.UpdatePlayerEvents()
            if db.playerShowLevel or (db.enemyEnabled and db.enemyShowLevel) then events:RegisterEvent("UNIT_LEVEL") else events:UnregisterEvent("UNIT_LEVEL") end
            if A.UpdateEnemyDistance then A.UpdateEnemyDistance() end
            if A.UpdateIconEvents then A.UpdateIconEvents() end
            if A.UpdateWoundedEvents then A.UpdateWoundedEvents() end
            if A.UpdateLevelDistance then A.UpdateLevelDistance() end
        end
        A.UpdatePlayerEvents()
        for _, name in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CVAR_UPDATE", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED", "QUEST_LOG_UPDATE", "UNIT_FACTION", "UNIT_NAME_UPDATE", "MERCHANT_SHOW", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE"}) do events:RegisterEvent(name) end
    elseif event == "PLAYER_LOGIN" then
        -- Logged out with everything hidden: your values come back first.
        if A.RestoreHiddenNames then A.RestoreHiddenNames() end
        A.ApplyCVars()
        if NamePlateDriverFrame and NamePlateDriverFrame.OnNamePlateAdded then
            A.nativeArrivalHook = true
            hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit) TrackPlate(unit, true) end)
        end
        for _, plate in pairs(C_NamePlate.GetNamePlates()) do
            if not (plate.IsForbidden and plate:IsForbidden()) then
                local unit = plate.unitToken or plate.namePlateUnitToken
                if IsWorldPlateToken(unit) then TrackPlate(unit, true) end
            end
        end
        A.CreateOptions()
        -- Companion Journal (installed): changes to your people redraw our labels.
        local people = A.People and A.People()
        if people and people.Subscribe then people.Subscribe(function() if db.enabled then A.Refresh() end end) end
        ScheduleAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if db.enabled then
            A.ApplyCVars()
            ScheduleAll()
        end
    elseif event == "CVAR_UPDATE" then
        -- Do not fight the client's or another addon's CVar changes.
        -- Preferences apply on login/world entry and explicit user changes.
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then TrackPlate(arg)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if not IsWorldPlateToken(arg) then return end
        if A.perf then A.perf.removed = A.perf.removed + 1 end
        local old = active[arg]
        active[arg] = nil
        local plate = old and old.plate
        if A.HideQuestMark then A.HideQuestMark(plate) end
        if plate and not (plate.IsForbidden and plate:IsForbidden()) then
            local frame = plate.UnitFrame
            local state = frame and A.RenderStates[frame]
            if (state and state.unit == arg) or (A.IsPrimedPlate and A.IsPrimedPlate(frame, arg)) then Restore(frame) end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if A.pendingCVars then A.ApplyCVars(); A.Refresh() end
        RefreshOpacity()
        ScheduleAll() -- also retry native frame changes deferred during combat
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_TARGET_CHANGED" then
        RefreshOpacity()
        -- The inline level yields to the selected player's level pill.
        -- A wounded bar also yields to the selected player's own health bar.
        -- Nearby-only levels always show on the selected player.
        if event == "PLAYER_TARGET_CHANGED" and ((db.targetHealthBar
            and ((db.playerShowLevel and db.targetHealthLevel) or (A.WoundedEnabled and A.WoundedEnabled())))
            or (db.playerShowLevel and A.LevelScope and A.LevelScope() ~= "all")
            or (db.enemyEnabled and db.enemyShowLevel and A.LevelScope and A.LevelScope(true) ~= "all")
            or (db.enemyEnabled and (db.enemyScope == "target" or db.enemyScope == "near"))) then
            -- Only the plate you left and the one you selected can change.
            local current
            for unit in pairs(active) do
                if Read(UnitIsUnit, unit, "target") == true then current = unit; break end
            end
            for _, unit in ipairs({lastTargetUnit or "", current or ""}) do
                if active[unit] and Read(UnitIsPlayer, unit) == true then QueueUnit(unit, true) end
            end
            lastTargetUnit = current
        end
    elseif event == "UNIT_LEVEL" then
        -- Registered only while "level after the name" is on.
        if active[arg] then QueueUnit(arg, true) end
    elseif event == "UNIT_FACTION" and arg == "player" then
        -- Your PvP flag changed: enemies switch between their two looks.
        if db.enemyEnabled then A.RequeuePlayers() end
    elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_FACTION" then
        -- Unit events also arrive for player/party/pet/target tokens. Only
        -- refresh the matching active plate; unrelated events must not turn
        -- into a crowd-wide cursor/tooltip scan.
        if IsWorldPlateToken(arg) then
            -- A plate token names its plate: no GUID compare across the crowd.
            if active[arg] then
                local cached = event == "UNIT_NAME_UPDATE" and titleCache[Read(UnitGUID, arg) or ""]
                if cached then cached.expires = 0 end
                QueueUnit(arg, true)
            end
            return
        end
        local guid = Read(UnitGUID, arg)
        if not guid then return end
        for unit in pairs(active) do
            if Read(UnitGUID, unit) == guid then
                local cached = titleCache[guid]
                if cached and event == "UNIT_NAME_UPDATE" then cached.expires = 0 end
                QueueUnit(unit, true)
            end
        end
    elseif event == "MERCHANT_SHOW" then Learn("vendor")
    elseif event == "GOSSIP_SHOW" then
        local available = C_GossipInfo.GetAvailableQuests() or {}
        local quests = C_GossipInfo.GetActiveQuests() or {}
        Learn((#available > 0 or #quests > 0) and "quest" or "interactive")
    elseif event == "QUEST_GREETING" or event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then Learn("quest")
    elseif event == "QUEST_LOG_UPDATE" then ScheduleQuestRefresh()
    end
end)
-- No OnUpdate or repeating ticker. Only events and bounded late-data retries
-- enqueue work; a settled scene performs no addon classification/tooltip scans.
-- Keep the last few blocked actions, so a report names the exact function.
local blocked = CreateFrame("Frame")
blocked:RegisterEvent("ADDON_ACTION_BLOCKED")
blocked:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blocked:SetScript("OnEvent", function(_, event, addon, action)
    if not db or not Public(addon) or addon ~= addonName or not Public(action) or type(action) ~= "string" then return end
    local list = type(db.blockedActions) == "table" and db.blockedActions or {}
    db.blockedActions = list
    -- One blocked call sets off a chain of identical reports; keep the first,
    -- which carries the stack that explains the cause.
    local last, now = list[#list], date and date("%Y-%m-%d %H:%M") or nil
    if last and last.action == action and last.time == now then return end
    local stack = debugstack and debugstack(2, 12, 0)
    list[#list + 1] = {event = event, action = action:sub(1, 200), time = now,
        stack = Public(stack) and type(stack) == "string" and stack:sub(1, 3000) or nil}
    while #list > 5 do table.remove(list, 1) end
end)
SLASH_FOREVERNAMES1 = "/fnames"
SLASH_FOREVERNAMES2 = "/forevernames"
SLASH_FOREVERNAMES3 = "/fnn" -- the old Friendly NPC Names command keeps working
SlashCmdList.FOREVERNAMES = function(message)
    if not db then return end
    local command = message:lower():match("^%s*(%S+)") or ""
    -- People, the journal and adding people live in Companion Journal (/cj).
    local people = A.People()
    if command == "journal" or command == "testleave" or command == "tag" or command == "people" then
        if not people then
            print("Forever Names: your People list and journals are in Companion Journal, which is not installed or is turned off.")
        elseif command == "journal" then
            if not people.OpenJournal(message:match("^%s*%S+%s+(.-)%s*$")) then print("Forever Names: no one by that name in Companion Journal.") end
        elseif command == "tag" then
            people.AddTarget(message:match("^%s*%S+%s+(.-)%s*$"))
        elseif command == "people" then
            people.Open()
        elseif SlashCmdList.COMPANIONJOURNAL then
            SlashCmdList.COMPANIONJOURNAL(message)
        end
        return
    elseif command == "perf" then
        if message:lower():match("^%s*perf%s+reset%s*$") or not A.perf then
            A.perf = {added = 0, removed = 0, updates = 0, players = 0, fontStyles = 0, totalMs = 0, maxMs = 0}
            print("Forever Names: measuring arrival/removal work. Walk across the distance threshold, then /fnames perf.")
        else
            local p = A.perf
            print(string.format("Forever Names: added %d; removed %d; updates %d (players %d); font styles %d; queued Lua total %.2f ms; worst update %.2f ms.",
                p.added, p.removed, p.updates, p.players, p.fontStyles, p.totalMs, p.maxMs))
        end
    elseif command == "players" then
        local choice = message:lower():match("^%s*players%s+(%S+)")
        if choice == "on" or choice == "off" then
            db.showFriendlyPlayers = choice == "on"
            if db.showFriendlyPlayers then A.nativePlateTest = false end
            A.ApplyCVars()
            A.Refresh()
        end
        print("Forever Names: custom friendly player names " .. (db.showFriendlyPlayers and "ON" or "OFF")
            .. "; player plate setting " .. tostring(GetCVar("nameplateShowFriends"))
            .. (A.pendingCVars and "; settings pending until combat ends." or ". /fnames players on or off."))
    elseif command == "vitals" then
        local choice = message:lower():match("^%s*vitals%s+(%S+)")
        if choice == "on" or choice == "off" then
            db.targetOnlyVitals = choice == "on"
            if A.RefreshVitals then A.RefreshVitals() end
        end
        if A.PrintVitals then A.PrintVitals() end
    elseif command == "enemytest" then
        A.SetEnemyTest(not A.enemyTest)
    elseif command == "hide" then
        A.ToggleLabels()
    elseif command == "enemynames" then
        ForeverNames_ToggleEnemyNames()
    elseif command == "blocked" then
        local list = type(db.blockedActions) == "table" and db.blockedActions or {}
        if #list == 0 then print("Forever Names: no blocked actions recorded.") end
        for _, entry in ipairs(list) do
            print("Forever Names:", entry.time or "?", entry.event, entry.action)
            if entry.stack then print(entry.stack) end
        end
    elseif command == "compare" then
        A.nativePlateTest = not A.nativePlateTest
        A.Refresh()
        print(A.nativePlateTest and "Forever Names: comparison ON - Blizzard plates, same distance/scale settings. /fnames compare restores addon labels."
            or "Forever Names: comparison OFF - addon labels restored.")
    elseif command == "native" then
        db.customizeGlobalFade = false
        A.fadeResetAll = true
        A.ApplyCVars()
        if A.RefreshOptions then A.RefreshOptions() end
        print("Forever Names: global fade/scale/distance overrides disabled; Blizzard defaults restored, or queued until combat ends.")
    elseif command == "names" then
        for name in pairs(cvars) do print("Forever Names:", name, "=", tostring(GetCVar(name))) end
    elseif command == "debug" then
        local _, texture, atlas = A.CursorRole("target")
        if Read(UnitIsPlayer, "target") == true then
            local okPlate, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
            plate = okPlate and plate or nil
            local forbidden = plate and plate.IsForbidden and plate:IsForbidden()
            local frame = plate and not forbidden and plate.UnitFrame
            local state = frame and A.RenderStates[frame]
            local okName, name = pcall(UnitName, "target")
            local hidden = okName and issecretvalue and issecretvalue(name)
            local secretIdentity = C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret
                and Read(C_Secrets.ShouldUnitIdentityBeSecret, "target")
            print("Forever Names: player; enemy:", tostring(A.IsEnemyPlayer and A.IsEnemyPlayer("target")),
                "mode:", tostring(A.EnemyMode and A.EnemyMode()), "you flagged:", tostring(A.PlayerFlagged and A.PlayerFlagged()),
                "their faction:", tostring(Read(UnitFactionGroup, "target")), "name hidden from addons:", tostring(hidden),
                "identity secret:", tostring(secretIdentity),
                "plate:", not plate and "none" or forbidden and "locked" or "yes",
                "our label:", not state and "none" or (state.visible and state.overlay:IsShown()) and "shown" or "hidden",
                "UnitNameEnemyPlayerName:", tostring(GetCVar("UnitNameEnemyPlayerName")))
        end
        print("Forever Names:", Read(UnitName, "target") or "No target", "NPC:", A.IsNPC("target"), "attackable:", tostring(Read(UnitCanAttack, "player", "target")), "reaction:", tostring(Read(UnitReaction, "target", "player")), "interactable:", tostring(Read(UnitIsInteractable, "target")), "role:", tostring(A.Classify("target")), "cursor:", tostring(texture), tostring(atlas), "title:", tostring(A.Title("target")))
    elseif command == "vendor" or command == "quest" or command == "interactive" or command == "hidenpc" or command == "auto" then
        -- Per-NPC override. "hidenpc" hides this NPC's label; "/fnames hide"
        -- (above) is the key that hides every label.
        local id = A.NPCID("target")
        if not id or not A.IsNPC("target") then print("Forever Names: target a living, non-attackable NPC first."); return end
        local override = command == "hidenpc" and "hide" or command
        db.overrides[id] = command ~= "auto" and override or nil
        A.Refresh()
        print("Forever Names:", UnitName("target"), "=", override)
    elseif A.OpenOptions then
        A.OpenOptions()
    end
end

-- Key bindings (Bindings.xml): works with keyboard and gamepad alike, in their
-- own section of Key Bindings (the settings look the category up in _G).
BINDING_CATEGORY_FOREVERNAMES = "Forever Names"
BINDING_NAME_FOREVERNAMES_TOGGLE_LABELS = "Hide or show all names and nameplates"
BINDING_NAME_FOREVERNAMES_TOGGLE_ENEMY_NAMES = "Show or hide enemy names"
BINDING_NAME_FOREVERNAMES_TOGGLE_LEVEL = "Show or hide friendly levels"
BINDING_NAME_FOREVERNAMES_TOGGLE_ENEMY_LEVEL = "Show or hide enemy levels"
function ForeverNames_ToggleLevel()
    if not A.db or not A.SetOption then return end
    A.SetOption("playerShowLevel", not A.db.playerShowLevel)
    print("Forever Names: friendly levels " .. (A.db.playerShowLevel and "shown." or "hidden."))
end
function ForeverNames_ToggleEnemyLevel()
    if not A.db or not A.SetOption then return end
    A.SetOption("enemyShowLevel", not A.db.enemyShowLevel)
    print("Forever Names: enemy levels " .. (A.db.enemyShowLevel and "shown." or "hidden."))
end
-- Blizzard's names over hostile NPCs, plus enemy players' names when shown.
function ForeverNames_ToggleEnemyNames()
    if not A.db or not A.SetOption then return end
    if not A.db.enabled then print("Forever Names is turned off; enemy names follow your game settings."); return end
    A.SetOption("hideNativeHostileNames", not A.db.hideNativeHostileNames)
    local when = A.pendingCVars and " when combat ends."
        or (A.AllNamesHidden and A.AllNamesHidden() and " when names come back.") or "."
    print("Forever Names: enemy names " .. (A.db.hideNativeHostileNames and "hidden" or "shown") .. when)
end
function ForeverNames_ToggleLabels()
    if A.db and A.ToggleLabels then A.ToggleLabels() end
end
