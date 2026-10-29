# Relics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run-only relics on a 5-slot belt and a per-turn Mult on every hit, so a good run snowballs, with harder late fights and bosses to match and the build shown at the run's end.

**Architecture:** All rules live in `scripts/combat.gd`: a `RELICS` table beside `SKILLS` and `MARKS`, the belt as `relics` (saved with the run), `mult()`, and damage split into hits (`hits_to`) so Mult and rounding apply per hit. `damage_to`, `preview_damage` and `resolve_player` all go through `hits_to`, so the preview can't disagree with the hit. A new `RelicPickScreen` (modelled on `PerkPickScreen`) is shown by `game.gd` after won fights, after the Warden and at a Mine start. The fight screen gets a belt row and a Mult readout. Icons are drawn in pxl.

**Tech Stack:** Godot 4.7.2 GDScript; pxl (`node .claude/skills/pxl-pixel-art/bin/pxl.js`); headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-10-29-relics-snowball-design.md`

## Global Constraints

- Mult starts at ×1 each turn. Adds (`+x Mult`) are summed first, then multipliers (`×x Mult`) apply. Mult applies to Attack, every skill's damage and relic damage, after enemy Guard and Bone Wall. It never applies to healing, Guard or Shards.
- A hit is one damage line against one enemy: the Attack total is one hit, and each skill that fires is one hit (Flurry is one hit). Each hit is `floori(base × Mult)`, rounded after Mult. Skill multipliers (Cleave ×1.5, Sunder ×2.5) stay in the skill's base.
- Belt: 5 slots. After every won fight (ambushes too, never the tutorial), pick one of three relics or skip for +3 Shards. Each card has a 1 in 6 chance to be a rare. Beating the Warden gives a pick of three rares, before the existing bonus perk pick. A run that starts in the Mine opens with a pick of three rares. The Pit King gives no pick. A pick never offers a relic already on the belt. Taking a relic onto a full belt breaks the one you choose, for +2 Shards. Belt order can be changed on the pick screen.
- Relics, with numbers as in the spec. **Commons:** Whetstone (Attack dice showing 5 or 6 deal +3 each), Twin Saints (Cleave or Sunder fires: +1 Mult), Rusted Censer (+0.5 Mult per Ember-marked face placed this turn), Clenched Jaw (+0.1 Mult per point of Grit this turn), Tithe Box (after each fight, +1 Shard per 5 held, max +3), Gravedigger's Tally (+0.1 Mult per kill since taken), Miner's Ledger (+1 to the Attack hit per 4 Shards spent at forges since taken), Spare Fuse (each unused reroll at end of turn: +0.25 Mult for this fight's later turns), Ward Icon (Guard left after the enemy phase is added to next turn's Attack hit; lost at fight end). **Rares:** Hungry Bell (+1 Mult per consecutive turn a skill fires; resets on a turn with none and at fight end), Cursed Crown (cursed faces count as 6 for damage; they still break patterns), Gilded Pip (+0.5 Mult per placed die showing a face above 6), Rosary of Steps (Flurry's +3 becomes +9), Black Candle (×1.5 Mult), Pit Lantern (×2 Mult when every placed die is in Attack), Mirror Shard (copies the relic to its right).
- Growing relics count from when taken and keep their own counters. Mirror Shard keeps its own counter, acts at its own place, makes copied economy relics pay twice, and does nothing next to another Mirror Shard or at the end of the belt.
- Balance (first guesses): Warden 120 HP, Pit King 220 HP. Every enemy in a late-column fight (columns 5–7) gets 1.5× HP, after the group is dealt from the unchanged windows. Ambushes and the entrance aren't scaled.
- The dice count stays at 3.
- Run end shows the belt, highest Mult and biggest single hit, then Embers as now. Embers are unchanged. (My call: **highest** Mult reached, not the last turn's, since a run that ends in death often ends on a ×1 turn.)
- Run save keeps the belt, its order and the run counters. An old run save without them loads with an empty belt.
- Relic icons drawn in pxl in the game's palette, with a glyph that reads without colour, like the marks (`art/pxl/marks.px.js` → `assets/ui/cut/mark_<key>.png`).
- Tests: `.\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_combat.gd` → `All combat checks passed.`; `... -s tests/test_fight_flow.gd` → `All fight-flow checks passed.`
- New class_name scripts or PNGs need one `--headless --path . --import` (it may segfault at exit; re-run if a texture is stale). Revert the `.import` line-ending noise on existing files and commit new `.import` files.
- Commit after each task. Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Preview vs. dealt with Cleave across three enemies and a fractional Mult:** the preview total equals what `resolve_player` deals, hit for hit. Test in Task 2.
- **Old campfire save without `relics`:** `valid_dict` accepts it and it loads with an empty belt. Test in Task 4.
- **Full belt plus a pick:** breaking pays +2 Shards and the new relic takes the broken one's slot. Taking a relic already on the belt is refused. Test in Task 2.
- **Mirror Shard at the end of the belt or next to a Mirror:** it does nothing and doesn't crash. Test in Task 2.
- **A scaled Hulk's Rubble and a scaled boss in phase 2:** the Rubble gets the fight's scale, and phase 2 and boss damage % use the enemy's real max HP, not `type.hp`. Test in Task 1.

---

### Task 1: Enemy max HP, late-column scaling, boss HP

**Files:** Modify `scripts/combat.gd` (`TYPES` warden/pit_king hp, `start_group`, `boss_damage_pct`, `is_phase2`, Rubble spawn in `resolve_player`), `scripts/floor.gd` (`deal`), `scripts/game.gd` (`_on_room_picked`), `scripts/combat_screen.gd` (lines reading `type.hp`: 303, 456, 479); Test `tests/test_combat.gd`.

**Interfaces:**
- Produces: every enemy dict has `"max": int`, and nothing reads `type.hp` for the current enemy's max any more. `func start_group(keys: Array, scale := 1.0) -> void` sets `hp = max = ceili(t.hp * scale)` and keeps `var hp_scale := 1.0` for the fight, so a Rubble spawns at `ceili(rubble.hp * hp_scale)`. `Floor.LATE_SCALE := 1.5`. `Floor.deal` sets `room["scale"]` to `LATE_SCALE` on late-column fights and `1.0` elsewhere. `game._on_room_picked` calls `combat.start_group(room.enemies, room.get("scale", 1.0))`, so saved maps without the key still load.

- [ ] **Step 1: Write the failing tests** in a new `_hp_scaling()`:
  - `start_group(["skeleton"], 1.5)`: `enemies[0].hp == 30 and enemies[0].max == 30`.
  - Scaled hulk killed in `resolve_player` → Rubble `hp == ceili(8 * 1.5)`.
  - `start_fight(WARDEN)`: `max == 120`. At `hp = 60`: `is_phase2`, and `boss_damage_pct() == 50`.
  - Pit King `max == 220`; update the existing line-652 check to match.
  - `Floor.deal("chapel")`: every fight in columns 5–7 has `scale == 1.5`, and every other fight has `1.0`.
  - Update `_fight_rewards`' "30/75 took 60%" check to the new Warden HP (`hp = 48` → 60%).
- [ ] **Step 2: Run test_combat — expect FAIL.**
- [ ] **Step 3: Implement** the Interfaces above.
- [ ] **Step 4: Run both suites — PASS.**
- [ ] **Step 5: Commit** — "Late fights and bosses get tougher: scaled HP, Warden 120, Pit King 220".

### Task 2: The belt, Mult and per-hit damage

**Files:** Modify `scripts/combat.gd`; Test `tests/test_combat.gd` (`_relic_belt()`, `_mult()`).

**Interfaces:**
- Consumes: `fired()`, `_values_in(slot, mark)`, `mark_of(d)`, `unplaced_count()`, `perks`.
- Produces:
  - `const RELICS := {id: {"name": String, "text": String, "rare": bool}}` with ids `whetstone, twin_saints, rusted_censer, clenched_jaw, tithe_box, gravedigger, miners_ledger, spare_fuse, ward_icon, hungry_bell, cursed_crown, gilded_pip, rosary, black_candle, pit_lantern, mirror_shard`. Names and texts come from Global Constraints. This task implements the Mult and Mirror relics. Task 3 fills in the rest; until then they're in the table with no effect.
  - `const BELT_SIZE := 5`, `const BREAK_SHARDS := 2`.
  - `var relics: Array = []`. Each entry is `{"id": String, "n": float, "f": float}`: `n` is the run counter (saved), `f` the fight counter, zeroed in `start_group`.
  - `func take_relic(id: String, replace := -1) -> bool`. Refuses an id already on the belt, or a full belt with `replace < 0`. With `replace`, puts the new entry in that slot and pays `BREAK_SHARDS`.
  - `func move_relic(from: int, to: int) -> void`
  - `func relic_id(k: int) -> String`: the id belt slot `k` acts as. Mirror returns its right neighbour's id, or `""` if there is none or it's a Mirror.
  - `func mult() -> float`: `1.0` plus adds, then multipliers. This task covers Twin Saints, Rusted Censer, Clenched Jaw, Gilded Pip, Black Candle and Pit Lantern; Pit Lantern needs at least one placed die. Grit this turn is `func grit_gain() -> int` (unplaced count, ×2 with Grit Teeth). `resolve_player` must use it too.
  - `func hits_to(i: int) -> Array[int]`: base hits on enemy `i`. First the Attack hit (only if some die is in Attack, `i == target`), then one entry per fired skill whose share on `i` is > 0. `skill_share(i)` becomes the sum of the skill entries, so existing callers keep working.
  - `func damage_to(i: int) -> int` = Σ `floori(h * mult() + 0.0001)` over `hits_to(i)`.
  - `func firing() -> Array[int]`: belt slots whose effect changes this turn's damage or Mult right now (for the screen's flash).
  - `var best_hit := 0`, `var best_mult := 1.0`, updated in `resolve_player` from the Mult-applied hits it deals.

- [ ] **Step 1: Write the failing tests:**
  - `take_relic("black_candle")` true. Again: false. Fill to 5, then `take_relic("rosary")` (not on the belt) is false; `take_relic("rosary", 2)` puts it in slot 2 with shards +2.
  - Mirror in the last slot: `relic_id == ""`. Mirror before a Mirror: `""`. Mirror before Black Candle: `"black_candle"`, and `mult() == 2.25`.
  - Twin Saints with a pair in Skill: `mult() == 2.0`. Without it: `1.0`.
  - Black Candle and a 5+4 Attack on an unguarded Skeleton: `damage_to(target) == floori(9 * 1.5) == 13`.
  - **Preview equals dealt:** Rats fight, Cleave pair of 5s, Black Candle. Record `preview_damage()`; `resolve_player()` returns the same, and each rat lost `damage_to(i)` as computed before.
  - Pit Lantern: all placed dice in Attack ×2. One die in Guard: ×1. No die placed: ×1.
  - `best_hit` and `best_mult` after a resolve.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** the Interfaces above.
- [ ] **Step 4: Run both suites — PASS** (no relics: every existing damage check is unchanged).
- [ ] **Step 5: Commit** — "Relic belt and Mult: every hit is base times Mult".

### Task 3: Growing, economy and rule relics

**Files:** Modify `scripts/combat.gd`, `scripts/forge_screen.gd` (lines 135 and 144); Test `tests/test_combat.gd` (`_relic_effects()`).

**Interfaces:**
- Consumes: Task 2's belt, `relic_id`, `hits_to`, `mult`.
- Produces, one effect per relic, each counted once per belt slot acting as that id (so a Mirror copy counts again):
  - **Whetstone:** +3 per Attack die showing ≥5, added to the Attack sum before Guard.
  - **Cursed Crown:** cursed (0) dice in Attack count as 6, before Guard.
  - **Miner's Ledger:** `+floori(n / 4)` to the Attack hit, after Guard. `n` grows in `func pay_forge() -> void` (takes `FORGE_COST` Shards, adds `FORGE_COST` to every Ledger's `n`) and shrinks again in `func refund_forge() -> void`. `forge_screen.gd` calls these instead of changing `shards` directly.
  - **Ward Icon:** at `end_enemy_phase`, `f = guard_pool`. Its `f` is added to the next Attack hit after Guard, then zeroed in `resolve_player`. It's zeroed at fight start too.
  - **Gravedigger's Tally:** `+0.1 × n`; `claim_fight` adds the kills to `n`.
  - **Spare Fuse:** `+f`. `resolve_player` adds `0.25 × rerolls` to `f` after the damage is dealt.
  - **Hungry Bell:** `+(f + 1)` while skills fire this turn, else `+0`. After dealing, `resolve_player` sets `f += 1` if any fired, else `f = 0`.
  - **Rosary:** Flurry's bonus becomes 9 if any slot acts as Rosary.
  - **Tithe Box:** in `claim_fight`, but only when the fight was won: `+mini(3, shards / 5)` per slot. `claim_fight(won := true)`; `game.gd` passes `won`.
- [ ] **Step 1: Write the failing tests**, one check per relic, with the numbers above. Also:
  - Mirror + Tithe Box pays twice.
  - Hungry Bell 1 → 2 → 3 over three skill turns, back to 1 after a turn without a skill, and back to 1 after `start_group`.
  - Ward Icon's stored Guard is gone after `start_group`.
  - A Ledger at 7 spent gives +1, at 8 gives +2.
- [ ] **Step 2: Run — FAIL. Step 3: Implement. Step 4: Run both suites — PASS.**
- [ ] **Step 5: Commit** — "Relic effects: growing, economy and rule relics".

### Task 4: Relics in the run save

**Files:** Modify `scripts/combat.gd` (`SAVED`, `valid_dict`, `from_dict`); Test `tests/test_combat.gd`.

**Interfaces:**
- Produces: `const SAVED_LATER := {"relics": [], "best_hit": 0, "best_mult": 1.0}`. These are fields added after saves existed. `to_dict` writes them, `valid_dict` accepts a dict missing them but rejects one where they're the wrong type, and `from_dict` fills in the defaults. The fight counter `f` is saved as is, since saves happen only at campfires.
- [ ] **Step 1: Test:**
  - Round-trip of a belt with counters, order and `best_*`.
  - A `to_dict()` with those three keys erased: `valid_dict` true, and it loads with an empty belt.
  - `"relics": "x"`: `valid_dict` false.
- [ ] **Step 2: Run — FAIL. Step 3: Implement. Step 4: Run both suites — PASS. Step 5: Commit** — "Run save keeps the relic belt".

### Task 5: Relic pick screen and the run flow

**Files:** Create `scripts/relic_pick_screen.gd`; Modify `scripts/game.gd` (`_on_fight_finished`, `_on_warden_beaten`, `_start_run`); Test `tests/test_combat.gd` (offer), `tests/test_fight_flow.gd` (flow).

**Interfaces:**
- Consumes: `Combat.RELICS`, `take_relic`, `move_relic`, `BELT_SIZE`.
- Produces:
  - `class_name RelicPickScreen extends Control`, with `var combat: Combat`, `var choices: Array`, `var rares := false`, `signal done`.
  - `static func offer(belt: Array, rares: bool, rng: RandomNumberGenerator) -> Array`. It returns up to 3 distinct ids not on the belt. With `rares`, all come from the rare pool. Otherwise each card is rare with chance `RARE_CHANCE := 1.0 / 6.0`, falling back to the other pool when one runs dry.
  - `const SKIP_SHARDS := 3`.
  - The screen copies `PerkPickScreen`'s card look, with relic icons. Heading: "Spoils" for a fight pick, or "The Warden's hoard" / "Into the Mine" for rare picks. Below the cards is the belt row. Each belt relic has a ◀ button that moves it left. When the belt is full, Take asks which relic to break (a ConfirmPanel per belt relic, or a second row of Break buttons). Skip gives `SKIP_SHARDS`. Every path emits `done`.
  - `game.gd`:
    - A won non-final fight (ambush too) shows the pick, then `_next_room`.
    - Warden: rare pick → perk pick → campfire.
    - `_start_run("mine")`: rare pick → map.
    - Pit King: straight to `_end_run(true)`.
    - Tutorial: unchanged.
- [ ] **Step 1: Test:**
  - `offer` with 4 rares on the belt and `rares=true` gives the 3 remaining rares.
  - `offer` never returns a belt id over 200 draws.
  - Flow: win a fight → RelicPickScreen → Take → the belt has it and the map is on the next layer.
  - Skip → +3 Shards.
  - Full belt → Take, break slot 0 → +2 Shards.
  - Kill the Warden → RelicPickScreen (all rares) → PerkPickScreen → campfire.
  - Start in the Mine → RelicPickScreen before the map.
  - Kill the Pit King → end notice, with no pick shown.
- [ ] **Step 2: Run — FAIL. Step 3: Implement. Step 4: Import, run both suites — PASS. Step 5: Commit** — "Relic picks after fights, the Warden and a Mine start".

### Task 6: The belt and Mult on the fight screen

**Files:** Modify `scripts/combat_screen.gd` (`_build`, `_refresh`, `_on_end_turn`); Test `tests/test_fight_flow.gd`.

**Interfaces:**
- Consumes: `relics`, `relic_id`, `mult()`, `firing()`, `hits_to`.
- Produces:
  - A belt row beside the dice tray, one `relic_<id>` icon per slot.
  - Hovering an icon shows the name and text. A Mirror shows "Copying: <name>".
  - Growing relics (Tally, Ledger, Fuse, Bell, Ward Icon) show their current value as small text on the icon.
  - The summary reads `Damage %d (×%s)` with Mult to one decimal, shown only when Mult ≠ 1. Its tooltip lists each enemy's base hits and the Mult.
  - In `_on_end_turn`, slots in `firing()` (read before `resolve_player`) flash gold as the hero's attack lands.
- [ ] **Step 1: Test** (fight-flow):
  - A fight with three relics has three belt icons.
  - With Black Candle, the summary shows `×1.5`; without relics, no `×`.
  - A full turn with every relic on the belt in turn plays with no engine errors.
- [ ] **Step 2: Run — FAIL. Step 3: Implement. Step 4: Run both suites — PASS.**
- [ ] **Step 5: Render check** with a non-headless scratch script outside the repo: a fight with five relics at 1280x720 and 1812x720. The belt doesn't overlap the tray or the buttons.
- [ ] **Step 6: Commit** — "The relic belt and Mult on the fight screen".

### Task 7: The build at the run's end

**Files:** Modify `scripts/game.gd` (`_end_run`); Test `tests/test_fight_flow.gd`.

**Interfaces:** `_end_run` adds three lines after "Boss damage dealt":
- `"Relics: " + ", ".join(names)`, or "Relics: none"
- `"Highest Mult: ×%.1f" % best_mult`
- `"Biggest hit: %d" % best_hit`

The Embers line stays highlighted (move the `highlight` index to match).

- [ ] **Step 1: Test:** a lost run with two relics and `best_hit = 41` shows those lines, and the highlighted line is still the Embers one. **Step 2: Run — FAIL. Step 3: Implement. Step 4: Run both suites — PASS. Step 5: Commit** — "Run end shows the relics, highest Mult and biggest hit".

### Task 8: Relic icons

**Files:** Create `art/pxl/relics.px.js`, `assets/ui/cut/relic_<id>.png` (16); Test `tests/test_combat.gd`.

- [ ] **Step 1: Test:** every `Combat.RELICS` id has `ResourceLoader.exists("res://assets/ui/cut/relic_%s.png" % id)`.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Draw** with the pxl-pixel-art skill, at the marks' size and palette (sample `art/pxl/marks.px.js`). One readable object per relic: whetstone, two saint figures, censer, clenched jaw, tithe box, tally-marked shovel, ledger, fuse, ward icon, bell, cracked crown, gilded die pip, rosary, black candle, miner's lantern, mirror shard. Rares get a gold rim. Build, and copy the PNGs into `assets/ui/cut/` the way the marks were.
- [ ] **Step 4: Render check** of the belt and the pick screen with all 16, using Task 6's scratch script.
- [ ] **Step 5: Import, run both suites — PASS. Commit** — "Relic icons, drawn in pxl".

### Task 9: Final check and handoff

- [ ] Run both suites on the final commit.
- [ ] Render a fight with a full belt, a relic pick and a run-end notice.
- [ ] Hand the game to the owner for a full two-floor run. Tuning numbers (Mult values, HP scale, boss HP, rare chance) is follow-up.
