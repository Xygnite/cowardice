# Background prompts for Gemini

Backgrounds: the fight, the main menu, the camp, the dice tray floor, and the forge, campfire and
end-of-run screens. All but the tray floor fill the whole 1280x720 screen and sit behind the UI.
The tray floor is a small tile repeated inside the dice box. The prompts work in ChatGPT too.

## Workflow

1. Start a fresh Gemini chat. Attach `art/reference/plague_doctor.webp` (style anchor).
2. Paste the **style block**, then one background prompt. Regenerate until you like it.
3. Save it as `assets/ui/bg_<name>.png` (`bg_fight`, `bg_menu`, `bg_camp`, `bg_tray`, `bg_forge`,
   `bg_campfire`, `bg_victory`, `bg_defeat`). Keep PNG.
4. Check it (see **Checks**), then hand it over to be cut and wired in.

## Style block (paste first in every chat)

```
You are drawing backgrounds for a dark-fantasy dice roguelike. Match the pixel style of the attached image (the plague doctor) exactly:
- Pixel art on an even square grid, every art-pixel the same size, no anti-aliasing, no blur, no gradients, no dithering noise.
- Flat colour areas with 2-3 shades each; muted cold greys, slate blues and dark browns, with small warm orange accents for fire and candles.
- Dark and low in contrast overall: characters and UI are drawn on top and must stand out against it.
- Light comes from the upper left unless a fire in the scene is the light.
- No characters, no creatures, no text, no UI, no frame, no vignette border. The art goes edge to edge.
Reply "ready" and wait.
```

## Background prompts

### Fight (`bg_fight`)

```
Draw a 16:9 background, 320 by 180 art-pixels: the inside of a sunken, half-flooded stone chapel crypt, seen from the side like a stage. A flat flagstone floor runs across the whole image, with its top edge at exactly half the image height: the characters stand on that line, a hero on the left and enemies on the right. Behind the floor: a back wall of big damp stone blocks, two arched alcoves with old bones and melted candles (small orange flames), a broken stained-glass window high in the middle letting in a faint cold blue light, hanging chains, cobwebs. Keep the middle of the image, just above the floor line, plain and darker, where the characters stand. Below the floor line the flagstones fade into near-black, because a dice tray panel covers the lower half of the screen.
```

### Main menu (`bg_menu`)

```
Draw a 16:9 background, 320 by 180 art-pixels: the moss-covered stone entrance of a sunken chapel at night, a great arched doorway in the centre leading down into darkness, worn steps going down, two iron braziers with small orange fires on either side of the door, a few gravestones and dead trees at the edges, a cold blue-grey night sky with a pale moon behind thin clouds. The centre of the image (the dark doorway, roughly the middle third horizontally and from 25% to 85% of the height) must stay calm, dark and empty of detail: a large title logo and a column of buttons are drawn over it.
```

### Camp (`bg_camp`)

```
Draw a 16:9 background, 320 by 180 art-pixels: a deserter's camp in a ruined forest clearing at night, seen from the side. A small campfire with orange flames and rising sparks near the bottom left corner, a bedroll and a leaning round shield beside it, a tattered lean-to tent on the right edge, crooked dark trees framing both sides, a cold blue-grey sky through the branches. The middle band of the image (from 30% to 85% of the height, the full width minus the outer sixth on each side) must stay calm and dark, with only distant tree trunks: three perk cards are drawn over it. Firelight warms only the lower left.
```

### Dice tray floor (`bg_tray`)

The first try came back darker toward its edges, so the tile showed a grid when repeated. This
version spells the flatness out. Skip the style block for it: its lighting and contrast lines work
against a flat tile.

```
Pixel art texture tile for a game, 1:1 square, exactly 64 by 64 art-pixels, each art-pixel drawn as a perfect square block of the same size (nearest-neighbor upscale, no anti-aliasing, no blur).

Subject: dark green gambler's felt seen straight from above, perfectly flat, like a scan of fabric.

The tile will be repeated hundreds of times edge to edge, so:
- EVEN BRIGHTNESS EVERYWHERE. No vignette, no darker corners or edges, no lighter centre, no spotlight, no shading, no gradient of any kind. The 4 pixels nearest each edge must be just as bright as the middle.
- SEAMLESS. The leftmost column must continue straight into the rightmost column, and the top row into the bottom row, as if the tile wrapped around.
- NO FEATURES THAT REPEAT VISIBLY. No scuffs, stains, burn marks, holes, stitches, borders or any single noticeable mark. Only a fine, uniform felt grain spread evenly over the whole tile.

Colours: only 3 to 4 flat colours, all close together: deep green-black #10201a, #14261e, #182b22, and a rare #1c3027 for the grain. Nothing brighter, nothing darker. Very low contrast, so white and bone dice stand out on it.

No text, no frame, no border, no light source, no 3D effect.
```

Check it: put it in an image editor, tile it 3x3, and squint. If you can see where the copies meet, or
any repeating spot, regenerate.

### Forge (`bg_forge`)

The Forge screen shows your dice as 3D dice to upgrade, laid on a work surface in the middle.

```
Draw a 16:9 background, 320 by 180 art-pixels: a smithy carved into the dungeon rock, seen from the side. A big iron anvil on a tree-stump block at the lower left, hammers and tongs hanging on the wall behind it, a stone forge on the right edge with glowing orange coals and a hood above it, a bellows, a water barrel, sparks drifting up from the coals. The centre of the image (from 25% to 85% of the width and from 30% to 90% of the height) is a flat dark iron workbench top seen from slightly above, plain and calm: three dice and their buttons are drawn over it. Warm orange forge light on the right, cold dark stone everywhere else.
```

### Campfire (`bg_campfire`)

The rest stop inside the dungeon, shown between rooms; one heading, one line of text and two
buttons sit in the middle.

```
Draw a 16:9 background, 320 by 180 art-pixels: a small campfire built in a crumbling side chamber of the crypt, seen from the side. The fire sits low in the bottom centre, on the floor, with orange flames and a few rising sparks; a bedroll and a leaning round wooden shield beside it; a cracked stone wall behind with an arch to a dark corridor on the left and a hanging chain on the right. The fire's warm light reaches only the floor and the lower wall; the top half of the image is calm, plain dark stone where a title and text are drawn.
```

### End of run: victory (`bg_victory`)

Shown with the run tally after the Bone Warden falls; the title, six lines of results and two
buttons sit in the centre.

```
Draw a 16:9 background, 320 by 180 art-pixels: the crypt after the battle, seen from the side, quiet and still. The Bone Warden's armour, tower shield and mace lie scattered in a heap of bones at the lower right, its candles guttered out; pale cold dawn light falls in a single beam from a broken window high on the left onto the floor. Dust in the air. The middle of the image (the middle 60% of the width, from 15% to 90% of the height) is plain dark stone wall, calm and empty: a title, text and buttons are drawn over it.
```

### End of run: defeat (`bg_defeat`)

Shown with the run tally when you fall or flee; same layout as victory.

```
Draw a 16:9 background, 320 by 180 art-pixels: the crypt entrance seen from inside, looking back up a long dark stone stairway toward a small grey doorway of daylight far at the top. A dropped round wooden shield and a broken sword lie on the bottom steps in the lower left; long shadows reach up the stairs. The middle of the image (the middle 60% of the width, from 15% to 90% of the height) stays plain and dark, the stairway fading into black: a title, text and buttons are drawn over it.
```

## Checks

- **Pixels:** every art-pixel the same size. If Gemini drew it at an uneven scale, regenerate; the
  cutting tool reads one art-pixel per grid cell.
- **Dark enough:** put a character sprite and the logo over it in an image editor. They must stand
  out clearly. If not, ask Gemini to make it darker and lower in contrast.
- **Clear areas:** the parts the prompts keep empty (the menu centre, the camp's middle band, the
  fight's middle above the floor line) really are calm.
- **Tray tile:** place four copies side by side in a 2x2 grid. No seams should show.
