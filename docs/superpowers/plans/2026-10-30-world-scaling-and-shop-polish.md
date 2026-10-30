# World Scaling and Shop Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enemy HP follows a fixed per-world factor (the Mine at ×1.8 now), a balance bot checks it, and the Spoils shop gets a reroll, a "Your belt" heading, even belt spacing and 32×32 relic art on its cards.

**Architecture:** The world factor is a table in `Floor` read by `game.gd` when it starts a room's fight or an ambush; the run's world number comes from `rooms_before`, which the run save already keeps. The shop changes stay inside `RelicPickScreen` and `BeltRow`; the large art is a new pxl file whose PNGs `RelicIcon` shows when asked for the big version.

**Tech Stack:** Godot 4.7.2, GDScript, headless test scripts, pxl (`.claude/skills/pxl-pixel-art`) for art.

**Spec:** `docs/superpowers/specs/2026-10-30-world-scaling-and-shop-polish-design.md`

## Global Constraints

- Godot: `"C:/Users/ricon/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`; the sandbox blocks it, so run it with the sandbox disabled.
- Tests: `<godot> --headless --path . -s tests/test_combat.gd` and `<godot> --headless --path . -s tests/test_fight_flow.gd`. Pass = exit 0 and no `FAIL`, `SCRIPT ERROR` or `Parse Error` lines (a parse error can still print "passed"). Run `<godot> --headless --path . --import` after adding images.
- World factors, verbatim: world 1 ×1.0, world 2 ×1.8, world 3 ×2.9, world 4 ×4.6, world 5 ×7.4. Ambushes take the factor. The factor follows the world's place in the run: a Mine start plays the Mine at ×1.0.
- Reroll cost: 2 Shards, then +1 per further reroll in the same visit; back to 2 at the next shop. Not saved.
- Combat rules stay in `scripts/combat.gd` / `scripts/floor.gd` with no UI.
- Art in pxl only. Large relics are 32×32, same palette (`pal` in `art/pxl/relics.px.js`) and glyph style, readable without colour; rares keep a gold rim. Exported at 2× nearest-neighbour into `assets/ui/cut/`, like the small ones.
- Small icons stay on the fight belt, the shop's "Your belt" row, tooltips and end-of-run screens. Large icons bob like the belt; no frame loop.
- Old run saves keep loading (no `RunSave.VERSION` bump).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A run saved at the campfire after the Warden and continued plays the Mine as world 2 (×1.8), not world 1. Test in Task 1.
2. Reroll can never take Shards below 0, and is disabled when the shop's pool has no relic left to deal. Test in Task 3.
3. A reroll in the Warden's hoard deals rares only, and in the first Spoils commons only. Test in Task 3.
4. The shop's belt is evenly spaced even when it is empty (no Destroy button exists to measure). Test in Task 4.
5. A large-icon card still has the relic's tooltip. Test in Task 6.

---

### Task 1: World factor on fights and ambushes

**Files:**
- Modify: `scripts/floor.gd` (constants block near `LATE_SCALE`)
- Modify: `scripts/game.gd` (`_on_room_picked`, `_start_ambush`)
- Test: `tests/test_combat.gd` (`_hp_scaling`), `tests/test_fight_flow.gd` (`_two_floors`, `_mine_start`)

**Interfaces:**
- Produces: `Floor.WORLD_FACTORS := [1.0, 1.8, 2.9, 4.6, 7.4]`; `static func Floor.world_factor(world: int) -> float` (world is 1-based; beyond 5 returns the last factor, for endless later). `func game.world() -> int` = `1 + rooms_before / Floor.COLUMNS`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_combat.gd` `_hp_scaling()`:
```gdscript
check(Floor.world_factor(1) == 1.0 and Floor.world_factor(2) == 1.8 and Floor.world_factor(5) == 7.4, "world factors 1.0, 1.8 ... 7.4")
check(Floor.world_factor(6) == 7.4, "past world 5 the last factor holds")
```
In `tests/test_fight_flow.gd` `_two_floors()`, after the Mine's map shows: replace the direct `start_group(["pit_king"])` + `_show_fight` with `game.layer = game.map.size() - 1` then `game._on_room_picked(0)`, and add:
```gdscript
check(game.world() == 2, "the Mine after the Chapel is world 2")
check(game.combat.enemies[0].max == ceili(220 * 1.8), "the Pit King in world 2 has %d HP (got %d)" % [ceili(220 * 1.8), game.combat.enemies[0].max])
```
Before that fight, also start an ambush and check its scale:
```gdscript
game._start_ambush()
check(game.combat.enemies.all(func(e): return e.max == ceili(e.type.hp * 1.8)), "a world-2 ambush takes the factor")
```
Still in `_two_floors`, before walking into the Mine: save at the post-Warden campfire with `game._save_and_quit("mine")`, then `game._continue_run()` and check `game.world() == 2` (the continued run keeps its world).
In `_mine_start()`, after the Mine-start map shows: `check(game.world() == 1, "a Mine start is world 1")`, then `game.layer = game.map.size() - 1; game._on_room_picked(0)` and `check(game.combat.enemies[0].max == 220, "a Mine-start Pit King keeps 220 HP")`.

- [ ] **Step 2: Run both suites; expect the new checks to FAIL** (`world_factor`/`world` not found as parse errors count as failing).

- [ ] **Step 3: Implement** `WORLD_FACTORS`, `world_factor(world: int) -> float` in `scripts/floor.gd`; `world() -> int` in `scripts/game.gd`; multiply `room.get("scale", 1.0)` by `Floor.world_factor(world())` in `_on_room_picked`, and pass `Floor.world_factor(world())` as `start_group`'s scale in `_start_ambush`.

- [ ] **Step 4: Run both suites; expect PASS.** Fix any older check that assumed unscaled Mine HP when reached through `_on_room_picked`.

- [ ] **Step 5: Commit** `scripts/floor.gd scripts/game.gd tests/` — "Enemy HP follows a fixed per-world factor".

### Task 2: Balance simulation tool

**Files:**
- Create: `tools/balance_sim.gd`

**Interfaces:**
- Consumes: `Floor.world_factor(world)`, `Floor.deal`, `Combat` (`start_group`, `start_turn`, `reroll`, `assign`, `preview_damage`, `resolve_player`, `resolve_enemy`, `end_enemy_phase`, `claim_fight`, `buy_relic`, `destroy_relic`, `move_relic`, `forge`, `pay_forge`), `RelicPickScreen.offer`, `Events.AMBUSH_CHANCE`, `Events.AMBUSH_SHARDS`.
- Produces: `godot --headless --path . -s tools/balance_sim.gd [-- --runs=N]` printing, per profile ("new": Cleave only; "veteran": every skill) and stage (`wN 0`, `wN 1-4`, `wN 5-8`, `wN boss`): fights, median enemy HP, damage per turn (median, p75, p90, p99, max), Mult (median, p90, max), turns to kill (median, p25, min), and for bosses a kill-turn histogram 1..8+.

The bot is fixed by the spec's "What the simulation found" section. Port it from the session's throwaway (`sim5.gd`) with these rules:
- Worlds: `["chapel", "mine", "mine", "mine", "mine"]` (worlds 3–5 stand in with the Mine until they exist), each `Floor.deal`'d; one random room per column; every fight's scale is `room.scale × Floor.world_factor(w)`; ambush (`Events.AMBUSH_CHANCE`) at `Floor.world_factor(w)`, pays `AMBUSH_SHARDS`; a non-ambush "?" is a free forge half the time; forge rooms spend all Shards on throws; campfires are a free forge half the time; player HP is restored after each fight and each enemy phase.
- Shops: first Spoils commons, later "any", after each boss but the last a "rare" shop and a free forge. Buy by this ranking, best last: `tithe_box, ward_icon, miners_ledger, rosary, clenched_jaw, rusted_censer, spare_fuse, whetstone, cursed_crown, gravedigger, twin_saints, gilded_pip, hungry_bell, pit_lantern, mirror_shard, black_candle`; on a full belt destroy the lowest-ranked if the offer outranks it and it pays for it; then order adds first, then `mirror_shard, black_candle, pit_lantern`.
- Turns: reroll while rerolls remain unless Sunder, Flurry or Oath fires, locking a pair if any, else the highest die; then place the dice by trying all 27 NONE/ATTACK/SKILL assignments for the highest `preview_damage()`. Enemy turns resolve at `Grade.MISS`. Cap 60 turns a fight.
- Forge throw: a random `FORGE_ROLL`; a step goes on the lowest face of the die with the lowest face total; a mark on a random face.
- Default 500 runs per profile.

- [ ] **Step 1: Write `tools/balance_sim.gd`** (extends `SceneTree`, a header comment with the command and what it ignores: player HP, perks, event details, map links).

- [ ] **Step 2: Run it** with `--runs=500`. Expected: the `veteran|w2 boss` line shows median enemy HP 396, a kill-turn histogram with 1 turn at about 2% and p25 kill turns about 3; `veteran|w1 boss` p25 about 2. Paste the two boss lines into the commit message.

- [ ] **Step 3: Commit** `tools/balance_sim.gd` — "Balance bot: simulates whole runs against the world curve".

### Task 3: Shop reroll

**Files:**
- Modify: `scripts/relic_pick_screen.gd`
- Test: `tests/test_fight_flow.gd` (`_relic_picks`)

**Interfaces:**
- Produces: `const REROLL_COST := 2`; `static func reroll_cost(n: int) -> int` (= `REROLL_COST + n`); `var rerolls := 0` (this visit); `var reroll_button: Button`; `func _reroll() -> void`. The three cards are built by a function that can clear and rebuild them in place (`var cards: HBoxContainer`), so `buys` is refilled on each deal.

- [ ] **Step 1: Write the failing tests** in `_relic_picks()`, on the first Spoils (commons) before buying:
```gdscript
check(pick.reroll_button.text == "Reroll offer  2" and pick.reroll_button.disabled, "Reroll offer costs 2, disabled at 0 Shards")
game.combat.shards = 5
pick._refresh()
var before: Array = pick.choices.duplicate()
pick.reroll_button.pressed.emit()
check(game.combat.shards == 3 and pick.rerolls == 1 and pick.reroll_button.text == "Reroll offer  3", "a reroll pays 2 and the next costs 3")
check(pick.choices.size() == 3 and pick.choices.all(func(id): return not Combat.RELICS[id].rare), "the first Spoils rerolls into commons")
check(pick.buys.size() == 3 and pick.buys.all(func(b): return b.is_inside_tree()), "the cards are rebuilt with their Buy buttons")
pick.reroll_button.pressed.emit()
check(game.combat.shards == 0, "the second costs 3")
check(pick.reroll_button.disabled and game.combat.shards >= 0, "can't afford the third; Shards never go below 0")
```
After a relic is bought and the shop is rerolled: the bought relic is still on the belt and not among `pick.choices`. In the Warden's hoard part: give 20 Shards, reroll, `check(game.screen.choices.all(func(id): return Combat.RELICS[id].rare), "the hoard rerolls into rares")`. Pool exhausted, in the hoard: append every rare straight onto `game.combat.relics` (`{"id": id, "n": 0.0, "f": 0.0}`; the test may exceed `BELT_SIZE` here), give 20 Shards, `_refresh()`, and `check(game.screen.reroll_button.disabled, "no rare left to deal: Reroll is disabled")`. A later shop's first reroll costs 2 again: `check(next_pick.reroll_button.text == "Reroll offer  2", ...)` on the "any" Spoils already reached at the end of the first part.

- [ ] **Step 2: Run `test_fight_flow`; expect FAIL** (no `reroll_button`).

- [ ] **Step 3: Implement.** The button sits centred between the cards and the belt heading, `custom_minimum_size = Vector2(240, 44)`, text `"Reroll offer  %d" % reroll_cost(rerolls)`. `_reroll()` pays `reroll_cost(rerolls)` from `combat.shards`, increments `rerolls`, re-deals `choices = offer(combat.relics, rarity, combat.rng)`, clears `bought`, rebuilds the cards, `_refresh()`. No confirm panel (cheap and frequent; the spec's confirm rule covers buy, destroy and leave). Disabled when `combat.shards < reroll_cost(rerolls)` or no relic of the shop's rarity is off the belt.

- [ ] **Step 4: Run both suites; expect PASS.**

- [ ] **Step 5: Commit** — "Spoils shop: Reroll offer, 2 Shards and 1 more each time".

### Task 4: "Your belt" heading and even belt spacing

**Files:**
- Modify: `scripts/relic_pick_screen.gd` (the "Your belt" label), `scripts/belt_row.gd` (`rebuild`)
- Test: `tests/test_fight_flow.gd` (`_relic_picks`)

**Interfaces:**
- Consumes: Task 3's layout (heading goes right under the reroll button).

- [ ] **Step 1: Write the failing tests**:
```gdscript
var heading: Array = pick.find_children("*", "Label", true, false).filter(func(l): return l.text == "Your belt")
check(heading.size() == 1 and heading[0].get_theme_font("font") == UI.HEADING_FONT and heading[0].get_theme_font_size("font_size") == 32, "Your belt is a 32 px heading")
var widths: Array = range(Combat.BELT_SIZE).map(func(k): return pick.belt_row.get_child(k).size.x)
check(widths.all(func(w): return is_equal_approx(w, widths[0])), "every belt slot is as wide as the others: %s" % [widths])
```
Run the width check twice: with an empty belt on the first Spoils (await a frame for layout), and with two relics bought.

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Implement.** `UI.heading(root, 32, "Your belt")` centred. In `BeltRow.rebuild()`, when `show_destroy`, an empty slot also gets a "Destroy" button that holds the width but can't be seen or used: `modulate.a = 0`, `disabled = true`, `mouse_filter = MOUSE_FILTER_IGNORE`. The fight belt (`show_destroy == false`) is unchanged.

- [ ] **Step 4: Run both suites; expect PASS** (the existing "a Destroy button under every belt relic" check counts only enabled ones; adjust its filter to `not b.disabled`).

- [ ] **Step 5: Commit** — "Shop: Your belt heading, evenly spaced slots".

### Task 5: Draw the 32×32 relics in pxl

**Files:**
- Create: `art/pxl/relics_big.px.js`
- Create: `assets/ui/cut/relic_<id>_big.png` for all 16 ids in `Combat.RELICS`
- Test: `tests/test_combat.gd` (`_relic_icons`)

**Interfaces:**
- Produces: `res://assets/ui/cut/relic_<id>_big.png`, 64×64 (32×32 at 2×).

Use the pxl-pixel-art skill. Same palette block as `relics.px.js` (copy its `pal`), each relic the same object as its small icon with more detail: commons on a 32×32 canvas under the dark rim, rares with the gold second rim. Header comment with the build command (`node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/relics_big.px.js`, then copy `out/sprites/relic_*_big.png` into `assets/ui/cut/` at 2× nearest-neighbour) and a `sheet("relics_big_sheet", ...)` preview of all 16.

- [ ] **Step 1: Write the failing test** in `_relic_icons()`:
```gdscript
for id in Combat.RELICS:
	var big := "res://assets/ui/cut/relic_%s_big.png" % id
	check(ResourceLoader.exists(big) and load(big).get_size() == Vector2(64, 64), "relic %s has its 64x64 large art" % id)
```
- [ ] **Step 2: Run `test_combat`; expect FAIL.**
- [ ] **Step 3: Draw all 16, build, export at 2×, `--import`.** Show the owner `relics_big_sheet.png` next to `relics_sheet.png` before moving on.
- [ ] **Step 4: Run `test_combat`; expect PASS.**
- [ ] **Step 5: Commit** `art/pxl/relics_big.px.js assets/ui/cut/relic_*_big.png*` — "Large 32x32 relic art".

### Task 6: Large art on the shop's cards

**Files:**
- Modify: `scripts/relic_icon.gd` (`of`, `_build`, `_process`), `scripts/relic_pick_screen.gd` (card head)
- Test: `tests/test_fight_flow.gd` (`_relic_picks`, `_belt_row`)

**Interfaces:**
- Consumes: Task 5's PNGs.
- Produces: `static func RelicIcon.of(id: String, big := false) -> RelicIcon`; a big icon shows `relic_<id>_big` as a still (no strip, no frame stepping) with the same bob, and `custom_minimum_size` 64×64.

- [ ] **Step 1: Write the failing tests**:
```gdscript
var icons: Array = pick.cards.find_children("*", "RelicIcon", true, false)
check(icons.size() == 3 and icons.all(func(i): return i.custom_minimum_size == Vector2(64, 64)), "the cards show the large art")
check(icons.all(func(i): return i.tooltip_text.begins_with(Combat.RELICS[i.relic].name)), "a large icon keeps its tooltip")
check(pick.belt_row.find_children("*", "RelicIcon", true, false).all(func(i): return i.custom_minimum_size == Vector2(32, 32)), "the shop's belt keeps the small icons")
```
In `_belt_row` (the fight belt) assert its icons are 32×32 too.

- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement** `big` in `RelicIcon` and use `RelicIcon.of(id, true)` on the shop cards; the card head stays a row (art, then name), name vertically centred on the art.
- [ ] **Step 4: Run both suites; expect PASS.** Screenshot the shop (a windowed run saving `root.get_texture().get_image()`) and show the owner.
- [ ] **Step 5: Commit** — "Shop cards show the large relic art".
