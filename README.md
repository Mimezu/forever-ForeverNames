# Forever Names (Forever 16001)

Formerly **Friendly NPC Names**. Immersion and RP labels for friendly NPCs and
players in the open world. Every feature added since 1.7.0 has its own toggle
and ships off, so with all of them off the addon behaves exactly like 1.6.1.

## 1.16.1 Probe for the camera drag bug (temporary)

- The 1.16.0 setting below changes nothing in game: with any of its three
  choices a drag that starts on a nameplate or on a name still does not move
  the camera. Its cause was read from Blizzard's code and never measured.
- `/fnames clicks` measures. It prints what the game reports for the
  nameplate under the mouse, and from then on records every left or right
  press: what was under the mouse and, half a second later, whether the
  camera took the drag.
- `/fnames clicks 1`, `2`, `3` try three ways of removing the clickable area
  on every nameplate (clear it, move it off the plate, shrink it with the
  game-wide insets); `/fnames clicks 0` puts the game's own areas back.
- Everything is also kept in the saved settings (`clickProbe`), written on
  `/reload`. Nothing runs until the command is typed. The probe and, if it
  cannot be made to work, the 1.16.0 setting will be removed.

## 1.16.0 Camera drag on nameplates

- The cause: where a nameplate can be clicked, the game selects the unit on
  the press and never starts a camera drag there, with either mouse button.
  That clickable area is the game's own, around the name and the health bar,
  and it stayed in place, invisible, under every name this addon draws.
- New: **All names > Text & tools > Mouse on nameplates > Click to select**.
  - **Names and bars** (default): as before, the game's behavior.
  - **Bars only**: the names this addon draws let the mouse through, so a
    drag that starts on one moves the camera. Blizzard's health-bar plates
    (enemies, and our names on their bars) still select on a click.
  - **Off**: every nameplate lets the mouse through.
- The trade: a plate that lets the mouse through cannot be clicked to select
  or interact. Click the character itself; that always works.
- In combat the game only lets an addon change a plate as it appears, so a
  change of this setting made in combat finishes when combat ends.
- Checked in game: no effect (see 1.16.1).

## 1.15.0 Settings window, layout B (to try)

- The footer has a **Layout A | B** switch (also `/fnames layout a` / `b`).
  **A** is the window as it was and stays the default. **B** is a redesign of
  the same four pages. Both edit the same settings; switching keeps the page,
  the view and the window's place.
- Layout B, same functions, less to read:
  - One header line per page: title (hover it for the description), the views
    as text tabs, the page's master switch on the right.
  - Labels in one column, controls in the next, so each card reads top to
    bottom. Choices, steppers and color/icon buttons share one quiet plate
    style; the selected choice is gold. Red buttons are kept for actions
    (Reset, Close, keys, Compare, Mislabeled NPC).
  - Rows that depend on a switch appear when it is on (bar sizes under
    "health bar", icon rows under their icon option...).
  - Reference notes moved into each row's tooltip.
- The window is 20 px taller in layout B. `OptionsModern.lua` holds its kit;
  the pages are built once by the same code for both layouts.

## 1.14.0 Two keys, set in the addon

- **Hide everything** (the old "Hide or show names" key, same binding, and
  `/fnames hide`): hides every name and nameplate, Blizzard's too (enemy,
  friendly and personal plates, names over characters), and nothing else. Press
  again for exactly the values you had. They are stored per character, so a
  /reload or disconnect while hidden puts them back at login. In combat our
  labels fade at once; Blizzard's plates follow when combat ends.
- **Enemy names** (new key, `/fnames enemynames`): flips "Hide Blizzard hostile
  NPC names". Showing them also turns on enemy players' names, to spot enemies
  past nameplate range. Hiding leaves enemy player names on: turning those off
  blanks names on Blizzard's enemy plates.
- **All names > Text & tools > Keys**: set or clear the four Forever Names keys
  from the addon (click, press a key; Esc cancels). Not in combat.

## 1.13.0 Quest enemies

- New option **Show ! beside enemies for your quests** (NPCs > Which NPCs,
  card "Quest enemies"; off by default). A yellow ! sits left of the health bar
  of hostile and neutral NPCs that belong to an active quest: kill targets and
  mobs that drop quest items. It goes away when the objective is done.
- Uses the client's `C_QuestLog.UnitIsRelatedToActiveQuest`; without it, falls
  back to unfinished quest objective lines in the unit's tooltip data. Blizzard
  keeps these plates; the ! is a separate layer (`QuestMarks.lua`).
- Work only on plate arrival and quest-log updates; none while the option is off.

## 1.12.0 One settings window

- The settings window is the one organized by who a setting is about:
  **Players, Enemies, NPCs, All names**. The old window (layout A, as before
  1.10), the footer's **A | B** switch and `/fnames layout` are gone.
- Friendly and enemy settings are always separate now. Layout A used to write
  the icon position and size and the level side, size and color to both.
- "Hide Blizzard NPC names" is now two settings: **Hide Blizzard NPC names**
  and **Hide Blizzard hostile NPC names** (NPCs > Which NPCs). Uncheck the
  hostile one to keep the game's names over hostile NPCs while the others stay
  hidden. Both start checked, so nothing changes until you uncheck one.

## 1.11.5 Cleanup: one-time migrations removed

- The settings file is `ForeverNamesDB` only. The 1.7.0 adoption of the old
  `FriendlyNPCNamesDB` and the one-time clears of retired keys
  (`sharpSmoothScaling`, `playerLevelNearOnly`, the 1.9.5 enemy lab keys, the
  pre-1.2 style keys, `journalGroupmates`) are gone; the live account's saved
  settings held none of them. Settings older than 1.9.16 would no longer carry
  over automatically.
- Removed the unreachable fallback branch at the end of the event handler.
  Nothing changes in game.

## 1.11.4 Review fixes (live client 70707)

- Fixed: the **Hide** button of "Mislabeled NPC?" (and the old `/fnames hide`
  override) had been hiding *every* label since the hide-all key took that
  command. The per-NPC override is now `/fnames hidenpc`; `/fnames hide` and
  the key binding keep hiding and showing all labels.
- Fixed: the wounded-bar preview in layout A's Health bars page showed white
  instead of a class color when the bar color was set to Class.

## 1.11.3 Your people's icon, and the suite switch

- Where your people's icon sits among the other icons (before the name, after
  it, or with the others) is now a Forever Names setting: Players > Icons in
  layout B, the Icons page's Look card in layout A. It starts from what you
  had in Companion Journal. Who has which icon, and whether they show at all,
  stays in Companion Journal.
- With Companion Journal installed, the footer has a **Names | Journal**
  switch (in layout A too) that goes to the other window.

## 1.11.2 Settings without Companion Journal

- Without Companion Journal installed (or turned off), the settings no longer
  mention it: no People tab, no "Open Companion Journal" or "Open Rivals", and
  "Known:" lists just Group, Guild and Friends.
- Preview: the selected player shows one health bar (their own), as in the
  world, and bars sit right under the name when there is no guild line.

## 1.11.1 Battle.net friend icon

- Fixed: a Battle.net friend's icon could stay missing for the whole session
  when their plate appeared before Battle.net linked their character (right
  after you both log in). The icon now appears as soon as their game presence
  arrives; other friends changing zones refresh nothing.
- Note: your People icon counts toward **Show up to**. A companion in your
  group already has two icons (People + Group), so the Battle.net sparkle needs
  **Show up to 3** (Players > Icons).

## 1.11.0 settings window, layout B

- New settings window layout, organized by who a setting is about: **Players,
  Enemies, NPCs, All names**. The footer switch (A | B, in both windows, or
  `/fnames layout a` / `b`) picks it; layout A is the window as it was before
  1.10 and stays as the fallback. Both edit the same settings.
- Players and Enemies use the same cards in the same places (Name, Strangers,
  Level, Guild and title; then Icons and health bars) under a live preview of
  sample players with your settings.
- Enemies now have their own level settings, starting at what you had: size,
  side, color (Match name, Class or Custom) and range (All, 10, 15, 28 yd,
  Target). Also new for enemies: guild rank, the crossed swords' position, the
  icon size, and the health bar color. Layout A keeps writing both sides, so it
  behaves as before.
- One color control everywhere: Match name / Class / Custom with a swatch (level,
  wounded bar, selected player's bar, enemy bar). The selected player's bar
  gains Class.
- Key bindings: "Show or hide friendly levels" and the new "Show or hide enemy
  levels".
- Only Classic level badges in layout B (layout A still offers all styles).

## 1.10.0 People moved to Companion Journal

- Your People list, the journal, the group popup, the campfire and the
  right-click "add" entry are now their own addon: **Companion Journal**
  (`/cj`), with its own window. Forever Names is about names on nameplates.
- With both installed, Forever Names still draws your people's display names
  and icons on its labels, counts them as known (Immersion), and keeps Rivals
  named in enemy stranger mode. It asks Companion Journal through a small API
  (`CompanionJournalAPI`); without it there are no People features here and
  nothing is looked up.
- Your data: Companion Journal copies your people, journals and People options
  from Forever Names' saved settings once, the first time it loads. Nothing is
  removed from Forever Names' saved settings.
- Settings window: the People tab is now a link to Companion Journal (last
  tab); the Immersion page's journal card and Enemies' "Open Rivals" link
  there too. The window reopens on the page you used last.
- `/fnames people`, `/fnames journal`, `/fnames tag` and `/fnames testleave`
  pass on to Companion Journal. The "Add target to People" key binding moved
  with it and keeps working.
- Forever Names publishes `ForeverNamesAPI` (which plates it labels, its icon
  size, its settings window) so Companion Journal's icons beside Blizzard's
  names never double up with ours.

## 1.9.16 groupmates you add later: always on

- Keeping aside what you do with groupmates who are not in your list yet
  (written into their journal when you add them, usually as the group ends;
  forgotten if you don't) is now simply part of the journal. The 1.9.15
  option "Also with groupmates I add later" is gone, from the Immersion page
  and from saved settings.

## 1.9.15 journal: together means together; People first

- Quests: the journal writes "You completed ... together" only with companions
  who had the same quest: seen on it while you travelled together, and still
  with you when its objectives were done (it still counts if they leave before
  you turn it in). A quest only you had (a profession or starter quest turned
  in while grouped) is no longer credited to the group, and a quest you had
  finished alone stays yours. A companion who takes a quest moments after you
  (a letter you both carry) counts. Checked only while you travel with someone
  the journal follows, at most once a second (your party, your quest log).
  The record of who was with you is saved per character until the turn-in (a
  week at most), so a /reload or a night in between keeps it.
- Groupmates who are not in your list yet: what you do together (the outing,
  dungeons, bosses, quests you both had) is kept aside. Add them (from the
  group prompt when they leave, or by hand within the hour) and it becomes the
  start of their journal, which opens with "You first met ... while grouped".
  "Don't add" (or closing the prompt) forgets it; otherwise it is forgotten
  an hour after you part (kept while the prompt still asks). Option: Immersion
  > Your People list > "Also with groupmates I add later" (on; only while the
  journal is on).
- A /reload inside a dungeon continues the outing without writing the dungeon
  a second time.
- Journal paper: clean parchment for everyone; only Rivals get their
  faction's paper.
- Settings: People is the first tab, and the window always opens there.
  Double-click someone in the People list to open their journal.

## 1.9.14 journal line spacing

- Fix: journal entries that wrap to two lines overlapped the next entry. Each
  line was measured before its width was known (a width inherited from
  anchors is only resolved later), so it measured as one line. Lines now get
  an explicit width before measuring, and the page lays itself out again if
  its width changes. The test harness now wraps text at explicit widths.

## 1.9.13 enemy names; gamepad blocks

- Fix: `UnitNameEnemyPlayerName` is never managed. Blizzard's plate shows an
  enemy name only when UnitShouldDisplayName allows it, which follows that
  setting, so turning it off blanked enemy names on Blizzard's plates
  (flagged mode, plates locked to addons). Our labels hide the plate's own
  name region instead; the recorded original value is restored.
- Fix: where the game hides an enemy's name from addons, Blizzard's plate
  stays (as the Enemy tab says) instead of an empty label.
- Fix: the People right-click menu (Add Friend, Whisper, Invite) is not opened
  in the gamepad interface. Opening an addon menu there, and Whisper focusing
  chat from addon code, made Blizzard's gamepad focus code run tainted, so
  later gamepad presses (cancel: SpellStopCasting/ClearTarget; interact
  prompts) were blocked and blamed on Forever Names.
- `/fnames debug` on a targeted player reports enemy details (mode, flag,
  faction, hidden name, plate state, label state, enemy-name setting).

## 1.9.12 raid markers above our labels

- Blizzard's raid marker is anchored to its own (hidden) health bar, so on
  NPC plates it floated beside our label. Labeled plates now draw their own
  marker centered above the name, at Blizzard's size and gap (22 px, 10 px),
  above any "above" icons. The secret marker index goes straight to the icon
  sheet (SetSpriteSheetCell); RAID_TARGET_UPDATE updates drawn labels only.
  "Our names on their bars" keeps Blizzard's marker.

## 1.9.11 raid markers visible

- Fix: raid target markers (skull, star, ...) were hidden on every plate with
  a Forever Names label. Blizzard's RaidTargetFrame is no longer suppressed;
  it keeps placing the marker above the name (the index is secret to addons).

## 1.9.10 review pass

- Fix: with the Enemy tab on **Target** (or a range, where your target always
  shows), selecting an enemy now shows their name at once (target changes
  requeue player plates).
- Fix: two texture paths in GroupPrompt.lua used single backslashes (the
  round portrait mask and the ring never loaded).
- Faster: enemy plates look up the People list only while a People option or
  enemy strangers need it; the settings window no longer redraws while it is
  closed (it redraws when opened).
- Cleanup: unused variables and an empty branch (luacheck clean apart from two
  notes in GroupPrompt/JournalUI); pre-1.2 saved keys (outline, shadow, font,
  size, titleSize) are cleared on load.
- Enemies tab: the right card is titled "Icons and colors".
- Tests: the test harness's Show() now runs OnShow like the game does; the
  enemy Target test no longer forces a refresh (it fails without the fix).

## 1.9.9 fix: enemy levels

- Enemy levels no longer follow the Players tab's "Show for" level scope
  (a far enemy's name showed without its level under "All"). The Enemy tab
  decides whether an enemy label shows; its level goes with it.

## 1.9.8 enemy experiments settled

- Kept: **Mark** (none, « Name », (Name)) on the Enemies tab, and the
  faction emblem always **before** the name. Removed: font and opacity
  experiments, the emblem side choice, "pretend I'm flagged", and the lab
  window (their saved values are cleared on load).
- The Enemies tab's small **Test (not saved)** card keeps "Show friendly
  players as enemies" (`/fnames enemytest`).

## 1.9.5 enemy lab (A/B experiments); flat emblem

- Enemies > "Open the enemy lab": a small window with the test switches (not
  saved) and saved experiments for enemy names: **Font** (Game, Morpheus,
  Skurri, Friz Quadrata, Arial Narrow; enemy name and guild line only),
  **Mark** (none, « Name », (Name)), **Opacity** (100/85/70%), and
  **Emblem** side (like other icons, before, after). WoW has no italic font,
  so a typeface stands in for it. Keep what reads best; prune the rest later.
- "In their class color" draws the faction emblem as a **flat silhouette**:
  solid class color masked by the emblem (tinted emblem if masks are missing).
- Icons are laid out per side: the People icon and the faction emblem may
  each have their own side; everything else follows the Icons page.

## 1.9.4 enemy health bar and class colors

- Enemies > Health bar: **always show their health bar** under their name, in
  their class color, with width and height (`enemyHealthBar`, off by default).
  Same secret-safe StatusBar as the wounded bars, without the curve; not in
  "our names on their bars" mode, where Blizzard's bar is shown.
- **Faction emblem in their class color** (desaturated, then tinted) and
  **their level in their class color** (`enemyFactionClassColor`,
  `enemyLevelClassColor`).

## 1.9.3 tab order

- The Enemies tab now sits right after People (display order only; page
  numbers are unchanged).

## 1.9.2 smaller side tabs

- The settings window's side tabs are drawn at 90% (`TAB_SCALE`), so the
  nine tabs end well above the window's bottom edge.

## 1.9.1 enemy test mode

- Enemies tab > **Test (not saved)**: "Show friendly players as enemies" draws
  friendly players with the Enemy settings, as the other faction; "Pretend I'm
  flagged for PvP" shows the flagged look. Also `/fnames enemytest` and
  `/fnames enemytest flagged`. Both are off again after a reload.

## 1.9.0 Enemy tab (opposite-faction players)

Everything is off by default: with the Enemy tab off, enemy plates stay native.

- **Custom names for opposite-faction players** (open world; where the game
  hides identities, Blizzard's plates stay). Manages `nameplateShowEnemies` and
  hides native enemy world names only while on.
- **While you are flagged for PvP:** Blizzard's plates (default), or our name
  on their plate with Blizzard's health, casts and debuffs kept (only the
  native name is replaced). Switches on your flag change (UNIT_FACTION player).
- **While you are not flagged:** our label, Blizzard's bars hidden. Show names
  for All / 10 / 15 / 28 yd / Target / None (distance checked every 0.75 s
  only in the yard modes; your target always shows).
- Name color Blizzard / class / **faction** (default) / custom; name and
  subtitle size; level (uses the Players level style), guild, title; stranger
  mode with its own style ("Orc Warrior"); Rivals keep their names.
- Icons: Blizzard's **faction emblem** (atlas, texture fallback) and **crossed
  swords** (new glyph) when their PvP flag is on; size/position from Icons.
- **Rivals:** a People category. Add my target / key binding / /fnames tag on
  an enemy files them there; right-click entry on enemy player menus.
- Fix: "Hide Blizzard player names" no longer hides **enemy** player names
  (it made opposite-faction names appear only when targeted). Enemy world
  names are managed only while the Enemy tab is on; the original setting is
  restored automatically.

## 1.8.23 People right-click actions

- Right-click a player in Companions, Acquaintances, or Campfire for **Add Friend**
  **Whisper**, and **Invite to Group**. Whisper opens the chat box ready to type. All actions use the
  stored character name and realm, even when a custom display name is shown.
- NPCs and the blocked list do not offer these actions. Left-click still selects
  a person for editing.

## 1.8.22 never add again (blocklist)

- Selected person > **Never add again**: removes them and adds them to a
  blocklist (`peopleBlocked`) that group and campfire adding skip. Adding them
  by hand (Add my target, typed name, /fnames tag, key binding, right-click)
  allows them again.
- People > Options > "Never added automatically": count and **Show the list**
  (a Blocked view with **Allow again**). Blocked names never affect plates.

## 1.8.21 remove several people in a row

- After Remove, the next entry of the same list is selected (the previous one
  at the end), so many people can be removed quickly.

## 1.8.19 slower distance check

- Nearby-only levels are checked every 0.75 s (1.8.20; was 0.5 s).

## 1.8.18 15 yd level range

- Show for: **All / 10 yd / 15 yd / 28 yd / Target**. 15 yd uses
  C_Item.IsItemInRange with Linen Bandage (1251), the usual 15-yard probe;
  the item is requested once and need not be in your bags.

## 1.8.17 level fade; show level for

- Players > Show their level > **Show for: Everyone / 10 yd / 28 yd /
  Selected** (`playerLevelScope`, `playerLevelRange`; the 1.8.16 checkbox
  carries over). The selected player always shows the level.
- The level (and its pill) fades in and out in 0.2 s when it appears or
  disappears; no fade on a plate's first paint.

## 1.8.16 levels only for nearby players

- Players > Show their level > **Only nearby players** (off by default), range
  **10 yd** or **28 yd** (CheckInteractDistance 3 / 4; the game offers no exact
  distance for other players). The selected player always shows the level.
- Cost while on: a 0.5 s check of labeled players; a plate is requeued only
  when its level crosses the range. Unknown results (the check can be blocked
  in combat) keep the previous state. Nothing runs while it is off.

## 1.8.15 wounded bar color modes

- The wounded bar color can be custom, the player's **class color**, or the
  **name color** (`woundedColorMode`), chosen in the same palette as icons.

## 1.8.14 own key binding section; icon defaults

- Key bindings have their own **Forever Names** section (not AddOns):
  Add target to People, Hide or show names, **Show or hide player levels**.
- "New entries start with" is an icon choice (any glyph or None), default the
  **diamond** (was the heart). Existing entries keep their icons.
- Adding people > "Give them the group icon" (on by default): groupmates
  added automatically get the group glyph in soft blue, per person after.

## 1.8.13 fire icon for campfire people

- New glyph **fire** (18 glyphs; `tools/make_glyphs.py`).
- People > Options > "Give them the fire icon" (under the campfire option, on
  by default): people added at a campfire get the fire icon in orange, stamped
  on their entry so you can change or remove it per person.

## 1.8.11 open straight to your target

- 1.8.12: while the window is open, targeting someone from your People list
  selects them (an edit in progress is saved to the previous person first).

- `/fnames` (or `/fnn`) with a targeted player or NPC from your People list
  opens the People tab with that entry selected. Otherwise the last tab opens.

## 1.8.10 health bar styles remember their settings

- Minimal, Default and Classic each keep their own width, height, gap and
  opacity (`targetHealthStyleSettings`). Switching style no longer resets the
  others; an untouched style starts at its built-in size. Reset bar clears all.

## 1.8.9 per-person icon size

- People > selected person: **Icon size** ([-] Auto [+], 6-48 px). Auto uses
  the Icons tab size; a set size applies to that person only.
- 1.8.8: the wounded bar's bronze rim now belongs to the bar, so the curve
  alpha hides it at full health too (it stayed visible as a thin line).

## 1.8.7 People icon position

- People > Options: the People icon can sit **Before** or **After** the name,
  or **Like other icons** (default, follows the Icons tab). On a different
  side it is placed alone; relationship icons keep their own position.

## 1.8.6 People options back on the People tab

- The People tab has two views, **List | Options** (top right). Options holds
  every list-wide setting in two cards: what the list shows in the world, and
  how people are added. The selected person's "Options" button opens it.
- Immersion is back to immersion settings, with a short pointer to People.

## 1.8.5 Campfire people (experimental)

- New People category **Campfire**, and an experimental option (off by
  default): "Add people who sit at a campfire with me". While your Welcoming
  Campfire timer (spell 1229739, plus any variant Frame Gambit learned with
  /fg campfire) runs, tracked friendly players within about 28 yards with the
  same aura are added ("Met ..., <zone> (by the campfire)").
- Cost: listens only to your own UNIT_AURA while enabled; five bounded scans
  of already-tracked plates during a sit (3, 15, 30, 45, 57 s), stopped when
  you stand up. Needs readable auras (not in combat or instances).
- Players move freely between Companions, Acquaintances and Campfire.

## 1.8.4 per-person icons and tooltips

- Icons are per person: the icon picker has a **None** tile (tracked without
  an icon). "Show their icon" is the master switch. Acquaintances start with
  no icon (the "Also for acquaintances" toggle is gone); "New entries start
  with: An icon / No icon" sets the default for entries you add.
- Tooltip lines appear for people with a note or a "last seen" record: icon
  and name, the note (if any), and when you last saw them.

## 1.8.3 settings layout fixes

- People list options (display names, icons, tooltip notes, last seen,
  auto-adding groupmates, right-click entry) moved to a **People list** card
  on the Immersion page; the People page's right side is only the selected
  person, with an "Options" link and a line saying what shows in the world.
- Color palette: the "Or use" row sits under R/G/B, actions at the bottom.
  Clicking the selected "Class color" / "Name color" again returns to the
  custom color.

## 1.8.2 People categories

- The People list has three tabs: **Companions** (people you add), 
  **Acquaintances** (auto-added from your groups, optional, off by default)
  and **NPCs** (always there; cannot be moved). "Move to Companions /
  Acquaintances" moves players between the first two.
- Auto-add runs on group changes only, never demotes a companion, and records
  when and where you met ("Met 2026-09-26, Tirisfal Glades (grouped)").
- Acquaintances get their own default icon (gray ring), and their icons are a
  separate toggle ("Also for acquaintances"). "Remove all acquaintances" asks
  for a second click.

## 1.8.1 icon color modes; NPCs in People

- Every icon color (each relationship, each People entry) can be a fixed
  color, the player's **class color**, or the **name color** (which includes a
  custom name color). The palette shows "Class color" / "Name color" for icons.
- **NPCs join the same People list**, keyed `npc:<NPC ID>`: Add my target, the
  key binding, `/fnames tag`, or the target frame's right-click menu. They get
  the display name, icon, tooltip note and last seen. A People NPC keeps a
  label even where Forever Names would hide it (plain townsfolk).

## 1.8.0 icons, People, wounded bars, immersion

Everything below is off by default; with it all off the addon looks like 1.7.0.

- **Level:** color (match name, class, custom), size (Auto or custom), style
  (plain number or Minimal/Default/Classic pill), before or after the name.
- **Colors** use the addon's own palette (24 presets plus R/G/B steps).
  Blizzard's color picker is blocked for addons in the gamepad interface; its
  wheel is still offered with mouse and keyboard.
- **Icons tab:** single-color glyphs (`Media/Glyphs`, generated by
  `tools/make_glyphs.py`) for group members, friends, Battle.net friends and
  guild members; per-relationship glyph and color; size, position (before,
  after, above), and "show up to" 1-3.
- **People tab:** account-wide list (`people`, keyed Name-Realm). Display name,
  own icon and color (shown first), tooltip note, last seen date and zone. Add
  with "Add my target", by typing a name, `/fnames tag [note]`, the key binding
  "Add target to People", or the optional right-click entry (hidden in the
  gamepad interface, where the game blocks addon menu entries).
- **Health bars tab:** thin bars on wounded friendly players, or only on group
  members. Health stays secret: the bar gets the values directly and its
  visibility comes from `UnitHealthPercent` through a curve (visible below full
  health). The selected player's bar now sits under the guild line when shown.
- **Immersion tab:** unknown players can keep their name, show as a stranger
  ("Night Elf Druid", "Night Elf" or "Stranger"), or have no label. Known =
  People, plus optional group, guild and friends. "Hide or show names" key
  binding and `/fnames hide` fade every label out and back.
- `/fnames blocked` lists recorded blocked actions (first of each burst).

## 1.7.0 renamed; friendly player label extras

- Renamed to Forever Names (folder `ForeverNames`). Commands: `/fnames`,
  `/forevernames`, and the old `/fnn`. Settings carry over once from
  `FriendlyNPCNamesDB` into `ForeverNamesDB`.
- New **Players** tab (all off by default, for custom player names only):
  level after the name, guild under the name (optional rank: "Officer of
  <Guild>"), chosen title with the full name kept, and name color (Blizzard,
  class, or one custom color). A live preview shows the result.
- Friendly players have their own row in the **Styles** size table.
- The selected player's bar moved to its own **Health bar** tab.
- Cost: nothing is read unless its option is on. The level option subscribes
  to `UNIT_LEVEL` only while enabled. A missing guild gets at most three
  bounded retries per arrival. `/fnames perf` now counts player updates.


## 1.6.1 new settings window only

The single scrolling settings page and the layout toggle were removed. `/fnn`
opens the tabbed window described below; the retired `optionsLayout` saved
value is cleared on load. The last selected page is still remembered
(`optionsPage`).

## 1.6.0 new settings layout

`/fnn` opens a Legacy-style window: icon tabs on the right edge (as in
Forever's Legacy menu) switch between four pages, each a set of cards that fits
without scrolling:

- **General** - hiding Blizzard's NPC names, opposite-faction services, font
  smoothing, *Compare with Blizzard*, and Vendor/Quest giver/Service/Hide/Auto
  buttons for the targeted NPC (same as `/fnn vendor` etc.).
- **NPC styles** - one table row per type: live preview, color swatch, name and
  subtitle size steppers, Reset. Gray sizes are inherited; click a white size to
  inherit again.
- **Visibility** - custom label opacity, the resulting distance ranges, and the
  opt-in game-wide distance/fade/size group.
- **Friendly players** - player-name options, the health bar settings, and a
  live bar preview. Bar settings grey out while the bar is off.

The master **Enable** checkbox stays in the footer on every page.

## 1.5.4 health with either player-name option; preserve surnames

The selected friendly player's custom health bar and optional level pill now work
with **Use custom names for friendly players** checked or unchecked. With it off,
a single reusable addon host attaches the bar beneath Blizzard's native name.
The native name is never rewritten; only the selected plate's native health/level
visuals are suppressed while our bar replaces them. That ownership releases on
target changes, removal, comparison, and disabling the bar. No native health
handler is invoked. Health/level reads still belong only to the selected target.

Custom labels now use this client's `GetUnitName(unit, true)` surname-aware display
formatter, with readable native text/basic-name fallbacks. No tooltip scans are
used for player names.

Either custom player names or the health bar keeps `nameplateShowFriends` enabled,
since the bar requires a nameplate anchor. Turn both off to restore the captured
prior plate setting; changes during combat apply afterward. Existing external
CVar changes are still respected on release. Options text now explains this.

Validation covers full surnames without tooltip reads, native-name anchoring,
target health/level updates, duplicate-bar suppression, target changes, removal
and reentry, switching both name modes, and CVar ownership. Mock tests cannot
validate live appearance/security; `/reload` and check a friendly player with
custom names both off and on. Backup:
`StorageInvestigation/friendlynpc-before-independent-health-1.5.4`.

## 1.5.3 fix tainted native health refresh on target selection

The reported stack entered Blizzard's `TextStatusBar:UpdateTextStringWithValues`
through FNN's manual call to the native nameplate `OnEvent` handler. Its nested
`SetMinMaxValues` callback compared secret health values in addon-tainted execution.
Wrapping that call in `pcall` did not make the native secret-value operations safe.

Removed synthetic native event dispatch entirely. Restoring a selected plate,
disabling the filter, comparison, rollback, and recycling now restore subscriptions
and visual ownership only. Blizzard processes its own subsequent events; native
values can remain at their previous value until Blizzard refreshes them. FNN's
separate custom target bar still initializes immediately through its own StatusBar
API and updates independently. Its health and level features remain available.
The obsolete synthetic-refresh error counter was removed from `/fnn vitals`.

Validation: the native-handler regression rejects the backed-up implementation;
the corrected implementation passes 411 native-vitals assertions and 840 custom
renderer/health/level assertions. All nine Lua files pass syntax checks. These
simulations cannot reproduce WoW's complete taint system. `/reload` is required
to replace the loaded code and clear existing UI taint, followed by an in-game
friendly-player selection check. Backup:
`StorageInvestigation/friendlynpc-before-native-taint-fix-1.5.3`.

## 1.5.2 level pill follows the health-bar style

The bar preset now also chooses the level pill's surface, border, and text palette:
Minimal is flat and borderless with light text; Default uses the same stock
status-bar texture, a subtle bar-color tint, matching dark rim, and light text;
Classic keeps Blizzard's native gold level badge and gold text. Minimal/Default
use Blizzard's portrait alpha mask for rounded ends. If Classic's atlas is absent,
the rounded shell uses the bar's gold border and stock texture instead.

Switching presets updates the live target and preview immediately, reuses the
same pill, and clears artwork from the previous style. It does not add timers,
level reads, or crowd scans. The level checkbox and its default remain unchanged.
Validation: 840 renderer/style/event assertions, 404 native-vitals assertions,
and Lua syntax checks. Actual appearance still needs an in-game check after
`/reload`. Backup: `StorageInvestigation/friendlynpc-before-pill-styles-1.5.2`.

## 1.5.1 optional selected-player level pill

In `/fnn`, under **Selected friendly player's health**, enable **Show player
level in a pill attached to the right of the bar**. It defaults off to preserve
the existing bar appearance. The settings preview includes a sample level 60.
The pill uses this client's `ui-hud-nameplates-levelindicator` artwork and
`SystemFont_NamePlateLevel`, attached with a slight overlap at the bar's right
edge. It inherits bar opacity and engine fading, sizes itself to remain readable
with each bar style, and reserves enough space below the name for its upper rim.
Clients missing that atlas fall back to Blizzard's tooltip border.

The pill is created only when enabled and reused with the single target bar.
It reads only the selected friendly player's effective level (matching Blizzard;
`UnitLevel` fallback for older clients). Selection/enabling, target level events,
and reconnects refresh it; health changes and idle time do not. Hiding the pill
unregisters `UNIT_LEVEL`; disabling the bar, changing to an ineligible target,
leaving range, or comparison mode also releases it. Unknown/restricted levels
display `?`. No native level frame or update mixin is reenabled.

Validation: 804 renderer/event/health/level assertions and 404 native-vitals
assertions, including target-only reads, no hidden/idle level work, appearance
changes without crowd scans, target-change races, restricted values, atlas
fallback, and restoration. Lua syntax checks passed. Visual appearance still
requires `/reload` and an in-game check. Backup:
`StorageInvestigation/friendlynpc-before-level-pill-1.5.1`.

## 1.5.0 selected friendly player health and less arrival work

After `/reload`, open `/fnn` and scroll to **Selected friendly player's health**.
An optional small health bar appears beneath the selected friendly player's custom
name. It defaults on with the Minimal style (82 x 4 px). Default and Classic
presets use the stock WoW status-bar texture with dark and gold borders. Width,
height, spacing, opacity, name-matched/custom color, a static preview, and reset
are available. Dimensions are before engine nameplate scaling. The bar inherits
engine fading and multiplies the custom name opacity. No health text or animation
is added. Native bars and level badges stay hidden on custom friendly plates.

There is one lazily created live StatusBar for all targets, plus a separate static
settings preview. Only `target` health/max-health/connection events are registered
while a selected friendly player has a rendered custom name. No NPC, enemy, self,
or untargeted player health is read by this feature; no level is read. Clearing
the target, leaving range, disabling custom player names/the addon, or entering
comparison mode hides the bar and unregisters its health events. Restricted health
values pass directly to the native StatusBar API, without Lua calculations or
formatting. This works independently of the existing native vitals-filter option
and preserves that saved preference. Blizzard still performs its own initial
native setup; this feature does not prevent engine frame construction.

Arrival optimization: the pending visual-suppression owner becomes the rendered
state directly, avoiding a second region list and ownership pass. Shared alpha
suppression checks the current alpha and writes only when it needs to change,
while still re-hiding native visuals after a native options refresh. Bar settings
refresh only the target/preview; they do not invalidate NPC tooltip caches or
rescan the crowd. The two-arrivals-per-frame queue and zero idle scan behavior
remain intact.

Validation: Lua 5.1 syntax checks; renderer/event/health integration simulations;
and the separate native-vitals permission/rollback suite. Tests cover immediate
native suppression without duplicate writes, one reused health widget, target
changes before notifications, queue delays, combat selection, leaving range,
faction changes, secret health, invalid/failed health writes, styles, size bounds,
settings isolation, and zero idle health reads for 60 simulated seconds. Mocks
cannot establish real-client security compatibility, appearance, or FPS gains.
Reload and verify target/deselection, damage/healing, and crowded camera rotation
in game. Backup: `StorageInvestigation/friendlynpc-before-target-health-1.5.0`.
No saved variables, junctions, or Windows settings were edited.

## 1.4.1 blank until the name is ready

Arrival suppression now runs after Blizzard's `OnNamePlateAdded` completes and
has acquired/initialized the final unit frame. An earlier unit event can refer
to an old or uninitialized frame; hiding that placeholder must not mark the final
frame as handled. The queued work therefore sees an already-hidden native plate,
and delays show as missing custom text rather than a temporary health bar. Native
options refreshes reapply the owned visual suppression while text is pending or
already rendered. Interaction prompts/widgets keep their original visibility.

This prevents display of replaceable visuals on accessible friendly plates; it
does **not** prevent Blizzard from allocating its native frame/bar objects or
running all initial setup. No supported construction-disable switch was found
in the inspected client APIs. `/fnn vitals` includes the loaded version to make
live tests unambiguous when code is updated during a play session.

The user reported almost no stutter after a reload with vitals enabled, but longer
bar-to-name delays. The exact intermediate version/configuration was not recorded.
That is promising subjective evidence, not a measured result for this final build.

## 1.4.0 custom friendly player names and arrival-flash fix

Friendly players now use the same pooled custom text renderer as NPC names.
The player path reads the name and native name color, uses the overall custom
text size/opacity/smooth-scaling preferences, and has no subtitle. It performs
no NPC cursor classification or tooltip scans. Native health/level/cast/aura
visuals are replaced; target information remains available in the target frame.
Enemy players, hostile NPCs, and the personal resource display retain native
rendering. The target-only vitals subscription option also applies to players.

`/fnn players on` enables custom friendly player names; `/fnn players off`
restores the captured prior friendly-player-plate setting. Bare `/fnn players`
reports status. A checkbox is also available under **Friendly players** at the
bottom of `/fnn`. Enabling owns `nameplateShowFriends=1`, since custom text still
requires the native player-nameplate anchor. This is deferred in combat and
does not continually override external changes. Disabling releases that CVar
only if it still has the owned value. NPC-nameplate visibility is separate.

The user found that player plates off with custom NPC names still visible was
smooth. That is evidence for a player-nameplate-specific problem, not proof
that changing fonts or hiding health visuals will fix it. The new renderer
still uses Blizzard's player plate creation/positioning and cannot eliminate
all native setup work. In-game camera-turn/crowd testing is still required.

The earlier two-updates-per-frame queue allowed native health bars to be visible
before the custom label was ready. A lightweight arrival pass now makes replaced
native visuals transparent immediately, including through the driver's post-hook
if the unit event arrived before the frame existed. Font strings, classification,
and subtitles remain queued. Suppression transfers to the rendered state without
an intermediate visible native bar, and releases if the unit disappears before
its queued update. No timer or permanent polling loop was added.

The vitals fix replaces the overly broad protected-container check with actual
object/event access checks. A protected layout alone is not treated as a ban on
permitted event registration or alpha changes. Forbidden/inaccessible event
operations are still skipped. Failed changes roll back; failed restorations
retain ownership for a later retry. `/fnn vitals` now distinguishes **ACTIVE**,
**OFF**, **ENABLED, INACTIVE**, **SUSPENDED (compare)**, and unavailable APIs, with
specific skip reasons. Only successfully modified subscriptions count as paused.
The user's prior screenshot (0 paused, 11–13 skipped) showed no active filtering.

Tests cover immediate suppression before the first queue frame, crowded arrivals,
removal before rendering, friendly-player filtering/color/tooltip avoidance, CVar
restoration/deferred changes, and the native permission/rollback cases. The
protected-container regression fails against 1.3.0. Mock tests cannot establish
real-client security compatibility or frame-time improvements.

## 1.3.0 target-only friendly health and level events

Enabled by default at the user's request, for friendly NPCs **and friendly
players**. Unselected friendly world nameplates stop subscribing to health,
maximum-health, healing/absorb, and level-change events. Their native health
bars and level badges are transparent so stale values are not displayed.
Selecting a friendly unit restores its original subscriptions and asks the
existing Blizzard event handler for a one-time health/level refresh. The NPC
renderer still keeps its custom name/subtitle appearance on selection; a native
player plate regains its health/level visuals. Target-frame updates are untouched.

`/fnn vitals` prints the mode, paused count, inaccessible-frame count, and native
refresh failures. `/fnn vitals off` restores normal subscriptions and visuals;
`/fnn vitals on` enables the filter again. This preference is saved. Disabling
the addon through its own settings or enabling `/fnn compare` restores the
normal subscriptions too. A reload clears compare mode, but keeps the preference.

The filter preserves names, interaction prompts, widgets, enemy plates, and
party/raid frames. It reapplies after native unit-event registration, and releases
ownership on removal, recycling, target/faction changes, or explicit disabling.
NPC-renderer and vitals visibility ownership are coordinated so neither restores
a region the other still needs hidden. Protected/forbidden/unsupported frames
and units with unreadable friendliness are left to Blizzard.

**Scope:** Blizzard's level handling is event-driven, not a constant poll. This
filters the regular health/level change events; it does not intercept initial
plate creation, general native refreshes, name/faction-triggered work, or an
already-pending native update. It does not eliminate all underlying health/level
reads or engine-side plate work. No native function/script is replaced, no native
layout/option/dirty flag is changed, and no periodic addon loop is installed.
Selecting a previously paused unit invokes its existing native event handler
once for each required refresh event. This is an overhead reduction to test,
not a measured stutter fix or a guarantee of live client security compatibility.

`lua Interface/AddOns/FriendlyNPCNames/tests/TargetVitals.lua` covers event bursts,
selection and deselection, friendly players, enemies, pooled-frame reuse, faction
changes, original unit filters, compare/disable restoration, shared alpha ownership,
and protected/secret-data fallbacks. `tests/Smoke.lua` still covers NPC rendering.
The pre-change runtime files are in
`StorageInvestigation/friendlynpc-before-target-vitals-20260923`; saved variables
and the `_SavedVariables.local` junction were not changed.

## 1.2.7 distance-threshold recycling

Overlay font/height/smoothing/color caches now survive native plate release.
Returning plates only apply a font style when it actually differs; settings
edits and native font changes still take effect. Ownership and captured native
region alphas are released/restored normally, including for recycled enemies.

For live diagnosis, `/fnn perf reset` starts session-only counters and queued
update timings. Walk across the threshold, then `/fnn perf` prints arrivals,
removals, updates, style changes and queued Lua time (not GPU/native frame time).
`/fnn compare` temporarily restores Blizzard plates while keeping current CVars,
distance and scale settings. Run it again to restore addon labels. Neither
diagnostic preference is saved; reload clears both. Simulated threshold tests
verify reduced work but do not establish the live stutter's cause.

## 1.2.6 inherited-font smooth scaling

The new smooth-scaling checkbox defaults on. The client UI source declares
`SystemFont_NamePlate` with `slug="true"` and its name label with
`smoothScaling="true"`; the addon now requests that same combination using
the inherited font. It does not force custom font paths/flags or add a size
animation loop. Disable the checkbox for an immediate A/B comparison if
movement hitches recur. Crispness and GPU cost still need live verification.

## 1.2.5 overall and per-category text sizes

The options panel includes separate name/subtitle heights (8-40 px before
engine scaling), overall and alongside each vendor, quest, interactive and
opposite-faction color. Auto uses Blizzard's name height; automatic subtitles
use 80% of the effective name height. Inherit clears a category override.
An asterisk marks inherited values. Opposite-faction size overrides follow
the opposite-faction color switch; with it off, service-role sizes apply.
Previews show effective sizes. Existing installations retain their appearance
until adjusted: new choices use `textSizes`, not the retired legacy fields.
Font family and flags still inherit from Blizzard. No new timers or
game-wide CVar writes are introduced by text sizing.

## 1.2.4 native NPC names across factions

The hide-native-NPC-names checkbox now also manages Blizzard's `UnitNameHostleNPC`
setting (that spelling is intentional). It hides native hostile/opposite-faction
NPC world names as well as friendly ones, and restores the captured preference
when unchecked or disabled. This is a global NPC world-name setting, not a
per-NPC filter; enemy nameplates and the separate player-name option are unchanged.

## 1.2.3 movement-stutter investigation

Unrelated unit-name/faction events no longer schedule a full crowd rescan.
Target/other aliases still refresh their matching visible NPC. Subtitle results
are retained by GUID across range changes in a bounded 256-entry, five-minute
session cache; name changes invalidate the matching entry. Complete tooltips
with no subtitle no longer trigger pointless delayed retries. Saved appearance
settings, nameplate CVars and the renderer are unchanged.

The 424-assertion smoke test passes, including unit-event bursts, returning NPCs,
token recycling, and missing subtitles. The unrelated-event regression fails
against the preceding code. This establishes reduced scan work, not a measured
in-game FPS fix; repeat the reported walk with the renderer enabled to confirm.

Version 1.2.1 uses separate name/subtitle text inheriting Blizzard's native font and the nameplate engine's position, scale, and fade. Only the replaced native visual regions are made transparent, including bars and both level displays. The parent frame, SoftTargetFrame interaction prompt, and WidgetContainer stay under Blizzard's visibility control. This fixes the gamepad prompt disappearing when the parent was transparent. Ownership lives in addon tables; native layout flags, component modes, force-name flags, and health calculations are not changed. No native layout/update routine is called. The attempted direct native-frame conversion was rejected after live restricted-region and secret-health errors.

Saved vendor, quest, interactive, and opposite-faction colors apply to both lines. Subtitles come from the NPC tooltip and use 80% of the configured native name height. Missing subtitles remain absent. Custom smooth scaling stays disabled. Native font objects are inherited, including their font flags; this differs from the previous custom font path. Old font/size/outline controls are retired. The result keeps the earlier two-line placement but is not an exact reproduction of Blizzard's internal player-name layout. Live visual/performance validation is required.

Updates are event-driven. Arrivals are deduplicated and processed two at a time on subsequent frames. Missing unit/title data gets at most three delayed retries per event. There is no OnUpdate loop, periodic crowd sweep, distance calculation, or addon scale animation. A native font-options post-hook refreshes only the addon text; the native unit-clear post-hook releases ownership. Target/combat changes update opacity. Explicit settings edits can refresh all active plates.

Type `/fnn` for standalone settings. Close only hides that window; it does not save bindings or write CVars. Settings change when their controls are used. Live client hangs and performance cannot be proven fixed by the simulated tests.

## Settings and commands

- Enable friendly NPC name-only plates controls this renderer. Friendly noninteractive NPC names are hidden; players and attackable enemies retain native styling.
- Hide native NPC names (both factions) suppresses duplicate world text independently. Disabling it restores previously owned NPC-name CVars.
- Include non-attackable opposite-faction service NPCs enables service cursor/learned-role and English service-subtitle exceptions. Unknown unfriendly units remain native.
- Colors and NPC opacity remain customizable. NPC opacity multiplies engine fading; it cannot reveal engine-hidden labels.
- Optional global distance, scale, fade, and occlusion settings affect ALL nameplates. Existing saved choices are preserved. These are engine controls, not an addon animation. Missing CVars show N/A, and changes defer in combat.
- `/fnn native` disables global customization and restores previous values still owned by this addon, preserving your custom choices for later. It leaves NPC name-only rendering enabled.
- `/fnn vendor`, `/fnn quest`, `/fnn interactive`, `/fnn hide`, and `/fnn auto` manage the targeted NPC's creature-ID override.
- `/fnn debug` prints classification/title information. `/fnn names` prints relevant name CVars.

Disabling the renderer in its own settings restores its current plate changes and owned CVars. Disabling the addon in the addon list cannot run restoration code. CVar preferences apply on login/world entry and explicit edits; external changes are not continually overridden. Native world-name distance has no supported writable setting in this Forever build.

Protected/forbidden plates are skipped. Nameplate range and positioning can differ from hardcoded world names. Role classification depends on the client's cursor information and remembered interactions; it is not a complete NPC database.

## Local beta persistence workaround

This installation has a confirmed Forever SavedVariables loader bug (see `StorageInvestigation/FINDINGS.md`). `_SavedVariables.local` is a junction to account `118944884#4`'s SavedVariables directory; the TOC loads this addon's save before Core.lua. Normal saving remains enabled. Remove that bridge TOC entry when packaging for another installation. Never recursively delete the junction contents: they are the real account saves.

## Verification

`lua Interface/AddOns/FriendlyNPCNames/tests/Smoke.lua` checks native-state preservation, inherited fonts, colors, selective visual suppression/restoration and interaction-prompt visibility, restricted-layout avoidance, filtering, subtitles, recycling, bounded arrival work, standalone options, and CVar restoration. The simulated idle crowd performs zero scans over 60 seconds. `luac -p` checks Lua 5.1 syntax. These are mock-client checks, not measured game FPS or proof of client security compatibility.

After reloading, compare a vendor, quest giver, dialogue NPC, and noninteractive resident. Confirm real names/subtitles, saved colors, no levels, native player/enemy appearance, target changes, and plate recycling. Verify camera movement and closing the standalone options in game.

## A/B baseline

The runtime files for the previous 1.1.8 implementation are preserved in `StorageInvestigation/friendlynpc-before-native-1.2.0`. Restore its Core.lua, Fading.lua, Options.lua and FriendlyNPCNames.toc to the addon folder, then reload. Its TOC does not load NativeRenderer.lua. Do not replace/delete SavedVariables. The comparison changes font rendering as well as scheduling, so it is not an isolated test of one optimization. Version 1.2.0's candidate files are separately preserved in `StorageInvestigation/friendlynpc-native-candidate-1.2.0`.

Hide native (hardcoded) player names is enabled by default. It suppresses friendly and enemy player world names, along with friendly pet, minion, and guardian world names, independently of the NPC toggle, while preserving player nameplate settings. Unchecking it or disabling the addon restores the captured name preferences. Changes during combat are deferred until combat ends. Own-name preferences are unchanged.
# Legacy settings appearance

`/fnn` opens the settings window with Forever Legacy leather, compact gold
borders, native checkboxes and close control, and the Legacy list scrollbar.
Drag the title bar to move it. Settings and nameplate rendering are unchanged;
this replaces the previous appearance without adding a theme selector.

## 1.5.7

Unchecking **Customize distance / size / occlusion for ALL nameplates** (or `/fnn native`) now resets every distance, size, fade and occlusion value to Blizzard's default. It no longer restores a recorded "previous" value. While the option stays off, values still matching the addon's own settings return to the default on each character's next login. Values you change elsewhere afterwards are kept.
