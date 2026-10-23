# Animated backgrounds

## Why

The backgrounds are still paintings. Small, slow motion would make the places feel lived in: fire that
flickers, fog that drifts, chains that sway. The owner asked for flames, fog and swaying chains on the
title menu, the camp and the fight screen, made with the pxl pixel-art tool already in the repo.

## Goals

- The title menu, camp and fight backgrounds each have looping motion: flames, fog, swaying chains.
- The motion matches the paintings: same palette, same pixel size, no blur, no smooth sub-pixel slides.
- It stays subtle: it never pulls the eye from the fight, the dice or the buttons.

## Non-goals

- Forge, campfire rest, victory, defeat and map screens stay still (they can be added later the same way).
- No repainting of the backgrounds themselves beyond patching where a chain is cut out.
- No changes to fighters, dice, UI or audio.

## Anti-goals (a failure even if it works)

- Smooth, blurry or sub-pixel motion that looks pasted on top of pixel art.
- An overlay that sits in the wrong place: a flame beside its torch, a chain hanging in the air, a seam.
- Fog over the fighters' feet or the dice tray, or anything that makes text or intents harder to read.
- A visible "jump" where a loop restarts.

## What moves where (decided)

- **Title menu** (`assets/ui/bg_menu.webp`): both torch flames by the stairs flicker; the chains hanging
  from the top sway; fog drifts across the moat at the bottom.
- **Camp** (`bg_camp.webp`): the campfire burns, with sparks rising (my call); low fog creeps along the ground.
- **Fight** (`bg_fight.webp`): the candle flames flicker; the hanging chains sway. A faint floor fog is
  optional (my call) and must stay clear of the fighters' feet; leave it out if it can't.

## How it is made (my calls, owner approved the outline)

- **Flames:** small looping pixel animations drawn with pxl, one per painted fire (or one shared loop
  reused at several fires where they look alike), placed exactly over the painted flame, in the painting's
  palette and at its art-pixel size. A gentle light flicker on the glow around a fire is welcome if it
  stays pixel-crisp.
- **Fog:** a semi-transparent pixel fog band drawn with pxl that tiles horizontally and scrolls slowly
  sideways, looping seamlessly; it moves in whole art pixels.
- **Chains:** the chains are painted into the backgrounds. Each chain that sways is cut out of the picture
  into its own sprite, the wall behind it is painted back in (with pxl or by hand-patching pixels), and the
  cut chain hangs from its top link and sways by a pixel or two, in whole-pixel frames like the character
  rigs (never smooth rotation that blurs).
- **Speed:** slow. Flames loop at roughly 6–10 frames a second; chains sway over several seconds; fog
  takes tens of seconds to cross the screen.
- **Placement:** every overlay lives in the backdrop's own image coordinates, so it stays put when the
  backdrop is scaled to cover the window (`UI.backdrop` uses keep-aspect-covered) and when the fight
  backdrop slides to put its floor under the fighters (`_ground_backdrop` in `scripts/combat_screen.gd`).

## Settled after review (my calls)

- **Pixel grid:** the backgrounds are 1024x572 images scaled about 1.26x to cover the screen. Overlays
  are authored in that same 1024x572 image space, at the painting's own chunky pixel size (about 4 image
  px), and drawn with nearest filtering as children of the backdrop, so Godot scales them exactly as it
  scales the painting. Their pixels then come out the same uneven widths as the painting's, which is
  what makes them match.
- **Which chains sway:** only chains that hang free and straight down, clear of trees, webs and other
  chains, about 3 to 5 per screen. Draped swags, chains crossing trees or webs, and chains that rest on
  the floor (the fight's long centre chain ending in a pile) stay painted and still. Each swaying chain
  moves as one piece from its top link.
- **UI on top:** overlays sit in the backdrop, under the UI, like the painting; the top bar or HP bar
  may cover a candle or chain top, and that is fine.
- **Order of work:** flames first, then fog, then chains, so the cheapest motion lands first. All three
  stay in scope.

## Constraints

- Godot 4.7, GDScript; screens built in code; 1280x720 canvas with `canvas_items` stretch.
- Backdrops are drawn by `UI.backdrop(screen, art)` in `scripts/ui.gd`; menu, camp and fight screens call it.
- pxl lives in `.claude/skills/pxl-pixel-art` (build: `node .claude/skills/pxl-pixel-art/bin/pxl.js build <file>`);
  existing pxl sources are in `art/pxl/`, frame sheets go to `assets/` and are wired as Godot animations
  (see `tools/frames_scene.gd` and how `*_frames.tscn` are used) or as AnimatedTexture/SpriteFrames.
- Tests: `tests/test_combat.gd` (rules) and `tests/test_fight_flow.gd` (real screens, fails on any engine
  error). The animated screens must open with no engine errors.
- New source art (pxl files) goes under `art/pxl/`; generated sheets under `assets/`.

## Left to the builder

- Exact positions and sizes of each fire, chain and fog band, read off the backdrop images.
- Whether flames are separate pxl animations or one shared loop, and frame counts.
- How overlays are attached in Godot (child nodes of the backdrop TextureRect, a helper in `ui.gd`, a
  per-backdrop table), as long as placement survives scaling and the fight backdrop's slide.
- Whether the chain cut-out and wall patch is done with a tool script or by hand.
