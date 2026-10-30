# Spoils Shop and Belt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Spoils into a priced shop, make Mult build left to right along a draggable belt that sits on the dice tray, count each End turn step by step, and give every relic idle motion and its own animation loop.

**Architecture:** Rules live in `Combat` (Mult order, prices, buy/destroy, a list of count steps the screen plays back). Two new shared Controls, `RelicIcon` (one animated relic) and `BeltRow` (the draggable belt), are used by both the shop and the fight screen. Art is extended in pxl.

**Tech Stack:** Godot 4.7 GDScript; headless tests in `tests/`; pxl for art (`.claude/skills/pxl-pixel-art`).

**Spec:** `docs/superpowers/specs/2026-10-30-spoils-shop-and-belt-design.md`

**Running tests** (Godot is not on PATH; the sandbox blocks launching it, so run unsandboxed or in a terminal tab):

```bash
"C:/Users/ricon/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_combat.gd
"C:/Users/ricon/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_fight_flow.gd
```

Pass = exit code 0 and no `FAIL:` lines. Both suites must pass at the end of every task.

## Global Constraints

- Prices: common 4 Shards, rare 8. Destroy pays half: 2 / 4. `BREAK_SHARDS` and `SKIP_SHARDS` are removed.
- Leave pays nothing. No free relic picks anywhere; the Mine start has no pick.
- The first Spoils of a run offers commons only; whether it has happened is saved with the run.
- Mult starts at 1 and each belt slot, left to right, adds its add then multiplies by its multiplier.
- Mult is shown with up to two decimals, trailing zeros dropped: `1.95`, `2.5`, `2`.
- Damage shown before End turn equals the count's final number equals what `resolve_player()` deals.
- Every buy, destroy and leave asks through `ConfirmPanel.ask`.
- Belt: 5 slots (`Combat.BELT_SIZE`), empty ones drawn dashed; hidden in the tutorial.
- Relic loops: 4 frames, ~6 fps, a horizontal strip `assets/ui/cut/relic_<id>_anim.png` beside the still `relic_<id>.png`, which stays.
- Comment style: the code's own — `##` doc line per function, sparse `#` for the why.

## Review Focus

1. **Shards exactly at the price** — buying with `shards == price` must work and leave 0. (Task 2 test.)
2. **Destroying the relic a Mirror Shard copies, or the Mirror itself** — Mirror counters reset as `_reset_changed_mirrors` does today; belt indices after the removed slot shift down. (Task 2 test.)
3. **Count with no Attack dice, or Attack on a dead/guarded target** — the count's Hit must still end on the sum of `hits_to`; a Guard bigger than the dice gives a Guard step that brings the Attack part to 0, not below. (Task 3 test.)
4. **Skip press during the count** — Space / Enter / click jumps to the end and is consumed; it must not trigger a block, a reroll or a second End turn. (Task 7 test.)
5. **Dragging while dice roll, a throw waits, the menu is open, or the enemy acts** — drop does nothing. (Task 7 test.)

---

### Task 1: Mult builds left to right

**Files:**
- Modify: `scripts/combat.gd:704-711` (`mult()`), `scripts/combat.gd:44-45` (the RELICS comment)
- Test: `tests/test_combat.gd` (`_mult`)

**Interfaces:**
- Produces: `Combat.mult() -> float` — unchanged signature, new order.

- [ ] **Step 1: Write the failing test** — add to `_mult()`:

```gdscript
	c = fresh()
	c.take_relic("twin_saints")
	c.take_relic("black_candle")
	place(c, 0, 3, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	check(is_equal_approx(c.mult(), 3.0), "+1 then x1.5: (1 + 1) x 1.5 = 3")
	c.move_relic(1, 0)
	check(is_equal_approx(c.mult(), 2.5), "x1.5 then +1: 1 x 1.5 + 1 = 2.5")
```

- [ ] **Step 2: Run `test_combat.gd`** — expect `FAIL: x1.5 then +1` (today both give 3).
- [ ] **Step 3: Rewrite `mult()`** as a left-to-right fold: `m = (m + _relic_add(k)) * _relic_times(relic_id(k))`. Update its `##` line and the RELICS comment ("Mult is 1 plus the adds, then times the multipliers") to say left to right.
- [ ] **Step 4: Run both suites** — expect pass (existing Mult tests use adds only, or one multiplier, so they hold).
- [ ] **Step 5: Commit** `scripts/combat.gd tests/test_combat.gd` — "Mult builds left to right along the belt".

---

### Task 2: Prices, buy, destroy, first-Spoils commons

**Files:**
- Modify: `scripts/combat.gd` (`RELICS` block constants, `take_relic`, `SAVED_LATER`, `valid_dict`, `from_dict`), `scripts/relic_pick_screen.gd` (`offer` only)
- Test: `tests/test_combat.gd` (`_relic_belt`, `_relic_save`, `_relic_offer`)

**Interfaces:**
- Produces:
  - `const Combat.COMMON_PRICE := 4`, `const Combat.RARE_PRICE := 8`
  - `static func Combat.price(id: String) -> int`
  - `static func Combat.sell_value(id: String) -> int` — `price(id) / 2`
  - `func Combat.buy_relic(id: String) -> bool` — refuses if owned, belt full, or `shards < price(id)`; else appends and pays.
  - `func Combat.destroy_relic(k: int) -> void` — removes slot k, pays `sell_value`, resets changed Mirrors.
  - `func Combat.take_relic(id: String) -> bool` — the free add, kept for tests and setup; the `replace` parameter is removed.
  - `var Combat.shopped := false` — in `SAVED_LATER`, true once the run's first Spoils has shown.
  - `static func RelicPickScreen.offer(belt: Array, rarity: String, rng: RandomNumberGenerator) -> Array` — `rarity` is `"any"`, `"common"` or `"rare"`.

- [ ] **Step 1: Write the failing tests.** In `_relic_belt`, replace the `take_relic("rosary", 2)` / `BREAK_SHARDS` checks with:

```gdscript
	c = fresh()
	c.shards = 4
	check(c.buy_relic("whetstone") and c.shards == 0, "a common costs exactly 4")
	check(not c.buy_relic("twin_saints"), "no Shards, no buy")
	c.shards = 7
	check(not c.buy_relic("black_candle") and c.shards == 7, "a rare costs 8")
	c.shards = 100
	for id in ["twin_saints", "gravedigger", "tithe_box", "rosary"]:
		c.buy_relic(id)
	check(not c.buy_relic("spare_fuse") and c.shards == 100 - 4 * 3 - 8, "a full belt refuses a buy")
	c.destroy_relic(4)  # Rosary, a rare
	check(c.relics.size() == 4 and c.shards == 100 - 4 * 3 - 8 + 4, "destroying a rare pays 4")
	c.destroy_relic(1)  # Twin Saints, a common
	check(c.shards == 100 - 4 * 3 - 8 + 4 + 2 and c.relic_id(1) == "gravedigger", "a common pays 2, and the belt closes the gap")
```

In the Mirror section replace `c.take_relic("rosary", 1)` with `c.destroy_relic(1)` and keep the "resets the Mirror" check. In `_relic_save`, set `c.shopped = true` before saving and check `back.shopped`; check a save without `"shopped"` loads with `false`. In `_relic_offer`, change calls to `offer(belt, "rare", rng)` / `offer(belt, "any", rng)` and add: 200 calls of `offer([], "common", rng)` never contain a rare.

- [ ] **Step 2: Run `test_combat.gd`** — expect parse errors / FAILs on the missing functions.
- [ ] **Step 3: Implement** the Interfaces block in `combat.gd`; delete `BREAK_SHARDS`; `destroy_relic` uses `_acting_ids()` + `_reset_changed_mirrors()` like `take_relic`. `valid_dict` accepts `shopped` missing or `bool`; `from_dict` reads `bool(d.get("shopped", false))`. `offer`: `"common"` uses only commons, `"rare"` only rares, `"any"` keeps today's `RARE_CHANCE` with fallback.
- [ ] **Step 4: Run both suites.** `test_fight_flow.gd` will fail where it calls `offer(…, bool, …)` or `BREAK_SHARDS` through the old screen — that is fixed in Task 6; until then, make `relic_pick_screen.gd` and `game.gd` compile by passing `"rare" if rares else "any"` and replacing the break path with `destroy_relic(k)` then `take_relic(id)`. Expect `test_combat.gd` to pass; `test_fight_flow.gd` may fail only on the `BREAK_SHARDS`/`SKIP_SHARDS` checks Task 6 rewrites.
- [ ] **Step 5: Commit** — "Relic prices, buy and destroy; first Spoils offers commons".

---

### Task 3: Count steps

**Files:**
- Modify: `scripts/combat.gd` (new function next to `hits_to`)
- Test: `tests/test_combat.gd` (new `_count_steps`, called from `_init`)

**Interfaces:**
- Produces: `func Combat.count_steps() -> Array[Dictionary]` — the End turn count, in order. Each step:
  `{"kind": String, "die": int, "slot": int, "amount": float, "hit": int, "mult": float}`
  - `kind`: `"die"` (an Attack die's face; `die` = dice index), `"relic_die"` (Whetstone/Crown adding to that die; `slot` = belt index), `"guard"` (Bone Wall + enemy Guard, `amount` negative), `"flat"` (Ledger / Ward Icon; `slot`), `"skill"` (one fired skill's hits summed over enemies; `die` = -1, `slot` = -1), `"mult"` (one belt slot changing Mult; `slot`).
  - `hit` and `mult`: the running totals after this step. Unused indices are -1.
  - The last step's `hit` == `range(enemies.size())` sum of `_sum(hits_to(i))`; last `mult` == `mult()`. No steps at all when `preview_damage() == 0`.

- [ ] **Step 1: Write the failing test** `_count_steps()`:

```gdscript
	var c := fresh()
	c.enemies[0].intent = {"kind": "guard", "value": 4}
	c.take_relic("whetstone")
	c.take_relic("twin_saints")
	c.take_relic("black_candle")
	place(c, 0, 5, CombatScript.Slot.ATTACK)
	place(c, 1, 2, CombatScript.Slot.ATTACK)
	var s := c.count_steps()
	check(s.map(func(x): return x.kind) == ["die", "relic_die", "die", "guard", "mult"], "dice, Whetstone on the 5, Guard, then Candle (got %s)" % [s.map(func(x): return x.kind)])
	check(s[3].amount == -4 and s[3].hit == 6, "Guard 4 takes 10 down to 6")
	check(s[-1].slot == 2 and is_equal_approx(s[-1].mult, 1.5), "Twin Saints doesn't fire, Candle does")
	check(c.preview_damage() == 9, "6 x 1.5 = 9")
	c.enemies[0].intent = {"kind": "guard", "value": 20}
	s = c.count_steps()
	check(s.is_empty() or s.filter(func(x): return x.kind == "guard")[0].hit == 0, "Guard above the dice stops at 0")
	c = fresh()
	check(c.count_steps().is_empty(), "no damage, no count")
```

Add one Cleave case on `_rats()` checking the final `hit` equals the sum of `hits_to` over the three rats and the final step's `mult` equals `mult()`.

- [ ] **Step 2: Run `test_combat.gd`** — FAIL, missing function.
- [ ] **Step 3: Implement `count_steps()`** following `hits_to` for the target (same Crown/Whetstone/Bone Wall/Guard/Sharp order; the guard step's amount is whatever reconciles the dice sum to the clamped Attack hit), then `_skill_hit(id, i)` summed over enemies per `fired()` id, then one `"mult"` step per slot where `_relic_add(k) != 0` or `_relic_times(relic_id(k)) != 1`, folding exactly as `mult()` does.
- [ ] **Step 4: Run both suites** — pass.
- [ ] **Step 5: Commit** — "Count steps: the End turn breakdown, in order".

---

### Task 4: Relic animation strips

**Files:**
- Modify: `art/pxl/relics.px.js`
- Create: `assets/ui/cut/relic_<id>_anim.png` × 16
- Test: `tests/test_combat.gd` (`_relic_icons`)

**Interfaces:**
- Produces: `assets/ui/cut/relic_<id>_anim.png` — 4 frames side by side, each the same size as `relic_<id>.png` (32×32 at 2x), frame 0 identical to the still.

- [ ] **Step 1: Write the failing test** — in `_relic_icons`, per id: the anim file exists, its width is 4 × the still's width and its height equals the still's.
- [ ] **Step 2: Run `test_combat.gd`** — FAIL.
- [ ] **Step 3: Draw the loops** with the `pxl-pixel-art` skill (invoke it; use `anim(...)` with `frame()` patches over the still's grid). One small motion per relic in the spec's spirit: lantern flame flicker, candle drip, bell swing, censer smoke, whetstone sparks, crown glint, etc. Keep the silhouette still enough to read at rest. Build, then copy `out/sprites/relic_<id>_anim.png` into `assets/ui/cut/` at 2x nearest-neighbour as the file header says for the stills. Check `out/_preview/` by eye.
- [ ] **Step 4: Run both suites** — pass.
- [ ] **Step 5: Commit** the `.px.js`, the 16 PNGs and their `.import` files — "Relic animation loops".

---

### Task 5: RelicIcon and BeltRow

**Files:**
- Create: `scripts/relic_icon.gd`, `scripts/belt_row.gd`
- Modify: `scripts/relic_pick_screen.gd` (`belt_icon` delegates to `RelicIcon`)
- Test: `tests/test_fight_flow.gd` (new `_belt_row`, called from `_init`)

**Interfaces:**
- Consumes: Task 4 strips; `Combat.move_relic`, `Combat.relic_id`.
- Produces:
  - `class_name RelicIcon extends Control` — `static func make(combat: Combat, k: int) -> RelicIcon`; plays its strip at 6 fps; idle bob a couple of pixels with a per-slot phase offset (`k * 0.7` rad); tooltip as `belt_icon` gives today; `func fire() -> void` (bounce up and a quick shake, ~0.25 s); `var value_label: Label` (gold, outlined, bottom-right, as `combat_screen.gd:567-575` styles it).
  - `class_name BeltRow extends HBoxContainer` — `var combat: Combat`; `var can_drag := func() -> bool: return true`; `var show_destroy := false`; `signal moved` (after a drop reordered the belt); `signal destroy_pressed(k: int)`; `func rebuild() -> void` (BELT_SIZE slots: a `RelicIcon` per relic, then dashed empty slots); `func icon(k: int) -> RelicIcon`.
  - Dragging uses Control drag-and-drop (`_get_drag_data` on the icon returning `{"belt_k": k}` with a lifted, tilted preview; `_can_drop_data`/`_drop_data` on the row computing the target index from the drop x). A drop calls `combat.move_relic(from, to)`, `rebuild()`, emits `moved`. Nothing is draggable when `can_drag.call()` is false.

- [ ] **Step 1: Write the failing test** `_belt_row()`: build a `BeltRow` with 3 relics, `rebuild()`; check 5 children with 3 `RelicIcon`; call `row._drop_data(<x of slot 2>, {"belt_k": 0})` and check the first relic is now at index 2 and `moved` fired; set `can_drag = func(): return false` and check `icon(0)._get_drag_data(Vector2.ZERO) == null`; with `show_destroy = true` check 3 "Destroy" buttons and that pressing the second emits `destroy_pressed(1)`.
- [ ] **Step 2: Run `test_fight_flow.gd`** — FAIL.
- [ ] **Step 3: Implement** both classes; make `RelicPickScreen.belt_icon` return `RelicIcon.make(...)` so callers keep working.
- [ ] **Step 4: Run both suites** — pass.
- [ ] **Step 5: Commit** — "RelicIcon and a draggable BeltRow".

---

### Task 6: The Spoils shop and the run flow

**Files:**
- Modify: `scripts/relic_pick_screen.gd` (becomes the shop; keep the class name so `game.gd` and tests change least), `scripts/game.gd:135-146, 250-296`
- Test: `tests/test_fight_flow.gd` (`_relic_picks`, `_mine_start`)

**Interfaces:**
- Consumes: Task 2 (`price`, `sell_value`, `buy_relic`, `destroy_relic`, `shopped`, `offer(…, rarity, …)`), Task 5 (`BeltRow` with `show_destroy = true`).
- Produces: `RelicPickScreen` with `var rarity: String`, buttons labelled `"Buy  <n>"` (one per card), `"Destroy"` (one per belt relic), `"Leave"`; `signal done` on Leave only. Copy, exactly:
  - Subtitle: `"Shards %d. Buy what you can afford and fit on the belt."`
  - Buy confirm: title `"Buy %s?"`, body `"%d Shards. For this run only."`, yes `"Buy it"`.
  - Destroy confirm: title `"Destroy %s?"`, body `"+%d Shards. It's gone for the rest of the run."`, yes `"Destroy it"`.
  - Leave confirm: title `"Leave the shop?"`, body `"Nothing is paid for leaving."`, yes `"Leave"`.

- [ ] **Step 1: Rewrite the tests.** `_relic_picks`: a won fight shows a `RelicPickScreen` titled "Spoils" with 3 commons (first Spoils); give 20 Shards, buy two cards → both on the belt, Shards 12, screen still the shop and the bought cards' Buy buttons disabled; a Buy you can't afford is disabled; fill the belt → every Buy disabled; Destroy + agree → belt 4, Shards up by `sell_value`; Leave + agree → map, Shards unchanged by leaving; a second won fight offers `rarity == "any"`. No `"<"` buttons anywhere. Keep the Pit King check. `_mine_start`: picking The Hollow Mine goes straight to the `MapScreen`, belt empty. Add a Warden's hoard check: `_on_warden_beaten()` shows the shop with `rarity == "rare"` and Leave goes to the perk pick.
- [ ] **Step 2: Run `test_fight_flow.gd`** — FAIL.
- [ ] **Step 3: Implement.** Shop layout keeps today's cards (icon now a `RelicIcon`), each with its price and Rare/Common line; Buy disabled when `shards < price`, belt full or already bought; the belt is a `BeltRow` with `show_destroy`; the heading line shows current Shards and refreshes after each buy/destroy. `game.gd`: Mine start calls `_enter_floor("mine")`; Spoils passes `"any" if combat.shopped else "common"` then sets `combat.shopped = true`; hoard passes `"rare"`. Delete `SKIP_SHARDS`, `_move_left`, `breaking`.
- [ ] **Step 4: Run both suites** — pass.
- [ ] **Step 5: Commit** — "Spoils is a shop; no free picks".

---

### Task 7: Fight screen — belt on the tray, the count, the fade

**Files:**
- Modify: `scripts/combat_screen.gd` (`_build` 557-604, `_build_dice`, `_refresh` 392-400, `_on_end_turn` 238-269, the enemy loop 278-292, `_unhandled_input`, `_flash`), `scripts/dice_tray.gd` (`_fit`)
- Test: `tests/test_fight_flow.gd` (`_fight_belt`)

**Interfaces:**
- Consumes: Task 3 `count_steps()`, Task 5 `BeltRow` / `RelicIcon.fire()`.
- Produces:
  - `CombatScreen.belt: BeltRow` (replaces the `VBoxContainer`; `belt_values` goes, values live on `belt.icon(k).value_label`).
  - `CombatScreen.counting: bool`, `func _play_count(steps: Array[Dictionary]) -> void` (awaitable), `func _skip_count() -> void`.
  - `static func CombatScreen.mult_text(m: float) -> String` — `1.95 → "1.95"`, `2.5 → "2.5"`, `2.0 → "2"`.
  - `DiceTray.top_inset: float` — screen pixels the top wall sits below the felt's top edge.

- [ ] **Step 1: Rewrite `_fight_belt` tests:** the belt is a `BeltRow` inside `dice_box`, right of the Skills button, with 5 slots; `dice_tray.top_inset > 0`; the summary reads `"Hit %d × Mult %s = %d"` with `mult_text` (Black Candle, Attack 9 → `"Hit 9 × Mult 1.5 = 13"`); `mult_text` cases above; in the tutorial the belt is hidden. Count: `_on_end_turn()` sets `counting`, the summary passes through a `"= ?"` state, and the turn's damage equals the preview captured before End turn; a Space key event during the count ends it at once (`counting` false next frame), is marked handled, and the reroll count is unchanged. Drag lock: while `busy`, `belt.can_drag.call()` is false; also while the menu is open. Fade: during the enemy's timing bar `belt.modulate.a < 0.5`, back to 1 after. Keep the 5-relics-at-a-time no-errors loop.
- [ ] **Step 2: Run `test_fight_flow.gd`** — FAIL.
- [ ] **Step 3: Implement.**
  - Remove the belt column from `bottom_row`; add a `BeltRow` as a child of `dice_box` at `(skill_button right + 16, 8)`, `can_drag = func(): return not busy and not paused and not counting`, hidden when `combat.is_tutorial()`. Set `tray.top_inset` to the belt's height + 8.
  - `DiceTray._fit`: move the top wall (index 2) and the dice clamp down by `top_inset / UNIT`.
  - `_refresh`: summary uses Hit (sum of `hits_to`) × `mult_text(mult())` = `preview_damage()`, then Guard and Grit as now; drop the `(×…)` form.
  - `_on_end_turn`: after `busy = true`, `await _play_count(combat.count_steps())` before `resolve_player()`. `_play_count` walks the steps: `"die"` pops that die (`tray` highlight) and ticks Hit; `"relic_die"`/`"flat"`/`"mult"` call `belt.icon(slot).fire()`; `"guard"` shows the minus; each step updates the summary to `"Hit %d × Mult %s = ?"`; step delay starts at 0.3 s and shrinks ×0.9 per step (floor 0.12 s); ends showing the damage. `_skip_count` sets a flag that makes the loop jump to the final summary. The old post-hit `_flash` loop over `lit` goes (the count did it).
  - `_unhandled_input` and the tray's click: while `counting`, Space / Enter / a left click call `_skip_count()` and `set_input_as_handled()`, before any other handling.
  - Enemy loop: tween `belt.modulate.a` to 0.25 when `timing_hint.show()`, back to 1 on `hide()`.
- [ ] **Step 4: Run both suites** — pass. Then launch the game (`--path .`, not headless), play a fight with 3+ relics: drag to reorder, End turn, watch the count, press Space mid-count, block an attack. Fix what looks wrong.
- [ ] **Step 5: Commit** — "Belt on the tray, a counted End turn".

---

### Task 8: Spec and docs follow-through

**Files:**
- Modify: `docs/superpowers/specs/2026-10-29-relics-snowball-design.md` (the "Adds are summed first" line and "beside the dice tray"), `scripts/combat.gd` header comments that mention breaking for `BREAK_SHARDS`.

- [ ] **Step 1:** Point the old spec's Mult rule and belt location at the new spec in one line each.
- [ ] **Step 2:** Grep for `BREAK_SHARDS`, `SKIP_SHARDS`, `Break`, `Skip the relics`, `rares: bool` — expect no hits outside git history.
- [ ] **Step 3: Run both suites** — pass.
- [ ] **Step 4: Commit** — "Docs follow the shop and left-to-right Mult".
