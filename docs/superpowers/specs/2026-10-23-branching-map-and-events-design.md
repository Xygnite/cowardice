# Branching map and mystery rooms

## Why

A run used to be the same four rooms in the same order. The last change dealt a fresh ten-layer floor
each run with random enemy groups, but the map was still rows of buttons, and every room in the next
row was open to you. This change makes the map read as a real map and makes the route a decision:

- The floor becomes a branching map drawn on the parchment, going left to right, like a Slay the
  Spire–style node map but in Cowardice's own look (reference: the neon diamond grid the owner shared,
  used only for its structure, not its style).
- You can only walk along the lines, so you plan a route: towards the forge, around the hard fight,
  through the "?".
- "?" mystery rooms add short events, several of which roll your own dice, plus the odd ambush.

## Goals

- A map that looks drawn, not built from buttons, and fits one 1280x720 screen.
- Every run's floor is different in shape and content.
- Route choice matters: what you can reach depends on where you are.
- "?" rooms that feel like small stories with a trade-off, and dice rolls where the dice you forged pay off.

## Non-goals

- New enemies or enemy art. Fights are still random groups of the nine dungeon enemies.
- New art per event. Events reuse existing backdrops and icons; dedicated event art can come later.
- Balancing beyond the first numbers in this document. Tuning happens after playtesting.
- Changes to the tutorial, the boss fight, perks or the camp.

## Anti-goals (a failure even if it works)

- The map still looks like a menu: rectangles with text in them.
- A floor where some room can't reach the boss, or a route with no way forward.
- An event that kills you, or takes HP with no choice offered first.
- Lines that cross, so you can't tell where a path goes.

## The map

### Shape (decided)

- Ten columns, left to right. Column 0 is the entrance (one room), column 9 is the Bone Warden (one room).
- Up to five lanes (rows). Columns 1–8 hold between two and five rooms.
- Rooms are linked to rooms in the next column. You can only move along a link.
- Every room can be reached from the entrance and leads to the boss. Links never cross.

### How a floor is dealt (my call, owner approved the outline)

- Five walkers start at the entrance. Their first steps go to lanes 0, 1, 3, 4 and one random lane.
- At each column a walker steps up a lane, straight ahead, or down a lane, at random, but never in a way
  that crosses a link already drawn in that gap (a link from lane a to b+1 crosses one from b+1 to a).
- Every room a walker stands on becomes a room; every step becomes a link. From column 8 all walkers
  step into the boss.

### What each room holds (my call)

- Column 0: a fight, ENTRANCE_HP.
- Column 8, right before the boss: every room is a campfire.
- Columns 1–7: each room is rolled: fight 55%, "?" 20%, campfire 13%, forge 12%. Columns 1–2 roll
  only fight or "?". A forge never links to a forge, nor a campfire to a campfire; reroll if so. So
  column 7 never holds a campfire, since column 8 is all campfires (my call: intended).
- Fights are random enemy groups as now (`_group()` in game.gd): ENTRANCE_HP at column 0, EARLY_HP in
  columns 1–4, LATE_HP in columns 5–7. No group twice on a floor.
- The old guarantee of exactly two forges and two campfires goes away; different routes meet different rooms.

### How it looks (decided: the game's current style, not the reference's)

- The parchment (`assets/ui/cut/map.png`) fills the screen as now, with "The Sunken Chapel" title and
  the HP / Shards line above it.
- Rooms are the existing room icons (`room_fight`, `room_forge`, `room_campfire`, `room_unknown` for
  "?", `room_boss`), drawn at the pixel art's scale on the parchment, with no button frame or label.
- Links are dark ink lines in the pixel style, dashed for the road ahead.
- Walked rooms switch to `room_cleared`, and the links you took turn solid red-brown ink.
- The rooms you can pick next glow (gold), branches you passed by fade out, and rooms further ahead are dimmed.
- "The Warden's Lair" is lettered under the boss.
- Hovering a fight shows its enemies ("Skeleton, Bone Rats"); hovering a "?" shows nothing more.
- The mockup the owner approved: `.superpowers/brainstorm/1644-1792757756/content/map-branching.html`.

## Mystery rooms ("?")

When you step into a "?":

- One time in five it is an **ambush**: a fight against an EARLY_HP group, announced with a line
  ("Something moves in the dark."). Winning pays 4 bonus Shards on top of the usual kill Shards.
- Otherwise it is one of the events below, chosen at random, never the same one twice in a run.

Every event offers a way to walk away with nothing lost. No event takes you below 1 HP (my call).

### Trades

1. **Cracked shrine.** Lose 6 HP: one free forge upgrade (the campfire's "tend the dice" screen). Or leave.
2. **Drowned pilgrim.** Take their coin: +6 Shards. Or close their eyes: heal 5 HP.
3. **Weeping altar.** Give up 5 max HP for this run (current HP drops with it, not below 1): raise two
   die faces of your choice by FORGE_STEP. Or leave.
4. **Ember-lit niche.** A quiet alcove: +10 Embers, added to the end-of-run payout whether you win or flee. No catch.

### Dice events

These throw your own dice, with their forged faces, in the dice tray, the same 3D tray as in combat.
The result is read out once they land. A cursed face rolls 0 and counts as 0 here too (my call).

5. **Bone pile.** Dig: roll one die. 1–2: a Bone Rat bites, lose 4 HP. 3 and up: gain that many Shards.
   Or leave.
6. **Collapsing corridor.** Run for it: roll all three dice. A total of 10 or more gets you through
   unhurt; otherwise lose HP equal to the shortfall. Or brace: lose 4 HP. (There is no free way out here:
   it's the one event without a "leave", and its worst case is still capped at 1 HP.)
7. **Rusted chest.** Pick the lock: roll one die, up to two tries. 5 and up: it opens, one free forge
   upgrade. 1: a needle trap, lose 5 HP, and the event ends with the chest shut (my call: one trap at
   most). 2–4: nothing; try again or leave.
8. **Gambler's skull.** Bet 4 Shards (needs 4): you roll your three dice, the skull rolls three plain
   dice. Higher total wins 8 Shards back; a tie returns your bet; lower loses it. Or decline.
9. **Cursed die cast.** Carve a 9 onto one face of your choice; a random other face of that die becomes
   cursed (Combat.CURSE, counts as 0) for the rest of the run. Or leave.
   - Unlike the one-fight curses from Mother Moss and the Warden, this curse survives into later
     fights, and putting the die in Guard does not burn it off (owner's decision).
   - Forging that face clears it: any forge upgrade on it (paid at a forge, or free at a campfire or
     event) sets the face back to the value it had before the curse, instead of adding FORGE_STEP (my call).
   - So the curse lives in the die's `base` faces, and the forge screen shows the cursed face as
     cursed (the `die_cursed` art) so the player can see it can be cleared.

## Constraints

- Godot 4.7, GDScript, screens built in code (see `scripts/ui.gd`), 1280x720 canvas.
- Run state lives in `Combat` (HP, Shards, dice); between-run state in `Meta` (Embers). The Ember-lit
  niche needs a run-level Ember bonus that `_end_run` in game.gd adds to the payout.
- The dev shortcut `--fight=N`, the tutorial and the boss fight keep working.
- Tests: `tests/test_combat.gd` (headless rules) and `tests/test_fight_flow.gd` (real screens).
  Dealt floors must be checked: reachability, no crossing links, column 8 all campfires, ranges by
  column, no repeated groups. Each event's outcomes need a rules check, including the 1 HP floor.

## Left to the builder

- How the map is drawn in Godot (custom `_draw`, Line2D, TextureButtons for rooms), as long as rooms
  stay clickable and hover-able and it looks like the mockup.
- The event screen: extend NoticeScreen or a new screen; where the dice tray sits on it. DiceTray has
  no "landed" signal today; add one or wait it out.
- Where event logic lives (a new `events.gd` is the obvious place) and how the "no repeat" set is kept.
- Wording of the event text, in the game's voice (terse, grim, a little dry).
- If a floor can't find enough distinct enemy groups for its fights, allow a repeat rather than loop forever.
