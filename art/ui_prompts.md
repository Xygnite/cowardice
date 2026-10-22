# UI art prompts for Gemini

Reference: `art/reference/ui_reference.webp`. Attach it to every prompt as the style reference.

## What to take from the reference

- **Mood:** near-black blue-grey backgrounds, cold iron frames, and a few warm accents (torch orange, gold highlight, blood red). The same palette as our sprites.
- **Frames:** 1–2 px dark outline, a lighter bevel line inside it, and small riveted bracket ornaments on the corners only. The edges between corners are plain, which is what makes them stretchable (9-slice).
- **Slots:** recessed dark squares with a 1 px inner shadow. Items sit inside them with a count in the bottom-right corner (the inventory grid).
- **Selection:** a warm gold/bronze fill on the chosen row (the "Open" button). Everything else stays cold and grey.
- **Bars:** thin, flat red (HP) or blue fills inside a dark recessed track, with a small icon on the left.
- **Parchment:** the dungeon map is the one warm, light panel. It's tan paper with burnt edges, a compass rose, and dark ink lines.
- **No text in the art.** Godot draws every label in a pixel font, so the art must have none.

## What Cowardice needs from it

| Piece | Used for | Where in the code now |
|---|---|---|
| 1. Panel frame (9-slice) | every panel: log, dice tray, enemy column, screens | `UI.page`, `UI.box` |
| 2. Button (4 states) | End turn, Reroll, map rooms, camp, forge | `UI.button` |
| 3. Bar | player and enemy HP, Guard pool | HP labels in `combat_screen.gd` |
| 4. Die and slot tiles | the 3 dice and the Attack / Guard / Cleave slots | `_build_die` |
| 5. Intent and resource icons | enemy intents, Grit, Shards, Embers, rerolls | intent label, header text |
| 6. Map parchment and room icons | floor map | `map_screen.gd` |
| 7. Timing bar | block / parry wind-up | `timing_bar.gd` |
| 8. Portrait frame | murmurs and narrator lines | murmur label |

## Shared style block

Paste this once at the start of the Gemini chat, with the reference image attached. Each prompt below repeats the essentials, so they also work on their own.

```
I'm making UI art for a dark-fantasy pixel-art dungeon game. The attached image is the style reference: match its iron frames, riveted corner brackets, recessed slots, dark blue-grey panels and warm gold selection highlight. Do not copy its layout, characters or text.

Rules for every image I ask for:
- Pixel art with hard square pixels: no anti-aliasing, no blur, no gradients, no soft glow, no texture noise.
- Flat front-on view, no perspective, no drop shadow outside the piece.
- Exactly one piece, centred, on a flat solid #FF00FF magenta background with nothing else on it.
- No text, letters, numbers or logos anywhere.
- Use only colours close to this palette: #030405 #0c0f10 #151221 #1a1f1e #1c202c #222734 #29323c #323d45 #3b484d #425156 #4a5e63 #586c6f #667d7e #7b9594 #a5b8af #402c25 #4b3f3a #584e46 #734935 #736558 #95826d #b3683c #e0a169
Reply "ready" and wait for the first piece.
```

## Prompts, one piece each

### 1. Panel frame (9-slice)

```
Pixel-art UI panel frame, square, 1:1. A dark iron frame of even thickness all around, with a 1-pixel near-black outline and a 1-pixel lighter steel bevel inside it. Each of the 4 corners has a small riveted bracket ornament, all four the same, mirrored. The straight edges between the corners are completely plain and identical along their length, with no ornaments, rivets or breaks, so they can be stretched. The inside is one flat dark blue-grey fill (#1a1f1e). Match the frames in the attached reference. Hard square pixels, no anti-aliasing, no gradients, no text. Centred on flat #FF00FF background.
```

### 2. Button, four states

```
Pixel-art game button sprite sheet: 4 identical wide buttons (about 4:1 each) stacked vertically with a gap between them, on flat #FF00FF background. All four share the same dark iron frame with small corner rivets and plain stretchable edges, like the attached reference.
1) normal: dark slate fill.
2) hover: same, with a 1-pixel warm gold inner border.
3) pressed: warm bronze-gold fill like the selected "Open" row in the reference, shifted 1 pixel down.
4) disabled: desaturated, darker, low contrast.
No text, no icons on the buttons. Hard square pixels, no anti-aliasing, no gradients.
```

### 3. Bar (HP / Guard)

```
Pixel-art status bar pieces on flat #FF00FF background, arranged in a row with gaps:
1) an empty bar track: long thin horizontal recessed slot, about 12:1, dark iron 1-pixel frame, near-black inside;
2) a red fill strip that fits exactly inside that track, flat blood red with a 1-pixel lighter top highlight;
3) the same strip in steel blue;
4) a small pixel heart icon;
5) a small pixel shield icon.
Match the HP and mana bars in the attached reference. Hard square pixels, no anti-aliasing, no gradients, no text or numbers.
```

### 4. Die and slot tiles

```
Pixel-art dice UI tiles on flat #FF00FF background, 5 square tiles in a row with gaps:
1) a blank die face: bone-white rounded square with a dark outline and a 1-pixel shade on the bottom and right, completely empty (no pips, a number is drawn on it later);
2) the same die face, darker and cracked, for a cursed die;
3) an empty recessed slot like the inventory slots in the attached reference, dark with a 1-pixel inner shadow;
4) the same slot with a faint warm-orange inner rim (Attack slot);
5) the same slot with a faint cold steel-blue inner rim (Guard slot).
Hard square pixels, no anti-aliasing, no gradients, no text, no numbers, no pips.
```

### 5. Intent and resource icons

```
Pixel-art icon sheet: 10 small square icons in a 5x2 grid with even gaps, on flat #FF00FF background, each readable at 16x16 pixels with a 1-pixel dark outline, in the style of the item icons in the attached reference.
Row 1 (enemy intents): a sword (attack), a round iron shield (guard), a shield cracked in two with a red glint (unblockable), a dark sticker or rune seal with a crack (curse), a bronze bell (ring).
Row 2 (resources): a bloodied bandage knot (grit), a jagged pale-blue crystal shard (shards), a glowing orange ember (embers), two dice with a curved arrow (reroll), a small skull (kills).
Hard square pixels, no anti-aliasing, no gradients, no text.
```

### 6. Map parchment and room icons

Two prompts: the paper and the icons.

```
Pixel-art parchment map background, 16:9, on flat #FF00FF background. Aged tan paper with darker burnt and torn edges and a small compass rose in the top-right corner, like the "Dungeon Map" panel in the attached reference, but completely empty inside: no rooms, no grid, no lines. Muted tan and brown only. Hard square pixels, no anti-aliasing, no text.
```

```
Pixel-art map icons drawn in dark brown ink, as if stamped on parchment, 6 small square icons in a row with gaps, on flat #FF00FF background: crossed swords (fight), an anvil (forge), a campfire (rest), a horned skull (boss), a dotted path segment, a small X mark (current room). Readable at 16x16 pixels each, ink-dark with a tiny gold accent. Hard square pixels, no anti-aliasing, no text.
```

### 7. Timing bar (block / parry)

```
Pixel-art timing bar for a block-and-parry reaction, on flat #FF00FF background, laid out as separate pieces in a column with gaps:
1) a long horizontal recessed track, about 16:1, dark iron 1-pixel frame, near-black inside;
2) a short steel-blue zone that fits inside the track (good block);
3) a narrower gold zone (perfect parry);
4) a thin bright vertical needle marker, slightly taller than the track.
Same frame style as the attached reference. Hard square pixels, no anti-aliasing, no gradients, no text.
```

### 8. Portrait frame

```
Pixel-art portrait frame, square, 1:1, on flat #FF00FF background. Dark iron frame with riveted corner brackets like the character portraits in the attached reference, with a fully transparent-looking empty centre filled with flat #FF00FF magenta (no face, no character). Plain straight edges. Hard square pixels, no anti-aliasing, no gradients, no text.
```

## After generating

- Gemini draws "pixel art" at high resolution on an uneven grid. Shrink each piece with nearest-neighbour scaling to its game size, then snap it to `assets/palette.png`, which is what `tools/make_sprites.gd` already does for sprites.
- Target sizes in game pixels (shown at 3×): 9-slice corner 6–8 px, button 64×16, bar track 48×5, die and slot 20×20, icons 12–16 px, portrait 32×32.
- Before you cut, check that the 9-slice edges are really plain. Gemini often sneaks rivets into them, and those rivets smear when the panel stretches.
