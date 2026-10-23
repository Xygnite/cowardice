# Combat UI prompts (ChatGPT or Gemini)

Icons and effects for the fight screen. Each prompt makes one sheet: several pieces in a row on
magenta, which `tools/make_ui.gd` cuts apart, left to right. These work in ChatGPT and in Gemini.

## Workflow

1. Start a fresh chat. Paste the **style block**, then one prompt.
2. Check the result (see **Checks**) and regenerate until it passes.
3. Save it under `assets/ui/` with the file name the prompt gives. Keep PNG or WebP; never JPG.

## Style block (paste first)

```
You are drawing pixel art UI pieces for a dark-fantasy dice roguelike. Rules for every image:
- Hard square pixels only: every art-pixel exactly the same size on one grid, scaled up with nearest-neighbor. No anti-aliasing, no blur, no soft glow, no gradients.
- A closed 1-pixel near-black (#070e10) outline around every piece.
- Flat colours, 2-3 shades each. Palette: dark iron greys and slate blues, bone white (#c1b59b), rust and bronze, gold (#e8b04a), warm orange (#e8822e), blood red (#c0392b), sickly green (#7fae4f).
- NEVER use pink, purple, violet or magenta anywhere in the art: the background is magenta and is cut out by colour.
- Background: one flat solid #FF00FF magenta, edge to edge, no texture or noise.
- Pieces in ONE horizontal row, the same size, evenly spaced, with wide magenta gaps between them (at least a quarter of a piece's width) and a wide magenta margin around the edges. Pieces must not touch.
- No text, no numbers, no labels, no frame, no watermark.
Reply "ready" and wait.
```

## 9. Enemy intent icons (`assets/ui/intents.png`)

Shown above each enemy next to a number ("attack 5"), so they are small and must read at a glance.

```
Draw 5 intent icons in one row, left to right, each about 16 by 16 art-pixels, as bold simple silhouettes:
1. ATTACK: a straight sword pointing diagonally down-left, steel blade, gold crossguard.
2. GUARD: a round iron shield seen from the front, with a bright steel rim and boss.
3. UNBLOCKABLE: a sword stabbing straight down through a shield that is cracking in two, with a bright blood-red crack.
4. CURSE: a bone die with a dripping sickly-green eye on its face, green drips running off the bottom.
5. RING: a small bronze bell tilted mid-swing, with two orange curved sound arcs beside it.
```

## 10. Target marker (`assets/ui/target.png`)

Floats above the enemy you are aiming at (gold) and above the enemy taking its turn (red).

```
Draw 2 markers in one row, each about 13 art-pixels wide and 11 tall: a chunky arrowhead pointing straight DOWN, like a cursor hovering over someone's head, with a small notch cut into its top edge.
1. TARGET: gold (#e8b04a) with a lighter gold highlight on its upper-left edge.
2. ACTING: blood red (#c0392b) with a lighter red highlight on its upper-left edge.
Same shape for both, only the colour differs.
```

## 11. Grave Bell ring (`assets/ui/ring.png`)

The Grave Bell's "ring" makes another enemy's attack unblockable this turn. These show the link:
the first on the bell while it rings, the second above the enemy it empowered.

```
Draw 2 pieces in one row:
1. RINGING: three curved sound-wave arcs fanning out to the left, each arc thicker and fainter-coloured than the one before (warm orange #e8822e, then darker orange, then rust), about 18 art-pixels wide and 20 tall, like the sound coming out of a struck bell. Only the arcs, no bell.
2. EMPOWERED: a small round orange-and-gold rune mark, a circle with a tiny bell shape cut out of its middle and four short rays around it, about 14 by 14 art-pixels, like a brand glowing on the enemy.
```

## 12. Hit effects (`assets/ui/effects_slash.png`, `effects_spark.png`, `effects_block.png`)

Short animations played over a fighter when a blow lands. Make each in its own chat message so
every sheet holds one animation. Floating damage numbers need no art: they use the game's font.

Slash, played on an enemy you hit:

```
Draw a 4-frame animation in one row, every frame the same canvas, about 40 by 40 art-pixels: a quick diagonal sword slash from top-right to bottom-left.
Frame 1: a thin bright white-yellow line just starting at the top right.
Frame 2: a full curved crescent slash, white core with a gold edge.
Frame 3: the crescent wider and breaking into 3-4 separate streaks, gold fading to orange.
Frame 4: only a few small orange flecks left where the slash was.
Keep the slash in the same place on every frame; draw frames side by side, not overlapping.
```

Parry spark, played on the hero when a parry lands:

```
Draw a 4-frame animation in one row, every frame the same canvas, about 32 by 32 art-pixels: a metal-on-metal parry spark bursting from the centre.
Frame 1: a small bright white star at the centre.
Frame 2: a bigger white-and-gold starburst with 6 sharp spikes.
Frame 3: spikes breaking off into 8 small gold and orange sparks flying outward.
Frame 4: 5 tiny orange embers near the edges, nothing in the middle.
Same centre on every frame; frames side by side, not overlapping.
```

Block impact, played on the hero when a block lands:

```
Draw a 3-frame animation in one row, every frame the same canvas, about 32 by 32 art-pixels: a blunt impact on a raised shield, seen from the side, the force coming from the right.
Frame 1: a flat curved arc of steel-grey and white on the right side, like a shockwave just hitting.
Frame 2: the arc wider, with 3 short white dust puffs spreading up, down and to the right.
Frame 3: only the 3 dust puffs, fading to grey and smaller.
Same position on every frame; frames side by side, not overlapping.
```

## 13. Perk icons (`assets/ui/perks.png`)

One per perk card on the camp's perk board, shown at the top of the card beside its name. New perks
get added to the end of the row later, in the same style.

```
Draw 3 perk icons in one row, left to right, each about 24 by 24 art-pixels, each set on its own small round bronze-rimmed medallion (dark slate inside, bronze rim, 1-pixel outline) so they read as a matching set:
1. STEADY HAND: an armoured gauntlet held flat and still, a bone die balanced upright on its open palm, two short gold "steady" lines beside it.
2. THICK SKIN: a heart made of riveted iron plates, a small blood-red heart showing through a gap in the middle plate.
3. GAMBLER'S HEART: two bone dice side by side each showing a single pip (snake eyes), with a small gold crown above them.
```

## Checks

- **Background:** pure flat magenta. If the art has any pink or purple, regenerate: that colour gets
  cut out with the background.
- **Gaps:** every piece and frame stands alone with clear magenta all round. Touching pieces get cut
  as one.
- **Pixels:** zoom in. Every art-pixel must be the same size; soft or blurry edges mean regenerate,
  or add "hard square pixels only, no smoothing" to the end of the prompt.
- **Frames:** in an animation, the effect sits in the same spot in every frame, so it doesn't jump
  when played.
