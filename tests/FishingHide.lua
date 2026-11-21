-- Fishing hides everything; something else equipped or a fight puts back what you had.
-- lua5.1 Interface/AddOns/ForeverNames/tests/FishingHide.lua (from the WoW folder)
local root = 'Interface/AddOns/ForeverNames/'
local checks, A = 0, {}
local function eq(a, b, why) checks = checks + 1; assert(a == b, why .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b)) end
local frames = {}
function CreateFrame() local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, v) self[k] = v end
    frames[#frames + 1] = f; return f end
local combat, hand, cvars = false, nil, { nameplateShowEnemies = '1', UnitNameNPC = '1' }
function InCombatLockdown() return combat end
function GetCVar(k) return cvars[k] end
function SetCVar(k, v) if combat then error('blocked') end cvars[k] = v end
function UnitGUID() return 'Player-1' end
function GetInventoryItemID(_, slot) return slot == 16 and hand or nil end
C_Item = { GetItemInfoInstant = function(id) if id == 6256 then return id, nil, nil, nil, nil, 2, 20 end return id, nil, nil, nil, nil, 2, 7 end }
A.db = { hideWhileFishing = true }
A.FadeLabels = function() end
A.ApplyCVars = function() end
assert(loadfile(root .. 'HideAll.lua'))('ForeverNames', A)

-- the rule
eq(A.FishingStep(true, true, false, false, nil), 'hide', 'a pole, no fight: hide')
eq(A.FishingStep(true, true, false, true, nil), nil, 'already hidden by you: left alone')
eq(A.FishingStep(true, false, false, true, true), 'show', 'the pole off: back')
eq(A.FishingStep(true, true, true, true, true), 'show', 'a fight: back')
eq(A.FishingStep(true, false, false, true, nil), nil, 'hidden by you, no pole: still yours')
eq(A.FishingStep(false, true, false, false, nil), nil, 'switched off: nothing')

-- driven
local ev
for _, f in ipairs(frames) do if f.events.PLAYER_EQUIPMENT_CHANGED then ev = f.OnEvent end end
hand = 6256
ev(nil, 'PLAYER_EQUIPMENT_CHANGED', 16)
eq(cvars.nameplateShowEnemies, '0', 'the pole on: plates hidden')
eq(A.fishingHid, true, 'hidden by fishing')
ev(nil, 'PLAYER_REGEN_DISABLED')            -- (fires before the lockdown)
eq(cvars.nameplateShowEnemies, '1', 'a fight begins: plates back before the lockdown')
combat = true
ev(nil, 'PLAYER_EQUIPMENT_CHANGED', 16)
eq(cvars.nameplateShowEnemies, '1', 'in the fight: nothing changes')
combat = false
ev(nil, 'PLAYER_REGEN_ENABLED')
eq(cvars.nameplateShowEnemies, '0', 'after the fight, the pole still in hand: hidden again')
hand = 1201
ev(nil, 'PLAYER_EQUIPMENT_CHANGED', 16)
eq(cvars.nameplateShowEnemies, '1', 'the weapons on: back as you had them')
eq(cvars.UnitNameNPC, '1', 'names back too')
-- hidden by you first: fishing leaves it alone
A.ToggleLabels(true)
hand = 6256; ev(nil, 'PLAYER_EQUIPMENT_CHANGED', 16)
hand = 1201; ev(nil, 'PLAYER_EQUIPMENT_CHANGED', 16)
eq(cvars.nameplateShowEnemies, '0', 'your own hide stays after the pole')
A.ToggleLabels(false)
-- you bring things back while fishing: yours, until the next fishing moment (a fight ends, the pole on again)
hand = 6256; ev(nil, 'PLAYER_EQUIPMENT_CHANGED', 16)
A.ToggleLabels(false)
eq(A.fishingHid, nil, 'your own show takes over')
print(('PASS: fishing hide (%d checks)'):format(checks))
