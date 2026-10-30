# World scaling for five worlds, and shop polish

## Why

The owner watched the Mult showcase hit 2227 on a 220 HP Pit King and found the world too easy. The showcase was
staged (every face a 12, counters preset), so we simulated real runs to see where the curve actually breaks.

The owner plans **five worlds** for the full release, each ten columns long with its own boss gimmick. Enemy HP
must keep pace with the relic snowball across all five, so the boss of each world feels like a real fight for a
good build and a one-shot only for an exceptional one.

In the same pass, the Spoils shop gets a reroll, a clearer split between the offer and the belt, and larger,
more detailed relic art.

Success: a top-quarter build kills each world's boss in 2 to 4 turns; about one run in a hundred one-shots it.

## Goals

1. **A fixed HP curve by depth.** Enemy HP depends only on which world and column you are in, never on your build.
2. **World 2 (the Mine) retuned now** to the curve, which the current game can be measured against.
3. **Targets for worlds 3 to 5** written down now, for the content that will fill them to meet.
4. **Shop reroll**, a bigger "Your belt" heading, and evenly spaced belt slots in the shop.
5. **Large relic art** (32×32) for all 16 relics, shown on the shop's offer cards.
6. **Extra dice decided as a power source**: up to 5 dice, with drop chances set now. Its rules are designed later.

## Non-goals

- Endless mode. It extends this curve past world 5 and gets its own design next.
- The 4th and 5th die's tray, skill patterns and bury rules. They get their own design.
- New relics, enemies, bosses or worlds 3 to 5 themselves.
- Changing world 1 (the Sunken Chapel). It plays where the owner wants it.

## Anti-goals (a failure even if it works)

- **HP that reads your build.** Scaling enemies to your Mult would punish good picks. The curve is fixed.
- **Bosses that become slogs.** If a world's new power falls short, its HP must come down to match, not stay put.
  The simulation showed what happens otherwise: with today's content, world 3 to 5 bosses on a guessed curve took
  8 or more turns in 55 to 97% of runs.
- **Gimmicks stacked on full HP.** A boss whose gimmick blunts damage (like the Warden's Bone Wall) spends part of
  its HP budget on that gimmick.

## What the simulation found

A bot played 2,000 full runs on `Combat`'s real rules: it bought relics with the Shards it earned (best first by a
rough ranking, multipliers ordered to the right), forged at forges and some campfires, rerolled toward pairs and
skills, and placed dice for the most damage. "New" runs had Cleave only; "veteran" runs had every skill. It ignored
player HP, perks and event details, and took a random room per column. Read the numbers as the shape of the curve.

Damage per turn, veteran:

| | World 1 | World 2 | Worlds 3–5 (today's content) |
|---|---|---|---|
| Regular fights, median | 19–31 | 68–98 | 103–157 |
| Boss, top 25% | 52 | 116 | 126–135 |
| Boss, best 1% | 193 | 398 | 477–556 |

- World 1 is right as it is: the Warden takes 2 to 4 turns for most veteran runs.
- World 2 is where it broke: the Warden's rare shop lifts Mult to 4–5 while Mine HP rose only ~30%.
- From world 3, today's damage levels off: the 5-slot belt is full and nothing new is sold. Worlds 3 to 5 need new
  power, and the owner decided they get it (below).

## The curve

### Shape

Each world has a **world factor** that multiplies every enemy's HP there: regular fights, ambushes and the boss.
Within a world, the existing ramp stays (columns 5–8 at ×1.5 over columns 1–4). A world's enemy roster and boss
are written at a "base" HP comparable to the Mine's today; the factor carries the curve.

- *My call:* ambushes take the factor too; today they aren't scaled, which would make late ambushes trivial.
- *My call:* the factor follows the world's **place in the run**, not the floor. A run that starts in the Mine plays
  it as its first world, at ×1.0, as today: it arrives with no relics, so the Chapel run's ×1.8 would wall it.

| World | Factor | Boss HP (no defensive gimmick) | Boss damage/turn it is sized for (top 25%) | One-shot at (≈ best 1%) |
|---|---|---|---|---|
| 1 Sunken Chapel | 1.0 | 120 (the Warden, as now) | 52 | ~190 |
| 2 Hollow Mine | 1.8 | ~400 (Pit King, 220 × 1.8) | 116 | ~400 |
| 3 | 2.9 | ~640 | ~185 | ~640 |
| 4 | 4.6 | ~1,000 | ~300 | ~1,000 |
| 5 | 7.4 | ~1,650 | ~480 | ~1,650 |

- World 2's row is measured: with the Mine's fights and Pit King at ×1.8, a top-quarter veteran build kills the Pit
  King in about 3 turns, about 2% of runs one-shot him, and regular Mine fights take 2 to 3 turns.
- Worlds 3 to 5 grow about ×1.6 per world. That is a **target for each world's new content to meet**: whatever
  power a world adds (relics, the extra dice, anything else) must lift top-quarter boss damage about ×1.6 over the
  world before. If it lands short or long, the factor moves to match, not the other way round.
- **Boss gimmicks spend HP.** The table's boss HP is for a boss whose gimmick doesn't reduce your damage. A gimmick
  that does (Bone Wall, damage caps, shields, tampering with dice) counts against it: the printed HP comes down until
  the simulation shows the 2–4 turn target again.

### Where power comes from in worlds 3 to 5

The owner decided worlds 3 to 5 keep growing through new power, while each boss also leans on its gimmick. Known
sources so far:

- **Extra dice** (below), common enough that about half of full runs have a 4th die by the late worlds.
- New relics and whatever else each world brings, designed with that world.

### Checking it

The simulation bot is kept as `tools/balance_sim.gd`, so every world's factor, new relic or boss gimmick is checked
against the same targets: boss kill turns for top-quarter builds, one-shot rate, and regular fights at 2–3 turns for
a median build.

## Extra dice (decided now, designed later)

- A run can reach **5 dice** (today: 3).
- **Each world boss, except the last world's**, has a **15%** chance to give an extra die.
- **Each room** has a **0.4%** chance: the Spoils shop, a forge, a campfire, or a "?" room.
- Estimated across a full five-world run (about 45 rooms, 4 bosses that can give one): about half of runs get one
  from a boss, about 16% find one in a room, about 56% get at least one overall, and about 1 in 6 reach a fifth die.
  The owner chose this on purpose: extra dice are part of how the later worlds keep up, the room find stays a rare
  surprise (about 3.5% per world), and the 5th die is the real prize.
- How 4 and 5 dice work (tray size, skill patterns such as whether a 4th die can join Sunder, bury rules, the
  Pit Lantern's "every die in Attack") is its own design. This document only fixes the drop chances and the cap.

## Shop polish

The owner approved the mockup with the reroll above the belt (`shop_mock_c.png`, made in this session).

- **Reroll offer**: a button centred under the three cards, just above the belt, reading "Reroll offer  N".
  - It deals three fresh relics by the same rule as that shop: commons only in the first Spoils of a run, rares
    only in the Warden's hoard, the usual mix otherwise. Relics on the belt are never offered, as now.
  - Relics already bought this visit stay bought; the three cards are all replaced.
  - **Cost**: 2 Shards, then 1 more for each further reroll in the same visit; back to 2 at the next shop.
    *(My call; the owner didn't object.)*
  - Greyed out when you can't afford it, and when the pool has no fresh relics left to deal.
- **"Your belt"** becomes a heading in the gothic heading font at 32 px, so the offer and the belt read as two parts.
- **Even belt spacing in the shop**: every slot, filled or empty, is as wide as a Destroy button, so the dashed empty
  slots sit at the same spacing as the relics.

## Large relic art

- All 16 relics get a **32×32** version, drawn in pxl (extending `art/pxl/relics.px.js`): the same relic, idea and
  palette as the 16×16 icon, with more detail. At the game's pixel scale it is about the size of the shield in the
  shop's campfire backdrop. Each still reads without colour.
- **Shown on the shop's offer cards** (the Spoils and the Warden's hoard) in place of today's small icon.
- **Small icons stay** everywhere else: the fight belt, the "Your belt" row in the shop *(my call: the belt looks
  the same in the shop and the fight)*, tooltips and end-of-run screens.
- **Motion**: the large art gets the belt's gentle bob, no frame loop of its own. *(My call: 16 detailed 4-frame
  loops roughly quadruple the art; they can come later.)*

## Constraints

- Godot 4.7, GDScript, screens built in code; tests in `tests/test_combat.gd` and `tests/test_fight_flow.gd`, both
  passing.
- Combat rules stay in `scripts/combat.gd` and `scripts/floor.gd` with no UI.
- Run saves keep working: a run saved before this change loads and carries on; its remaining fights may use the new
  HP. The reroll count is per visit and isn't saved.
- Art in pxl only (`art/pxl/`), per the project's rule.

## Left to the builder

- Where the world factor lives (on `Floor.FLOORS`, or a table by world number) and whether it replaces the
  `hp` windows' numbers or multiplies them.
- How the reroll button looks beyond the mockup, and how its price shows when disabled.
- The large icons' exact framing on the card.
- Tests: the world factor on Mine fights and the Pit King, reroll cost and reset, reroll keeps the shop's rarity
  rule, belt slots evenly spaced, large icon on offer cards and small on the belt.

## Code touched

- `scripts/floor.gd`, `scripts/combat.gd`: the world factor; Pit King and Mine fights at ×1.8.
- `scripts/relic_pick_screen.gd`: reroll, heading, large icons on cards.
- `scripts/belt_row.gd`: even slot width when Destroy buttons show.
- `scripts/relic_icon.gd` (or a sibling): the large art.
- `art/pxl/relics.px.js`, `assets/ui/cut/`: the 32×32 relics.
- `tools/balance_sim.gd`: the simulation bot, kept.
- `tests/`: as above.
