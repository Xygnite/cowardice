# The Hollow Mine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A second floor, the Hollow Mine, with five new enemies, the Rubble and the Pit King, reached by beating the Warden (with a bonus perk) or chosen at camp once unlocked.

**Architecture:** Floors become data: `Floor.FLOORS` holds each floor's enemies, HP windows, boss, title and backdrop, and `Floor.deal(floor_id)` deals either. Combat gains the Mine's rules (attack bonuses, the Rubble, burying) as new `TYPES` keys and small hooks, played first with the existing placeholder boxes. `game.gd` carries one run across both floors. Art comes last: each character is drawn as a pxl still, then goes through the existing rig → pxl frames pipeline; the Mine backdrop is a pxl scene with BackdropLife.

**Tech Stack:** Godot 4.7.2 GDScript; pxl (`node .claude/skills/pxl-pixel-art/bin/pxl.js`); the rig/frames tools in `tools/`; headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-10-24-hollow-mine-design.md`

## Global Constraints

- The Gambler and the Monk appear nowhere (reserved as future heroes).
- Mine fight HP windows: entrance 24–36, early 34–50, late 56–72. The Mine's last column before the boss is all campfires, as in the Chapel.
- Enemy numbers (first guesses, to tune): Lantern-Eye Miner ~22 HP (attack, attack, unblockable); Tunnel Crawler ~8 HP; Rubble Hulk ~30 HP; Rubble ~8 HP; Canary Wraith ~12 HP (ring); Shaft Foreman ~26 HP; Pit King ~110 HP.
- Attack bonuses: Shaft Foreman +2 to every other enemy's attack; each Tunnel Crawler +1 per other living Crawler; they add; only on attack/unblockable values; recomputed each turn from who is alive; the intent shows the final number.
- Burying: a cave-in (enemy phase) buries one random unburied die; next turn that die isn't rerolled, keeps its value and slot, can't be rerolled/locked/unlocked/moved, gives no Grit if unplaced; free the turn after; Pit King phase 2 buries one die per turn alongside an attack; never the last unburied die.
- Rubble: when a Rubble Hulk dies, a Rubble replaces it at the same index at once, with no intent until next turn; both count as kills.
- Run: beating the Warden leads to a bonus-perk pick (3 random perks, owned or not, excluding the 2 equipped; active this run only, applied once: Thick Skin +10 max HP and +10 HP), then a campfire stop (not a room), then the Mine. HP, Shards, dice, perks and seen events carry over. Beating the Warden unlocks the Mine (Meta, saved; old saves load locked). Camp offers a floor choice once unlocked; a Mine start never gets the bonus perk.
- Embers: rooms cleared add up across both floors; a run is only "won" by beating the Pit King (a Warden win always continues down), and that win pays +100 instead of today's +50; boss damage % is against the boss of the floor the run ended on; victory screen only after the Pit King.
- Art: pxl only, in the game's palette (sample existing sprites/backdrops); characters at the Chapel cast's scale (normal ≈ Skeleton height, Pit King ≈ Warden size); attack impact 0.2 s in.
- Tests: `.\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_combat.gd` → `All combat checks passed.`; `... -s tests/test_fight_flow.gd` → `All fight-flow checks passed.` (every new enemy and the boss play a real fight with no engine errors).
- New class_name scripts or PNGs need one `--headless --path . --import` (may segfault at exit; re-run if a texture is stale); revert the `.import` line-ending noise on existing files (`git ls-files -m | grep '\.import$'`, `git checkout --` each, quoting names with spaces); commit new `.import` files.
- Commit after each task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Pit King buries with two dice left:** he never buries the last unburied die, even in phase 2. Test in Task 3.
- **A buried die that was placed in Guard or Cleave:** it acts again next turn with the same value and slot; Cleave needs its pair. Test in Task 3.
- **Old save without the Mine fields:** loads with the Mine locked, no crash. Test in Task 4.
- **Rubble Hulk killed by Cleave alongside others:** the Rubble appears in its slot and the fight doesn't end early. Test in Task 3.
- **Thick Skin as the bonus perk when it's already equipped:** excluded from the pick, so HP is never doubled. Test in Task 4.

---

### Task 1: Floors as data

**Files:** Modify `scripts/floor.gd`, `scripts/game.gd` (`_start_run`, `_show_map`), `scripts/map_screen.gd` (title and boss label); Test `tests/test_combat.gd` (`_floors()`).

**Interfaces:**
- Produces:
  - `Floor.FLOORS := {"chapel": {"title": "The Sunken Chapel", "lair": "The Warden's Lair", "enemies": [...today's ENEMIES], "hp": [[18, 26], [18, 38], [42, 56]], "boss": ["warden"], "backdrop": "fight"}, "mine": {"title": "The Hollow Mine", "lair": "The Pit King's Throne", "enemies": ["miner", "crawler", "hulk", "canary", "shaft_foreman"], "hp": [[24, 36], [34, 50], [56, 72]], "boss": ["pit_king"], "backdrop": "mine"}}` (hp = entrance, early, late)
  - `static func deal(floor_id := "chapel") -> Array`; `static func group(hp: Array, used: Dictionary, enemies: Array = FLOORS.chapel.enemies) -> Array`
  - `game.floor_id := "chapel"`; `MapScreen.title: String`, `MapScreen.lair: String` (set by game from FLOORS)
  - Existing `ENEMIES`, `ENTRANCE_HP`, `EARLY_HP`, `LATE_HP`, `BOSS` stay as aliases of the chapel entry only if something still reads them; otherwise remove them.
- Mine enemy keys don't exist in `Combat.TYPES` until Task 2, so Task 1's mine checks run against placeholder entries you add to TYPES now as minimal `{"name", "hp", "phase1": [{"kind": "attack", "value": 4}]}` stubs — Task 2 replaces them.

- [ ] **Step 1: Test** — `_floors()` loops over both floor ids: every check it already makes, with HP windows, enemies and boss taken from `FLOORS[id]`; the mine floor's fights use only mine enemies and its last room is `enemies == ["pit_king"]`.
- [ ] **Step 2: Run — fails.** **Step 3: Implement.** **Step 4: Run both suites — pass. Commit** — "Floors as data: the Chapel and the Hollow Mine".

---

### Task 2: Mine enemies and their rules

**Files:** Modify `scripts/combat.gd`; Test `tests/test_combat.gd` (`_mine_enemies()`), `tests/test_fight_flow.gd` (play each mine enemy type).

**Interfaces:**
- Consumes: Task 1's mine keys.
- Produces: `Combat.TYPES` entries `miner`, `crawler`, `hulk`, `rubble`, `canary`, `shaft_foreman` (numbers from Global Constraints; patterns using existing intent kinds; `hulk` has `"leaves": "rubble"`; `crawler` has `"pack": 1`; `shaft_foreman` has `"rallies": 2`). Bonuses are applied in `start_turn` after intents are chosen (so the intent shows the final value). Rubble spawn happens in `resolve_player` when a `leaves` enemy hits 0 HP: replace it in place with a fresh `rubble` enemy dict whose intent is `{}`, and count the kill (track kills so `claim_fight` still counts both).
- [ ] **Step 1: Test** —
  - Miner's third intent is unblockable.
  - Two Crawlers each attack for base + 1; three for base + 2; after one dies, the others drop next turn.
  - Foreman alive: a Skeleton-like attack in the same fight is +2; with two Crawlers too, a Crawler is base + 1 + 2; a guard intent is unchanged.
  - Hulk killed: index keeps an enemy named "Rubble" with Rubble HP, `fight_won()` is false, kills counted = 1 so far; Rubble killed: fight won, kills = 2.
  - Hulk and another enemy killed in one Cleave: Rubble appears, fight not won.
  - Canary rings: another enemy's attack becomes unblockable.
- [ ] **Step 2: Run — fails. Step 3: Implement. Step 4: Run both suites (flow test plays a fight against each mine type, placeholder boxes) — pass. Commit** — "Hollow Mine enemies: miners, crawlers, hulks, canaries, the foreman".

---

### Task 3: The Pit King and buried dice

**Files:** Modify `scripts/combat.gd`, `scripts/combat_screen.gd` (buried dice can't be clicked/locked/assigned; reroll skips them; a "buried" look), `scripts/dice_tray.gd` (rubble over a buried die); Test `tests/test_combat.gd` (`_pit_king()`), `tests/test_fight_flow.gd` (play the Pit King).

**Interfaces:**
- Produces: dice dicts gain `"buried": 0` (turns left); new intent kind `"cave_in"` (phase 1) and the flag `"cave_in": true` on phase-2 attack intents; `Combat.bury_one() -> int` (index buried, -1 if none allowed); `start_turn` doesn't reroll or reset slot/lock on a die with `buried > 0` and counts its turns down; `assign`, `toggle_lock` and `reroll` leave buried dice alone; unplaced buried dice give no Grit. `TYPES.pit_king` with `"boss": true`, ~110 HP, phase 1 mixing attacks and `cave_in`, phase 2 attacks with `cave_in: true`.
- [ ] **Step 1: Test** —
  - A cave-in buries exactly one die; next turn its value and slot are unchanged, `reroll()` leaves it, `assign`/`toggle_lock` can't change it, and it's free the turn after.
  - With two dice already buried, `bury_one()` returns -1.
  - A buried die placed in Guard guards again next turn with the same value; a buried die in Cleave keeps its pair's Cleave.
  - Phase 2 (HP at half): each turn's attack intent carries `cave_in`.
- [ ] **Step 2: Run — fails. Step 3: Implement** (the tray's buried look can be the die in "locked" art with a few rubble pixels drawn over it — your call, kept pixel-crisp). **Step 4: Run both suites — pass. Commit** — "The Pit King: cave-ins bury dice".

---

### Task 4: One run across two floors

**Files:** Modify `scripts/game.gd`, `scripts/meta.gd`, `scripts/camp_screen.gd`, `scripts/combat.gd` (`add_perk`), `scripts/combat_screen.gd` (backdrop from the floor); Create `scripts/perk_pick_screen.gd` (`class_name PerkPickScreen`); Test `tests/test_combat.gd`, `tests/test_fight_flow.gd`.

**Interfaces:**
- Produces:
  - `Meta.mine_unlocked := false` (saved/loaded; old saves → false)
  - `Combat.add_perk(id: String) -> void` (adds to `perks`; Thick Skin raises `max_hp` and `player_hp` by 10 once)
  - `Combat.bonus_perk := ""`
  - `PerkPickScreen`: `var choices: Array` (3 perk ids), `signal picked(id: String)`; cards like the camp's
  - `game._on_fight_finished`: a won Warden fight on the Chapel → `meta.mine_unlocked = true`, save, PerkPickScreen (choices: 3 random from `Meta.PERKS` minus `meta.equipped`) → `add_perk` → the campfire notice → `floor_id = "mine"`, deal, `layer = 0`, keep `path`/`seen_events` per floor as needed → map. A won Pit King fight → `_end_run(true)`.
  - `game.rooms_before := 0` (rooms cleared on earlier floors this run), used by `_end_run`.
  - `Meta.embers_for(kills, rooms_cleared, boss_pct, won)` keeps its signature; its win bonus becomes 100 (update the existing `_meta()` check that expects 50).
  - Camp: when `meta.mine_unlocked`, a floor choice (two buttons or a toggle: "Sunken Chapel" / "Hollow Mine") beside Start run; `start_run` passes the floor id; `_start_run(floor := "chapel")`.
  - `CombatScreen.backdrop := "fight"` set by game from `Floor.FLOORS[floor_id].backdrop` (the "mine" backdrop arrives in Task 6; until then fall back to "fight" if `bg_mine` doesn't exist).
- [ ] **Step 1: Test** — Meta round-trip and an old save → locked; `add_perk("thick_skin")` +10/+10 once; the pick never offers an equipped perk; flow: win the Warden (set his HP to 1 and kill) → PerkPickScreen → pick → campfire notice → map titled "The Hollow Mine" with HP/Shards unchanged and the perk active; `meta.mine_unlocked` saved; Embers after a Pit King win include rooms from both floors and +100.
- [ ] **Step 2: Run — fails. Step 3: Implement. Step 4: Import, run both suites — pass. Commit** — "One run, two floors: the way down to the Hollow Mine".

---

### Task 5: Mine cast art

**Files:** Create `art/pxl/mine_cast.px.js` (still sprites), `assets/sprites/{miner,crawler,hulk,rubble,canary,shaft_foreman,pit_king}.png`, their `RIGS` entries in `tools/rig_sprites.gd`, `art/pxl/<name>.px.js` frame files, `assets/sprites/<name>_frames.png/.json`, `scenes/<name>.tscn`, `scenes/<name>_frames.tscn`; Modify `scripts/combat.gd` (`"sprite"` on each mine type).

Follow the rigging skill (`.claude/skills/rigging-pixel-sprites/SKILL.md`), with one change: the still sprite is drawn in pxl and saved straight to `assets/sprites/<name>.png` (no `make_sprites.gd` entry). Then: zoom it, write its `RIGS` entry (facing -1), `rig_sprites.gd --only=<name>`, `pxl_parts.gd <name>`, `art/pxl/<name>.px.js` calling `standard("<name>")`, build, copy frames, `frames_scene.gd <name>`, import.

- [ ] **Step 1: Test** — every mine type has a `sprite`, and `scenes/<sprite>_frames.tscn` and `assets/sprites/<sprite>.png` exist.
- [ ] **Step 2: Run — fails. Step 3: Draw and rig all seven** (look: dead miners, pale blind grubs, loose stone, a ghostly canary, an overseer with whip and ledger, a crowned mass of fused miners and ore; Pit King ≈ Warden's size). **Step 4: Render** a fight with each (non-headless scratch script outside the repo) and the pose sheets; fix cuts. **Step 5: Run both suites — pass. Commit** — "Hollow Mine cast, drawn and animated in pxl".

---

### Task 6: The Mine backdrop

**Files:** Create `art/pxl/bg_mine.px.js`, `assets/ui/bg_mine.webp` (1024x572, lossless), lantern/dust/chain life art in `assets/ui/life/`; Modify `scripts/backdrop_life.gd` (`LIFE.mine`), `scripts/combat_screen.gd` (floor ledge per backdrop: `const LEDGES := {"fight": 0.683, "mine": <measured>}`).

- [ ] **Step 1: Test** — `bg_mine` exists at 1024x572; `LIFE.mine` has lantern flames, dust fog and at least one swaying chain; `LEDGES` has both backdrops.
- [ ] **Step 2: Run — fails. Step 3: Draw** the mine (timber supports, rails, hanging lanterns, dripping water, a floor ledge) as a pxl scene at 2 image px per pxl pixel; draw hanging lantern chains as separate sway strips (in the BackdropLife chain format) instead of painting them in; flames over the lanterns; a dust band. **Step 4: Render** a mine fight; the fighters stand on the ledge. **Step 5: Run both suites — pass. Commit** — "The Hollow Mine's backdrop, alive".

---

### Task 7: Whole check

- [ ] Run both suites; render the camp floor choice, the perk pick, the Mine map and a Pit King fight; hand the game to the owner for a full two-floor run (tuning is follow-up).
