# Branching Map and Mystery Rooms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the button-row map with a branching, left-to-right map drawn on the parchment, where you can only walk along links, and add "?" rooms holding nine events (four of them dice rolls) or an ambush.

**Architecture:** A new `Floor` class deals the floor as data (columns of rooms with links). `MapScreen` draws that data on the parchment. A new `Events` class holds the event rules as pure functions over `Combat`; a new `EventScreen` shows an event, throws dice in a `DiceTray` and applies the result. `game.gd` keeps the run flow and wires rooms to screens.

**Tech Stack:** Godot 4.7.2, GDScript, screens built in code (`scripts/ui.gd`), headless test scripts extending SceneTree.

**Spec:** `docs/superpowers/specs/2026-10-23-branching-map-and-events-design.md`

## Global Constraints

- Godot 4.7, GDScript; 1280x720 canvas; screens built in code with the `UI` helpers.
- Ten columns, five lanes; column 0 the entrance (one fight), column 9 the Bone Warden (one room).
- Fight HP ranges stay as now: ENTRANCE_HP `[18, 26]` (column 0), EARLY_HP `[18, 38]` (columns 1–4), LATE_HP `[42, 56]` (columns 5–7).
- Room rolls in columns 1–7: fight 55%, "?" 20%, campfire 13%, forge 12%. Columns 1–2: fight or "?" only. Column 8: all campfires.
- No event takes the player below 1 HP. Every event but the corridor has a way out at no cost.
- Existing behaviour that must keep working: tutorial, boss fight, `--fight=N`, camp, perks, audio hooks in `game._show`.
- Tests run with the console binary from the project root:
  - `.\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_combat.gd` → last line `All combat checks passed.`
  - `.\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_fight_flow.gd` → last line `All fight-flow checks passed.`
- Commit after each task, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Gambler's skull with fewer than 4 Shards:** the bet choice is disabled, not a negative Shard count. Test in Task 4.
- **Events at 1 HP:** shrine, corridor, bone pile, chest and altar leave you at 1 HP, never 0. Test in Task 4.
- **Carving a die whose other faces are all cursed:** the 9 is carved and nothing else changes; no crash on an empty choice. Test in Task 1.
- **Forging a cleared curse twice:** the first forge restores the old value, the second adds FORGE_STEP as normal. Test in Task 1.
- **Clicking a room that isn't linked:** nothing happens; only linked rooms are clickable. Test in Task 3.

---

### Task 1: Lasting curses and event helpers in Combat

**Files:**
- Modify: `scripts/combat.gd` (die dictionaries in `_init`, `forge`, new functions)
- Test: `tests/test_combat.gd` (new `_lasting_curse()` and `_event_helpers()`, called from `_init`)

**Interfaces:**
- Produces:
  - each die dictionary gains `"uncursed": {}` — face index → value it had before a lasting curse
  - `func curse_face(i: int, f: int) -> void` — lasting curse: remembers `base[f]` in `uncursed`, sets `base[f] = CURSE`, copies `base` to `faces`
  - `func carve(i: int, f: int) -> int` — sets `base[f] = 9` (clearing any curse record on f), then `curse_face`s a random other face of die i that isn't already CURSE; returns that face index, or -1 if none
  - `forge(i, f, no_cost)` — if f is in `uncursed`, restores that value and erases the record instead of adding FORGE_STEP
  - `func hurt(amount: int) -> int` — loses up to `amount` HP but never below 1; returns HP actually lost
  - `func lose_max_hp(amount: int) -> void` — max_hp -= amount; player_hp = clampi(player_hp, 1, max_hp)
  - `var bonus_embers := 0`
  - `func roll_dice(which: Array) -> Array` — rolls each die index in `which` (using `_roll`) and returns their values in order

- [ ] **Step 1: Write the failing tests**

```gdscript
func _lasting_curse() -> void:
	var c := CombatScript.new(7)
	c.curse_face(0, 5)  # the 6
	check(c.dice[0].base[5] == CombatScript.CURSE and c.dice[0].faces[5] == CombatScript.CURSE, "a lasting curse is on the die")
	c.start_fight(SKELETON_BELL)
	check(c.dice[0].faces[5] == CombatScript.CURSE, "it survives into the next fight")
	c.dice[0].value = CombatScript.CURSE
	c.assign(0, CombatScript.Slot.GUARD)
	c.resolve_player()
	check(c.dice[0].faces[5] == CombatScript.CURSE, "Guard doesn't burn a lasting curse off")
	c.forge(0, 5, true)
	check(c.dice[0].base[5] == 6, "forging clears it back to the old face")
	c.forge(0, 5, true)
	check(c.dice[0].base[5] == 6 + CombatScript.FORGE_STEP, "after that, forging adds as usual")
	var k := CombatScript.new(7)
	var g := k.carve(1, 0)
	check(k.dice[1].base[0] == 9 and g != 0 and k.dice[1].base[g] == CombatScript.CURSE, "carve: a 9, and another face cursed")
	var all := CombatScript.new(7)
	for f in range(1, 6):
		all.curse_face(2, f)
	check(all.carve(2, 0) == -1 and all.dice[2].base[0] == 9, "carving with every other face cursed curses nothing more")


func _event_helpers() -> void:
	var c := CombatScript.new(7)
	c.player_hp = 3
	check(c.hurt(6) == 2 and c.player_hp == 1, "hurt stops at 1 HP")
	c.player_hp = 3
	c.lose_max_hp(5)
	check(c.max_hp == CombatScript.PLAYER_MAX_HP - 5 and c.player_hp == 3, "max HP drops; HP below it stays")
	c.player_hp = c.max_hp
	c.lose_max_hp(5)
	check(c.player_hp == c.max_hp, "HP is capped by the new max")
	var v := c.roll_dice([0, 2])
	check(v.size() == 2 and v[0] == c.dice[0].value and v[1] == c.dice[2].value, "roll_dice returns the rolled values")
```

- [ ] **Step 2: Run the rules test to verify it fails**

Run the rules test (Global Constraints). Expected: parse errors naming `curse_face` / `hurt`.

- [ ] **Step 3: Implement the Interfaces above in `scripts/combat.gd`**

Update the TYPES comment / file header to say lasting curses live in `base`. `start_group` and the Guard burn-off already copy `base` to `faces`, so a curse in `base` survives both without other changes.

- [ ] **Step 4: Run the rules test to verify it passes**

Expected: `All combat checks passed.`

- [ ] **Step 5: Commit** (`scripts/combat.gd`, `tests/test_combat.gd`), message "Lasting curses, carve, and event helpers in Combat".

---

### Task 2: Floor dealer

**Files:**
- Create: `scripts/floor.gd` (`class_name Floor`, `extends RefCounted`)
- Modify: `scripts/game.gd` — delete `make_map`, `_group`, `_fight_room`, `ENEMIES`, `*_HP`, `LAYERS`, `EARLY_LAYERS`, `SPECIALS` (they move to Floor or go away); `_start_run` calls `Floor.deal()`
- Test: `tests/test_combat.gd` — replace `_maps()` with `_floors()`

**Interfaces:**
- Produces:
  - `const COLUMNS := 10`, `const LANES := 5`, `ENEMIES`, `ENTRANCE_HP`, `EARLY_HP`, `LATE_HP` (values as now), `const BOSS := 6`
  - `static func deal() -> Array` — the floor: `COLUMNS` arrays (columns), each an Array of room Dictionaries sorted by lane:
    `{"kind": "fight"|"unknown"|"forge"|"campfire", "lane": int, "next": Array[int], "label": String}` plus `"enemies": Array` for fights. `next` holds indices into the next column. The boss room is `kind "fight"`, `enemies ["warden"]`, `label "Boss: Bone Warden"`, `next []`. Labels: fights as now (`"Fight: Archivist, Bone Rats"`), `"Forge"`, `"Campfire"`, `"?"`.
  - `static func group(hp: Array, used: Dictionary) -> Array` — the current `_group`, plus: after 200 failed tries, accept a repeat
  - `static func fight_room(keys: Array) -> Dictionary` — the current `_fight_room` (no lane/next; deal adds them)

- [ ] **Step 1: Write the failing test `_floors()`**

Over 200 dealt floors check, each with its own message:
- 10 columns; columns 0 and 9 have one room; columns 1–8 have 2 to 5 rooms; lanes in a column are distinct and in 0..4, sorted
- every room in columns 1–9 has at least one parent; every room in columns 0–8 has at least one `next`; every `next` index is valid
- no crossing: for any two links a→b and x→y in the same gap (by lane), not (a < x and b > y) and not (a > x and b < y)
- column 8 all `"campfire"`; columns 1–2 only `"fight"` or `"unknown"`; no forge links to a forge, no campfire to a campfire
- fight HP totals: column 0 in ENTRANCE_HP, columns 1–4 in EARLY_HP, 5–7 in LATE_HP; 1–3 enemies from `Floor.ENEMIES`
- no enemy group twice on a floor (as the old test)
- the last room is `enemies == ["warden"]`, label `"Boss: Bone Warden"`
- over all 200: every kind appears in columns 3–7, and more than 5 distinct column-1 shapes (`[rooms.size(), lanes]`)

- [ ] **Step 2: Run the rules test to verify it fails** — Expected: `Floor` not declared.

- [ ] **Step 3: Implement `Floor.deal()`**

The walk, which the tests check but don't pin down:

```gdscript
# rooms[c] maps lane -> room; links[c] holds [from_lane, to_lane] pairs for the gap c -> c+1
# entrance at lane 2. Five walkers; first steps to lanes 0, 1, 3, 4 and one random lane.
# Columns 1..7: each walker steps to lane-1, lane or lane+1 (kept in 0..LANES-1), picked at random from
# the steps that don't cross a link already in that gap (straight never crosses, so there's always one).
# Column 8 -> boss: every column-8 room links to the boss (lane 2).
```

Then roll kinds column by column, after links exist: column 0 and 9 fights, column 8 campfires, columns 1–2 fight 55/(55+20) else "?", columns 3–7 by the Global Constraints rates; if the roll is forge or campfire and any parent has the same kind, roll again. Then deal enemy groups per column range with one shared `used`. Finally convert lane maps to sorted arrays and links to `next` indices.

- [ ] **Step 4: Wire `game.gd`** — `map = Floor.deal()` in `_start_run`; `--fight=N` and `_end_run` keep using `map.size()`. Map screen still renders (Task 3 redraws it); don't fix layout here.

- [ ] **Step 5: Run both tests** — Expected: both pass.

- [ ] **Step 6: Commit** — "Deal branching floors in Floor".

---

### Task 3: Drawn map screen and linked moves

**Files:**
- Modify: `scripts/map_screen.gd` (rewrite the room area), `scripts/game.gd` (`_on_room_picked`, `_show_map`)
- Test: `tests/test_fight_flow.gd` (new `_map_moves()`, run before the fights)

**Interfaces:**
- Consumes: `Floor.deal()` rooms (`kind`, `lane`, `next`, `label`, `enemies`)
- Produces:
  - `MapScreen.pickable() -> Array` — room indices in column `layer` you may enter: `[0]` when `layer == 0`, else `rooms[layer - 1][path[layer - 1]].next`
  - `MapScreen.room_buttons: Array` — per column, its rooms' `TextureButton`s (tests click them)
  - `signal picked(index: int)` (unchanged)

- [ ] **Step 1: Write the failing test `_map_moves()`**

Start a game as `_play` does, call `game._show_map()`, then:
- every room button outside `pickable()` is disabled; every one inside is enabled
- set `game.layer = 2`, `game.path = [0, p]` where `p` is `map[1]`'s first room index linked from 0, show the map again; check `pickable() == game.map[1][p].next`
- a disabled room button can't be pressed: `button.disabled` is true and its `pressed` signal is the only path to `picked`, so emitting nothing changes `game.layer` (check `game.layer` is unchanged after a frame)
- no engine errors while doing so (same ErrorCounter check as `_play`)

- [ ] **Step 2: Run the flow test to verify it fails** — Expected: `pickable` not found.

- [ ] **Step 3: Implement the drawn map**

- The room area is a Control over the parchment (keep the HP/Shards row and title as now); positions: column c at x = left + (c + 0.5) / 10 * width, lane l at y = top + (l + 0.5) / 5 * height, inside the parchment with an inset that clears its burnt edge.
- Links drawn in `_draw()` with `draw_dashed_line` in ink `Color(0.23, 0.16, 0.1)`, width 2, alpha 0.75 ahead and 0.2 behind; walked links solid `Color(0.48, 0.14, 0.09)`, width 3; links leaving branches you passed by aren't drawn.
- Rooms are `TextureButton`s with the room art (`room_` + kind, `room_unknown` for "?", `room_boss` for the boss, `room_cleared` once walked), `texture_filter` nearest, `tooltip_text` = the room's label for fights, nothing for "?".
- Pickable rooms glow: `modulate` = `UI.GOLD` pulsing with a looping tween between 0.8 and 1.2 brightness; future rooms alpha 0.6; passed-by rooms hidden; disabled when not pickable.
- "The Warden's Lair" label under the boss in the ink colour.
- `game._on_room_picked(i)`: `path.append(i)`; room is `map[layer][i]`; `"unknown"` goes to Task 5's handler (for now treat it as a fight against an EARLY_HP group so the flow works).

- [ ] **Step 4: Run both tests** — Expected: both pass.

- [ ] **Step 5: Screenshot check** — render the map three rooms in (a scratch SceneTree script like the one used for the old map: start a run, set `path`/`layer`, `_show_map()`, save the viewport) and compare with the approved mockup `.superpowers/brainstorm/1644-1792757756/content/map-branching.html`: rooms on the parchment, no frames, links visible, glow on pickable rooms, nothing off-screen.

- [ ] **Step 6: Commit** — "Draw the floor as a branching map".

---

### Task 4: Event rules

**Files:**
- Create: `scripts/events.gd` (`class_name Events`, `extends RefCounted`)
- Test: `tests/test_combat.gd` (new `_events()`)

**Interfaces:**
- Consumes: Task 1's `hurt`, `lose_max_hp`, `bonus_embers`, `carve`, `heal`, `shards`
- Produces:
  - `const IDS := ["shrine", "pilgrim", "altar", "niche", "bone_pile", "corridor", "chest", "gambler", "cursed_cast"]`
  - `const AMBUSH_CHANCE := 0.2`, `const AMBUSH_SHARDS := 4`
  - `const EVENTS := {id: {"title": String, "text": String, "choices": [{"label": String, "dice": int}]}}` — `dice` is 0 (no roll), 1 (the player clicks one die to throw) or 3 (all dice). The last choice is the way out, except the corridor.
  - `static func pick(seen: Array) -> String` — a random id not in `seen`, or `""` if all are seen (the game then ambushes)
  - `static func can_choose(id: String, choice: int, c: Combat) -> bool` — false only for the gambler's bet under 4 Shards
  - `static func resolve(id: String, choice: int, c: Combat, rolled: Array, tries := 1) -> Dictionary` — applies the outcome to `c` and returns `{"text": String, "forge": int, "carve": bool, "retry": bool}` (missing keys mean 0/false). `forge` is how many free forge upgrades to grant; `carve` asks the game to let the player pick a face to carve; `retry` shows the choices again (chest only).
  - The skull's three dice for the gambler are `rolled[3..5]`, rolled by the screen with `c.rng.randi_range(1, 6)`.

Outcomes, exactly as the spec (choice 0 is the first listed):
- shrine: 0 → `hurt(6)`, forge 1; 1 → nothing
- pilgrim: 0 → shards += 6; 1 → `heal(5)`
- altar: 0 → `lose_max_hp(5)`, forge 2; 1 → nothing
- niche: 0 → `bonus_embers += 10` (one choice only, "Take the embers")
- bone_pile (dice 1): 0 → roll ≤ 2: `hurt(4)`; else shards += roll; 1 → nothing
- corridor: 0 (dice 3) → total ≥ 10 nothing, else `hurt(10 - total)`; 1 (dice 0) → `hurt(4)`
- chest (dice 1): 0 → roll ≥ 5: forge 1; roll ≤ 1 (a cursed 0 counts as the worst): `hurt(5)`, ends; 2–4: retry if tries < 2; 1 → nothing
- gambler (dice 3): 0 → pay 4; yours > skull: +8; tie: +4; less: nothing; 1 → nothing
- cursed_cast: 0 → carve true; 1 → nothing

- [ ] **Step 1: Write the failing test `_events()`** — one check per outcome above using fixed `rolled`, including:
  - shrine at 3 HP leaves 1 HP and grants forge 1
  - corridor `[1, 2, 3]` at 40 HP loses 4; at 2 HP leaves 1
  - chest: `[1]` hurts 5 and `retry` false; `[3]` with tries 1 → retry true, with tries 2 → false; `[6]` → forge 1
  - gambler: `can_choose("gambler", 0, c)` false at 3 Shards, true at 4; `[6,6,6, 1,1,1]` from 4 Shards → 8; `[1,1,1, 6,6,6]` → 0; `[2,2,2, 3,2,1]` → 4
  - bone pile `[0]` (a cursed face) hurts 4
  - `pick(Events.IDS)` → `""`; `pick([])` ∈ IDS
  - every EVENTS entry but corridor has a last choice whose resolve changes nothing in `c`

- [ ] **Step 2: Run the rules test to verify it fails** — Expected: `Events` not declared.
- [ ] **Step 3: Implement `scripts/events.gd`.** Text in the game's voice: terse, grim, a little dry (e.g. shrine: "A shrine split down the middle. Something still listens."). Result texts state the outcome with numbers ("The rat bites. -4 HP.").
- [ ] **Step 4: Run the rules test** — Expected: `All combat checks passed.`
- [ ] **Step 5: Commit** — "Event rules for mystery rooms".

---

### Task 5: Event screen and "?" rooms in the run

**Files:**
- Create: `scripts/event_screen.gd` (`class_name EventScreen`, `extends Control`)
- Modify: `scripts/dice_tray.gd` (`signal landed`), `scripts/forge_screen.gd` (cursed faces, carve mode), `scripts/game.gd` ("?" handling, ambush, embers)
- Test: `tests/test_fight_flow.gd` (new `_play_events()`)

**Interfaces:**
- Consumes: `Events` (Task 4), `Combat.roll_dice`, `Combat.carve`, `Combat.bonus_embers` (Task 1)
- Produces:
  - `DiceTray.landed` — emitted once when the last rolling die settles after a `throw`
  - `EventScreen`: `var combat: Combat`, `var id: String`, `signal finished(result: Dictionary)`; `func choose(choice: int, die := 0) -> void` (what a button press or die click calls; tests call it directly)
  - `ForgeScreen.carve := false` — face clicks call `combat.carve(i, f)` and emit `done`; heading "Carve a 9"
  - `game.seen_events: Array`, `game.ambush := false`

- [ ] **Step 1: Write the failing test `_play_events()`** — for each id in `Events.IDS`: start a game, create the EventScreen via the game's handler with that id forced, call `choose(0)` (for dice events wait for `finished`), and follow the result through any forge/carve screens by pressing their first enabled face, until the map shows again. Check no engine errors and that the screen after is a MapScreen. Plus one ambush: force ambush, play it as `_play` does, check Shards rose by at least `Events.AMBUSH_SHARDS` on a win.

- [ ] **Step 2: Run the flow test to verify it fails** — Expected: `EventScreen` not declared.

- [ ] **Step 3: Add `DiceTray.landed`** — in `_process` (or where `rolling` turns false), emit when a throw was in flight and no die is rolling any more.

- [ ] **Step 4: ForgeScreen** — a face whose `base` value is `Combat.CURSE` uses the `die_cursed` art for its normal style and shows "0"; add the `carve` mode.

- [ ] **Step 5: EventScreen**

- Backdrop "campfire" behind a centered column like NoticeScreen: title (48), text (20), a row of choice buttons (`can_choose` disables), and below them a DiceTray (about 640x200, framed like combat's `_build_dice`) shown only for dice events.
- dice 1: text "Pick a die to throw." and wait for `die_clicked(i)`; dice 3: throw all. Rolls come from `combat.roll_dice`, shown with `tray.show_die` then `tray.throw`; wait for `landed`; gambler adds three skull dice (tray dice 3–5, plain `[1..6]` faces in the "locked" art so they read as the skull's, not yours) rolled with `combat.rng`.
- After `resolve`: replace the text with the result, show "Go on" (emits `finished(result)`), or the choices again when `retry`.

- [ ] **Step 6: game.gd**

- `"unknown"` room: if `randf() < Events.AMBUSH_CHANCE` or `Events.pick(seen_events) == ""` → ambush: `ambush = true`, notice line "Something moves in the dark." (via the combat log `_log` is fine, or a short NoticeScreen), fight `Floor.group(Floor.EARLY_HP, {})`. Else `seen_events.append(id)` and show EventScreen.
- `finished(result)`: `result.forge` free forge screens in a row (`_show_forge(true)` chained), then a carve ForgeScreen if `result.carve`, then `_next_room()`.
- `_on_fight_finished`: if `ambush` and won, `combat.shards += Events.AMBUSH_SHARDS`; reset `ambush`.
- `_end_run`: add `combat.bonus_embers` to `earned`. `_start_run` clears `seen_events`.

- [ ] **Step 7: Run both tests** — Expected: both pass.

- [ ] **Step 8: Screenshot check** — render the bone pile and the gambler's skull after landing; text readable, dice in the tray, buttons on screen.

- [ ] **Step 9: Commit** — "Mystery rooms: events, dice rolls and ambushes".

---

### Task 6: Whole-run check

- [ ] **Step 1:** Run both test suites. Expected: both pass.
- [ ] **Step 2:** Launch the game (`Start-Process .\Godot_v4.7.2-stable_win64.exe -ArgumentList "--path", "."`) and hand it to the owner for a playtest of a full run; note anything they report as follow-up tuning, not part of this plan.
