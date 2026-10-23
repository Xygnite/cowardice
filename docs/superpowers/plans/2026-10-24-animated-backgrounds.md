# Animated Backgrounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flickering flames, drifting fog and swaying chains on the title menu, camp and fight backgrounds, drawn in the paintings' own pixel style.

**Architecture:** A `BackdropLife` node attached under each backdrop `TextureRect` holds a `Node2D` "stage" whose transform maps the 1024x572 image space onto the covered rect, so every overlay is placed in image coordinates and follows scaling and the fight backdrop's slide. Flames and fog are pxl animations built from `art/pxl/life.px.js`; chains are cut out of the original paintings by `tools/cut_chains.gd`, which also writes the patched backdrops and each chain's sway strip.

**Tech Stack:** Godot 4.7.2 GDScript; pxl (`node .claude/skills/pxl-pixel-art/bin/pxl.js`); headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-10-24-animated-backgrounds-design.md`

## Global Constraints

- Screens: title menu (`bg_menu`), camp (`bg_camp`), fight (`bg_fight`) only; forge, campfire rest, victory, defeat and map stay still.
- Overlays live in the backdrop's 1024x572 image space, drawn with nearest filtering, so Godot scales them exactly like the painting.
- Painting pixel size, measured with `.claude/skills/rigging-pixel-sprites/measure_cells.gd`: menu ≈ 2.14 image px, fight ≈ 2.13, camp ≈ 4.24 (grids are loose; confirm by eye on a zoom). Overlays are authored at that size: one pxl pixel = `px` image px (menu 2, fight 2, camp 4).
- Motion moves in whole pxl pixels; never smooth rotation or sub-pixel slides. Flames 6–10 fps; chains sway over several seconds (one swing ≈ 3–4 s); fog crosses the screen in tens of seconds.
- Chains that sway: only free-hanging straight ones clear of trees, webs and other chains, about 3–5 per screen; each moves as one piece from its top link. Chains on the floor (the fight's long centre chain) stay still.
- Fog never covers the fighters' feet or the dice tray; the fight floor fog is optional and dropped if it can't stay clear.
- Overlays sit under all UI; UI covering a candle or chain top is fine.
- Order of work: flames, then fog, then chains.
- Tests: `.\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_combat.gd` → `All combat checks passed.`; `... -s tests/test_fight_flow.gd` → `All fight-flow checks passed.`
- New class_name scripts need one `--headless --path . --import`; revert the `.import` line-ending noise it causes (`git ls-files -m | grep '\.import$'` → `git checkout --` each) and commit only real changes.
- Commit after each task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Window not 16:9 (or maximized at 1812 wide):** overlays stay glued to their painted spots. Test in Task 1 (cover math at two rect sizes).
- **Fight backdrop slide:** after `_ground_backdrop` moves the crypt, candles still sit on their candlesticks. Checked by Task 2's fight render.
- **Leaving and re-entering a screen many times:** no growing node count or errors (life is freed with its screen). Covered by Task 1's flow check opening each screen twice.
- **Fog loop seam:** the scrolling band has no visible jump where it wraps. Task 3 test: band width is a whole multiple of its scroll step and the band tiles (left column matches right neighbour).
- **Chain cut leaves no hole or double chain:** patched backdrop under each chain shows wall, not chain. Task 4 render at both sway extremes.

---

### Task 1: BackdropLife stage and the life table

**Files:**
- Create: `scripts/backdrop_life.gd` (`class_name BackdropLife`, `extends Control`)
- Modify: `scripts/ui.gd` (`backdrop()` attaches life), `tests/test_combat.gd` (new `_backdrop_life()`), `tests/test_fight_flow.gd` (new `_screens_with_life()`)

**Interfaces:**
- Produces:
  - `const IMAGE := Vector2(1024, 572)`
  - `const LIFE := {"menu": {"px": 2, "parts": []}, "camp": {"px": 4, "parts": []}, "fight": {"px": 2, "parts": []}}` — later tasks fill `parts` with dictionaries `{"kind": "flame" | "fog" | "chain", "art": String, "at": Vector2 (image px, top-left), ...}`
  - `static func cover(rect: Vector2, image := IMAGE) -> Transform2D` — scale `maxf(rect.x / image.x, rect.y / image.y)`, origin centring the scaled image in `rect` (matches `STRETCH_KEEP_ASPECT_COVERED`)
  - `static func attach(backdrop: TextureRect, art: String) -> BackdropLife` — adds a full-rect, mouse-ignoring child holding a `Node2D` stage (`texture_filter` nearest), re-applies `cover()` on `resized`, builds `LIFE[art].parts`; returns null for arts not in LIFE
  - `static func frames(sheet: String, fps: float) -> SpriteFrames` — loads `res://assets/ui/life/<sheet>.png` + `.json` (pxl frame sheet: frames in order, one row) into one looping "default" animation
  - `var stage: Node2D`
- `UI.backdrop()` calls `BackdropLife.attach(r, art)` after adding the rect.

- [ ] **Step 1: Write the failing tests**
  - `_backdrop_life()` in test_combat: `cover(Vector2(1280, 720))` has scale `720.0 / 572` (height decides, since 1280/1024 is smaller), maps image (0,0) to (≈ -4.45, 0) and image (1024,572) to (≈ 1284.45, 720); `cover(Vector2(1812, 720))` has scale `1812.0 / 1024` and maps the image centre (512, 286) to (906, 360); `BackdropLife.LIFE` has exactly the keys `["menu", "camp", "fight"]`.
  - `_screens_with_life()` in the flow test (run first): show the menu, camp and a fight twice each via the game's own `_show_menu()`, `_show_camp()`, `_show_fight()`; after each, the screen's backdrop has exactly one `BackdropLife` child; no engine errors (ErrorCounter as `_play`).
- [ ] **Step 2: Run both suites — expect parse failure on `BackdropLife`.**
- [ ] **Step 3: Implement** `scripts/backdrop_life.gd` per Interfaces, and the one-line hook in `UI.backdrop()`. Parts are added as children of `stage` at `at`, scaled by `px` (a pxl pixel becomes `px` image px).
- [ ] **Step 4: Import once, run both suites — expect both to pass.**
- [ ] **Step 5: Commit** — "BackdropLife: overlays in backdrop image space".

---

### Task 2: Flames

**Files:**
- Create: `art/pxl/life.px.js` (flames now; fog joins in Task 3), `assets/ui/life/*.png` + `.json`
- Modify: `scripts/backdrop_life.gd` (LIFE entries, "flame" kind), `tests/test_combat.gd` (`_backdrop_life()` additions)

**Interfaces:**
- Consumes: Task 1 `LIFE`, `frames()`, `stage`
- Produces: flame parts `{"kind": "flame", "art": "<sheet>", "at": Vector2, "fps": float}` played as `AnimatedSprite2D` with `frames(art, fps)`, random start frame so neighbours don't flicker in step.

- [ ] **Step 1: Test** — every LIFE part's `art` resolves: `ResourceLoader.exists("res://assets/ui/life/%s.png" % art)`; each screen has at least: menu 2 flames, camp 1 flame (with sparks in its frames or as a second part), fight ≥ 2 flames.
- [ ] **Step 2: Run — fails (no parts yet).**
- [ ] **Step 3: Draw** in `art/pxl/life.px.js`, at each screen's pxl pixel size, sampling the flame colours from the painting: `torch` (menu braziers), `campfire` (camp, with 1–3 sparks rising and fading), `candle` (fight; one small loop reused per candle). 6–8 frames each, looping cleanly. Build: `node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/life.px.js`; copy each anim's frame strip PNG + JSON to `assets/ui/life/`.
- [ ] **Step 4: Place** — read each painted flame's top-left in image px off a zoom of the backdrop (`.claude/skills/rigging-pixel-sprites/zoom_sprite.gd`), add the parts to LIFE.
- [ ] **Step 5: Render check** (non-headless scratch SceneTree script outside the repo, saving viewport PNGs): menu, camp, and a fight after `_ground_backdrop` has run; each flame sits exactly on its painted fire. Fix positions until it does.
- [ ] **Step 6: Import, run both suites — pass. Commit** — "Flickering flames on menu, camp and fight backgrounds".

---

### Task 3: Fog

**Files:**
- Modify: `art/pxl/life.px.js`, `assets/ui/life/`, `scripts/backdrop_life.gd`, `tests/test_combat.gd`

**Interfaces:**
- Produces: fog parts `{"kind": "fog", "art": "<band>", "at": Vector2, "width": float (image px to cover), "period": int (pxl px after which the band repeats), "step_s": float (seconds per 1-pxl-pixel step), "alpha": float}` played as a `Sprite2D` with `texture_repeat` enabled and `region_enabled`, its region x advancing one pxl pixel every `step_s` and wrapping at `period`.

- [ ] **Step 1: Test** — for each fog part: its band PNG's width is a whole multiple of `period`, and `image.get_region(Rect2i(0, 0, period, h)).get_data() == image.get_region(Rect2i(period, 0, period, h)).get_data()` (the band repeats exactly, so the wrap has no seam). Menu has a moat fog part and camp a ground fog part; any fight fog part's bottom edge (`at.y + band height × px`, image px) is above `CombatScreen.FLOOR_LEDGE * 572`.
- [ ] **Step 2: Run — fails.**
- [ ] **Step 3: Draw** soft pixel fog bands (2–3 tones, no blur, ordered alpha steps) for `moat` (menu), `ground` (camp) and optionally `floor` (fight, kept above the ledge). Scroll ≈ 1 pxl pixel per 0.3–0.6 s.
- [ ] **Step 4: Render check** as in Task 2, plus two shots ~2 s apart to see it move without a seam; in the fight shot the fighters' feet and the dice tray are clear.
- [ ] **Step 5: Run both suites — pass. Commit** — "Drifting fog on menu, camp and fight backgrounds".

---

### Task 4: Swaying chains

**Files:**
- Create: `tools/cut_chains.gd`, `art/reference/bg_menu_still.webp`, `art/reference/bg_fight_still.webp` (and camp only if it has qualifying chains): copies of today's backdrops, the tool's source
- Modify: `assets/ui/bg_menu.webp`, `assets/ui/bg_fight.webp` (written by the tool), `assets/ui/life/chain_*.png`, `scripts/backdrop_life.gd`, `tests/test_combat.gd`

**Interfaces:**
- Produces:
  - `tools/cut_chains.gd` with `const CHAINS := {"menu": [{"outline": PackedVector2Array (image px), "top": Vector2 (hanging point)}, ...], "fight": [...]}`. For each backdrop it reads `art/reference/bg_<name>_still.webp`, copies the pixels inside each outline into `assets/ui/life/chain_<name>_<i>.png` as a sway strip of 5 frames (rows sheared about `top`: bottom offset −2, −1, 0, +1, +2 pxl pixels, linear in height, whole pixels), fills the cut pixels in the backdrop from the nearest uncut wall pixel in the same row (left or right), and saves `assets/ui/bg_<name>.webp` (lossless).
  - chain parts `{"kind": "chain", "art": "chain_<name>_<i>", "at": Vector2, "period": float}` played ping-pong across the 5 frames over `period` seconds (≈ 3–4 s per swing).
- [ ] **Step 1: Test** — each chain part's strip exists and has exactly 5 frames; running `cut_chains.gd` twice produces byte-identical outputs (it always reads the `_still` sources).
- [ ] **Step 2: Run — fails.**
- [ ] **Step 3: Pick the chains** (Global Constraints: free-hanging, straight, clear of trees/webs/other chains, 3–5 per screen) and trace outlines off zooms; copy the original backdrops to `art/reference/*_still.webp`; write and run the tool; patch any wall the row-fill gets wrong by adding a hand patch list to the tool (no hand-editing of the output).
- [ ] **Step 4: Render check** — each screen at sway frame 0 and frame 4: no chain ghost or hole in the wall, chains hang from their painted hooks, the fight's centre floor chain unchanged.
- [ ] **Step 5: Import, run both suites — pass. Commit** — "Swaying chains on menu and fight backgrounds".

---

### Task 5: Whole check

- [ ] **Step 1:** Run both suites on the final commit. Expected: both pass.
- [ ] **Step 2:** Render menu, camp and fight once more at 1280x720 and at 1812x720; overlays stay on their painted spots.
- [ ] **Step 3:** Hand the owner the renders and the game for a look; tuning (speeds, which chains) is follow-up.
