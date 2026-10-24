# Art direction brief: every background

Scope (owner, 2026-10-24): all 17 backgrounds share one hand-drawn pxl style — the nine "?" events,
the title menu, camp, campfire, forge, fight (Sunken Chapel), the Mine, victory and defeat. The
painted Gemini backgrounds are replaced. The first Weeping Altar was approved in look but judged
**flat**: every scene must have real depth (rules below).

## Game frame

- Player fantasy: a frightened deserter pushing through a drowned chapel and a dead mine, gambling with dice.
- Core verbs: roll, place, gamble; in an event: read, choose, sometimes throw dice.
- Engine and renderer: Godot 4.7, GL Compatibility, 2D, `canvas_items` stretch.
- Target platforms: desktop.
- Camera/view/facing: straight-on, eye level, slight high horizon (floor visible), like `bg_campfire.webp`.
- Native viewport and common display scale: 1280x720; backdrop drawn KEEP_ASPECT_COVERED.
- Typical asset size on screen: full screen.

## Visual system

- Shape language: chunky, blocky masonry and props; arches and niches frame the subject; nothing thin or fussy.
- Silhouette priorities: the event's subject (altar, shrine, chest, bones…) must read as one clear dark/lit shape at thumbnail size.
- Value structure: 4 bands. Near-black shadow (top, corners, edges of frame) → dark slate wall → mid stone near the light → warm light pool. Subject sits on the lit band; everything else falls off.
- Palette roles and exact swatches (sampled from bg_campfire / bg_forge / bg_fight):
  - shadow `#030304` `#0c1115` `#181a20`
  - wall slate `#232c35` `#2c343a` `#3c4147`
  - stone light `#4c4e55` `#475f6b` (cold, only near cold light)
  - warm earth/wood `#3c312e` `#644f41` `#8c6452`
  - fire `#a76236` `#e0782a` `#ffb24a` `#ffe08a` (only at a light source)
  - event accent per scene (one each, small): wax/tears near-black red `#3a0f12`, drowned water `#18282f`/`#2f424c`, ember orange, rust `#7a3a20`, bone `#bfb39a`.
- Materials and surface cues: stone = blocky courses with dark mortar, 2–3 shades; wood = plank lines; metal = rust with a single highlight; water = flat dark bands with a few light streaks; bone = pale clusters with dark gaps.
- Edge/line treatment: hard pixel clusters at ~2 image px per art pixel (draw at 512x286, export at 2x); no anti-aliasing, no blur, no gradients except ordered steps.
- Lighting direction and contrast: the scene's own light source (candle, ember, cold drip of light) lights the subject; ambient is near-black; light pools on the floor around the source; low contrast elsewhere.
- Detail density and focal hierarchy: detail only on and around the subject; walls are calm.
- Motion character: stills (no BackdropLife).
- Explicit exclusions: characters, creatures (the drowned pilgrim is a body, not a figure in focus), text, UI, frames, vignette borders, saturated blue walls, evenly lit brick.

## Depth (required in every scene)

The flat version failed because everything sat on one plane: a back wall facing the camera, a floor
strip, the subject pasted in front. Every scene now builds at least three planes:

- **One-point perspective.** A vanishing point near the centre, slightly above the subject. Floor tiles
  (or ground, rails, planks) converge to it and shrink toward the horizon; side walls recede toward it
  instead of a flat back wall facing the camera.
- **Foreground framing.** Large, near-black shapes at the left/right edges and/or top (a pillar, an
  arch edge, a beam, roots, a rock) cropped by the frame, darker and bigger than anything behind.
- **Midground subject** on the floor plane, with a cast shadow and a contact shadow where it touches.
- **Background recess.** A deeper space behind the subject — a corridor, a doorway, a far wall, stairs
  down — darker and slightly cooler (atmospheric perspective) and lower contrast than the midground.
- **Light falloff with distance.** The scene's light lights the nearest surfaces most; the floor's
  light pool is an ellipse in perspective; far surfaces sink toward the shadow swatches.
- **Overlap.** Planes overlap (a pillar crosses the side wall, the subject crosses the recess) so
  depth reads at thumbnail size.

## Per-screen layout contract

- **Events:** UI (title, text, buttons; dice tray on dice events at screen x 160–1120, y 335–530) in the
  centre — subject low and centred, recess behind it, framing at the edges, top dark.
- **Fight (Chapel) and Mine:** fighters stand on a floor ledge at a fixed fraction down the picture
  (`LEDGES` in scripts/combat_screen.gd; keep ≈0.67–0.68 so `_ground_backdrop` still works); hero on
  the left third, enemies on the right two thirds; the dice tray covers the bottom ~third. Keep the
  floor band behind the fighters calm. Candles/lanterns and hanging chains are drawn as separate
  BackdropLife parts (flames, sway strips), not baked in.
- **Title menu:** the logo sits top-centre and the buttons centre; an entrance (gate, stairs down) is the
  focal recess; torches and chains as BackdropLife parts; fog along the bottom.
- **Camp:** the perk board covers most of the screen (two rows of cards, top bar, bottom buttons); a
  campfire in the lower-left gap; mostly framing and mood.
- **Campfire / forge / victory / defeat:** notice-style screens (title, lines, buttons centred) — same
  rule as events.

## Composition contract (event screen layout)

- The event screen draws title + text + buttons in the centre (screen y ≈ 180–330) and, for dice events, a dice tray at screen x ≈ 160–1120, y ≈ 335–530.
- So: the **subject sits bottom-centre**, its base in the lower band (image y ≈ 410–572), rising behind the UI as a dim shape; the light source sits low (never behind the title); architecture (arch, niche, pillars) frames the left/right thirds; the top third stays dark and calm for white text.

## Technical contract

- Asset dimensions/aspect: 1024x572 (drawn 512x286, nearest-neighbour 2x).
- Alpha/background: opaque.
- Grid: 2x2 image px per art pixel.
- Filtering/mipmaps/compression: lossless WebP, nearest filter via the project's 2D default.
- Naming and folders: source `art/pxl/bg_events.px.js`; output `assets/ui/bg_event_<id>.webp`; brief and manifest in `art/events/`.

## Visual target

- Hero: Weeping Altar (`bg_event_altar`), approved by the owner before the other eight.
- Reference: `bg_campfire.webp` (layout, value structure), `bg_forge.webp` (materials).
- Don't: the previous pass (saturated blue brick room repeated, subject tiny and pushed to an edge).
