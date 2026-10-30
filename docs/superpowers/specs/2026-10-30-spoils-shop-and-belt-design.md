# Spoils shop and a belt you arrange

## Why

The relics design ([2026-10-29-relics-snowball-design.md](2026-10-29-relics-snowball-design.md)) gave the run a
snowball, but the owner played it and found the screens around it hard to read and the choices thin:

- **Spoils is a free pick.** Taking a relic costs nothing, so there is no real choice, and skipping pays +3 Shards.
- **Belt order is invisible.** Mult sums every add and then multiplies, so order matters only for the Mirror
  Shard. The "<" button that reorders the belt doesn't say what it is for.
- **The damage is a single number.** The player never sees how the dice and relics built the hit.

The owner wants this to feel like Balatro: relics cost money, you sell one to afford or make room for another,
you arrange them by dragging, their order changes the score, and the count plays out step by step so you watch
your build work.

Success: a player who has never seen the game buys a relic, drags it into a better spot, and on End turn can see
from the count why the new order hit harder.

## Goals

1. **Spoils is a shop.** Relics cost Shards, you can buy as many as you can afford and fit, you can destroy any
   belt relic for some Shards back, and leaving pays nothing.
2. **Mult builds left to right.** Each relic changes the running Mult in belt order, so arranging the belt is
   a real decision.
3. **The belt sits along the top of the dice tray** and can be dragged into a new order during your turn.
4. **End turn counts the hit step by step**, Hit and Mult ticking up, with the damage landing last.

## Non-goals

- Rerolling the shop's offer.
- Selling relics outside the Spoils shop (in a fight, on the map, at events).
- New relics, or changing what an existing relic does beyond the Mult order.
- A game-speed setting for the count.

## Anti-goals (a failure even if it works)

- **A count that becomes a chore.** If watching it on turn 30 is boring, it failed. It must be quick, and
  skippable.
- **Dragging that fights the dice.** A drag must never start a throw, pick up a die, or land while dice are
  rolling or the turn is resolving.
- **A preview that lies.** The damage shown before End turn must equal what the count ends on.
- **A shop that strands you.** The player can always leave; buying never blocks the way out.

## What the owner decided

### Spoils shop

- Every relic card shows a price in Shards. Buy is greyed out when you can't afford it or the belt is full.
- You can buy several relics in one visit.
- **Destroy** is on every belt relic, always, not only when the belt is full. It pays Shards back.
- **Leave** pays nothing. The +3 Shards for skipping is gone (`SKIP_SHARDS`).
- **No free picks anywhere.** The Warden's hoard becomes a shop too (rares only, priced). The Mine start loses its
  "Into the Mine" pick entirely, since you start with 0 Shards.
- **The first Spoils of a run offers only commons**, since a rare isn't affordable yet.
- The "<" button goes. The belt is reordered by dragging, here as in the fight.

### Mult

- Mult starts at 1 each turn. Each belt relic, left to right, applies its effect to the running Mult: an add
  adds, a multiplier multiplies. `×1.5` after `+1` is worth more than before it. This replaces "adds summed
  first, then multipliers" in `Combat.mult()` and in the relics spec.
- The Mirror Shard keeps copying the relic to its right, and acts at its own position in the order.

### Fight layout

- The belt moves out of its column beside the tray into a row along the **top edge of the dice tray**, right of
  the Faces and Skills buttons, 5 slots with empty ones drawn dashed. The tray takes the column's old width.
- The summary line above the tray (today "Damage 26 (×2.5) Guard 3 Grit +1") becomes the counter:
  **Hit × Mult = Damage**, then Guard and Grit as now.
  Later: the counter sits big on the tray's top edge, Faces, Skills, Guard and Grit above the tray, and the Damage
  reads "?" until End turn's count lands on it. Before End turn, Hit and Mult show the dice and skills alone (Mult 1);
  the count adds every relic's part.
- While the block/parry hint and timing bar are up across the top of the tray, the belt fades out.
- The tray's top wall moves down by an icon's height so thrown dice never come to rest under the belt.

The owner approved the "Proposed" mockup in `.superpowers/brainstorm/1560-1793322381/content/fight-layout-fit.html`.
The counting mockup is `fight-belt-counting.html` in the same folder.

### Relic animations

Relics should feel alive, on the belt in a fight and in the shop. Two layers:

- **Shared motion, every relic:** a gentle hover or sway at rest (each slot offset in phase, so the row
  doesn't bob in lockstep), a lift and slight tilt while dragged, and a bounce and shake when it fires in the count.
- **Each relic's own loop:** a few frames per relic of the thing it depicts moving: the Pit Lantern's flame
  flickers, the Black Candle drips, the Hungry Bell swings, the censer smokes, the whetstone sparks, and so on
  for all 16. Drawn in pxl, extending `art/pxl/relics.px.js`, at the icons' 16x16 size and palette.

## My calls (the owner can overrule these)

- **Relic loops:** 4 frames each at about 6 fps, exported as a horizontal strip per relic beside the existing
  still icon, which stays for places that don't animate (tooltips, end-of-run screens). Each loop is quiet
  enough to read the shape at rest; the relic's "fire" in the count is the shared bounce, not a separate loop.

- **Prices:** common 4 Shards, rare 8. For scale: a kill pays 2, a forge throw costs 4.
- **Destroy pays half the price:** 2 for a common, 4 for a rare. This replaces `BREAK_SHARDS`.
- **Taking onto a full belt** no longer has its own flow: destroy one first, then buy.
- **Each purchase and each destroy asks to confirm** with the existing `ConfirmPanel`, like every action on this
  screen does today. Leave asks too, since it now forfeits the offer for nothing.
- **"First Spoils of a run"** means the Spoils after the first fight of the run, whichever floor the run started on.
- **The count, in order:**
  1. Each Attack die pops in turn and adds its value to Hit. Relics that change a die (Cursed Crown, Whetstone)
     pop with it and show their part.
  2. Enemy Guard and Bone Wall take their part off Hit, shown as a minus.
  3. Miner's Ledger and Ward Icon add to Hit.
  4. Each skill that fires adds its hit to Hit, in `fired()` order.
  5. Each relic, left to right, pops and changes Mult. Relics with no Mult effect this turn stay dim.
  6. Damage appears, then the hits land on the enemies as now.

  Hit on the counter is the sum of all of this turn's hits; each hit is still multiplied and rounded down on its
  own, so Damage is the sum of the rounded hits and not always `floor(Hit × Mult)`.
- **Pace:** about 0.3 s a step, and each step after the first a little quicker, so a long count stays short.
  A click, Space or Enter during the count jumps to the end.
- **When you can drag in a fight:** during your turn when nothing is rolling and nothing is resolving, and not
  during the enemy phase. Dropping reorders through `Combat.move_relic`, so Mirror counters reset as they do now.
- **Drag look:** the relic lifts and follows the cursor, and the others slide apart to show where it will land.
- The old belt column and the per-icon gold value labels move with the belt into the row.
- **Mult shows two decimals** (×1.95, not ×2.0), since left-to-right order makes such values common.
- **Whether the first Spoils has happened is saved** with the run (`SAVED_LATER` or worked out from run state),
  so quitting and continuing doesn't bring rares into it.
- **A bought relic lands at the right end of the belt.** That can change what a Mirror Shard copies, and its
  counters reset as they already do.
- **Cleave and other skills hitting several enemies** add their hits to Hit as one total for that skill.
- **A turn that deals no damage skips the count.**
- **The belt row is hidden in the tutorial**, and shown with dashed empty slots everywhere else, even with no relics.
- **No dragging while a turn's opening throw waits** in the hand.
- **The skip press is consumed**, so a Space or click meant to skip the count never reaches block or parry.

## Left to the builder

- How the counter is drawn and animated, within the layout above.
- Exact tray wall offsets.
- Tests: Mult order, shop buy and destroy, first-Spoils commons, preview equal to the count's result, and
  updating the existing tests that expect free picks, `SKIP_SHARDS` or the Mine start's pick.

## Code touched

- `scripts/relic_pick_screen.gd`: becomes the shop.
- `scripts/combat.gd`: `mult()` left to right; `take_relic` and the `BREAK_SHARDS` path become buy and destroy
  with prices.
- `scripts/combat_screen.gd`: belt row on the tray, dragging, counter, belt fade during block/parry.
- `scripts/game.gd`: Mine start without the pick; first-Spoils commons; hoard as a shop.
- `art/pxl/relics.px.js` and `assets/ui/cut/`: the per-relic animation strips.
- `tests/`: as above.
