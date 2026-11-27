-- Threat on enemy plates: lead line, loose halo, who it hits, secrets.
-- Run from the game folder: lua5.1 Interface/AddOns/ForeverNames/tests/Threat.lua
local root = 'Interface/AddOns/ForeverNames/'
local passed = 0
local function check(ok, label) assert(ok, label); passed = passed + 1 end
local function equal(a, b, label) check(a == b, label .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b)) end

local secret = setmetatable({}, {__tostring = function() return 'SECRET' end})
function issecretvalue(v) return v == secret end

local O = {}; O.__index = O
local function Obj() return setmetatable({shown = true, alpha = 1, events = {}, scripts = {}}, O) end
function O:Show() self.shown = true end
function O:Hide() self.shown = false end
function O:IsShown() return self.shown end
function O:SetAlpha(a) self.alpha = a end
function O:SetAlphaFromBoolean(v, t, f) self.fromBoolean = v; self.alpha = 'by secret' end
function O:SetAllPoints() end
function O:SetPoint() end
function O:ClearAllPoints() end
function O:SetSize(w, h) self.w, self.h = w, h end
function O:SetHeight(h) self.h = h end
function O:GetWidth() return 120 end
function O:GetHeight() return 10 end
function O:EnableMouse() end
function O:SetTexture() end
function O:SetBlendMode() end
function O:SetVertexColor() end
function O:SetColorTexture() end
function O:SetStatusBarTexture() end
function O:SetMinMaxValues(a, b) self.min, self.max = a, b end
function O:SetValue(v) self.value = v end
function O:SetStatusBarColor(r, g, b) self.color = {r, g, b} end
function O:SetText(t) self.text = t end
function O:SetTextColor(r, g, b) self.textColor = {r, g, b} end
function O:SetTextHeight() end
function O:RegisterEvent(e) self.events[e] = true end
function O:UnregisterEvent(e) self.events[e] = nil end
function O:SetScript(k, f) self.scripts[k] = f end
function O:IsForbidden() return false end
function O:CreateTexture() return Obj() end
function O:CreateFontString() return Obj() end
function O:CreateAnimationGroup()
    local g = Obj(); g.playing = false
    function g:SetLooping() end
    function g:CreateAnimation() local a = Obj(); function a:SetFromAlpha() end; function a:SetToAlpha() end; function a:SetDuration() end; function a:SetSmoothing() end; return a end
    function g:Play() self.playing = true end
    function g:Stop() self.playing = false end
    function g:IsPlaying() return self.playing end
    return g
end
local frames = {}
function CreateFrame() local f = Obj(); frames[#frames + 1] = f; return f end

-- One mob on plate 1; its world.
local plate = Obj(); plate.UnitFrame = {HealthBarsContainer = Obj()}
C_NamePlate = {GetNamePlateForUnit = function(u) if u == 'nameplate1' then return plate end end}
local threat = {}   -- tanking, status, scaled
local lead = 150
local target = {name = 'Elyra', class = 'PRIEST', me = false, party = true}
local inGroup = true
function IsInGroup() return inGroup end
function UnitExists(u) return u == 'nameplate1' end
function UnitCanAttack() return true end
function UnitIsPlayer() return false end
function UnitDetailedThreatSituation() return threat.tanking, threat.status, threat.scaled, threat.scaled, 1000 end
function UnitThreatPercentageOfLead() return lead end
function UnitThreatLeadSituation() return 0 end
function UnitName(u) if u == 'nameplate1target' then return target.name end return 'Gnoll' end
function UnitClass(u) return 'Priest', target.class end
function UnitIsUnit(a, b) return a == 'nameplate1target' and b == 'player' and target.me end
function UnitPlayerOrPetInParty() return target.party end
function UnitPlayerOrPetInRaid() return false end
RAID_CLASS_COLORS = {PRIEST = {r = 1, g = 1, b = 1}, WARRIOR = {r = 0.78, g = 0.61, b = 0.43}}

local A = {defaults = {}}
assert(loadfile(root .. 'Threat.lua'))('ForeverNames', A)
A.db = {enabled = true}
for k, v in pairs(A.defaults) do A.db[k] = v end
local events, login = frames[1], frames[2]

-- Off by default: nothing listens.
equal(A.db.threat, false, 'off by default')
login.scripts.OnEvent(login, 'PLAYER_LOGIN')
check(not events.events.UNIT_THREAT_LIST_UPDATE, 'no threat events while off')

A.db.threat = true
A.UpdateThreatEvents()
check(events.events.UNIT_THREAT_LIST_UPDATE, 'threat events on')
local function Fire(e) events.scripts.OnEvent(events, e, 'nameplate1') end
local function Mark() return frames[3] end

-- Not fighting: nothing drawn.
Fire('NAME_PLATE_UNIT_ADDED')
check(Mark() == nil or not Mark().line.shown, 'idle mob: nothing')

-- On you, safe lead: iron line, no halo.
threat.tanking, threat.status, threat.scaled, lead = true, 3, 100, 150
target.me = true
Fire('UNIT_THREAT_LIST_UPDATE')
local m = Mark()
check(m.line.shown, 'on you: line'); equal(m.line.value, 150, 'line = your lead')
check(m.line.color[1] < 0.9, 'safe lead: iron'); check(not m.glow.shown, 'on you: no halo'); check(not m.who.shown, 'on you: no name')

-- A DPS closes in: amber, then ember.
lead = 120; Fire('UNIT_THREAT_LIST_UPDATE'); equal(m.line.color[1], 1.00, 'closing in: warm'); equal(m.line.color[2], 0.70, 'closing in: amber')
lead = 105; Fire('UNIT_THREAT_LIST_UPDATE'); equal(m.line.color[2], 0.34, 'about to lose it: ember')
lead = 300; Fire('UNIT_THREAT_LIST_UPDATE'); equal(m.line.value, 160, 'big lead: full line')
lead = nil; Fire('UNIT_THREAT_LIST_UPDATE'); equal(m.line.value, 160, 'nobody else on it: full line')

-- Loose: on the healer.
threat.tanking, threat.status, threat.scaled = false, 1, 70
target.me = false
Fire('UNIT_TARGET')
check(m.glow.shown, 'loose: halo'); check(m.breath.playing, 'loose: halo breathes')
check(m.who.shown, 'loose: who it hits'); equal(m.who.text, '\226\134\146 Elyra', 'loose: their name')
equal(m.line.value, 70, 'loose: line = your % of theirs'); equal(m.line.max, 100, 'loose: out of 100')

-- A mob you never touched, on your healer: still loose.
threat.tanking, threat.status = nil, nil
Fire('UNIT_THREAT_LIST_UPDATE')
check(m.glow.shown, 'untouched on a friend: halo'); check(not m.line.shown, 'untouched: no line'); check(m.who.shown, 'untouched: who')
-- ...on a stranger outside the group: nothing.
target.party = false
Fire('UNIT_TARGET')
check(not m.glow.shown and not m.who.shown, 'outside the group: nothing')
target.party = true

-- Options.
threat.tanking, threat.status, threat.scaled = false, 1, 70
A.db.threatWho = false; A.db.threatGlow = false; A.RefreshThreat()
check(not m.who.shown, 'Who it hits off'); check(not m.glow.shown, 'Glow off'); check(not m.breath.playing, 'Glow off: no breath')
A.db.threatWho, A.db.threatGlow = true, true
A.db.threatLine = false; threat.tanking, threat.status = true, 3; target.me = true; lead = 150; A.RefreshThreat()
check(not m.line.shown, 'Lead line off'); A.db.threatLine = true

-- Solo: nothing unless asked.
inGroup = false; A.RefreshThreat(); check(not m.line.shown, 'solo: nothing')
A.db.threatSolo = true; A.RefreshThreat(); check(m.line.shown, 'Solo too: line')
inGroup = true; A.db.threatSolo = false

-- Secret threat (a boss): the halo follows it, the line takes the value.
threat.tanking, threat.status = secret, secret; lead = secret
Fire('UNIT_THREAT_LIST_UPDATE')
equal(m.glow.fromBoolean, secret, 'secret: halo opacity from the secret')
check(not m.breath.playing, 'secret: no breath over it')
equal(m.line.value, secret, 'secret: line fills from the secret'); check(not m.who.shown, 'secret: name waits')

-- Plate gone: cleared; option off: everything gone.
threat.tanking, threat.status = false, 1; lead = 150
Fire('UNIT_THREAT_LIST_UPDATE'); Fire('NAME_PLATE_UNIT_REMOVED')
check(not m.glow.shown and not m.line.shown and not m.who.shown, 'plate removed: cleared')
Fire('NAME_PLATE_UNIT_ADDED'); check(m.glow.shown, 'back')
A.db.threat = false; A.UpdateThreatEvents()
check(not m.glow.shown, 'option off: cleared'); check(not events.events.UNIT_THREAT_LIST_UPDATE, 'option off: not listening')

print('PASS: ' .. passed .. ' threat assertions')
