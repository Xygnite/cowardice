# Rig-ready character prompts for Gemini

Goal: redraw every character so it rigs cleanly and the whole cast looks like one set. For each
character, Gemini makes a **base image** (the whole character), then one **layer image** per depth
layer, from the back to the front. Each layer is drawn **complete**: whatever a layer in front of it
hides is drawn in, so when the front layer moves there is real art behind it.

Example, the Deserter from back to front: the cape is hidden by the body, the shield hand is hidden
by the body, and the body is hidden by the sword arm. So the cape, the shield arm, the body and the
sword arm are each their own image, and each one is whole.

Every layer is an **edit of the base image**. Edits keep the base image's canvas, so the layers line
up pixel for pixel. Separately generated images would not.

## Workflow per character

1. Start a fresh Gemini chat. Attach `art/reference/plague_doctor.webp` (style anchor) and the
   character's current reference from `art/reference/` (design anchor).
2. Paste the **style block**, then the character's **base prompt**. Regenerate until you like it.
3. In the same chat, run the **layer prompt** once for every layer in that character's table below.
   Always edit the **base image**, never a previous layer.
4. Save the base as `art/reference/<name>.png` and each layer as `art/reference/<name>_<NN>_<layer>.png`,
   numbered from the back (`01`) to the front, e.g. `deserter_01_cape.png`. The number is the draw order.
   Keep PNG; never re-save pixel art as JPG.
5. Stack the layers in order in an image editor. They must rebuild the base image exactly (see
   **Checks**). Regenerate any layer that doesn't.

The tools don't read numbered layers yet. Today `tools/make_sprites.gd` takes a single `"body"` layer,
and `tools/rig_sprites.gd` cuts the moving parts from the base by outline. Reading numbered layers
needs a tool update.

## Style block (paste first in every chat)

```
You are drawing game sprites for a dark-fantasy dice roguelike. Match the style of the FIRST attached image (the plague doctor) exactly:
- Pixel art on an even square grid, every art-pixel the same size, no anti-aliasing, no blur, no gradients, no dithering noise.
- A closed 1-pixel near-black outline around the figure and around every separate part.
- Flat colour areas with 2-3 shades each; muted cold greys, slate blues and dark browns, with small warm orange accents for fire, eyes and glows.
- Light comes from the upper left.
- Background: one flat solid #FF00FF magenta, edge to edge. No floor, no ground shadow, no vignette, no text, no frame.
- Exactly one character, full body, centred, with empty margin on all sides. Square 1:1 image.
Reply "ready" and wait.
```

## Pose rules (part of every base prompt)

Layers are drawn complete, so parts may overlap. These rules keep the animation readable:

- The **weapon arm** hangs or is held on one side of the body, so its swing reads clearly.
- The **head** sits on the shoulders with a visible neck line.
- The **legs** stand slightly apart, both feet flat on one baseline.
- Cloth that should flutter (cape ends, robe tatters) hangs in a few separate strips.
- Facing: the hero faces **right**; every enemy faces **left**, toward the hero.

## Base prompts

Each one follows the style block. The second attached image is that character's current design.
Target heights are in art-pixels; they keep the cast to one scale.

### Deserter (hero)

```
Redraw the character in the SECOND attached image as a new sprite in the agreed style: a deserter knight in battered dark plate with rust-orange edges, a ragged dark green-grey cape, a closed helm, a short sword in his right hand and a round wooden shield with a bronze rim in his left. About 64 art-pixels tall.
Pose for animation: facing RIGHT, three-quarter view. His sword arm hangs straight down from the back shoulder along the LEFT edge of the figure, in front of the cape; the hand is beside his thigh, and the sword points down and slightly back. The sword arm and blade stay entirely outside the torso and legs: no part of the sword crosses his body. Shield held at the front edge of his body; head clear on the shoulders; feet apart; cape ending in 3 loose strips.
```

### Skeleton

```
Redraw the character in the SECOND attached image as a new sprite in the agreed style: an undead skeleton warrior with grey-blue bones, glowing orange eye sockets, a rusty short sword and a round dark wooden shield. About 48 art-pixels tall.
Pose for animation: facing LEFT; sword arm on the far side, held out and away from the ribcage, blade down; shield on the near side at the body's front edge; skull clearly separate above the neck vertebrae; feet apart.
```

### Rotwood Treant

```
Redraw the right-hand creature in the SECOND attached image as a new sprite in the agreed style: a rotting walking tree wrapped in dark green vines, with a carved angry face, glowing orange cracks, and two bone dice tangled in its bark. About 54 art-pixels tall.
Pose for animation: facing LEFT; one long branch-arm on its front side reaching down and slightly out, clear of the trunk; the face-knot at the top reads as a separate head; two stumpy root-legs apart.
```

### Mother Moss

```
Redraw the character in the SECOND attached image as a new sprite in the agreed style: a hulking moss-and-root giant with a bearded bark face, glowing orange fungi, and a fist made of a huge stone die. About 80 art-pixels tall.
Pose for animation: facing LEFT; the stone-die fist on the front side, hanging at the end of a clear arm that does not overlap the chest; the bearded face clearly a separate head on the shoulders; root-legs apart.
```

### Foreman Grieve

```
Redraw the character in the SECOND attached image as a new sprite in the agreed style: a hunched stone-skinned mine foreman with pale crystal growths on his shoulders and fists, a rusty pickaxe in one hand and a hanging lantern with an orange flame in the other. About 76 art-pixels tall.
Pose for animation: facing LEFT; pickaxe arm on the front side, held down and out, handle not crossing the belly; lantern hanging from the back hand on a short handle, clear of the body; head clearly on the shoulders; feet apart.
```

### Archivist

```
Redraw the character in the SECOND attached image as a new sprite in the agreed style: a tall hooded spectral librarian in tattered grey robes with orange-lit edges, surrounded by floating open books and small glowing dice. About 88 art-pixels tall, including the trailing robe.
Pose for animation: facing LEFT; one open book floating in front of the raised front hand, separate from the robe; a stack of floating books on the back side, separate from the body; the hood clearly a separate head; the robe ending in 4 loose ghostly strips instead of feet.
```

### Bone Warden (boss)

```
Redraw the character in the SECOND attached image as a new sprite in the agreed style: a towering armoured skeleton knight with candles burning on his pauldrons, a skull-and-bone tower shield, and a flaming bone mace. About 94 art-pixels tall; he is the boss and the biggest figure.
Pose for animation: facing LEFT; tower shield on the front side, held at the body's front edge; mace arm on the back side, hanging down and away from the body, not crossing the chest; helmeted skull clearly on the shoulders; feet apart; tattered loincloth ending in 3 loose strips. No ground shadow.
```

### New enemies (no current design)

These four have no reference yet, so attach **only** `art/reference/plague_doctor.webp` and use
the prompt as written ("Draw", not "Redraw"). Save the base as `art/reference/<name>.png`:
`dummy`, `bone_rat`, `acolyte`, `grave_bell`.

#### Training Dummy (tutorial)

```
Draw a new sprite in the agreed style: a battered straw training dummy on a thick wooden post sunk into a small square stone base. Burlap sack head with a stitched X for each eye and a crooked stitched mouth, straw poking out of the seams; a cracked wooden practice sword lashed to one arm, a dented pot-lid shield tied to the other; two broken arrows stuck in its chest. Dull straw yellows and brown burlap, rope bindings, one small orange accent: a glowing ember stuck in a stitch. About 56 art-pixels tall.
Pose for animation: facing LEFT; the practice-sword arm on the front (left) side, sticking out sideways from the shoulder and angled down, clear of the chest; the pot-lid shield arm on the back side; the sack head clearly separate above a rope-tied neck; the post straight down into the stone base, no legs.
```

#### Bone Rat

```
Draw a new sprite in the agreed style: a rat skeleton the size of a small dog, grey-blue bones, a long bony tail, a cracked skull with long front teeth and a glowing orange eye socket, a few scraps of dark fur hanging off the spine. About 22 art-pixels tall and 36 long; it is small, three of them fight at once.
Pose for animation: facing LEFT, side view, low to the ground; skull at the front (left), clearly separate from the neck vertebrae, jaw slightly open; four thin legs apart, all feet on one baseline; the tail curving up and back behind it, clear of the body.
```

#### Shield Acolyte

```
Draw a new sprite in the agreed style: a hunched cultist in a heavy grey-brown hooded robe, face hidden in shadow except two small orange eyes, a few melted candles stuck to its shoulders. It hides behind a huge kite shield made of bone plates lashed with rope, with a rib-cage emblem; it holds a short curved ritual dagger. About 60 art-pixels tall.
Pose for animation: facing LEFT; the huge bone shield held on the front (left) side, covering the lower body but not the hood; the dagger arm on the back side, held low and away from the robe, blade down; the hood clearly a separate head; the robe hem ending in 3 loose strips above two visible feet.
```

#### Grave Bell

```
Draw a new sprite in the agreed style: a cracked bronze funeral bell hanging by a short rusty chain from a small gallows made of two thigh bones and a crossbeam, set in a pile of skulls. The clapper inside is a skeletal hand; an orange ghost-light glows from inside the bell mouth; green-black verdigris streaks on the bronze. About 56 art-pixels tall.
Pose for animation: facing LEFT (the gallows arm reaches out to the left); the bell hangs straight down below the crossbeam with clear empty space around it so it can swing; the skeletal-hand clapper hangs just out of the bell mouth; the chain is short and straight.
```

### Plague Doctor

The Plague Doctor already matches the style, so it only needs the layer edits. Use
`art/reference/plague_doctor.webp` as the base image.

## Layer prompt

Run once per layer, on the base image. Fill in `[LAYER]` and `[IN FRONT]` from the character's table:
`[IN FRONT]` lists the layers drawn after it, which hide parts of it.

```
Edit the base image. Keep ONLY [LAYER], in exactly the same position, size and pose. Draw it complete: wherever [IN FRONT] covered it in the base image, draw the hidden pixels so [LAYER] is whole, continuing its shapes, colours and shading. Give it its own closed 1-pixel outline. Turn every other pixel into the flat #FF00FF magenta background. Same canvas, same size.
```

The front-most layers have nothing in front of them: use `nothing` for `[IN FRONT]`.

## Layers per character, back to front

Enemies face left, so their near side (the front layers) is the left-hand side of the image.

**Deserter** (faces right; the sword arm is the near arm)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the cape` | `the shield arm, the legs, the body, the shield, the head and the sword arm` |
| 02 | `the shield arm, from the shoulder to the hand` | `the body, the shield and the sword arm` |
| 03 | `the legs, from the hips down` | `the body and the sword arm` |
| 04 | `the body: torso, belt and tunic, without arms or head` | `the shield, the head and the sword arm` |
| 05 | `the round shield` | `nothing` |
| 06 | `the helmeted head` | `nothing` |
| 07 | `the sword arm from the shoulder to the sword tip` | `nothing` |

**Skeleton** (faces left; the shield is on the near side)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the sword arm from the shoulder to the sword tip` | `the legs, the ribcage, the skull and the shield arm` |
| 02 | `the legs, from the pelvis down` | `the ribcage and the shield arm` |
| 03 | `the ribcage and spine, without arms or skull` | `the skull and the shield arm` |
| 04 | `the skull` | `nothing` |
| 05 | `the shield arm and the round shield` | `nothing` |

**Rotwood Treant** (faces left)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the back branch-arm` | `the root-legs, the trunk, the face-knot and the front branch-arm` |
| 02 | `the root-legs` | `the trunk and the front branch-arm` |
| 03 | `the trunk, without arms or the face-knot` | `the face-knot and the front branch-arm` |
| 04 | `the carved face-knot at the top` | `nothing` |
| 05 | `the front branch-arm` | `nothing` |

**Mother Moss** (faces left)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the back arm` | `the root-legs, the body, the bearded face and the stone-die fist arm` |
| 02 | `the root-legs` | `the body and the stone-die fist arm` |
| 03 | `the body, without arms or face` | `the bearded face and the stone-die fist arm` |
| 04 | `the bearded face` | `nothing` |
| 05 | `the front arm and stone-die fist` | `nothing` |

**Foreman Grieve** (faces left; pickaxe in the near hand, lantern in the far hand)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the lantern arm, the hanging lantern and its handle` | `the legs, the body, the head and the pickaxe arm` |
| 02 | `the legs` | `the body and the pickaxe arm` |
| 03 | `the body, without arms or head` | `the head and the pickaxe arm` |
| 04 | `the head` | `nothing` |
| 05 | `the pickaxe arm from the shoulder to the pickaxe head` | `nothing` |

**Archivist** (faces left)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the stack of floating books on the back side` | `the robe, the hooded head and the front arm with its open book` |
| 02 | `the robe and its trailing strips, without head or front arm` | `the hooded head and the front arm with its open book` |
| 03 | `the hooded head` | `nothing` |
| 04 | `the front arm, hand and the open book in front of it` | `nothing` |

**Bone Warden** (faces left; shield on the near side, mace on the far side)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the mace arm from the shoulder to the mace head` | `the legs, the body, the helmeted skull and the shield` |
| 02 | `the legs` | `the body and the shield` |
| 03 | `the body: armoured torso and loincloth, without arms or head` | `the helmeted skull and the shield` |
| 04 | `the helmeted skull` | `nothing` |
| 05 | `the shield arm and the tower shield` | `nothing` |

**Plague Doctor** (faces left; saw in the near hand, lantern in the far hand)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the lantern arm, the lantern and its chain` | `the legs, the coat, the beaked head and the saw arm` |
| 02 | `the legs` | `the coat and the saw arm` |
| 03 | `the coat and its tails, without arms or head` | `the beaked head and the saw arm` |
| 04 | `the beaked head` | `nothing` |
| 05 | `the saw arm from the shoulder to the saw tip` | `nothing` |

**Training Dummy** (faces left; the practice sword is on the near side)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the pot-lid shield arm` | `the post and stone base, the straw body, the sack head and the sword arm` |
| 02 | `the wooden post and the stone base` | `the straw body and the sword arm` |
| 03 | `the straw body with its arrows, without arms or head` | `the sack head and the sword arm` |
| 04 | `the sack head` | `nothing` |
| 05 | `the practice-sword arm, from the shoulder to the sword tip` | `nothing` |

**Bone Rat** (faces left)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the tail` | `the far legs, the body, the near legs and the skull` |
| 02 | `the two far legs` | `the body and the near legs` |
| 03 | `the body: spine, ribs and hips, without legs, tail or skull` | `the near legs and the skull` |
| 04 | `the two near legs` | `nothing` |
| 05 | `the skull and jaw` | `nothing` |

**Shield Acolyte** (faces left; the shield is on the near side)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the dagger arm from the shoulder to the dagger tip` | `the robe, the hooded head and the shield` |
| 02 | `the robe and its strips, with the feet, without arms or head` | `the hooded head and the shield` |
| 03 | `the hooded head` | `the shield` |
| 04 | `the shield arm and the bone kite shield` | `nothing` |

**Grave Bell** (faces left; the bell and clapper swing)

| # | `[LAYER]` | `[IN FRONT]` |
|---|---|---|
| 01 | `the bone gallows and the pile of skulls` | `the chain, the bell and the clapper` |
| 02 | `the chain` | `the bell` |
| 03 | `the bell, with the glow inside its mouth` | `the clapper` |
| 04 | `the skeletal-hand clapper` | `nothing` |

## Checks before using the layers

- **Rebuild:** stack every layer in order at 100%. The result must match the base image exactly, with
  no shifted part. If one is off, regenerate that layer.
- **Complete:** hide each front layer in turn. The layer behind must be whole where it was covered,
  with no gap or magenta hole.
- **Background:** pure #FF00FF and nothing else. Gemini sometimes leaves a soft halo; the cut-out
  handles flat magenta but not a halo.
- **Outline:** every layer has its own closed outline, including along the edge where it joins the
  next layer.
