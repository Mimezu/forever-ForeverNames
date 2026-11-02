-- Lua 5.1 simulation of Forever's native nameplate components and event queue.
local root='Interface/AddOns/ForeverNames/'
local cjRoot='Interface/AddOns/CompanionJournal/'
local A, frames, units, plates, timers = {},{},{},{},{}
local now, combat, assertions, lookups, cursorReads, tooltipReads, updateCalls = 0,false,0,0,0,0,0
local cvars={nameplateShowFriendlyNpcs='0',UnitNameNPC='1',UnitNameInteractiveNPC='1',UnitNameFriendlySpecialNPCName='1',nameplateMaxDistance='45',nameplateMaxAlpha='1',nameplateMinAlpha='0.6',nameplateMaxAlphaDistance='40',nameplateMinAlphaDistance='10',nameplateOccludedAlphaMult='0.4',nameplateMaxScale='1',nameplateMinScale='0.8',nameplateMaxScaleDistance='10',nameplateMinScaleDistance='10'}
cvars.UnitNameFriendlyPlayerName='1'
cvars.UnitNameEnemyPlayerName='0'
local friendlySummonNames = {'UnitNameFriendlyPetName','UnitNameFriendlyMinionName','UnitNameFriendlyGuardianName'}
for _,name in ipairs(friendlySummonNames) do cvars[name]='1' end
cvars.UnitNameHostleNPC='1'
cvars.nameplateShowFriends='1'
cvars.nameplateShowEnemies='1'
local font={path='NativeFont',height=14,flags='SLUG'}
local M={};M.__index=M
local function check(value,why) assertions=assertions+1;assert(value,why) end
local function equal(a,b,why) check((type(a)=='number' and type(b)=='number' and math.abs(a-b)<0.00001) or a==b,why..': '..tostring(a)..' ~= '..tostring(b)) end
local function object() return setmetatable({scripts={},events={},shown=true,alpha=1,color={1,1,1,1},fontObject=font,text='',fontHeight=14},M) end
function M:SetScript(k,v) self.scripts[k]=v end
function M:RegisterEvent(e) self.events[e]=true end
function M:RegisterUnitEvent(e,...) self.events[e]=true;self.unitFilters=self.unitFilters or {};self.unitFilters[e]={...} end
function M:UnregisterEvent(e) self.events[e]=nil;if self.unitFilters then self.unitFilters[e]=nil end end
function M:IsEventRegistered(e) return self.events[e] or false end
function M:Hide() self.shown=false end
-- Like WoW: showing a hidden frame runs its OnShow script.
function M:Show() local was=self.shown;self.shown=true;if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function M:IsShown() return self.shown end
function M:SetShown(v) if v then self:Show() else self.shown=false end end
function M:SetAlpha(v) self.alpha=v;self.alphaWrites=(self.alphaWrites or 0)+1 end
function M:SetStatusBarTexture(v) self.barTexture=v end
function M:SetStatusBarColor(...) self.barColor={...} end
function M:SetMinMaxValues(low,high) self.minimum,self.maximum=low,high;self.rangeWrites=(self.rangeWrites or 0)+1 end
function M:SetValue(v) self.value=v;self.valueWrites=(self.valueWrites or 0)+1 end
function M:GetAlpha() return self.alpha end
function M:SetPoint(...) self.anchor={...} end
function M:SetSize(w,h) self.width,self.height=w,h end
function M:GetSize() return self.width or 100,self.height or 24 end
function M:SetHeight(h) self.height=h end
function M:GetHeight() return self.height or 24 end
function M:ClearAllPoints() self.anchor=nil end
function M:HookScript(event,fn)
 local prior=self.scripts[event]
 self.scripts[event]=function(...) if prior then prior(...) end; fn(...) end
end
function M:SetMovable() end
function M:SetScale(v) self.scale=v end
function M:SetClampedToScreen() end
function M:RegisterForDrag() end
function M:RegisterForClicks(...) self.clicks={...} end
function M:EnableMouseWheel() end
function M:GetVerticalScrollRange() return 100 end
function M:GetVerticalScroll() return self.scroll or 0 end
function M:SetVerticalScroll(v) self.scroll=v end
function M:RegisterCallback(event,fn,owner) self.callback,self.callbackOwner=fn,owner end
function M:SetVisibleExtentPercentage(v) self.extent=v end
function M:SetPanExtentPercentage(v) self.pan=v end
function M:SetScrollPercentage(v) self.percentage=v end
function M:SetAtlas(name,size)
 self.atlas=name
 if size then local info=C_Texture.GetAtlasInfo(name); self:SetSize(info.width,info.height) end
end
function M:SetTexCoord(...) self.coords={...} end
function M:SetColorTexture(...) self.color={...} end
function M:SetVertexColor(...) self.tint={...} end
function M:SetAllPoints() end
function M:SetWidth(w) self.textWidth=w end
function M:SetTextHeight(h) assert(not self.nativeName,'addon resized native name');self.fontHeight=h;self.heightWrites=(self.heightWrites or 0)+1 end
function M:SetWordWrap() end
function M:SetJustifyH() end
function M:EnableMouse() end
function M:SetFrameStrata() end
function M:GetFrameLevel() return 10 end
function M:SetFrameLevel(value) self.level=value end
function M:SetParent(parent) self.parent=parent end
function M:SetBackdrop() end
function M:SetBackdropColor() end
function M:SetBackdropBorderColor(...) self.borderColor={...} end
function M:SetScrollChild() end
function M:SetChecked(v) self.checked=v end
function M:SetDesaturated(v) self.desaturated=v end
function M:CreateMaskTexture() return object() end
function M:AddMaskTexture(m) self.masks=self.masks or {};self.masks[m]=true end
function M:RemoveMaskTexture(m) if self.masks then self.masks[m]=nil end end
function M:SetShadowOffset(x,y) self.shadowOffset={x,y} end
function M:SetShadowColor(...) self.shadowColor={...} end
function M:SetAutoFocus() end
function M:SetMaxLetters() end
function M:ClearFocus() self.focused=false end
function M:HasFocus() return self.focused==true end
-- Journal window
function M:SetToplevel() end
function M:Raise() end
-- Like the game: text wraps at an explicit width (about 7 px per character).
function M:GetStringHeight()
 if not self.textWidth or self.textWidth<=0 or type(self.text)~='string' then return 14 end
 return math.max(1,math.ceil(#self.text*7/self.textWidth))*14
end
function M:GetWidth() return self.width or 400 end
function M:SetDrawLayer() end
function M:GetChecked() return self.checked end
function M:SetEnabled(v) self.enabled=v end
function M:IsEnabled() return self.enabled~=false end
function M:GetFontString() return self end
function M:SetFont() error('native renderer must never set a font path') end
function M:SetFontObject(v) assert(not self.nativeName,'addon replaced native font object');self.fontObject=v;self.fontWrites=(self.fontWrites or 0)+1 end
function M:GetFontObject() return self.fontObject end
function M:GetLineHeight() error('restricted measurement must not be called') end
function M:SetSmoothScaling(v) assert(not self.nativeName,'addon changed native smoothing');self.smooth=v end
function M:SetText(v) assert(not self.nativeName,'addon overwrote native name text');self.text=v end
function M:GetText() return self.text end
function M:SetTextColor(...) self.color={...} end
function M:GetTextColor() return unpack(self.color) end
function M:SetTexture(v) self.texture=v end
function M:SetMask(v) self.mask=v end
function M:GetTexture() return self.texture end
function M:GetAtlas() return nil end
function M:IsForbidden() return self.forbidden or false end
function M:IsProtected() return self.protected or false end
function M:CreateTexture() return object() end
function M:CreateFontString(_,_,template) local f=object();f.template=template;return f end
function M:SetOwner() end
function M:ClearLines() self.lines={} end
function M:SetUnit(unit)
 self.lines=units[unit] and units[unit].legacy or {}
 for i=1,4 do local text=self.lines[i];_G['ForeverNamesTitleScannerTextLeft'..i]={GetText=function() return text end} end
end
function M:NumLines() return #self.lines end
function CreateFrame(kind,name,parent,template)
 local f=object();f.kind=kind;f.parent=parent;f.Text=object();frames[#frames+1]=f;if name then _G[name]=f end;return f
end
function hooksecurefunc(objectOrName,key,callback)
 local obj=objectOrName
 if type(obj)=='string' then obj,key,callback=_G,obj,key end
 local old=obj[key];assert(type(old)=='function','missing native method '..key)
 obj[key]=function(...) local r=old(...);callback(...);return r end
end
function GetTime() return now end
C_Timer={After=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end}
local function tick(dt)
 now=now+(dt or .03)
 local batch=timers;timers={}
 for _,t in ipairs(batch) do if t.at<=now then t.fn() else timers[#timers+1]=t end end
end
local function settle() for i=1,200 do tick(.03) end end
function InCombatLockdown() return combat end
function GetCVar(key) return cvars[key] end
local cvarWrites=0
function SetCVar(key,value) cvarWrites=cvarWrites+1;cvars[key]=tostring(value) end
function UnitExists(u) return units[u]~=nil end
function UnitGUID(u) return units[u] and 'Creature-0-1-1-1-'..units[u].id..'-abc' end
function UnitName(u) return units[u] and units[u].name end
function GetUnitName(u,showSurname)
 local data=units[u]
 return data and (data.name .. (showSurname and data.surname and (' '..data.surname) or ''))
end
function UnitIsPlayer(u) return units[u] and units[u].player end
function UnitPlayerControlled(u) return units[u] and units[u].pet end
function UnitIsDeadOrGhost(u) return units[u] and units[u].dead end
function UnitCanAttack(_,u) return units[u] and units[u].enemy or false end
function UnitIsFriend(_,u) return units[u] and not units[u].enemy and not units[u].opposite end
function UnitReaction(u) return units[u] and ((units[u].enemy or units[u].opposite) and 2 or 5) end
function UnitIsInteractable(u) return units[u] and units[u].interactive end
function UnitIsUnit(a,b) return units[a]~=nil and units[a]==units[b] end
local healthReads,maxHealthReads,levelReads=0,0,0
function UnitHealth(u) assert(u=='target','must never read crowd health');healthReads=healthReads+1;return units[u] and (units[u].health or 65) end
function UnitHealthMax(u) assert(u=='target','must never read crowd maximum health');maxHealthReads=maxHealthReads+1;return units[u] and (units[u].maxHealth or 100) end
function UnitLevel(u) assert(u=='target','must never read crowd level');levelReads=levelReads+1;return units[u] and units[u].level end
function SetUnitCursorTexture(texture,u)
 cursorReads=cursorReads+1
 local cursor=units[u] and units[u].cursor
 if cursor then texture:SetTexture('Interface\\CURSOR\\'..cursor);return true end
 return false
end
C_TooltipInfo={GetUnit=function(u)
 tooltipReads=tooltipReads+1
 local d=units[u];if not d then return end
 local lines={{leftText=d.name}}
 if d.title then lines[#lines+1]={leftText=d.title} end
 lines[#lines+1]={type=47,leftText='Level 5'}
 return {lines=lines}
end}
C_NamePlate={GetNamePlateForUnit=function(u) assert(u:match('^nameplate%d+$'));lookups=lookups+1;return plates[u] end,GetNamePlates=function() return plates end}
C_GossipInfo={GetAvailableQuests=function() return {} end,GetActiveQuests=function() return {} end}
Enum={TooltipDataLineType={UnitLevel=47,UnitType=48}}
NamePlateSetupOptions={healthBarFontHeight=14}
NamePlateDriverFrame={OnNamePlateAdded=function(self,unit)
 if self.nextFrame then plates[unit].UnitFrame=self.nextFrame;self.nextFrame=nil end
end}
function CompactUnitFrame_UpdatePlayerLevelDiff() end
function CompactUnitFrame_UpdateName(frame)
 if frame.unit and units[frame.unit] then
  frame.name.text=units[frame.unit].name;frame.name.color={1,1,1,1}
  frame.name.shown=frame.forceShowUnitName or cvars.UnitNameNPC=='1'
 end
end
SlashCmdList={}
Settings=setmetatable({}, {__index=function() error('must not register with Blizzard Settings') end})
function ReloadUI() end
C_Texture={GetAtlasInfo=function(name)
 return {file=123,width=name=='Legacy-Challenge-BG' and 920 or 300,height=name=='Legacy-Challenge-BG' and 575 or 25,
 leftTexCoord=.1,rightTexCoord=.9,topTexCoord=.2,bottomTexCoord=.8}
end}
NineSliceUtil={ApplyLayoutByName=function(frame,name) frame.layout=name;frame.TopEdge=object() end}
for _,file in ipairs({'Core.lua','Fading.lua','NativeRenderer.lua','NativeVitals.lua','TargetHealthBar.lua','Players.lua','Icons.lua','PeopleBridge.lua','Wounded.lua','OptionsSkin.lua','ColorPicker.lua','Options.lua','OptionsB.lua'}) do assert(loadfile(root..file))('ForeverNames',A) end
-- Companion Journal installed too: your People list, the journal, and the API
-- Forever Names asks for display names and icons. Its own namespace: C.
local C={}
local cjFirst=#frames+1
for _,file in ipairs({'Core.lua','Glyphs.lua','OptionsSkin.lua','ColorPicker.lua','People.lua','Characters.lua','GroupPrompt.lua','LoreData.lua','Lore.lua','Journal.lua','JournalBook.lua','JournalTellers.lua','JournalTale.lua','JournalWords.lua','JournalStyles.lua','JournalUI.lua','Plates.lua','API.lua','Options.lua'}) do assert(loadfile(cjRoot..file))('CompanionJournal',C) end
local cjEvents=frames[cjFirst]
local originalUpdate=A.Update
A.Update=function(...) updateCalls=updateCalls+1;return originalUpdate(...) end
local events=frames[1]
local healthDriver
for _,frame in ipairs(frames) do if frame.unitFilters and frame.unitFilters.UNIT_FACTION then healthDriver=frame end end
local function emit(e,u)
 events.scripts.OnEvent(events,e,u)
 if healthDriver.events[e] then
  local filters=healthDriver.unitFilters[e]
  if not filters or filters[1]==u or filters[2]==u then healthDriver.scripts.OnEvent(healthDriver,e,u) end
 end
end
emit('ADDON_LOADED','ForeverNames');cjEvents.scripts.OnEvent(cjEvents,'ADDON_LOADED','CompanionJournal')
emit('PLAYER_LOGIN');cjEvents.scripts.OnEvent(cjEvents,'PLAYER_LOGIN');settle()
check(CompanionJournalAPI and ForeverNamesAPI,'both addons publish their API')
SlashCmdList.FOREVERNAMES('vitals off')
equal(A.db.targetOnlyVitals,false,'vitals off disables the saved preference')
equal(A.GetVitalsStatus().mode,'OFF','off command reports off even without native API')
SlashCmdList.FOREVERNAMES('vitals')
equal(A.db.targetOnlyVitals,false,'bare vitals reports status without enabling')
SlashCmdList.FOREVERNAMES('vitals on')
equal(A.db.targetOnlyVitals,true,'vitals on enables the saved preference')
equal(cvars.UnitNameHostleNPC,'0','hostile NPC world names hidden with friendly names')
A.db.hideNativeNames=false;A.ApplyCVars()
equal(cvars.UnitNameHostleNPC,'1','unchecking NPC option restores hostile names')
A.db.hideNativeNames=true;A.ApplyCVars()
equal(cvars.UnitNameHostleNPC,'0','rechecking NPC option hides hostile names')
-- Do not overwrite a later user/other-addon preference on release.
cvars.UnitNameHostleNPC='1';A.db.hideNativeNames=false;A.ApplyCVars()
equal(cvars.UnitNameHostleNPC,'1','external hostile-name preference survives release')
A.db.hideNativeNames=true;A.ApplyCVars()
equal(cvars.UnitNameFriendlyPlayerName,'0','native friendly player names hidden by default')
equal(cvars.UnitNameEnemyPlayerName,'0','Enemy tab off: enemy names keep the player setting (0 here)')
for _,name in ipairs(friendlySummonNames) do equal(cvars[name],'0',name..' hidden with player names') end
equal(cvars.nameplateShowFriends,'1','friendly player plate setting untouched')
equal(cvars.nameplateShowEnemies,'1','enemy plate setting untouched')
A.db.hideNativePlayerNames=false;A.ApplyCVars()
equal(cvars.UnitNameFriendlyPlayerName,'1','toggle restores previous friendly names')
equal(cvars.UnitNameEnemyPlayerName,'0','toggle preserves previously disabled enemy names')
for _,name in ipairs(friendlySummonNames) do equal(cvars[name],'1',name..' restored on uncheck') end
equal(cvars.UnitNameNPC,'0','player toggle independent of NPC suppression')
cvars.UnitNameEnemyPlayerName='1'
combat=true;A.db.hideNativePlayerNames=true;A.ApplyCVars()
equal(cvars.UnitNameEnemyPlayerName,'1','player name changes deferred during combat')
for _,name in ipairs(friendlySummonNames) do equal(cvars[name],'1',name..' deferred during combat') end
combat=false;emit('PLAYER_REGEN_ENABLED')
equal(cvars.UnitNameEnemyPlayerName,'1','Hide Blizzard player names leaves enemy names alone')
A.db.enemyEnabled=true;A.ApplyCVars()
equal(cvars.UnitNameEnemyPlayerName,'1','the Enemy tab leaves the enemy-name setting alone (Blizzard plates need it)')
A.db.enemyEnabled=false;A.ApplyCVars()
equal(cvars.UnitNameEnemyPlayerName,'1','and so does turning it off')
for _,name in ipairs(friendlySummonNames) do equal(cvars[name],'0',name..' hidden after combat') end
A.db.hideNativeNames=false;A.ApplyCVars()
equal(cvars.UnitNameFriendlyPlayerName,'0','NPC toggle does not release player suppression')
for _,name in ipairs(friendlySummonNames) do equal(cvars[name],'0',name..' independent of NPC toggle') end
A.db.hideNativeNames=true;A.ApplyCVars()
check(not events.scripts.OnUpdate,'no per-frame script')
local function component()
 local c=object();function c:SetShowOnlyName(v) self.showOnlyName=v;self.shown=not v end;return c
end
local function spawn(token,data)
 units[token]=data
 local plate,frame=object(),object();plate.UnitFrame=frame;plates[token]=plate;frame.unit=token
 frame.LevelFrame,frame.PlayerLevelDiffFrame=object(),object()
 frame.name=object();frame.name.nativeName=true;frame.name.smooth=true
 frame.HealthBarsContainer=object();frame.HealthBarsContainer.healthBar=component();frame.CastBarsContainer=object();frame.CastBarsContainer.castBar=component()
 frame.SoftTargetFrame=object();frame.SoftTargetFrame.Icon=object();frame.SoftTargetFrame.Icon:Hide()
 frame.AurasFrame,frame.ClassificationFrame,frame.RaidTargetFrame=component(),component(),component()
 function frame:UpdateAnchors() assert(self.nativeLayout,'addon must not invoke restricted layout');self.anchorUpdates=(self.anchorUpdates or 0)+1;self.name.nativeAnchor=self.showOnlyName and 'BlizzardNameOnly' or 'BlizzardBars' end
 function frame:UpdateHitTestArea() plate.hitboxCleared=self.showOnlyName end
 function frame:UpdateShowOnlyName()
  self.showOnlyName=units[self.unit] and units[self.unit].player or false
  for _,c in ipairs({self.HealthBarsContainer.healthBar,self.CastBarsContainer.castBar,self.AurasFrame,self.ClassificationFrame,self.RaidTargetFrame}) do c:SetShowOnlyName(self.showOnlyName) end
  self.nativeLayout=true;self:UpdateAnchors();self.nativeLayout=nil;self:UpdateHitTestArea()
 end
 function frame:ApplyFrameOptions() self.name.fontObject=font;self.name.fontHeight=font.height;NamePlateSetupOptions.healthBarFontHeight=font.height;self.nativeLayout=true;self:UpdateAnchors();self.nativeLayout=nil end
 function frame:UpdateForceShowUnitName() self.forceShowUnitName=false;CompactUnitFrame_UpdateName(self) end
 function frame:OnUnitCleared() self.unit=nil;self.showOnlyName=nil;self.forceShowUnitName=nil end
 CompactUnitFrame_UpdateName(frame)
 if data.lateFrame then
  local placeholder=object();placeholder.unit=token;placeholder.name=object();placeholder.HealthBarsContainer=object()
  plate.UnitFrame=placeholder;plate.placeholder=placeholder;NamePlateDriverFrame.nextFrame=frame
 end
 emit('NAME_PLATE_UNIT_ADDED',token);NamePlateDriverFrame:OnNamePlateAdded(token)
 return plate,frame
end
local vendor,vf=spawn('nameplate1',{id='10',name='Vendor',cursor='Buy',title='General Goods'})
settle()
local function state(frame) return A.RenderStates[frame] end
local vs=state(vf)
equal(vf.name.fontObject,font,'native font object untouched')
equal(vf.forceShowUnitName,nil,'native force-name field untouched')
equal(vf.showOnlyName,nil,'native layout flag untouched')
equal(vf.HealthBarsContainer.healthBar.showOnlyName,nil,'native component flag untouched')
equal(vf.name.nativeAnchor,nil,'restricted native layout never called')
equal(vf.alpha,1,'native parent remains visible for interaction prompt')
equal(vf.HealthBarsContainer.alpha,0,'native bars hidden')
equal(vf.HealthBarsContainer.alphaWrites,1,'primed owner promotion does not hide native bars twice')
A.PrimePlate(vf,'nameplate1')
equal(vf.HealthBarsContainer.alphaWrites,1,'unchanged suppression does not repeat alpha writes')
equal(vf.LevelFrame.alpha,0,'native level hidden')
equal(vf.PlayerLevelDiffFrame.alpha,0,'native level difference hidden')
equal(vf.name.alpha,0,'duplicate native name hidden')
equal(vf.SoftTargetFrame.alpha,1,'interaction frame alpha unchanged')
equal(vf.SoftTargetFrame.Icon.shown,false,'addon does not force interaction icon visible')
vf.SoftTargetFrame.Icon:Show()
equal(vf.SoftTargetFrame.Icon.alpha*vf.SoftTargetFrame.alpha*vf.alpha,1,'Blizzard can display interaction icon after plate is styled')
vf.SoftTargetFrame.Icon:Hide()
equal(vf.SoftTargetFrame.Icon.shown,false,'Blizzard can dismiss interaction icon')
equal(vs.name.text,'Vendor','real NPC name retained')
equal(vs.title.text,'<General Goods>','real subtitle retained')
equal(vs.name.fontObject,font,'own name inherits Blizzard font')
equal(vs.title.fontHeight,11.2,'subtitle retains smaller size')
equal(vs.name.smooth,true,'inherited font uses Blizzard smooth scaling')
equal(vs.title.smooth,true,'subtitle uses Blizzard smooth scaling')
A.db.nativeSmoothScaling=false;A.Refresh()
equal(vs.name.smooth,false,'smoothing can be disabled without reload')
equal(vs.title.smooth,false,'subtitle smoothing can be disabled')
A.db.nativeSmoothScaling=true;A.Refresh()
equal(vs.name.smooth,true,'smoothing can be reenabled')
for i=1,3 do equal(vs.name.color[i],A.db.colors.vendor[i],'saved name color');equal(vs.title.color[i],A.db.colors.vendor[i],'saved subtitle color') end
vf:UpdateShowOnlyName();equal(vf.HealthBarsContainer.healthBar.showOnlyName,false,'native refresh remains unmodified')
font={path='NewNativeStyle',height=18,flags='SLUG'};vf:ApplyFrameOptions()
equal(vs.name.fontObject,font,'own text follows native font options')
equal(vs.title.fontHeight,14.4,'subtitle follows native size')
local resident,rf=spawn('nameplate2',{id='20',name='Resident'});settle()
equal(state(rf).overlay.shown,false,'noninteractive resident hidden')
local enemy,ef=spawn('nameplate3',{id='30',name='Enemy',enemy=true});settle()
equal(state(ef),nil,'enemy untouched')
local playerCursorReads,playerTooltipReads=cursorReads,tooltipReads
local player,pf=spawn('nameplate4',{id='40',name='Player',player=true})
equal(pf.HealthBarsContainer.alpha,0,'player bar hidden immediately before queue runs')
equal(pf.LevelFrame.alpha,0,'player level hidden immediately before queue runs')
equal(pf.name.alpha,0,'native player name hidden immediately before queue runs')
equal(state(pf),nil,'immediate arrival pass does not build text overlays')
pf.name.color={.2,.5,.9,1};settle()
equal(state(pf).name.text,'Player','friendly player uses pooled custom name renderer')
equal(state(pf).title.text,'','friendly player has no subtitle')
equal(state(pf).title.shown,false,'friendly player subtitle hidden')
equal(state(pf).name.color[1],.2,'player preserves Blizzard name color')
equal(state(pf).name.fontObject,font,'player uses same inherited font as NPC')
equal(pf.name.alpha,0,'native player name replaced by overlay')
equal(pf.HealthBarsContainer.alpha,0,'player health bar suppressed')
equal(pf.LevelFrame.alpha,0,'player level suppressed')
equal(pf.RaidTargetFrame.alpha,0,'Blizzard marker (anchored to its hidden bar) replaced')
do
 -- Our own raid marker above the name; the secret index goes to the texture.
 local secret=setmetatable({}, {__eq=function() error('secret compared') end,__lt=function() error('secret compared') end})
 local realSecret=issecretvalue
 issecretvalue=function(v) return v==secret end
 local marks={}
 function GetRaidTargetIndex(u) return marks[u] end
 function M:SetSpriteSheetCell(cell,rows,cols) self.cell,self.rows,self.cols=cell,rows,cols end
 A.Update('nameplate4')
 equal(state(pf).overlay.raidMarker,nil,'no marker: nothing created')
 marks.nameplate4=secret
 local markerFrame
 for _,f in ipairs(frames) do if f.events and f.events.RAID_TARGET_UPDATE then markerFrame=f end end
 markerFrame.scripts.OnEvent(markerFrame,'RAID_TARGET_UPDATE')
 local marker=state(pf).overlay.raidMarker
 check(marker and marker.shown,'marker drawn when the unit has one')
 check(marker.cell==secret and marker.rows==4 and marker.cols==4,'secret index goes straight to the icon sheet')
 equal(marker.anchor[1],'BOTTOM','marker above the name')
 equal(marker.anchor[2],state(pf).name,'anchored to our name')
 marks.nameplate4=nil
 markerFrame.scripts.OnEvent(markerFrame,'RAID_TARGET_UPDATE')
 equal(marker.shown,false,'marker cleared')
 issecretvalue=realSecret;GetRaidTargetIndex=nil;M.SetSpriteSheetCell=nil
end
equal(cursorReads,playerCursorReads,'player arrival performs no NPC cursor scans')
equal(tooltipReads,playerTooltipReads,'player arrival performs no tooltip scans')
units.nameplate4.surname='Strikes';A.Update('nameplate4')
equal(state(pf).name.text,'Player Strikes','custom player name preserves surname through display formatter')
equal(tooltipReads,playerTooltipReads,'full player name requires no tooltip scans')
units.nameplate4.surname=nil;A.Update('nameplate4')
A.db.showFriendlyPlayers=false;A.Refresh()
equal(state(pf),nil,'custom player switch restores native player appearance')
equal(pf.name.alpha,1,'native player text restored on disable')
A.db.showFriendlyPlayers=true;A.Refresh()
equal(state(pf).name.text,'Player','custom player switch reenables names')
-- Relationship icons: nothing is read or created while every icon is off.
do
 local reads={party=0,guild=0,friend=0,bnet=0}
 function UnitInParty(u) reads.party=reads.party+1;return units[u] and units[u].party or false end
 function UnitInRaid(u) return nil end
 function UnitIsInMyGuild(u) reads.guild=reads.guild+1;return units[u] and units[u].guildmate or false end
 C_FriendList={IsFriend=function(guid) reads.friend=reads.friend+1;return guid=='Creature-0-1-1-1-40-abc' end}
 C_BattleNet={GetAccountInfoByGUID=function(guid) reads.bnet=reads.bnet+1;return nil end}
 local p4=units.nameplate4
 p4.party,p4.guildmate=true,true
 A.Update('nameplate4')
 equal(reads.party+reads.guild+reads.friend+reads.bnet,0,'icons off: no relationship reads')
 equal(state(pf).overlay.icons,nil,'icons off: no icon textures')
 check(not events.events.GROUP_ROSTER_UPDATE,'icons off: no roster subscription')
 A.SetOption('iconsGuild',true);A.SetOption('iconsParty',true);settle()
 local pool=state(pf).overlay.icons
 check(pool and pool[1].shown and pool[2].shown,'two icons shown')
 equal(pool[1].path,A.GlyphPath('party'),'group icon first (priority order)')
 equal(pool[2].path,A.GlyphPath('shield'),'guild icon second')
 equal(pool[1].tint[1],A.db.colors.icon_party[1],'icon tinted with its color')
 equal(pool[1].anchor[1],'RIGHT','icons sit before the name by default')
 equal(pool[1].width,A.GetTextSizes('friendlyPlayer'),'automatic icon size matches the name')
 equal(reads.friend+reads.bnet,0,'friend lookups only when friend icons are on')
 A.SetOption('iconMax',1);settle()
 equal(pool[2].shown,false,'show up to 1 hides the second icon')
 A.SetOption('iconMax',2);A.SetOption('iconPosition','above');settle()
 equal(pool[1].anchor[1],'BOTTOM','icons can sit above the name')
 A.SetOption('iconPosition','right');A.SetOption('iconSize',10);settle()
 equal(pool[1].anchor[1],'LEFT','icons can sit after the name')
 equal(pool[1].width,10,'custom icon size')
 A.SetOption('iconsFriend',true);settle()
 equal(pool[2].path,A.GlyphPath('star'),'friend icon outranks guild')
 local friendDriver
 for _,f in ipairs(frames) do if f.events.FRIENDLIST_UPDATE then friendDriver=f end end
 check(friendDriver~=nil,'friend icons subscribe to friend-list changes')
 -- A roster burst refreshes player plates once, after a short delay.
 local iconDriver
 for _,f in ipairs(frames) do if f.events.GROUP_ROSTER_UPDATE then iconDriver=f end end
 check(iconDriver~=nil,'group icons subscribe to roster changes')
 local before=updateCalls
 for i=1,10 do iconDriver.scripts.OnEvent(iconDriver,'GROUP_ROSTER_UPDATE') end
 settle()
 check(updateCalls-before>=1 and updateCalls-before<=3,'roster burst coalesces into one player refresh')
 -- Battle.net: a friend whose game presence arrives after their plate was
 -- seen gets the icon when it does; other presence changes refresh nothing.
 A.SetOption('iconsFriend',false);A.SetOption('iconsGuild',false);A.SetOption('iconsBnet',true);settle()
 local bnetGuid=units.nameplate4.guid or UnitGUID('nameplate4')
 local online=false
 C_BattleNet={GetAccountInfoByGUID=function(guid) reads.bnet=reads.bnet+1;return online and guid==bnetGuid and {} or nil end,
  GetFriendAccountInfo=function(i) return i==3 and {gameAccountInfo={playerGuid=bnetGuid}} or {gameAccountInfo={playerGuid='Player-1-other'}} end}
 A.Update('nameplate4');settle()
 equal(pool[2].shown,false,'not yet linked to Battle.net: no sparkle')
 local bnDriver
 for _,f in ipairs(frames) do if f.events.BN_FRIEND_INFO_CHANGED then bnDriver=f end end
 check(bnDriver~=nil,'Battle.net icons subscribe to friend presence changes')
 online=true
 local quiet=updateCalls
 bnDriver.scripts.OnEvent(bnDriver,'BN_FRIEND_INFO_CHANGED',5);settle()
 equal(updateCalls,quiet,'another friend changing zones refreshes nothing')
 bnDriver.scripts.OnEvent(bnDriver,'BN_FRIEND_INFO_CHANGED',3);settle()
 check(updateCalls>quiet,'their presence arriving refreshes the plates')
 equal(pool[2].shown and pool[2].path,A.GlyphPath('sparkle'),'and the sparkle appears')
 A.SetOption('iconsBnet',false)
 for _,key in ipairs({'iconsParty','iconsFriend','iconsGuild'}) do A.SetOption(key,false) end
 A.SetOption('iconPosition','left');A.SetOption('iconSize',nil);settle()
 equal(pool[1].shown,false,'icons hidden when turned off')
 check(not iconDriver.events.GROUP_ROSTER_UPDATE,'turning icons off unsubscribes')
 p4.party,p4.guildmate=nil,nil
 UnitInParty,UnitInRaid,UnitIsInMyGuild,C_FriendList,C_BattleNet=nil,nil,nil,nil,nil
end
-- Immersion: unknown players as strangers or unlabeled; a key hides all labels.
do
 function UnitRace(u) return units[u] and 'Night Elf' end
 function UnitClass(u) return units[u] and 'Druid','DRUID' end
 function UnitFullName(u) local d=units[u];return d and d.name,d and d.realm end
 function GetNormalizedRealmName() return 'HomeRealm' end
 A.db.knownFriends=false -- the icons test cached this player as a friend
 A.Update('nameplate4')
 equal(state(pf).name.text,'Player','immersion off: name unchanged')
 A.SetOption('playerUnknownMode','stranger');settle()
 equal(state(pf).name.text,'Night Elf Druid','unknown player shown as race and class')
 A.SetOption('playerStrangerStyle','race');settle()
 equal(state(pf).name.text,'Night Elf','race only')
 A.SetOption('playerStrangerStyle','stranger');settle()
 equal(state(pf).name.text,'Stranger','plain stranger')
 C.AddPerson('Player');settle()
 equal(state(pf).name.text,'Player','People list members are known')
 C.db.people={}
 function UnitInParty(u) return u=='nameplate4' end
 A.Refresh();settle()
 equal(state(pf).name.text,'Player','group members are known')
 A.SetOption('knownGroup',false);settle()
 equal(state(pf).name.text,'Stranger','group can stop counting as known')
 A.SetOption('playerUnknownMode','hide');settle()
 equal(state(pf).overlay.shown,false,'unknown player can have no label')
 equal(pf.name.alpha,0,'hidden unknown player keeps the native name hidden')
 A.SetOption('knownGroup',true);A.SetOption('playerUnknownMode','name');A.SetOption('playerStrangerStyle','raceclass');settle()
 equal(state(pf).overlay.shown,true,'label back when immersion is off')
 A.ToggleLabels(true)
 equal(state(pf).name.alpha,0,'hide key fades every label out')
 A.ToggleLabels(false)
 check(state(pf).name.alpha>0,'hide key brings labels back')
 A.db.knownFriends=true
 UnitRace,UnitClass,UnitFullName,GetNormalizedRealmName,UnitInParty=nil,nil,nil,nil,nil
end
-- Wounded bars: health stays opaque; visibility comes from the curve result.
do
 local secret=setmetatable({}, {__lt=function() error('secret compared') end,__le=function() error('secret compared') end,__tostring=function() error('secret formatted') end})
 issecretvalue=function(v) return v==secret end
 local points
 C_CurveUtil={CreateCurve=function() points={};return {AddPoint=function(_,x,y) points[#points+1]={x,y} end} end}
 local realHealth,realMax=UnitHealth,UnitHealthMax
 local healthReads=0
 UnitHealth=function(u) healthReads=healthReads+1;return secret end
 UnitHealthMax=function(u) return secret end
 local percentCalls=0
 UnitHealthPercent=function(u,predicted,curve) percentCalls=percentCalls+1;assert(curve~=nil,'curve passed');return secret end
 A.Update('nameplate4')
 equal(healthReads,0,'wounded bars off: no health reads')
 equal(state(pf).overlay.wounded,nil,'wounded bars off: no bar created')
 A.SetOption('woundedPlayers',true);settle()
 local holder=state(pf).overlay.wounded
 check(holder and holder.shown,'wounded bar created for a friendly player')
 check(holder.bar.value==secret,'secret health goes straight to the bar')
 check(holder.bar.alpha==secret,'visibility comes from the secret curve result')
 equal(holder.rim,nil,'nothing drawn outside the bar (it would stay visible at full health)')
 check(holder.bar.rim~=nil,'the rim belongs to the bar')
 equal(points[2][1],0.999,'curve stays visible just below full health')
 equal(points[3][2],0,'curve hides the bar at full health')
 equal(holder.anchor[2],state(pf).name,'bar under the name without a guild line')
 equal(holder.bar.barColor[1],A.db.colors.wounded[1],'bar uses its own color by default')
 A.db.woundedColorMode='name';A.Refresh();settle()
 equal(holder.bar.barColor[1],state(pf).name.color[1],'bar can follow the name color')
 function UnitClass(u) return units[u] and 'Paladin','PALADIN' end
 RAID_CLASS_COLORS={PALADIN={r=.96,g=.55,b=.73}}
 A.db.woundedColorMode='class';A.Refresh();settle()
 equal(holder.bar.barColor[1],.96,'bar can follow the class color')
 A.PickWoundedColor()
 local popover=_G.ForeverNamesColorPopover
 check(popover.modeButtons[1].shown,'bar palette offers Class color / Name color')
 popover.modeButtons[1].scripts.OnClick()
 equal(A.db.woundedColorMode,'custom','clicking the selected Class color again returns to custom')
 UnitClass=nil
 local driver
 for _,f in ipairs(frames) do if f.events.UNIT_HEALTH and not f.unitFilters then driver=f end end
 check(driver~=nil,'wounded bars listen for health changes')
 local before=percentCalls
 driver.scripts.OnEvent(driver,'UNIT_HEALTH','nameplate4')
 equal(percentCalls,before+1,'health change updates that plate')
 driver.scripts.OnEvent(driver,'UNIT_HEALTH','nameplate999')
 equal(percentCalls,before+1,'unrelated units cost one table lookup')
 A.db.woundedPlayers=false;A.SetOption('woundedParty',true);settle()
 equal(holder.shown,false,'group-only mode skips non-members')
 function UnitInParty(u) return u=='nameplate4' end
 A.Refresh();settle()
 equal(holder.shown,true,'group-only mode shows members')
 A.SetOption('woundedParty',false);settle()
 equal(holder.shown,false,'bar hidden when turned off')
 check(not driver.events.UNIT_HEALTH,'turning off unsubscribes from health changes')
 UnitHealth,UnitHealthMax,UnitHealthPercent,C_CurveUtil,UnitInParty,issecretvalue=realHealth,realMax,nil,nil,nil,nil
end
-- Level fade: none on first paint, then a quick fade out / in on changes.
do
 local played={}
 local function anim(name) return {Stop=function() end,Play=function() played[#played+1]=name end} end
 local holder={SetShown=function(self,v) self.shown=v end,Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,SetAlpha=function(self,v) self.alpha=v end,fadeIn=anim('in'),fadeOut=anim('out')}
 A.ShowLevel(holder,true)
 check(holder.shown and #played==0,'first appearance: no fade')
 A.ShowLevel(holder,true);equal(#played,0,'no change: nothing plays')
 A.ShowLevel(holder,false);equal(played[1],'out','hiding fades out')
 A.ShowLevel(holder,true);equal(played[2],'in','showing fades in');equal(holder.alpha,0,'fade in starts transparent')
end
-- Key bindings: own section, and a level toggle.
equal(BINDING_CATEGORY_FOREVERNAMES,'Forever Names','bindings have their own section')
do
 local before=A.db.playerShowLevel
 ForeverNames_ToggleLevel();equal(A.db.playerShowLevel,not before,'level key toggles levels')
 ForeverNames_ToggleLevel();equal(A.db.playerShowLevel,before,'and back')
 settle()
end
-- People: account-wide list; lookups only while a People option is on.
do
 local fullNameReads=0
 function UnitFullName(u) fullNameReads=fullNameReads+1;local d=units[u];return d and d.name,d and d.realm end
 function GetNormalizedRealmName() return 'HomeRealm' end
 time,date=os.time,os.date
 local tipHooks,menuHooks={},{}
 TooltipDataProcessor={AddTooltipPostCall=function(kind,fn) tipHooks[#tipHooks+1]=fn end}
 Enum.TooltipDataType={Unit=2}
 Menu={ModifyMenu=function(tag,fn) menuHooks[tag]=fn end}
 local person,key=C.AddPerson('Player')
 equal(key,'player-homerealm','people are keyed Name-Realm, case-insensitive')
 equal(person.name,'Player-HomeRealm','home realm added to a typed name')
 local _,otherKey=C.AddPerson('Someone-Other Realm')
 equal(otherKey,'someone-otherrealm','typed realm loses spaces')
 A.Update('nameplate4')
 equal(fullNameReads,0,'People options off: no identity reads')
 equal(state(pf).name.text,'Player','People options off: plate unchanged')
 person.display='Lady Evening';person.glyph='moon';person.note='Met at the inn'
 C.SetOption('peopleRename',true);settle()
 equal(state(pf).name.text,'Lady Evening','display name replaces the name')
 C.SetOption('peopleIcons',true);settle()
 local pool=state(pf).overlay.icons
 check(pool and pool[1].shown,'People icon shown')
 equal(pool[1].path,C.GlyphPath('moon'),'People icon uses their glyph')
 equal(pool[1].tint[1],C.db.colors.people[1],'People icon uses the People color')
 local normal=pool[1].width
 person.iconSize=24;A.Refresh();settle()
 equal(pool[1].width,24,'a person can have a bigger icon')
 person.iconSize=nil;A.Refresh();settle()
 equal(pool[1].width,normal,'Auto returns to the normal size')
 function UnitInParty(u) return units[u] and units[u].party or false end
 units.nameplate4.party=true;A.SetOption('iconsParty',true);settle()
 equal(pool[1].path,C.GlyphPath('moon'),'People icon comes before relationship icons')
 equal(pool[2].path,A.GlyphPath('party'),'relationship icon follows')
 equal(pool[1].anchor[1],'RIGHT','People icon before the name by default')
 A.SetOption('peopleIconSide','right');settle()
 equal(pool[1].anchor[1],'LEFT','People icon can sit after the name')
 equal(pool[1].anchor[2],state(pf).name,'alone, right after the name')
 equal(pool[2].anchor[1],'RIGHT','relationship icons stay before the name')
 equal(pool[2].anchor[2],state(pf).name,'relationship icons restart next to the name')
 A.SetOption('peopleIconSide','same');settle()
 equal(pool[2].anchor[2],pool[1],'like other icons: one row again')
 C.SetOption('peopleLastSeen',true);settle()
 check(person.seen~=nil,'last seen recorded')
 local stamp=person.seen;person.seen=stamp;A.Update('nameplate4')
 equal(person.seen,stamp,'last seen is not rewritten on every render')
 C.SetOption('peopleTooltip',true)
 equal(#tipHooks,1,'tooltip note installs one post-call')
 local lines={}
 local tip={GetUnit=function() return 'Player','nameplate4' end,AddLine=function(_,text) lines[#lines+1]=text end}
 tipHooks[1](tip)
 check(lines[1] and lines[1]:find('Lady Evening',1,true),'tooltip shows the display name')
 equal(lines[2],'Met at the inn','tooltip shows the note')
 person.note=nil;lines={};tipHooks[1](tip)
 check(#lines>=1 and lines[#lines]:find('Last seen',1,true),'no note but seen: tooltip still shows last seen')
 local seenAt=person.seen;person.seen=nil;lines={};tipHooks[1](tip)
 equal(#lines,0,'no note and never seen: no tooltip lines')
 person.seen=seenAt
 person.note='Met at the inn'
 C.SetOption('peopleTooltip',false);lines={};tipHooks[1](tip)
 equal(#lines,0,'tooltip note off: nothing added')
 check(menuHooks.MENU_UNIT_PLAYER==nil,'menu entry off: menus untouched')
 C.SetOption('peopleMenu',true)
 check(menuHooks.MENU_UNIT_PLAYER~=nil,'menu entry installs on player menus')
 local buttons={}
 local root={CreateDivider=function() end,CreateButton=function(_,text,fn) buttons[#buttons+1]={text=text,fn=fn} end}
 menuHooks.MENU_UNIT_PLAYER(nil,root,{name='Newcomer'})
 equal(buttons[1].text,'Add to Companion Journal','menu offers to add an unknown player')
 buttons[1].fn()
 check(C.db.people['newcomer-homerealm']~=nil,'menu adds the player')
 buttons={};menuHooks.MENU_UNIT_PLAYER(nil,root,{name='Newcomer'})
 equal(buttons[1].text,'Edit in Companion Journal','menu offers to edit a known player')
 InputUtil={IsGamepadUIEnabled=function() return true end}
 buttons={};menuHooks.MENU_UNIT_PLAYER(nil,root,{name='Newcomer'})
 equal(#buttons,0,'gamepad interface: no menu entry (the game blocks it there)')
 InputUtil=nil
 units.target={id='77',name='Bound',realm='Faraway',player=true}
 CompanionJournal_TagTarget()
 check(C.db.people['bound-faraway']~=nil,'key binding adds the target')
 units.target=nil
 -- Settings list shows people and removes with a confirming second click.
 C.OpenOptions();C.SelectPerson('player-homerealm')
 check(C.options.shown,'Companion Journal has its own window with the list')
 -- Social actions use the real name, and keep their recipient if rows are recycled.
 do
  local oldMenu,oldFriends,oldChat,oldParty=MenuUtil,C_FriendList,ChatFrameUtil,C_PartyInfo
  local menu,calls,menuCount={}, {},0
  MenuUtil={CreateContextMenu=function(owner,generate)
   menuCount=menuCount+1;menu={}
   generate(owner,{CreateTitle=function(_,name) menu.title=name end,CreateDivider=function() end,CreateButton=function(_,label,fn)
    local item={label=label,fn=fn,SetEnabled=function(self,on) self.enabled=on end}
    menu[#menu+1]=item;return item
   end})
  end}
  C_FriendList={AddFriend=function(name) calls.friend=name end}
  ChatFrameUtil={SendTell=function(name) calls.whisper=name end}
  C_PartyInfo={InviteUnit=function(name) calls.invite=name end}
  local row
  for _,f in ipairs(frames) do if f.key=='player-homerealm' and f.detail then row=f end end
  check(row and row.clicks[2]=='RightButtonUp','People row accepts right click')
  row.scripts.OnClick(row,'LeftButton');equal(menuCount,0,'left click only selects')
  C.CloseJournal()
  row.scripts.OnDoubleClick(row,'LeftButton')
  check(CompanionJournalBook and CompanionJournalBook:IsShown(),'double-click opens their journal')
  equal(CompanionJournalBook.paper.atlas,'QuestBG-Parchment','companions: clean parchment')
  do
   local person=C.db.people[row.key]
   local circle,faction=person.circle,person.faction
   person.faction='Horde';C.RefreshJournal()
   equal(CompanionJournalBook.paper.atlas,'QuestBG-Parchment','a Horde companion keeps the clean parchment')
   person.circle,person.faction='rival','Alliance';C.RefreshJournal()
   equal(CompanionJournalBook.paper.atlas,'QuestBG-Alliance','rivals get their faction paper')
   person.circle,person.faction=circle,faction
  end
  C.CloseJournal()
  row.scripts.OnClick(row,'RightButton')
  equal(#menu,4,'right click offers three social actions and the journal')
  equal(menu[4].label,'Open journal','journal entry follows the social actions')
  equal(menu.title,'Player-HomeRealm','menu identifies actual character despite display name')
  check(next(calls)==nil,'opening menu performs no social action')
  local key=row.key;row.key='bound-faraway'
  for i=1,3 do local item=menu[i]; check(item.enabled,'available social action enabled');item.fn() end
  menu[4].fn()
  check(CompanionJournalBook and CompanionJournalBook:IsShown(),'journal entry opens the journal')
  -- A long entry wraps: the next entry starts below both of its lines.
  do
   local realChapters=C.JournalChapters
   local long=string.rep('You completed a long list of quests together. ',3)
   C.JournalChapters=function() return {{title='Day one',lines={{text=long,entry={}},{text='Short line.',entry={}}}}} end
   C.RefreshJournal()
   local lines=CompanionJournalBook.lines
   check(lines[2].height>=2*14,'a wrapped entry is measured at its real width (two lines or more)')
   equal(lines[3].anchor[3],lines[2].anchor[3]-lines[2].height-5,'the next entry starts below the wrapped one')
   C.JournalChapters=realChapters
  end
  row.key=key
  equal(calls.friend,'Player-HomeRealm','friend action keeps original character')
  equal(calls.whisper,'Player-HomeRealm','whisper keeps original character')
  equal(calls.invite,'Player-HomeRealm','invite keeps original character')
  local count=menuCount
  C.db.people['npc:987654']={name='Test NPC',npc=true}
  C.OpenPersonMenu(row,'npc:987654');C.OpenPersonMenu(row,'missing')
  equal(menuCount,count,'NPC and absent entries have no social menu')
  InputUtil={IsGamepadUIEnabled=function() return true end}
  C.OpenPersonMenu(row,row.key)
  equal(menuCount,count,'gamepad interface: no addon menu (it taints gamepad focus)')
  InputUtil=nil
  C.db.people['npc:987654']=nil
  MenuUtil,C_FriendList,ChatFrameUtil,C_PartyInfo=oldMenu,oldFriends,oldChat,oldParty
 end
 local optionsButton,listCard
 for _,f in ipairs(frames) do if f.text=='Options' and f.kind=='Button' then optionsButton=f end end
 optionsButton.scripts.OnClick()
 local optionsView
 for _,f in ipairs(frames) do if f.Text and f.Text.text=='Everyone I group with, as acquaintances' then optionsView=f.parent.parent end end
 check(optionsView and optionsView.shown,'People options open in the People tab')
 C.SelectPerson('player-homerealm')
 equal(optionsView.shown,false,'selecting a person returns to the list')
 local autoButton
 for _,f in ipairs(frames) do if f.text=='Auto' and f.kind=='Button' and f.anchor and f.anchor[2]==342 then autoButton=f end end
 local plus
 for _,f in ipairs(frames) do if f.text=='+' and f.anchor and f.anchor[2]==314 and f.anchor[3]==-112 then plus=f end end
 plus.scripts.OnClick()
 check(C.db.people['player-homerealm'].iconSize~=nil,'size + sets the icon size for this person')
 autoButton.scripts.OnClick()
 equal(C.db.people['player-homerealm'].iconSize,nil,'Auto clears it')
 local remove
 for _,f in ipairs(frames) do if f.text=='Remove' and f.kind=='Button' then remove=f end end
 C.SelectPerson('player-homerealm')
 remove.scripts.OnClick()
 check(C.db.people['player-homerealm']~=nil,'first Remove click only arms it')
 remove.scripts.OnClick()
 equal(C.db.people['player-homerealm'],nil,'second click removes')
 local nextSelected
 for _,f in ipairs(frames) do if f.key and f.detail and f.wash and f.wash.shown and f.shown then nextSelected=f.key end end
 check(nextSelected~=nil and nextSelected~='player-homerealm','after removing, another entry is selected')
 -- On a clean list: the next one, or the previous one at the end.
 local saved=C.db.people
 C.db.people={}
 C.AddPerson('Ann');C.AddPerson('Ben');C.AddPerson('Cal')
 local function selectedRow()
  for _,f in ipairs(frames) do if f.key and f.detail and f.wash and f.wash.shown and f.shown then return f.key end end
 end
 C.SelectPerson('ben-homerealm')
 remove.scripts.OnClick();remove.scripts.OnClick()
 equal(selectedRow(),'cal-homerealm','removing selects the next entry')
 remove.scripts.OnClick();remove.scripts.OnClick()
 equal(selectedRow(),'ann-homerealm','at the end of the list the previous one is selected')
 -- Never add again from the editor, then Allow again from the Blocked view.
 C.db.people={};C.AddPerson('Dee');C.AddPerson('Eve')
 C.SelectPerson('dee-homerealm')
 local never,allow,showList
 for _,f in ipairs(frames) do
  if f.kind=='Button' and f.text=='Never add again' then never=f end
  if f.kind=='Button' and f.text=='Allow again' then allow=f end
  if f.kind=='Button' and f.text=='Show the list' then showList=f end
 end
 never.scripts.OnClick()
 check(C.db.people['dee-homerealm']~=nil,'first Never add again click only arms it')
 never.scripts.OnClick()
 check(C.db.people['dee-homerealm']==nil and C.db.peopleBlocked['dee-homerealm'],'second click removes and blocks')
 equal(selectedRow(),'eve-homerealm','the next entry is selected')
 showList.scripts.OnClick()
 local blockedRow
 for _,f in ipairs(frames) do if f.key=='dee-homerealm' and f.detail and f.shown then blockedRow=f end end
 check(blockedRow~=nil,'the Blocked view lists blocked people')
 blockedRow.scripts.OnClick(blockedRow)
 allow.scripts.OnClick()
 equal(C.db.peopleBlocked['dee-homerealm'],nil,'Allow again unblocks')
 C.db.people=saved
 settle()
 equal(state(pf).name.text,'Player','removed person renders normally again')
 for _,k in ipairs({'peopleRename','peopleIcons','peopleLastSeen','peopleMenu'}) do C.SetOption(k,false) end
 A.SetOption('iconsParty',false)
 C.db.people={};units.nameplate4.party=nil
 UnitFullName,GetNormalizedRealmName,UnitInParty,TooltipDataProcessor,Menu=nil,nil,nil,nil,nil
 A.CloseOptions=nil;A.options:Hide();C.options:Hide()
 settle()
end
-- Icon colors can follow the class or the name; NPCs can join People.
do
 function UnitClass(u) return units[u] and 'Paladin','PALADIN' end
 RAID_CLASS_COLORS={PALADIN={r=.96,g=.55,b=.73}}
 function UnitInParty(u) return u=='nameplate4' end
 A.SetOption('iconsParty',true);settle()
 local pool=state(pf).overlay.icons
 equal(pool[1].tint[1],A.db.colors.icon_party[1],'icon uses its own color by default')
 A.db.iconColorModes.party='name';A.Refresh();settle()
 equal(pool[1].tint[1],state(pf).name.color[1],'icon can follow the name color')
 A.db.playerColorMode='custom';A.Refresh();settle()
 equal(pool[1].tint[1],A.db.colors.friendlyPlayer[1],'name-colored icon follows a custom name color')
 A.db.iconColorModes.party='class';A.Refresh();settle()
 equal(pool[1].tint[1],.96,'icon can follow the class color')
 -- Palette offers the two modes; choosing one closes it and saves the mode.
 A.PickIconColor('party')
 local popover=_G.ForeverNamesColorPopover
 check(popover.modeButtons[1].shown,'palette shows Class color / Name color for icons')
 popover.modeButtons[2].scripts.OnClick()
 equal(A.db.iconColorModes.party,'name','Name color chosen from the palette')
 check(not popover.shown,'choosing a mode closes the palette')
 A.PickIconColor('party');popover.modeButtons[2].scripts.OnClick()
 equal(A.db.iconColorModes.party,'custom','clicking the selected mode again returns to the custom color')
 equal(popover.done.anchor[3],-236,'with follow choices the actions sit below them')
 A.PickIconColor('party');popover.swatches[1].scripts.OnClick();popover.done.scripts.OnClick()
 equal(A.db.iconColorModes.party,'custom','picking a swatch returns to a custom color')
 A.PickRoleColor('vendor');check(not popover.modeButtons[1].shown,'plain colors do not offer modes')
 equal(popover.done.anchor[3],-202,'without them the actions sit under R/G/B');popover:Cancel()
 A.db.playerColorMode='blizzard';A.db.iconColorModes.party='custom'
 A.SetOption('iconsParty',false)
 -- A plain townsperson (normally unlabeled) joins People.
 local tom,tf=spawn('nameplate820',{id='820',name='Old Tom'});settle()
 equal(state(tf).overlay.shown,false,'townsperson unlabeled by default')
 local person,key=C.AddNPCPerson('820','Old Tom')
 equal(key,'npc:820','NPCs are keyed by NPC ID')
 settle()
 equal(state(tf).overlay.shown,false,'People options off: still unlabeled')
 person.display='Tom the Ferryman';person.glyph='flag';person.colorMode='name'
 C.SetOption('peopleRename',true);C.SetOption('peopleIcons',true);settle()
 equal(state(tf).overlay.shown,true,'People NPC gets a label')
 equal(state(tf).name.text,'Tom the Ferryman','People NPC display name')
 local npcPool=state(tf).overlay.icons
 equal(npcPool[1].path,C.GlyphPath('flag'),'People NPC icon')
 equal(npcPool[1].tint[1],state(tf).name.color[1],'NPC icon can follow the name color')
 units.target={id='821',name='Harbor Cat'}
 local added,addedKey=C.AddTargetPerson()
 C.options:Hide()
 SlashCmdList.COMPANIONJOURNAL('')
 check(C.options.shown,'/cj opens Companion Journal')
 local function Picked()
  for _,f in ipairs(frames) do if f.key==addedKey and f.wash and f.wash.shown and f.shown then return true end end
  return false
 end
 check(Picked(),'with a target from the list, /cj opens straight to them')
 -- Window open: targeting someone from the list jumps to them; others change nothing.
 C.SelectPeopleCircle('companion')
 units.target={id='999',name='Stranger NPC'}
 local follow=C.optionsTargetFollower
 follow.scripts.OnEvent(follow,'PLAYER_TARGET_CHANGED')
 check(not Picked(),'targeting someone not in the list selects nobody')
 units.target={id='821',name='Harbor Cat'}
 follow.scripts.OnEvent(follow,'PLAYER_TARGET_CHANGED')
 check(Picked(),'targeting a list entry while the window is open jumps to it')
 C.options:Hide()
 -- Forever Names' window: People is a link to Companion Journal, and the
 -- window reopens on the page you used last.
 A.db.optionsPage=2;A.options:Hide();SlashCmdList.FOREVERNAMES('')
 equal(A.db.optionsPage,2,'Forever Names reopens on the last page')
 SlashCmdList.FOREVERNAMES('people')
 check(C.options.shown,'/fnames people opens Companion Journal')
 C.options:Hide();A.options:Hide()
 units.target={id='821',name='Harbor Cat'}
 equal(addedKey,'npc:821','Add my target also takes NPCs')
 equal(added.npc,true,'NPC entries are marked')
 -- "/fnames hidenpc" hides the targeted NPC's label; "/fnames hide" is the key
 -- that hides every label. Both used to share one command.
 local labelsWere=A.labelsHidden
 SlashCmdList.FOREVERNAMES('hidenpc')
 equal(A.db.overrides['821'],'hide','/fnames hidenpc records a hide override for the target')
 equal(A.labelsHidden,labelsWere,'/fnames hidenpc leaves the hide-all key alone')
 SlashCmdList.FOREVERNAMES('auto')
 equal(A.db.overrides['821'],nil,'/fnames auto clears the override')
 units.target=nil
 C.RemovePerson('npc:820');settle()
 equal(state(tf).overlay.shown,false,'removed NPC goes back to unlabeled')
 C.SetOption('peopleRename',false);C.SetOption('peopleIcons',false)
 C.db.people={}
 UnitClass,UnitInParty=nil,nil
end
-- People categories: companions, acquaintances (auto from groups), NPCs.
do
 function UnitFullName(u) local d=units[u];return d and d.name,d and d.realm end
 function GetNormalizedRealmName() return 'HomeRealm' end
 function GetNumGroupMembers() return 3 end
 function IsInRaid() return false end
 units.party1={id='901',name='Brin',player=true}
 units.party2={id='902',name='Player',player=true}
 C.db.people={}
 C.AddPerson('Player')
 equal(C.PersonCircle(C.db.people['player-homerealm']),'companion','added by hand = companion')
 C.db.peopleGroupIcon=true
 equal(C.RecordGroup(),0,'auto-add off: groups are not recorded')
 C.SetOption('peopleAutoGroup',true)
 local brin=C.db.people['brin-homerealm']
 check(brin~=nil,'turning auto-add on records the current group')
 equal(brin.glyph,'party','groupmates get the group icon by default')
 brin.glyph=nil
 equal(C.PersonCircle(brin),'acquaintance','groupmates become acquaintances')
 check(brin.met~=nil,'acquaintances remember when they were met')
 equal(C.PersonCircle(C.db.people['player-homerealm']),'companion','companions are never demoted')
 equal(C.IconGlyph('people',brin),'none','acquaintances start without an icon')
 -- The list shows one category at a time.
 C.OpenOptions();C.SelectPerson('brin-homerealm')
 local visible={}
 for _,f in ipairs(frames) do if f.key and f.shown and f.kind=='Button' then visible[f.key]=true end end
 check(visible['brin-homerealm'] and not visible['player-homerealm'],'Acquaintances tab lists only acquaintances')
 C.MovePerson('brin-homerealm','companion')
 equal(C.PersonCircle(brin),'companion','acquaintance moved to companions')
 C.MovePerson('brin-homerealm','acquaintance')
 C.AddNPCPerson('555','Gate Guard')
 C.MovePerson('npc:555','companion')
 equal(C.PersonCircle(C.db.people['npc:555']),'npc','NPCs stay in the NPC category')
 -- Icons are per person: acquaintances start with none.
 C.SetOption('peopleIcons',true)
 equal(C.IconGlyph('people',brin),'none','acquaintances start without an icon')
 check(A.PlayerIcons('party1',nil,brin)==nil,'no icon for a person without one')
 brin.glyph='star'
 local icons=A.PlayerIcons('party1',nil,brin)
 equal(icons and icons[1],'people','giving one person an icon shows it')
 C.SetOption('peopleNewGlyph','none')
 local quiet=C.AddPerson('Quiet')
 equal(quiet.glyph,'none','new entries can start without an icon')
 C.SetOption('peopleNewGlyph','moon')
 equal(C.AddPerson('Moony').glyph,'moon','new entries start with the chosen icon')
 C.db.peopleNewGlyph=nil
 local loud=C.AddPerson('Loud')
 equal(C.IconGlyph('people',loud),'diamond','new entries start with the diamond by default')
 -- Never add again: removed, skipped by auto-add, allowed again by hand.
 C.BlockPerson('brin-homerealm')
 equal(C.db.people['brin-homerealm'],nil,'never add again removes them')
 C.RecordGroup()
 equal(C.db.people['brin-homerealm'],nil,'group adding skips blocked people')
 C.UnblockPerson('brin-homerealm');C.RecordGroup()
 check(C.db.people['brin-homerealm']~=nil,'allowed again: group adding adds them')
 C.BlockPerson('brin-homerealm');C.AddPerson('Brin')
 check(C.db.people['brin-homerealm'] and not C.db.peopleBlocked['brin-homerealm'],'adding by hand allows them again')
 C.MovePerson('brin-homerealm','acquaintance')
 C.db.peopleGroupIcon=false;C.db.people['brin-homerealm']=nil;C.RecordGroup()
 equal(C.db.people['brin-homerealm'].glyph,nil,'group icon can be turned off')
 C.RemoveAcquaintances()
 equal(C.db.people['brin-homerealm'],nil,'remove all acquaintances')
 check(C.db.people['player-homerealm'] and C.db.people['npc:555'],'companions and NPCs kept')
 for _,k in ipairs({'peopleAutoGroup','peopleIcons'}) do A.SetOption(k,false) end
 C.db.people={};units.party1,units.party2=nil,nil
 UnitFullName,GetNormalizedRealmName,GetNumGroupMembers,IsInRaid=nil,nil,nil,nil
end
-- Campfire (experimental): players sitting at the fire with you.
do
 function UnitFullName(u) local d=units[u];return d and d.name,d and d.realm end
 function GetNormalizedRealmName() return 'HomeRealm' end
 local auraReads=0
 C_UnitAuras={GetUnitAuraBySpellID=function(u,id) auraReads=auraReads+1;return units[u] and units[u].campfire and id==1229739 and {spellId=id} or nil end}
 units.player={id='1',name='Me',player=true}
 C.db.people={}
 C.db.peopleCampfireIcon=false
 local driver
 for _,f in ipairs(frames) do if f.unitFilters and f.unitFilters.UNIT_AURA then driver=f end end
 check(driver==nil or not driver.events.UNIT_AURA,'campfire off: no aura subscription')
 C.SetOption('peopleAutoCampfire',true)
 for _,f in ipairs(frames) do if f.unitFilters and f.unitFilters.UNIT_AURA and f.events.UNIT_AURA then driver=f end end
 check(driver~=nil,'campfire on: listens to your own auras only')
 driver.scripts.OnEvent(driver,'UNIT_AURA','player')
 for i=1,2200 do tick(.03) end
 equal(C.db.people['player-homerealm'],nil,'not sitting: nobody is added')
 units.player.campfire=true;units.nameplate4.campfire=true
 driver.scripts.OnEvent(driver,'UNIT_AURA','player')
 for i=1,200 do tick(.03) end
 local buddy=C.db.people['player-homerealm']
 check(buddy~=nil,'a player sitting at the fire with you is added')
 equal(C.PersonCircle(buddy),'campfire','added to Campfire')
 check(C.DescribeMet(buddy):find('by the campfire',1,true),'met by the campfire')
 equal(C.IconGlyph('people',buddy),'none','campfire entries start without an icon')
 C.db.people={};C.SetOption('peopleCampfireIcon',true)
 C.ScanCampfire()
 buddy=C.db.people['player-homerealm']
 equal(buddy.glyph,'fire','added at the campfire with the fire icon')
 equal(buddy.color[1],C.db.colors.campfire[1],'in the campfire orange')
 C.SetOption('peopleCampfireIcon',false)
 C.MovePerson('player-homerealm','companion')
 equal(C.PersonCircle(buddy),'companion','campfire entry moved to companions')
 units.player.campfire=nil;driver.scripts.OnEvent(driver,'UNIT_AURA','player')
 local reads=auraReads
 for i=1,2200 do tick(.03) end
 equal(auraReads,reads,'standing up stops the remaining scans')
 C.SetOption('peopleAutoCampfire',false)
 check(not driver.events.UNIT_AURA,'campfire off unsubscribes')
 C.db.people={};units.player,units.nameplate4.campfire=nil,nil
 UnitFullName,GetNormalizedRealmName,C_UnitAuras=nil,nil,nil
end
-- Player label extras: each read happens only while its option is on, so with
-- every extra off the player label is exactly the pre-1.7 label.
do
 local reads={guild=0,title=0,class=0}
 function GetGuildInfo(u) reads.guild=reads.guild+1;local d=units[u];return d and d.guild,d and d.rank end
 function UnitPVPName(u) reads.title=reads.title+1;local d=units[u];return d and (d.pvp or d.name) end
 function UnitClass(u) reads.class=reads.class+1;local d=units[u];return d and 'Paladin',d and 'PALADIN' end
 RAID_CLASS_COLORS={PALADIN={r=.96,g=.55,b=.73}}
 local realLevel,crowdLevels=UnitLevel,0
 UnitLevel=function(u) if u~='target' then crowdLevels=crowdLevels+1 end;return units[u] and units[u].level end
 local p4=units.nameplate4
 p4.guild,p4.rank,p4.pvp,p4.level='Silver Hand','Officer','Sergeant Player',42
 A.Update('nameplate4')
 equal(reads.guild+reads.title+reads.class,0,'extras off: no guild, title or class reads')
 equal(crowdLevels,0,'extras off: no crowd level reads')
 equal(state(pf).overlay.level,nil,'extras off: no level text is created')
 check(not events.events.UNIT_LEVEL,'extras off: no level event subscription')
 A.db.playerShowGuild=true;A.Update('nameplate4')
 equal(state(pf).title.text,'<Silver Hand>','guild shown under the name')
 equal(state(pf).title.shown,true,'guild line visible')
 A.db.playerShowGuildRank=true;A.Update('nameplate4')
 equal(state(pf).title.text,'Officer of <Silver Hand>','guild rank shown')
 A.db.playerShowTitle=true;p4.surname='Strikes';A.Update('nameplate4')
 equal(state(pf).name.text,'Sergeant Player Strikes','title keeps the full name')
 p4.pvp='Player Strikes';A.Update('nameplate4')
 equal(state(pf).name.text,'Player Strikes','untitled full name from the game is not doubled')
 p4.pvp='Sergeant Player Strikes';A.Update('nameplate4')
 equal(state(pf).name.text,'Sergeant Player Strikes','titled full name from the game is used as is')
 A.SetOption('playerShowLevel',true);settle()
 check(events.events.UNIT_LEVEL,'level option subscribes to level changes')
 equal(state(pf).overlay.level.text,'42','level after the name')
equal(state(pf).overlay.levelHolder.levelBadge,nil,'plain level creates no badge textures')
 equal(state(pf).overlay.level.anchor[1],'LEFT','level sits after the name by default')
 A.SetOption('playerLevelStyle','default');settle()
 local badge=state(pf).overlay.levelHolder.levelBadge
 check(badge and badge.fill.shown and badge.rim.shown,'Default pill draws a bordered badge')
 equal(badge.art.shown,false,'Default pill does not use the Classic artwork')
 A.SetOption('playerLevelStyle','classic');settle()
 equal(badge.art.shown,true,'Classic pill uses the native level artwork')
 A.SetOption('playerLevelSide','left');settle()
 equal(state(pf).overlay.level.anchor[1],'RIGHT','level can sit before the name')
 equal(state(pf).overlay.level.anchor[3],'LEFT','level anchors to the name start')
 A.SetOption('playerLevelSize',20);settle()
 equal(state(pf).overlay.level.fontHeight,20,'custom level size')
 A.SetOption('playerLevelSize',nil);A.SetOption('playerLevelSide','right');A.SetOption('playerLevelStyle','plain');settle()
 equal(badge.fill.shown,false,'Plain hides the badge again')
 equal(state(pf).overlay.level.anchor[1],'LEFT','level back after the name')
 equal(state(pf).overlay.levelHolder.shown,true,'level visible')
 equal(state(pf).overlay.level.color[1],state(pf).name.color[1],'level uses the name color')
 -- Nearby-only levels: far players hide the number; the selected one keeps it.
 local distanceReads=0
 function CheckInteractDistance(u,index) distanceReads=distanceReads+1;return units[u] and units[u].near==true end
 A.SetOption('playerLevelScope','near');settle()
 equal(state(pf).overlay.levelHolder.shown,false,'far player: level hidden')
 equal(state(pf).name.text~=nil,true,'far player keeps the name')
 p4.near=true;for i=1,40 do tick(.03) end;settle()
 equal(state(pf).overlay.levelHolder.shown,true,'walking close shows the level')
 p4.near=false;for i=1,40 do tick(.03) end;settle()
 equal(state(pf).overlay.levelHolder.shown,false,'walking away hides it again')
 local barWas=A.db.targetHealthBar;A.db.targetHealthBar=false
 units.target=p4;emit('PLAYER_TARGET_CHANGED');settle()
 equal(state(pf).overlay.levelHolder.shown,true,'selected player always shows the level')
 units.target=nil;emit('PLAYER_TARGET_CHANGED');settle()
 A.db.targetHealthBar=barWas
 C_Item={IsItemInRange=function(item,u) assert(item==1251,'15 yd uses the bandage probe');return units[u] and units[u].near15==true end}
 A.db.playerLevelRange=15;A.Refresh();settle()
 equal(state(pf).overlay.levelHolder.shown,false,'15 yd: far player hides the level')
 p4.near15=true;for i=1,40 do tick(.03) end;settle()
 equal(state(pf).overlay.levelHolder.shown,true,'15 yd: within range shows it')
 A.db.playerLevelRange=3;C_Item=nil;p4.near15=nil
 A.SetOption('playerLevelScope','target');settle()
 equal(state(pf).overlay.levelHolder.shown,false,'selected only: other players hide the level')
 A.db.targetHealthBar=false;units.target=p4;emit('PLAYER_TARGET_CHANGED');settle()
 equal(state(pf).overlay.levelHolder.shown,true,'selected only: the selected player shows it')
 units.target=nil;emit('PLAYER_TARGET_CHANGED');settle();A.db.targetHealthBar=barWas
 A.SetOption('playerLevelScope','all');settle()
 equal(state(pf).overlay.levelHolder.shown,true,'option off: every level shows')
 local reads=distanceReads
 for i=1,400 do tick(.03) end
 equal(distanceReads,reads,'option off: no distance checks run')
 CheckInteractDistance=nil;p4.near=nil
 p4.level=43;emit('UNIT_LEVEL','nameplate4');settle()
 equal(state(pf).overlay.level.text,'43','level change updates the plate')
 p4.level=-1;emit('UNIT_LEVEL','nameplate4');settle()
 equal(state(pf).overlay.level.text,'??','unknown level shows ??')
 A.db.playerColorMode='class';A.Update('nameplate4')
 equal(state(pf).name.color[1],.96,'class color mode')
 equal(state(pf).overlay.level.color[1],.96,'level follows a name color change')
 A.db.playerLevelColorMode='custom';A.db.colors.playerLevel={.1,.2,.3};A.Update('nameplate4')
 equal(state(pf).overlay.level.color[1],.1,'custom level color')
 equal(state(pf).name.color[1],.96,'custom level color leaves the name alone')
 A.db.playerColorMode='blizzard';A.db.playerLevelColorMode='class';A.Update('nameplate4')
 equal(state(pf).overlay.level.color[1],.96,'class level color with Blizzard name color')
 equal(state(pf).name.color[1],.2,'name keeps Blizzard color')
 A.db.playerLevelColorMode='name';A.Update('nameplate4')
 equal(state(pf).overlay.level.color[1],.2,'level back to the name color')
 A.db.playerColorMode='class';A.Update('nameplate4')
 A.db.playerColorMode='custom';A.Update('nameplate4')
 equal(state(pf).name.color[1],A.db.colors.friendlyPlayer[1],'custom color mode')
 -- Guildless (or not yet loaded) players: bounded retries, then silence.
 p4.guild=nil
 local before=updateCalls
 emit('UNIT_NAME_UPDATE','nameplate4');for i=1,400 do tick(.03) end
 equal(updateCalls-before,4,'missing guild gets at most three retries')
 equal(state(pf).title.shown,false,'no guild line without a guild')
 A.SetOption('playerShowLevel',false)
 check(not events.events.UNIT_LEVEL,'level option off unsubscribes')
 A.db.playerShowGuild,A.db.playerShowGuildRank,A.db.playerShowTitle,A.db.playerColorMode=false,false,false,'blizzard'
 A.Refresh();settle()
 equal(state(pf).overlay.levelHolder.shown,false,'level hidden when turned off')
 equal(state(pf).name.text,'Player Strikes','title removed when turned off')
 equal(state(pf).name.color[1],.2,'Blizzard color restored')
 p4.surname,p4.guild,p4.rank,p4.pvp,p4.level=nil,nil,nil,nil,nil
 UnitLevel=realLevel;GetGuildInfo,UnitPVPName,UnitClass=nil,nil,nil
 A.Update('nameplate4')
end
local hostilePlayer,hpf=spawn('nameplate6',{id='60',name='Hostile player',player=true,enemy=true});settle()
equal(state(hpf),nil,'enemy player remains native')
-- Enemy tab: opposite-faction players (untouched while it is off).
do
 local flagged=false
 function UnitFactionGroup(u) if u=='player' then return 'Alliance' end;local d=units[u];return d and (d.faction or (d.enemy and 'Horde' or 'Alliance')) end
 function UnitIsPVP(u) if u=='player' then return flagged end;return units[u] and units[u].pvp or false end
 function UnitRace(u) return units[u] and 'Orc' end
 function UnitClass(u) return units[u] and 'Warrior','WARRIOR' end
 function UnitFullName(u) local d=units[u];return d and d.name,d and d.realm end
 function GetNormalizedRealmName() return 'HomeRealm' end
 local enemyUnit=units.nameplate6
 A.Update('nameplate6')
 equal(state(hpf),nil,'Enemy tab off: enemy plate untouched')
 A.SetOption('enemyEnabled',true);settle()
 check(state(hpf)~=nil,'not flagged: our label on the enemy plate')
 equal(state(hpf).name.text,'Hostile player','enemy name shown')
 equal(hpf.HealthBarsContainer.alpha,0,'not flagged: Blizzard bars hidden')
 equal(state(hpf).name.color[1],A.factionColors.Horde[1],'faction color by default')
 -- A name the game hides from addons: Blizzard's plate stays.
 do
  local secretName=setmetatable({}, {__eq=function() error('secret compared') end,__concat=function() error('secret concatenated') end})
  local realUnitName,realSecret=UnitName,issecretvalue
  issecretvalue=function(v) return v==secretName end
  UnitName=function(u) if u=='nameplate6' then return secretName end;return realUnitName(u) end
  A.Update('nameplate6')
  equal(state(hpf),nil,'hidden enemy name: Blizzard plate stays')
  equal(hpf.name.alpha,1,'hidden enemy name: Blizzard name visible')
  UnitName,issecretvalue=realUnitName,realSecret
  A.Update('nameplate6')
  check(state(hpf)~=nil,'readable name again: our label')
 end
 -- Flagged: Blizzard's plates by default, or our name on their bars.
 flagged=true;emit('UNIT_FACTION','player');settle()
 equal(state(hpf),nil,'flagged: Blizzard enemy plates')
 equal(hpf.HealthBarsContainer.alpha,1,'flagged: native bars back')
 A.SetOption('enemyFlaggedStyle','names');settle()
 check(state(hpf)~=nil and state(hpf).keepBars,'flagged + names: our name on their plate')
 equal(hpf.HealthBarsContainer.alpha,1,'flagged + names: Blizzard bars kept')
 equal(hpf.name.alpha,0,'flagged + names: Blizzard name replaced')
 A.SetOption('enemyFlaggedStyle','native');flagged=false;emit('UNIT_FACTION','player');settle()
 equal(hpf.HealthBarsContainer.alpha,0,'unflagging hides the bars again')
 -- Icons: faction emblem, and crossed swords when their flag is on.
 A.SetOption('enemyFactionIcon',true);enemyUnit.pvp=true;A.SetOption('enemyPvpIcon',true);settle()
 local pool=state(hpf).overlay.icons
 equal(pool[1].path,'UI-HUD-UnitFrame-Player-PVP-HordeIcon','faction emblem')
 equal(pool[2].path,A.GlyphPath('swords'),'crossed swords when their PvP flag is on')
 enemyUnit.pvp=nil;A.Refresh();settle()
 equal(pool[2].shown,false,'no swords when their flag is off')
 -- Class colors: emblem (desaturated + tinted) and level.
 RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43}}
 A.SetOption('enemyFactionClassColor',true);settle()
 check(pool[1].color[1]==.78,'flat emblem: solid class color')
 check(pool[1].masks and pool[1].masks[pool[1].flatMask],'flat emblem: cut to the emblem outline')
 equal(pool[1].flatMask.atlas,'UI-HUD-UnitFrame-Player-PVP-HordeIcon','the mask is the faction emblem')
 A.SetOption('enemyFactionClassColor',false);settle()
 check(not (pool[1].masks and pool[1].masks[pool[1].flatMask]),'normal emblem: mask removed')
 equal(pool[1].atlas,'UI-HUD-UnitFrame-Player-PVP-HordeIcon','normal emblem again')
 check(pool[1].desaturated==false and pool[1].tint[1]==1,'emblem back to its own colors')
 -- A mark around enemy names.
 A.SetOption('enemyMark','guillemets');settle()
 equal(state(hpf).name.text,'\194\171 Hostile player \194\187','mark around the enemy name')
 A.SetOption('enemyMark','none');settle()
 equal(state(hpf).name.text,'Hostile player','no mark')

 -- The emblem always sits before the name, even when other icons go after it.
 enemyUnit.pvp=true;A.SetOption('iconPosition','right');settle()
 equal(pool[1].anchor[1],'RIGHT','emblem before the name')
 equal(pool[2].anchor[1],'LEFT','swords follow the Icons page (after)')
 A.SetOption('iconPosition','left');enemyUnit.pvp=nil;A.Refresh();settle()
 A.SetOption('enemyShowLevel',true);A.SetOption('enemyLevelClassColor',true)
 -- The Players "Show for" level scope does not hide enemy levels.
 A.db.playerLevelScope='target'
 enemyUnit.level=23
 local realLevel=UnitLevel;UnitLevel=function(u) return units[u] and units[u].level end
 A.Refresh();settle()
 equal(state(hpf).overlay.level.color[1],.78,'level in their class color')
 equal(state(hpf).overlay.levelHolder.shown,true,'enemy level shows whatever the friendly level scope')
 A.db.playerLevelScope='all'
 UnitLevel=realLevel;enemyUnit.level=nil
 A.SetOption('enemyShowLevel',false);A.SetOption('enemyLevelClassColor',false)
 -- 1.10: enemies have their own level, guild, icon and bar settings (layout B
 -- keeps them apart from the friendly ones; layout A writes both).
 do
  A.db.optionsLayout='b'
  enemyUnit.level=23
  local realLevel2=UnitLevel;UnitLevel=function(u) return units[u] and units[u].level end
  A.SetOption('enemyShowLevel',true);A.SetOption('playerLevelSide','right')
  A.SetOption('enemyLevelSide','left');settle()
  equal(state(hpf).overlay.level.anchor[1],'RIGHT','enemy level on its own side (before the name)')
  A.SetOption('enemyLevelSide','right')
  A.SetOption('enemyLevelSize',20);settle()
  equal(state(hpf).overlay.level.fontHeight,20,'enemy level size is its own')
  A.SetOption('enemyLevelSize',nil)
  A.SetOption('enemyLevelScope','target');settle()
  equal(state(hpf).levelNear,false,'enemy level Target range hides it')
  units.target=enemyUnit;emit('PLAYER_TARGET_CHANGED');settle()
  equal(state(hpf).levelNear,true,'the selected enemy shows its level')
  units.target=nil;emit('PLAYER_TARGET_CHANGED');settle()
  A.SetOption('enemyLevelScope','all');settle()
  A.SetOption('enemyLevelColorMode','custom');A.db.colors.enemyLevel={.1,.2,.3};A.Refresh();settle()
  equal(state(hpf).overlay.level.color[1],.1,'enemy level in its own custom color')
  equal(A.db.enemyLevelClassColor,false,'the old checkbox follows the color mode')
  A.SetOption('enemyLevelColorMode','class');equal(A.db.enemyLevelClassColor,true,'class mode ticks it')
  A.SetOption('enemyLevelColorMode','name');A.Refresh();settle()
  equal(state(hpf).overlay.level.color[1],state(hpf).name.color[1],'match name: the name color')
  A.SetOption('enemyShowLevel',false)
  UnitLevel=realLevel2;enemyUnit.level=nil
  -- Guild rank for enemies.
  function GetGuildInfo(u) return 'Silver Hand','Knight' end
  A.SetOption('enemyShowGuild',true);settle()
  equal(state(hpf).title.text,'<Silver Hand>','enemy guild line')
  A.SetOption('enemyShowGuildRank',true);settle()
  equal(state(hpf).title.text,'Knight of <Silver Hand>','enemy guild rank')
  A.SetOption('enemyShowGuildRank',false);A.SetOption('enemyShowGuild',false);GetGuildInfo=nil
  -- Icons: swords position and size are the enemy's own.
  enemyUnit.pvp=true;A.SetOption('enemyFactionIcon',true);A.SetOption('enemyPvpIcon',true)
  A.SetOption('iconPosition','right');A.SetOption('enemySwordsPosition','above');settle()
  local pool2=state(hpf).overlay.icons
  equal(pool2[1].anchor[1],'RIGHT','emblem before the name')
  equal(pool2[2].anchor[1],'BOTTOM','swords above, whatever the friendly position')
  A.SetOption('enemyIconSize',20);settle()
  equal(pool2[2].width,20,'enemy icon size is its own')
  A.SetOption('enemyIconSize',nil);A.SetOption('iconPosition','left');A.SetOption('enemySwordsPosition','left')
  A.SetOption('enemyFactionIcon',false);A.SetOption('enemyPvpIcon',false);enemyUnit.pvp=nil;settle()
  -- Enemy bar color: class (default), the name's, or a custom color.
  local fake={unit='nameplate6',color={.5,.6,.7}}
  equal(A.EnemyBarColor(fake)[1],.78,'enemy bar: class color by default')
  A.db.enemyBarColorMode='name';equal(A.EnemyBarColor(fake)[1],.5,'enemy bar: the name color')
  A.db.enemyBarColorMode='custom';A.db.colors.enemyBar={.2,.3,.4};equal(A.EnemyBarColor(fake)[1],.2,'enemy bar: custom')
  A.db.enemyBarColorMode='class'
  -- Level keys: friendly and enemy separately.
  local friendlyBefore,enemyBefore=A.db.playerShowLevel,A.db.enemyShowLevel
  ForeverNames_ToggleEnemyLevel()
  equal(A.db.enemyShowLevel,not enemyBefore,'the enemy level key toggles enemy levels')
  equal(A.db.playerShowLevel,friendlyBefore,'and leaves friendly levels alone')
  ForeverNames_ToggleEnemyLevel()
  A.db.optionsLayout='a'
  -- Layout A still writes both sides (the window as it was before 1.10).
  A.SetOption('playerLevelSide','left');equal(A.db.enemyLevelSide,'left','layout A: one level side for both')
  A.SetOption('playerLevelSide','right')
  A.SetOption('iconSize',18);equal(A.db.enemyIconSize,18,'layout A: one icon size for both')
  A.SetOption('iconSize',nil)
 end
 -- Always-on health bar, class colored; secret values go straight to the bar.
 local secret=setmetatable({}, {__lt=function() error('secret compared') end,__tostring=function() error('secret formatted') end})
 issecretvalue=function(v) return v==secret end
 local realHealth,realMax=UnitHealth,UnitHealthMax
 UnitHealth=function() return secret end;UnitHealthMax=function() return secret end
 A.SetOption('enemyHealthBar',true);settle()
 local bar=state(hpf).overlay.enemyBar
 check(bar and bar.shown,'enemy health bar shown')
 check(bar.bar.value==secret,'secret health goes to the bar')
 equal(bar.bar.alpha,1,'always visible, at any health')
 equal(bar.bar.barColor[1],.78,'in their class color')
 A.SetOption('enemyHealthBar',false);settle()
 equal(bar.shown,false,'bar hidden when turned off')
 UnitHealth,UnitHealthMax,issecretvalue=realHealth,realMax,nil
 -- Strangers, visibility.
 A.SetOption('enemyStranger',true);settle()
 equal(state(hpf).name.text,'Orc Warrior','enemies as strangers')
 A.SetOption('enemyStranger',false)
 A.SetOption('enemyScope','hidden');settle()
 equal(state(hpf).overlay.shown,false,'None: no enemy labels')
 A.SetOption('enemyScope','target');settle()
 equal(state(hpf).overlay.shown,false,'Target: others hidden')
 units.target=enemyUnit;A.db.targetHealthBar=false;emit('PLAYER_TARGET_CHANGED');settle()
 equal(state(hpf).overlay.shown,true,'Target: the selected enemy shows')
 -- Rivals.
 local readsBefore=levelReads -- adding records the target's level once; not part of later tallies
 local rival,key=C.AddTargetPerson()
 levelReads=readsBefore
 equal(C.PersonCircle(rival),'rival','an enemy target goes to Rivals')
 units.target=nil;A.db.targetHealthBar=true;C.RemovePerson(key)
 A.SetOption('enemyScope','all');A.SetOption('enemyFactionIcon',false);A.SetOption('enemyPvpIcon',false)
 -- Test mode: a friendly player drawn as an enemy of the other faction.
 A.SetEnemyTest(true);settle()
 equal(state(pf).sizeKey,'enemyPlayer','test mode: friendly player drawn as an enemy')
 equal(state(pf).name.color[1],A.factionColors.Horde[1],'test mode: shown as the other faction')
 A.SetEnemyTest(false);settle()
 equal(state(pf).sizeKey,'friendlyPlayer','test mode off: friendly again')
 A.SetOption('enemyEnabled',false);settle()
 equal(state(hpf),nil,'Enemy tab off again: plate native')
 equal(hpf.HealthBarsContainer.alpha,1,'and its bars restored')
 UnitFactionGroup,UnitIsPVP,UnitRace,UnitClass,UnitFullName,GetNormalizedRealmName=nil,nil,nil,nil,nil,nil
end
-- A player-only renderer can be toggled independently and must restore the
-- smooth player-plates-off setting captured before enabling it.
A.db.targetHealthBar=false
SlashCmdList.FOREVERNAMES('players off')
cvars.nameplateShowFriends='0'
SlashCmdList.FOREVERNAMES('players on')
equal(cvars.nameplateShowFriends,'1','custom player names enable their required anchors')
equal(A.db.previousCVars.nameplateShowFriends,'0','prior player-plates-off preference captured')
combat=true;SlashCmdList.FOREVERNAMES('players off')
equal(cvars.nameplateShowFriends,'1','player plate CVar change deferred in combat')
combat=false;emit('PLAYER_REGEN_ENABLED');settle()
equal(cvars.nameplateShowFriends,'0','player off restores prior setting after combat')
equal(state(pf),nil,'player off removes custom text')
equal(cvars.nameplateShowFriendlyNpcs,'1','player toggle preserves NPC anchors')
SlashCmdList.FOREVERNAMES('players on')
equal(state(pf).name.text,'Player','player on restores custom name')
A.db.targetHealthBar=true;A.ApplyCVars()
-- A plate can disappear before any queued work runs. Suppression still releases.
local pendingPlate,pendingFrame=spawn('nameplate700',{id='700',name='Quick arrival',cursor='Buy'})
equal(pendingFrame.HealthBarsContainer.alpha,0,'rapid arrival suppresses bars immediately')
equal(state(pendingFrame),nil,'rapid arrival has not rendered queued text yet')
emit('NAME_PLATE_UNIT_REMOVED','nameplate700');pendingFrame:OnUnitCleared()
equal(pendingFrame.HealthBarsContainer.alpha,1,'removal before first queued update restores bars')
check(not A.IsPrimedPlate(pendingFrame,'nameplate700'),'removal releases pending ownership')
settle();equal(state(pendingFrame),nil,'obsolete queued arrival cannot claim a removed frame')
local latePlate,lateFrame=spawn('nameplate701',{id='701',name='Late native frame',player=true,lateFrame=true})
equal(lateFrame.HealthBarsContainer.alpha,0,'final acquired frame hidden before first queued update')
equal(latePlate.placeholder.HealthBarsContainer.alpha,1,'early event does not claim a stale placeholder frame')
lateFrame.HealthBarsContainer:SetAlpha(1)
lateFrame:ApplyFrameOptions()
equal(lateFrame.HealthBarsContainer.alpha,0,'native options refresh cannot expose a pending health bar')
settle();equal(state(lateFrame).name.text,'Late native frame','final acquired frame receives custom name')
lateFrame.HealthBarsContainer:SetAlpha(1)
lateFrame:ApplyFrameOptions()
equal(lateFrame.HealthBarsContainer.alpha,0,'native options refresh cannot expose a rendered health bar')
local opposite,of=spawn('nameplate5',{id='50',name='Trainer',opposite=true,title='Hunter Trainer'});settle()
equal(A.Classify('nameplate5'),'interactive','opposite trainer identified')
-- Text sizes inherit without reviving custom smoothing or writing CVars.
local sizeWrites=cvarWrites
A.db.textSizes={general={name=20,subtitle=12},vendor={name=28,subtitle=17},
 quest={name=24,subtitle=14},interactive={name=22,subtitle=13},oppositeFaction={name=31,subtitle=19}}
A.Refresh()
equal(state(vf).name.fontHeight,28,'vendor name size overrides general')
equal(state(vf).title.fontHeight,17,'vendor subtitle size overrides general')
equal(state(of).name.fontHeight,31,'opposite faction uses its color category size')
equal(state(of).title.fontHeight,19,'opposite faction subtitle size')
A.db.useOppositeFactionColor=false;A.Refresh()
equal(state(of).name.fontHeight,22,'opposite faction falls back to role size with role colors')
equal(state(of).title.fontHeight,13,'role subtitle size applied')
A.db.useOppositeFactionColor=true
local questSize,questSubtitle=A.GetTextSizes('quest')
equal(questSize,24,'quest name override');equal(questSubtitle,14,'quest subtitle override')
A.db.textSizes.vendor={};A.Refresh()
equal(state(vf).name.fontHeight,20,'inherit restores general name size')
equal(state(vf).title.fontHeight,12,'inherit restores general subtitle size')
A.db.textSizes.general.subtitle=nil;A.Refresh()
equal(state(vf).title.fontHeight,16,'automatic subtitle is 80 percent of effective name')
A.db.textSizes.vendor={name=100,subtitle=-1};A.Refresh()
equal(state(vf).name.fontHeight,40,'saved size clamped to maximum')
equal(state(vf).title.fontHeight,32,'invalid subtitle falls back safely')
A.db.textSizes=nil;A.Refresh()
equal(state(vf).name.fontHeight,18,'auto restores current Blizzard height')
equal(state(vf).title.fontHeight,14.4,'auto restores native subtitle ratio')
equal(cvarWrites,sizeWrites,'text-size changes do not write game-wide settings')
equal(state(vf).name.smooth,true,'size edits preserve inherited smooth scaling')
units.target=units.nameplate1
A.db.targetOpacity=.5;emit('PLAYER_TARGET_CHANGED')
equal(vs.name.alpha,.5,'target opacity applied to own text')
A.db.targetOpacity=1;emit('PLAYER_TARGET_CHANGED')
-- Simulate repeatedly crossing the maximum-distance threshold on the same
-- native plate. Restore ownership, but reuse the addon font-string resources.
local fontWrites,heightWrites=vs.name.fontWrites,vs.name.heightWrites
local titleFontWrites,titleHeightWrites=vs.title.fontWrites,vs.title.heightWrites
local thresholdTooltips=tooltipReads
SlashCmdList.FOREVERNAMES('perf reset')
for i=1,20 do
 emit('NAME_PLATE_UNIT_REMOVED','nameplate1');vf:OnUnitCleared()
 vf.unit='nameplate1'
 emit('NAME_PLATE_UNIT_ADDED','nameplate1');NamePlateDriverFrame:OnNamePlateAdded('nameplate1')
 settle()
 equal(state(vf).name.text,'Vendor','threshold reentry retains correct name')
end
equal(vs.name.fontWrites,fontWrites,'threshold reentry does not reapply unchanged font')
equal(vs.name.heightWrites,heightWrites,'threshold reentry does not reapply unchanged height')
equal(vs.title.fontWrites,titleFontWrites,'threshold reentry reuses subtitle font')
equal(vs.title.heightWrites,titleHeightWrites,'threshold reentry reuses subtitle height')
equal(tooltipReads,thresholdTooltips,'threshold reentry reuses cached subtitle')
equal(A.perf.added,20,'threshold diagnostics count deduplicated additions')
equal(A.perf.removed,20,'threshold diagnostics count removals')
equal(A.perf.fontStyles,0,'threshold diagnostics record no font rebuilds')
local comparisonWrites=cvarWrites
SlashCmdList.FOREVERNAMES('compare')
equal(state(vf),nil,'comparison restores Blizzard plate')
equal(cvarWrites,comparisonWrites,'comparison preserves all engine settings')
SlashCmdList.FOREVERNAMES('compare')
equal(state(vf).name.text,'Vendor','comparison restores addon text')
equal(cvarWrites,comparisonWrites,'comparison exit preserves engine settings')
A.perf=nil
emit('NAME_PLATE_UNIT_REMOVED','nameplate1');vf:OnUnitCleared()
equal(state(vf),nil,'ownership released on recycling')
equal(vf.alpha,1,'native parent alpha untouched')
equal(vf.HealthBarsContainer.alpha,1,'bar alpha restored')
equal(vf.LevelFrame.alpha,1,'level alpha restored')
equal(vf.name.alpha,1,'native name alpha restored')
equal(vf.SoftTargetFrame.alpha,1,'interaction alpha untouched on recycling')
equal(vs.overlay.shown,false,'overlay hidden on recycling')
vf.unit='nameplate1';units.nameplate1={id='99',name='Recycled enemy',enemy=true};CompactUnitFrame_UpdateName(vf)
emit('NAME_PLATE_UNIT_ADDED','nameplate1');settle()
equal(state(vf),nil,'recycled enemy stays native')
-- Crowd arrivals are bounded, and idle scenes do zero scan work.
local before=updateCalls
for i=101,200 do spawn('nameplate'..i,{id=tostring(i),name='Vendor '..i,cursor='Buy',title='General Goods'}) end
equal(updateCalls,before,'100 arrivals deduplicated and expensive work queued')
for unit,plate in pairs(plates) do
 if unit:match('^nameplate1%d%d$') then equal(plate.UnitFrame.HealthBarsContainer.alpha,0,'crowd native bars hidden before first queue frame') end
end
for i=1,250 do local old=updateCalls;tick(.03);check(updateCalls-old<=2,'at most two queued scans per frame') end
for i=101,200 do equal(state(plates['nameplate'..i].UnitFrame).overlay.shown,true,'every queued NPC rendered') end
local idleLookups,idleCursor,idleTooltip=lookups,cursorReads,tooltipReads
for i=1,2000 do tick(.03) end
equal(lookups,idleLookups,'zero idle nameplate lookups across 60 seconds')
equal(cursorReads,idleCursor,'zero idle cursor queries across 60 seconds')
equal(tooltipReads,idleTooltip,'zero idle tooltip queries across 60 seconds')
equal(#timers,0,'no repeating timers once settled')
-- Unrelated unit events must not rescan a settled crowd.
units.party1={id='9000',name='Party member',player=true}
for i=1,30 do emit('UNIT_NAME_UPDATE','party1');emit('UNIT_FACTION','party1') end
settle()
equal(lookups,idleLookups,'unrelated unit events do not scan the crowd')
equal(cursorReads,idleCursor,'unrelated unit events do not classify the crowd')
equal(tooltipReads,idleTooltip,'unrelated unit events do not rescan subtitles')
emit('QUEST_LOG_UPDATE');equal(lookups,idleLookups,'quest event queues scans')
settle()
local singleQuestPass=lookups-idleLookups
local burstStart=lookups
for i=1,25 do emit('QUEST_LOG_UPDATE') end
settle()
equal(lookups-burstStart,singleQuestPass,'a burst of quest-log updates coalesces into one pass')
units.oldquestgiver={id='7777',name='Finished quest giver',interactive=true}
A.db.learned['7777']='quest'
equal(A.Classify('oldquestgiver'),'interactive','a learned quest role does not outlive the live quest cursor')
units.oldquestgiver=nil;A.db.learned['7777']=nil
units.nameplate101.name='New name';CompactUnitFrame_UpdateName(plates.nameplate101.UnitFrame);emit('UNIT_NAME_UPDATE','nameplate101');settle()
equal(state(plates.nameplate101.UnitFrame).name.text,'New name','Blizzard name update retained')
units.target=units.nameplate101
units.target.name='Renamed through target'
local aliasLookups=lookups
emit('UNIT_NAME_UPDATE','target');settle()
equal(lookups,aliasLookups+1,'target alias refreshes only its matching plate')
equal(state(plates.nameplate101.UnitFrame).name.text,'Renamed through target','alias name event still refreshes text')
local beforeReentry=tooltipReads
emit('NAME_PLATE_UNIT_REMOVED','nameplate101');plates.nameplate101.UnitFrame:OnUnitCleared()
local reentered,reenteredFrame=spawn('nameplate301',{id='101',name='Renamed through target',cursor='Buy',title='General Goods'})
settle()
equal(tooltipReads,beforeReentry,'same NPC reentering on another token reuses subtitle')
equal(state(reenteredFrame).title.text,'<General Goods>','cached subtitle still displayed')
local noTitleUpdates=updateCalls
spawn('nameplate302',{id='302',name='Vendor without subtitle',cursor='Buy'})
settle()
equal(updateCalls,noTitleUpdates+1,'complete tooltip without subtitle does not trigger retries')
-- A recycled token with a DIFFERENT GUID must not inherit that cached title.
emit('NAME_PLATE_UNIT_REMOVED','nameplate301');reenteredFrame:OnUnitCleared()
local changed,changedFrame=spawn('nameplate301',{id='303',name='Different vendor',cursor='Buy',title='Reagents'})
settle()
equal(state(changedFrame).title.text,'<Reagents>','recycled token gets its new NPC subtitle')
-- Close only hides standalone settings; never commits CVars.
local writes=cvarWrites
for i=1,20 do SlashCmdList.FOREVERNAMES('');A.optionsCloseButton.scripts.OnClick() end
equal(cvarWrites,writes,'settings close has no CVar writes')
-- Addon palette: live changes, cancel restores, Blizzard's picker untouched
-- (it is blocked for addons in the gamepad interface).
do
 local realPicker=ColorPickerFrame
 ColorPickerFrame=setmetatable({}, {__index=function() error('Blizzard color picker must not be opened') end})
 local before={unpack(A.db.colors.vendor)}
 A.PickRoleColor('vendor')
 local popover=_G.ForeverNamesColorPopover
 check(popover and popover.shown,'palette opens')
 equal(A.db.colors.vendor[1],before[1],'opening the palette changes nothing')
 local sample=A.colorPalette[20]
 popover.swatches[20].scripts.OnClick()
 equal(A.db.colors.vendor[1],sample[1],'palette swatch applies live')
 popover:Cancel()
 equal(A.db.colors.vendor[1],before[1],'cancel restores the original color')
 check(not popover.shown,'cancel closes the palette')
 A.PickLevelColor()
 popover.swatches[4].scripts.OnClick();popover.done.scripts.OnClick()
 equal(A.db.playerLevelColorMode,'custom','choosing a level color selects Custom')
 equal(A.db.colors.playerLevel[2],A.colorPalette[4][2],'level color saved')
 A.db.playerLevelColorMode='name';A.db.colors.playerLevel={.78,.78,.78}
 ColorPickerFrame=realPicker
end
-- Settings window: tabs, remembered page, and checkboxes wired to settings.
SlashCmdList.FOREVERNAMES('')
check(A.options.shown,'/fnames opens settings')
A.SelectOptionsPage(3);equal(A.db.optionsPage,3,'selected page is remembered')
equal(cvarWrites,writes,'opening and paging have no CVar writes')
do
 local toggle
 for _,f in ipairs(frames) do if f.Text and f.Text.text=='Custom names for friendly players' then toggle=f end end
 check(toggle~=nil,'settings expose friendly player names')
 local before=A.db.showFriendlyPlayers
 toggle.checked=not before;toggle.scripts.OnClick(toggle)
 equal(A.db.showFriendlyPlayers,not before,'checkbox saves the setting')
 toggle.checked=before;toggle.scripts.OnClick(toggle)
end
A.optionsCloseButton.scripts.OnClick()
check(not A.options.shown,'close hides settings')
local skinButton=CreateFrame('Button')
skinButton:SetSize(100,24)
local buttonArt=A.OptionsSkin.Button(skinButton)
equal(#buttonArt.pieces,9,'button uses nine fixed pieces')
for _,size in ipairs({{32,24},{150,24},{720,38}}) do
 skinButton:SetSize(unpack(size));skinButton.scripts.OnSizeChanged()
 equal(buttonArt.pieces[1].width,5,'button corner width remains fixed')
 equal(buttonArt.pieces[1].height,5,'button corner height remains fixed')
end
skinButton.scripts.OnMouseDown();equal(buttonArt.pieces[1].tint[1],.7,'pressed feedback')
skinButton.scripts.OnMouseUp();equal(buttonArt.pieces[1].tint[1],1,'released feedback')
skinButton:SetEnabled(false);skinButton.scripts.OnDisable()
equal(buttonArt.pieces[1].tint[1],.45,'disabled feedback')
do
 -- The real renderer, options, and new event driver run together. Any health
 -- read using a crowd token is rejected by the mocks, including in a busy scene.
 equal(healthReads,0,'NPC targets and idle crowd never read custom-bar health')
 equal(maxHealthReads,0,'NPC targets never read custom-bar maximum health')
 equal(A.targetHealthBar,nil,'live health widget is lazy; settings preview is separate')
 check(not healthDriver.events.UNIT_HEALTH,'no health subscription before a player target')
 units.target=units.nameplate4;emit('PLAYER_TARGET_CHANGED')
 local hp=A.targetHealthBar
 check(hp and hp.shown,'selecting a friendly player displays its custom health')
 equal(hp.parent,state(pf).overlay,'health bar belongs to selected player overlay')
 equal(hp.anchor[2],state(pf).name,'bar anchors below the custom name')
 equal(hp.anchor[3],'BOTTOM','health bar below rather than over text')
 equal(hp.width,82,'small minimal bar is default width')
 equal(hp.height,4,'small minimal bar is default height')
 equal(hp.value,65,'initial target health displayed')
 equal(hp.maximum,100,'initial target max health displayed')
 equal(hp.barColor[1],state(pf).color[1],'default bar follows player name color')
 equal(pf.HealthBarsContainer.alpha,0,'selection never exposes native health bars')
 equal(pf.LevelFrame.alpha,0,'selection never exposes native level')
 equal(healthDriver.unitFilters.UNIT_HEALTH[1],'target','unit event filtered to target')
 equal(#healthDriver.unitFilters.UNIT_HEALTH,1,'no crowd unit health registrations')
 check(not hp.scripts.OnUpdate and not healthDriver.scripts.OnUpdate,'no bar animation or polling')
 local reads,maximumReads,crowdLookups,tooltips=healthReads,maxHealthReads,lookups,tooltipReads
 for i=1,100 do emit('UNIT_HEALTH','nameplate'..i);emit('UNIT_MAXHEALTH','party1') end
 equal(healthReads,reads,'non-target health bursts do no work')
 units.target.health=27;units.target.maxHealth=150;emit('UNIT_MAXHEALTH','target')
 equal(hp.value,27,'maximum-health event refreshes target value')
 equal(hp.maximum,150,'maximum-health event refreshes range')
 equal(healthReads,reads+1,'target event reads one health value regardless of crowd')
 equal(maxHealthReads,maximumReads+1,'target event reads one maximum regardless of crowd')
 equal(lookups,crowdLookups,'health update does not enumerate nameplates')
 equal(tooltipReads,tooltips,'health update does not scan tooltips')
 reads=healthReads
 for i=1,2000 do tick(.03) end
 equal(healthReads,reads,'no idle health reads over 60 seconds with an active target')
 equal(#timers,0,'health bar creates no timer')
 local updateCount=updateCalls
 for _,key in ipairs({'minimal','default','classic'}) do
  A.SetTargetHealthPreset(key)
  equal(hp.width,A.targetHealthPresets[key].width,'preset width: '..key)
  equal(hp.height,A.targetHealthPresets[key].height,'preset height: '..key)
  equal(hp.edges[1].shown,key~='minimal','preset border: '..key)
 end
 A.SetTargetHealthPreset('minimal');A.db.targetHealthWidth=120;A.db.targetHealthGap=7
 A.SetTargetHealthPreset('default')
 equal(A.db.targetHealthWidth,A.targetHealthPresets.default.width,'an untouched style starts at its built-in width')
 A.db.targetHealthWidth=150
 A.SetTargetHealthPreset('minimal')
 equal(A.db.targetHealthWidth,120,'switching back restores the width of that style')
 equal(A.db.targetHealthGap,7,'and its gap')
 A.SetTargetHealthPreset('default')
 equal(A.db.targetHealthWidth,150,'each style keeps its own settings')
 A.ResetTargetHealth()
 equal(A.db.targetHealthStyleSettings,nil,'Reset bar forgets every style')
 A.SetTargetHealthPreset('classic')
 equal(healthReads,reads,'style edits do not query health again')
 equal(updateCalls,updateCount,'health settings do not refresh/classify the crowd')
 local function findControl(text,x,y)
  for _,f in ipairs(frames) do
   if f.text==text and f.anchor and f.anchor[2]==x and f.anchor[3]==y then return f end
  end
  error('missing settings control '..text)
 end
 findControl('+',350,-134).scripts.OnClick()
 equal(hp.width,112,'width button changes width rather than another captured row')
 findControl('+',350,-164).scripts.OnClick()
 equal(hp.height,10,'height button changes height')
 findControl('+',350,-194).scripts.OnClick()
 equal(hp.anchor[5],-4,'gap button moves bar farther below text')
 A.db.targetHealthOpacity=.5;A.db.targetOpacity=.4;A.db.otherOpacity=1
 emit('PLAYER_TARGET_CHANGED')
 equal(hp.alpha,.2,'bar opacity multiplies custom name target opacity')
 A.db.targetHealthR=.7;A.db.targetHealthG=.2;A.db.targetHealthB=.3;A.SetOption('targetHealthNameColor',false)
 A.RefreshTargetHealthAppearance()
 equal(hp.barColor[1],.7,'custom bar color applied')
 equal(hp.barColor[2],.2,'custom green applied')
 A.db.targetHealthWidth=999;A.db.targetHealthHeight=-1;A.db.targetHealthGap=999
 A.RefreshTargetHealthAppearance()
 equal(hp.width,180,'width safely clamped')
 equal(hp.height,2,'height safely clamped')
 equal(hp.anchor[5],-16,'gap safely clamped')
 A.db.targetHealthWidth=0/0;A.db.targetHealthStyle='missing';A.RefreshTargetHealthAppearance()
 equal(hp.width,82,'invalid saved size uses default')
 equal(hp.edges[1].shown,false,'unknown preset safely uses minimal')
 A.SetTargetHealthPreset('minimal')
 A.db.targetHealthOpacity=1;A.db.targetOpacity=1;A.db.targetHealthGap=3;A.SetOption('targetHealthNameColor',true)
 -- Opaque values may be sent to a StatusBar but must never be divided,
 -- compared, or formatted by addon Lua.
 local function forbiddenArithmetic() error('secret health used in Lua calculation') end
 local secretHealth=setmetatable({}, {__lt=forbiddenArithmetic,__le=forbiddenArithmetic,__div=forbiddenArithmetic,__tostring=forbiddenArithmetic})
 local secretMax=setmetatable({},getmetatable(secretHealth))
 issecretvalue=function(value) return value==secretHealth or value==secretMax end
 units.target.health=secretHealth;units.target.maxHealth=secretMax
 emit('UNIT_HEALTH','target')
 check(hp.value==secretHealth and hp.maximum==secretMax,'secret health passed through unchanged')
 check(hp.shown,'secret health can still draw through StatusBar API')
 issecretvalue=nil
 units.target.health=0;units.target.maxHealth=100;emit('UNIT_HEALTH','target')
 equal(hp.value,0,'dead player displays an empty bar')
 units.target.maxHealth=0;emit('UNIT_MAXHEALTH','target')
 equal(hp.shown,false,'unavailable maximum hides stale fill')
 units.target.maxHealth=100;emit('UNIT_MAXHEALTH','target')
 equal(hp.shown,true,'valid maximum recovers without polling')
 local oldSetValue=hp.SetValue
 hp.SetValue=function() error('restricted widget access') end
 emit('UNIT_HEALTH','target');equal(hp.shown,false,'rejected health write fails closed')
 hp.SetValue=oldSetValue;emit('UNIT_HEALTH','target')
 equal(hp.shown,true,'subsequent valid health event recovers')
 -- An event arriving between an actual target change and its notification
 -- must not draw another unit's health on the previous player's plate.
 units.target=units.nameplate101;reads=healthReads;emit('UNIT_HEALTH','target')
 equal(hp.shown,false,'target change race hides old bar immediately')
 equal(healthReads,reads,'target change race never reads NPC health')
 check(not healthDriver.events.UNIT_HEALTH,'deselection releases health events')
 units.target=units.nameplate6;emit('PLAYER_TARGET_CHANGED')
 equal(hp.shown,false,'hostile player has no custom friendly health bar')
 units.player=units.nameplate4;units.target=units.player;emit('PLAYER_TARGET_CHANGED')
 equal(hp.shown,false,'personal resource plate excluded')
 units.player=nil
 local count=0
 for _,f in ipairs(frames) do if f.kind=='StatusBar' then count=count+1 end end
 units.target={id='810',name='New selected player',player=true,health=33,maxHealth=80}
 emit('PLAYER_TARGET_CHANGED');equal(hp.shown,false,'target without a rendered plate stays blank')
 local targetPlate,targetFrame=spawn('nameplate810',units.target)
 equal(targetFrame.HealthBarsContainer.alpha,0,'selected pending player still has no native bar')
 equal(hp.shown,false,'health waits for selected custom name to be ready')
 settle()
 equal(hp.shown,true,'queued selected player binds health when its name is ready')
 equal(hp.parent,state(targetFrame).overlay,'single bar reparents to new target')
 equal(hp.value,33,'new target gets its own current health')
 local afterCount=0
 for _,f in ipairs(frames) do if f.kind=='StatusBar' then afterCount=afterCount+1 end end
 equal(afterCount,count,'switching targets reuses the one live health widget')
 combat=true;units.target=units.nameplate4;emit('PLAYER_TARGET_CHANGED')
 equal(hp.parent,state(pf).overlay,'target can change in combat without altering native frames')
 combat=false
 units.target=units.nameplate810;emit('PLAYER_TARGET_CHANGED')
 targetFrame.forbidden=true
 emit('NAME_PLATE_UNIT_REMOVED','nameplate810')
 equal(hp.shown,false,'range exit stops health even if native frame becomes inaccessible')
 targetFrame.forbidden=false;targetFrame:OnUnitCleared()
 equal(hp.shown,false,'range exit hides custom health immediately')
 check(not healthDriver.events.UNIT_HEALTH,'range exit stops health event subscriptions')
 units.target=units.nameplate4;emit('PLAYER_TARGET_CHANGED')
 SlashCmdList.FOREVERNAMES('compare')
 equal(hp.shown,false,'native comparison hides custom health')
 check(not healthDriver.events.UNIT_HEALTH,'native comparison unsubscribes custom health')
 SlashCmdList.FOREVERNAMES('compare')
 equal(hp.shown,true,'custom health returns after comparison')
 local healthToggle
 for _,f in ipairs(frames) do
  if f.Text and f.Text.text=='Show under the selected friendly player' then healthToggle=f end
 end
 check(healthToggle~=nil,'health option is exposed in settings')
 local settingUpdates=updateCalls
 healthToggle.checked=false;healthToggle.scripts.OnClick(healthToggle)
 equal(hp.shown,false,'health checkbox turns bar off immediately')
 equal(updateCalls,settingUpdates,'health checkbox never rescans crowd')
 check(not healthDriver.events.UNIT_HEALTH,'health checkbox releases events')
 healthToggle.checked=true;healthToggle.scripts.OnClick(healthToggle)
 equal(hp.shown,true,'health checkbox can restore target without reload')
 A.db.showFriendlyPlayers=false;A.Refresh()
 equal(hp.shown,true,'health remains active with custom player names off')
 equal(state(pf),nil,'native-name mode does not create a custom name state')
 equal(hp.anchor[2],pf.name,'native mode attaches bar beneath Blizzard name')
 equal(pf.name.alpha,1,'native mode preserves Blizzard name visibility')
 equal(pf.HealthBarsContainer.alpha,0,'native target bar hidden while custom health replaces it')
 equal(pf.LevelFrame.alpha,0,'native target level hidden while custom pill replaces it')
 pf.name.text='Player Strikes'
 local nativeReads=healthReads
 units.target.health=56;emit('UNIT_HEALTH','target')
 equal(hp.value,56,'native-name mode receives live target health')
 equal(healthReads,nativeReads+1,'native mode still reads just the target')
 equal(pf.name.text,'Player Strikes','native health updates never overwrite Blizzard surname')
 pf.HealthBarsContainer:SetAlpha(1);pf:ApplyFrameOptions()
 equal(pf.HealthBarsContainer.alpha,0,'native options refresh keeps duplicate target bar hidden')
 units.target=units.nameplate101;emit('PLAYER_TARGET_CHANGED')
 equal(hp.shown,false,'native mode hides bar on NPC selection')
 equal(pf.HealthBarsContainer.alpha,1,'native mode releases old target suppression')
 units.target=units.nameplate4;emit('PLAYER_TARGET_CHANGED')
 equal(hp.shown,true,'native target selection rebinds health without custom names')
 emit('NAME_PLATE_UNIT_REMOVED','nameplate4');pf:OnUnitCleared()
 equal(hp.shown,false,'native plate departure immediately hides health')
 check(not healthDriver.events.UNIT_HEALTH,'native plate departure unsubscribes health')
 pf.unit='nameplate4';emit('NAME_PLATE_UNIT_ADDED','nameplate4');NamePlateDriverFrame:OnNamePlateAdded('nameplate4');settle()
 equal(hp.shown,true,'native plate reentry attaches health after initialization')
 healthToggle.checked=false;healthToggle.scripts.OnClick(healthToggle)
 equal(cvars.nameplateShowFriends,'0','both features off restores captured nameplate preference')
 healthToggle.checked=true;healthToggle.scripts.OnClick(healthToggle)
 equal(cvars.nameplateShowFriends,'1','health alone enables required native player anchor')
 equal(hp.shown,true,'health alone binds existing native target')
 A.db.showFriendlyPlayers=true;A.Refresh()
 equal(hp.shown,true,'enabling custom players restores selected health')
 units.target.enemy=true;emit('UNIT_FACTION','target')
 equal(hp.shown,false,'hostile faction change removes selected friendly bar')
 units.target.enemy=false;emit('UNIT_FACTION','target')
 equal(hp.shown,true,'friendly faction change restores bar')
 A.db.targetOnlyVitals=false;A.RefreshVitals();A.RefreshTargetHealth()
 equal(hp.shown,true,'custom health works independently of native event-filter preference')
 do
  -- One read: a People entry records its last known level (at most every 5 minutes).
  check(levelReads<=1,'hidden level option makes no level queries beyond a known person record')
  equal(hp.levelPill,nil,'hidden level pill allocates no live badge')
  check(not healthDriver.events.UNIT_LEVEL,'hidden level has no unit-level subscription')
  local levelToggle
  for _,f in ipairs(frames) do
   if f.Text and f.Text.text=='Show the player\'s level' then levelToggle=f end
  end
  check(levelToggle~=nil,'level pill has a show/hide settings checkbox')
  units.target.level=42
  local readsBefore,updatesBefore,lookupsBefore,levelBefore=healthReads,updateCalls,lookups,levelReads
  levelToggle.checked=true;levelToggle.scripts.OnClick(levelToggle)
  local pill=hp.levelPill
  check(pill and pill.shown,'enabling level displays the attached pill')
  equal(pill.parent,hp,'pill inherits bar visibility and opacity')
  equal(pill.anchor[1],'LEFT','pill attaches by left edge')
  equal(pill.anchor[2],hp,'pill anchors to our own bar')
  equal(pill.anchor[3],'RIGHT','pill is on the bar right edge')
  equal(pill.anchor[4],-2,'pill slightly overlaps bar for an attached appearance')
  equal(pill.art.atlas,'ui-hud-nameplates-levelindicator','verified Blizzard artwork available for Classic')
  equal(pill.art.shown,false,'Minimal does not show the Classic gold badge')
  equal(pill.rim.shown,false,'Minimal pill has no border, like its bar')
  equal(pill.fill.texture,hp.barTexture,'Minimal pill uses its bar flat texture')
  equal(pill.fill.mask,'Interface\\CharacterFrame\\TempPortraitAlphaMask','pill rounded with native UI mask')
  equal(pill.text.template,'SystemFont_NamePlateLevel','uses native level font')
  equal(pill.text.text,'42','selected player level displayed')
  equal(levelReads-levelBefore,1,'enabling level queries only the selected player once')
  equal(healthDriver.unitFilters.UNIT_LEVEL[1],'target','level event filtered to target')
  equal(#healthDriver.unitFilters.UNIT_LEVEL,1,'only target level subscription')
  equal(healthReads,readsBefore,'level toggle does not reread health')
  equal(updateCalls,updatesBefore,'level toggle does not rescan or classify crowd')
  equal(lookups,lookupsBefore,'level toggle does not look up crowd plates')
  equal(hp.anchor[5],-8,'minimal bar moves just enough to keep pill below the name')
  check(not pill.scripts.OnUpdate,'level pill has no update loop')
  for _,style in ipairs({'minimal','default','classic'}) do
   A.SetTargetHealthPreset(style)
   local _,_,height,gap=A.GetTargetHealthSettings()
   equal(pill.height,math.max(14,height+4),'readable pill height with '..style)
   equal(-hp.anchor[5]-(pill.height-height)/2,gap,'pill respects name spacing with '..style)
   equal(pill.text.text,'42','style does not lose level')
   equal(pill.art.shown,style=='classic','native gold artwork limited to Classic')
   equal(pill.fill.shown,style~='classic','switching style clears previous fill visibility')
   equal(pill.rim.shown,style=='default','dark border limited to Default when native Classic artwork exists')
   local preset=A.targetHealthPresets[style]
   if style~='classic' then equal(pill.fill.texture,hp.barTexture,'pill and bar share '..style..' texture') end
   if style=='default' then
    for channel=1,3 do
     equal(pill.rim.tint[channel],hp.edges[1].color[channel],'Default bar and pill border match')
     equal(pill.fill.tint[channel],.025+hp.barColor[channel]*.18,'Default pill follows bar tint')
    end
   end
   for channel=1,3 do equal(pill.text.color[channel],preset.levelText[channel],'level text follows '..style..' palette') end
  end
  A.SetTargetHealthPreset('minimal')
  equal(pill.art.shown,false,'Classic artwork removed when returning to Minimal')
  equal(pill.rim.shown,false,'Classic border does not survive return to Minimal')
  A.OpenOptions() -- the settings preview is drawn while the window is open
  equal(levelReads-levelBefore,1,'style and preview changes do not read target level')
  local preview
  for _,f in ipairs(frames) do if f.kind=='StatusBar' and f~=hp and f.levelPill then preview=f end end
  check(preview and preview.levelPill.shown,'settings preview includes level pill')
  equal(preview.levelPill.text.text,'60','preview uses sample level, not target information')
  for i=1,50 do emit('UNIT_HEALTH','target');emit('UNIT_LEVEL','nameplate4');emit('UNIT_LEVEL','party1') end
  for i=1,2000 do tick(.03) end
  equal(levelReads-levelBefore,1,'health bursts, other units, and 60 idle seconds never read levels')
  readsBefore=healthReads;units.target.level=43;emit('UNIT_LEVEL','target')
  equal(levelReads-levelBefore,2,'target level event queries once')
  equal(pill.text.text,'43','target level change updates pill')
  equal(healthReads,readsBefore,'level change does not trigger health read')
  units.target.level=-1;emit('UNIT_LEVEL','target')
  equal(pill.text.text,'?','unknown level displays question mark without stale number')
  local secretLevel=setmetatable({}, {__lt=function() error('secret level comparison') end,__tostring=function() error('secret level formatted') end})
  issecretvalue=function(value) return value==secretLevel end
  units.target.level=secretLevel;emit('UNIT_LEVEL','target')
  equal(pill.text.text,'?','restricted level is never formatted or compared')
  issecretvalue=nil
  UnitEffectiveLevel=function(u) assert(u=='target');levelReads=levelReads+1;return 30 end
  emit('UNIT_LEVEL','target')
  equal(pill.text.text,'30','effective level matches Blizzard in scaled content')
  UnitEffectiveLevel=nil
  units.target.level=44;emit('UNIT_LEVEL','target')
  equal(pill.text.text,'44','public level recovers normally')
  A.db.showFriendlyPlayers=false;A.Refresh()
  equal(hp.shown,true,'enabled level and health work with Blizzard names')
  equal(pill.shown,true,'level pill stays visible with Blizzard names')
  equal(pill.text.text,'44','native name mode keeps correct target level')
  equal(hp.anchor[2],pf.name,'level plus bar attach to native name')
  A.db.showFriendlyPlayers=true;A.Refresh()
  local beforeDisable=levelReads
  levelToggle.checked=false;levelToggle.scripts.OnClick(levelToggle)
  equal(pill.shown,false,'checkbox hides pill immediately')
  check(not healthDriver.events.UNIT_LEVEL,'checkbox unsubscribes level events')
  equal(hp.anchor[5],-3,'hiding pill returns bar to original gap')
  check(hp.shown,'hiding level leaves health bar active')
  emit('UNIT_LEVEL','target');emit('UNIT_HEALTH','target')
  equal(levelReads,beforeDisable,'hidden pill never reads levels')
  levelToggle.checked=true;levelToggle.scripts.OnClick(levelToggle)
  equal(hp.levelPill,pill,'reenabling reuses the same pill')
  equal(pill.text.text,'44','reenabling refreshes current target level')
  units.target=units.nameplate101
  local beforeRace=levelReads;emit('UNIT_LEVEL','target')
  equal(pill.shown,false,'target-change race hides old level pill')
  equal(hp.shown,false,'target-change race releases bar')
  equal(levelReads,beforeRace,'target-change race never reads NPC level')
  check(not healthDriver.events.UNIT_LEVEL,'target-change race releases level subscription')
  units.target=units.nameplate4;emit('PLAYER_TARGET_CHANGED')
  equal(pill.text.text,'44','selecting player again restores its level')
  GetGuildInfo=function() return 'Silver Hand' end
  A.db.playerShowGuild=true;A.Update('nameplate4')
  equal(hp.anchor[2],state(pf).title,'bar moves below the guild line')
  A.db.playerShowGuild=false;A.Update('nameplate4')
  equal(hp.anchor[2],state(pf).name,'bar stays under the name without a guild line')
  GetGuildInfo=nil
  SlashCmdList.FOREVERNAMES('compare')
  equal(pill.shown,false,'compare hides custom level')
  check(not healthDriver.events.UNIT_LEVEL,'compare releases level subscriptions')
  SlashCmdList.FOREVERNAMES('compare')
  equal(pill.text.text,'44','compare exit restores selected level')
  healthToggle.checked=false;healthToggle.scripts.OnClick(healthToggle)
  equal(pill.shown,false,'health bar off hides its level too')
  check(not healthDriver.events.UNIT_LEVEL,'health bar off stops level updates')
  healthToggle.checked=true;healthToggle.scripts.OnClick(healthToggle)
  equal(pill.shown,true,'health bar back on restores enabled level')
  -- The client normally has this atlas; verify the older-client fallback too.
  local atlasInfo=C_Texture.GetAtlasInfo
  C_Texture.GetAtlasInfo=function(name) if name~='ui-hud-nameplates-levelindicator' then return atlasInfo(name) end end
  A.SetTargetHealthPreset('classic')
  local fallback=A.CreateTargetHealthBar(A.options)
  A.StyleTargetHealthBar(fallback,{1,1,1});A.SetTargetHealthLevelDisplay(fallback,60)
  equal(fallback.levelPill.text.text,'60','fallback still displays level')
  equal(fallback.levelPill.rim.tint[1],.65,'missing Classic atlas keeps matching gold border')
  equal(fallback.levelPill.rim.shown,true,'Classic fallback uses rounded border')
  equal(fallback.levelPill.fill.texture,fallback.barTexture,'Classic fallback keeps stock bar texture')
  equal(fallback.levelPill.art.shown,false,'missing native atlas is not displayed')
  A.SetTargetHealthPreset('minimal');A.StyleTargetHealthBar(fallback,{1,1,1})
  equal(fallback.levelPill.rim.shown,false,'fallback also clears gold rim when changing to Minimal')
  C_Texture.GetAtlasInfo=atlasInfo
 end
end
-- Changing target re-renders only the plate you left and the one you selected.
do
 local realLevel=UnitLevel;UnitLevel=function(u) return units[u] and units[u].level end
 A.SetOption('playerShowLevel',true);A.SetOption('playerLevelScope','near');settle()
 for i=1,20 do spawn('nameplate'..(300+i),{id=tostring(300+i),name='Crowd'..i,player=true}) end
 settle()
 units.target=units.nameplate301;emit('PLAYER_TARGET_CHANGED');settle()
 local before=updateCalls
 units.target=units.nameplate302;emit('PLAYER_TARGET_CHANGED');settle()
 check(updateCalls-before<=3,'a target change re-renders the old and new target plates only ('..(updateCalls-before)..' renders for 21 plates)')
 units.target=nil;emit('PLAYER_TARGET_CHANGED');settle()
 for i=1,20 do local token='nameplate'..(300+i);emit('NAME_PLATE_UNIT_REMOVED',token);units[token]=nil;plates[token]=nil end
 settle()
 A.SetOption('playerLevelScope','all');A.SetOption('playerShowLevel',false)
 UnitLevel=realLevel
end
-- Settings window, layout B: by who a setting is about, next to layout A.
do
 A.db.optionsLayout='a';A.options:Hide();A.optionsB:Hide()
 SlashCmdList.FOREVERNAMES('')
 check(A.options.shown and not A.optionsB.shown,'layout A opens by default')
 SlashCmdList.FOREVERNAMES('layout b')
 check(A.optionsB.shown and not A.options.shown,'/fnames layout b opens layout B and hides A')
 equal(A.db.optionsLayout,'b','the layout is remembered')
 local pages=A.optionsBPages
 equal(#pages,4,'four tabs: Players, Enemies, NPCs, All names')
 -- The preview follows the settings.
 A.SelectOptionsPageB(1)
 check(pages[1].frame.shown and not pages[2].frame.shown,'Players page shown')
 local slots=pages[1].preview.slots
 equal(slots[1].name.text,'Aerynwen','Players preview: a sample player')
 A.db.showFriendlyPlayers=true
 A.SetOption('playerShowGuild',true);A.RefreshOptionsB()
 check(slots[1].sub.text:find('Dawnwatch',1,true),'guild line in the preview')
 A.SetOption('playerShowGuild',false);A.RefreshOptionsB()
 equal(slots[1].sub.text,'','guild line gone when off')
 A.SetOption('showFriendlyPlayers',false);A.RefreshOptionsB()
 check(pages[1].preview.off.text:find('off',1,true),'preview says custom names are off')
 A.SetOption('showFriendlyPlayers',true)
 A.SelectOptionsPageB(2)
 check(pages[2].frame.shown and not pages[1].frame.shown,'Enemies page shown')
 A.SetOption('enemyEnabled',true);A.RefreshOptionsB()
 equal(pages[2].preview.slots[1].name.text,'Kaelith','Enemies preview: a sample enemy')
 A.SetOption('enemyMark','parens');A.RefreshOptionsB()
 equal(pages[2].preview.slots[1].name.text,'(Kaelith)','the mark shows in the preview')
 A.SetOption('enemyMark','none')
 A.SetOption('enemyEnabled',false)
 -- Views, the other tabs, and the layout switch in both windows.
 pages[1].select(2);check(pages[1].views[2].shown and not pages[1].views[1].shown,'the second view shows')
 pages[1].select(1)
 A.SelectOptionsPageB(3);check(pages[3].frame.shown,'NPCs page');A.SelectOptionsPageB(4);check(pages[4].frame.shown,'All names page')
 equal(A.db.optionsPageB,4,'the tab is remembered')
 A.optionsB.layouta.scripts.OnClick(A.optionsB.layouta)
 check(A.options.shown and not A.optionsB.shown and A.db.optionsLayout=='a','the switch in B goes back to A')
 A.options.layoutb.scripts.OnClick(A.options.layoutb)
 check(A.optionsB.shown and not A.options.shown,'the switch in A opens B')
 A.optionsBClose.scripts.OnClick()
 check(not A.optionsB.shown,'Close hides layout B')
 A.db.optionsLayout='a';A.options:Hide();A.optionsB:Hide()
end
-- Forever Names alone (Companion Journal not installed or turned off): no
-- People features, nothing breaks, and the People links say where they went.
do
 function UnitFullName(u) local d=units[u];return d and d.name,d and d.realm end
 function GetNormalizedRealmName() return 'HomeRealm' end
 local api=CompanionJournalAPI
 C.AddPerson('Player');C.db.people['player-homerealm'].display='Lady Evening'
 C.SetOption('peopleRename',true);C.SetOption('peopleIcons',true);settle()
 equal(state(pf).name.text,'Lady Evening','with Companion Journal: their display name')
 check(state(pf).overlay.icons[1].shown,'with Companion Journal: their icon')
 CompanionJournalAPI=nil
 A.Refresh();settle()
 equal(state(pf).name.text,'Player','without it: their own name')
 local pool=state(pf).overlay.icons
 check(not pool[1].shown or pool[1].path~=C.GlyphPath('diamond'),'without it: no People icon')
 local said,realPrint=nil,print
 print=function(...) said=table.concat({...},' ') end
 SlashCmdList.FOREVERNAMES('people')
 print=realPrint
 check(said and said:find('Companion Journal, which is not installed',1,true),'/fnames people says where People went')
 -- The settings are built at login, knowing whether Companion Journal is there:
 -- without it, both layouts show nothing of it (no People tab, links, notes or Rivals).
 local mentions,realSetText={},M.SetText
 M.SetText=function(self,v) if type(v)=='string' and v~='Companion Journal' and v:find('Companion Journal',1,true) then mentions[#mentions+1]=v end;return realSetText(self,v) end
 local first=#frames+1
 A.CreateOptions();if A.CreateOptionsB then A.CreateOptionsB() end
 A.OpenOptions();A.RefreshOptions();if A.RefreshOptionsB then A.RefreshOptionsB() end
 M.SetText=realSetText
 local links,rivals=0,0
 for i=first,#frames do
  local f=frames[i]
  if f.kind=='Button' and f.text=='Open Companion Journal' then links=links+1 end
  if f.kind=='Button' and f.text=='Open Rivals' then rivals=rivals+1 end
  if f.kind=='Button' and f.text=='Companion Journal' then check(f.shown==false,'the footer link to Companion Journal is hidden without it') end
 end
 -- Nor their tooltips.
 local realTip=GameTooltip
 GameTooltip=setmetatable({},{__index=function() return function(_,v) if type(v)=='string' and v:find('Companion Journal',1,true) then mentions[#mentions+1]='tooltip: '..v end end end})
 for i=first,#frames do
  local f=frames[i]
  if f.scripts and f.scripts.OnEnter and f.text~='Companion Journal' then pcall(f.scripts.OnEnter,f) end
 end
 GameTooltip=realTip
 equal(links,0,'no links to Companion Journal without it')
 equal(rivals,0,'no Open Rivals without it')
 equal(#mentions,0,'no text about Companion Journal without it: '..table.concat(mentions,' | '))
 A.options:Hide()
 CompanionJournalAPI=api
 A.CreateOptions();if A.CreateOptionsB then A.CreateOptionsB() end
 C.SetOption('peopleRename',false);C.SetOption('peopleIcons',false);C.db.people={}
 A.Refresh();settle()
 UnitFullName,GetNormalizedRealmName=nil,nil
end
A.db.enabled=false;A.ApplyCVars();A.Refresh()
equal(A.targetHealthBar.shown,false,'addon disable also hides custom health')
check(not healthDriver.events.UNIT_HEALTH,'addon disable releases custom health events')
check(not healthDriver.events.UNIT_LEVEL,'addon disable releases level events')
equal(A.targetHealthBar.levelPill.shown,false,'addon disable hides level pill')
equal(state(plates.nameplate101.UnitFrame),nil,'disable restores native layout')
equal(cvars.nameplateShowFriendlyNpcs,'0','disable restores previous nameplate CVar')
equal(cvars.UnitNameNPC,'1','disable restores previous world-name CVar')
equal(cvars.UnitNameHostleNPC,'1','disabling restores previous hostile NPC world names')
equal(cvars.UnitNameFriendlyPlayerName,'1','disable restores native friendly player names')
equal(cvars.UnitNameEnemyPlayerName,'1','disable restores newly captured enemy player names')
equal(cvars.nameplateShowFriends,'0','addon disable restores captured player plate preference')
for _,name in ipairs(friendlySummonNames) do equal(cvars[name],'1',name..' restored on disable') end
print('PASS: '..assertions..' native-renderer/event-queue assertions; zero idle scans over 60 simulated seconds.')
