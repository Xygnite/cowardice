# Relics: a run that snowballs

## Why

A run feels flat after a while, and winning pays almost nothing you can feel. Today a run grows in small flat
steps: the forge adds +2 to a face or puts a mark on it, perks are picked at camp before the run starts, and
skills have fixed multipliers. No upgrade makes another one stronger, so a good run ends only a little stronger
than it began. The Pit King falls the same way the Warden did.

The owner returns to Balatro again and again because its build **snowballs**. Jokers found during a run
multiply each other until a hand scores far beyond anything early on, and that build came from your own picks.
This design brings that to Cowardice: **Relics**, run-only items that hook into the dice and combine with one
another, plus a **Mult** on every hit so they can multiply instead of just adding up.

Success: by the second boss of a good run, a single turn hits for several times what floor one allowed, and
the player can say which three relics did it.

## Goals

- **Mult.** Every damage number the player deals is `base × Mult`. Mult starts at ×1 each turn. Relics raise it.
  The damage preview shows both parts ("14 × 2.5 = 35") so the player sees the build working.
- **Relics.** Run-only items held on a **Relic belt** of 5 slots beside the dice tray. Each one triggers on
  something the dice already do: pairs, runs, marks, curses, Guard, Grit, rerolls, kills, Shards.
- **Some relics grow during the run** ("+0.1 Mult per kill this run"). These are what makes the snowball.
- **The end of a run shows the build.** The victory and defeat screens show the belt, the final Mult, and the
  run's biggest single hit.

## Non-goals

- Changing the camp board, perks, skills or Embers. Those stay as they are for now. Relics are found only
  during a run.
- Unlocking relics with Embers or by doing specific things ("win with X"). That's a likely follow-up, and the
  design shouldn't block it.
- New floors, enemies, events or heroes. The Gambler and the Monk stay reserved.
- An endless mode.

## Anti-goals (a failure even if it works)

- **Relics that only add.** A belt of "+2 damage" relics fails the point. At least a third of the set must
  raise Mult or grow during the run.
- **A belt you can't read.** If the player can't tell why a hit was big, the snowball doesn't feel earned.
  Every relic that fires on a turn flashes, and its share shows in the preview breakdown on hover.
- **Bosses that are a formality for any build, or a wall for an average one.** A strong build should overkill
  (that's the fun). A run with a weak or unlucky belt should still be winnable with good dice play.
- **Losing the run state.** Relics, their growth counters and Mult rules must survive the run save and the
  floor change, like HP, Shards and forged faces.

## How it works (my calls)

### Mult and damage

- Mult is per turn. It starts at ×1, relics add to it (`+0.5 Mult`) or multiply it (`×1.5 Mult`). Adds are
  summed first, then multipliers apply, left to right on the belt, as in Balatro.
- Mult applies to everything the player deals: Attack to the target, every skill's damage (Cleave, Sunder,
  Flurry, Oath, Gambit), and relic damage. It applies after enemy Guard and Bone Wall are taken off, so Guard
  still matters. It never applies to healing, Guard or Shards.
- **A hit** is one damage line against one enemy: the Attack dice's total is one hit, and each skill that fires
  is one hit. Flurry stays one hit (its "three hits" is flavour). Mult applies to each hit, and each hit is
  rounded down after Mult.
- Existing skill multipliers (Cleave ×1.5, Sunder ×2.5) stay part of the skill's base, not Mult.

### Getting relics

- **After every won fight:** pick one of three relics, or skip for +3 Shards.
- **Rares** come three ways: any fight pick may show one (about 1 in 6 cards); beating the Warden gives a pick
  of three rares, alongside the existing bonus perk pick on the straight-through route; a run that starts in
  the Mine opens with a pick of three rares, so it isn't short of them. The Pit King ends the run, so it gives
  no pick.
- A pick never offers a relic already on the belt.
- **Belt full:** taking a new relic means breaking one on the belt, for +2 Shards.
- The tutorial gives no relics and has no Mult.
- Belt order matters only for ×Mult relics and Mirror Shard. The player can drag relics to reorder them
  between fights.

### The first set (16; names, numbers and art to tune)

Commons:

| Relic | Effect | Kind |
|---|---|---|
| Whetstone | Attack dice showing 5 or 6 deal +3 each | flat |
| Twin Saints | When Cleave or Sunder fires, +1 Mult | mult |
| Rusted Censer | +0.5 Mult for each Ember-marked face placed this turn | mult |
| Clenched Jaw | +0.1 Mult per point of Grit this turn | mult |
| Tithe Box | After each fight, +1 Shard for every 5 Shards you hold (max +3) | economy |
| Gravedigger's Tally | +0.1 Mult for every kill since you took it | grows |
| Miner's Ledger | +1 to the Attack hit for every 4 Shards spent at forges since you took it | grows |
| Spare Fuse | Each unused reroll at end of turn adds +0.25 Mult to this fight's later turns | grows (fight) |
| Ward Icon | Guard left over after the enemy phase is added to next turn's Attack hit (lost when the fight ends) | rule |

Rares (boss picks):

| Relic | Effect | Kind |
|---|---|---|
| Hungry Bell | +1 Mult each turn a skill fires, kept while you keep firing one; resets on a turn with none and at the end of each fight | grows (fight) |
| Cursed Crown | Cursed faces count as 6 for damage instead of 0 (they still break skill patterns) | rule |
| Gilded Pip | +0.5 Mult for each placed die showing a face above 6 (forged or carved) | mult |
| Rosary of Steps | Flurry's +3 becomes +9 | rule |
| Black Candle | ×1.5 Mult | ×mult |
| Pit Lantern | ×2 Mult on a turn where every placed die is in Attack | ×mult |
| Mirror Shard | Copies the relic to its right | rule |

- **Growing relics** count from when you take them, keep their own counters, and save them with the run.
- **Mirror Shard** acts as a second copy of its neighbour with its own counter, applied at Mirror's place on
  the belt. Economy relics copied pay twice. It can't copy another Mirror Shard (it does nothing then).

### Screens

- **Fight screen:** the belt sits beside the dice tray with small relic icons. Hover shows the name and text.
  The damage preview gains a Mult line. A relic that fires this turn flashes as the hit lands, and a growing
  relic shows its current value on its icon.
- **Relic pick:** after a fight, a screen like the bonus-perk pick (three cards and a skip button).
- **Run end:** belt, final Mult, biggest hit, then the Embers as now.

### Balance (first guesses, to tune in play)

- Average belts should reach about ×2 to ×3 Mult by the Warden and ×4 to ×6 by the Pit King. Lucky ones go higher.
- Enemy HP in the late columns and bosses goes up to match: Warden about 120, Pit King about 220, and each
  enemy in a late-column fight gets about 1.5× its HP. Groups are still dealt from the unchanged HP windows,
  then scaled, so late fights stay varied. Ambushes aren't scaled. These are starting numbers for a playtest,
  not targets.
- Embers stay as they are.

## Constraints

- Godot 4.7, GDScript, screens built in code; tests in `tests/test_combat.gd` and `tests/test_fight_flow.gd`.
  Both suites must pass, and a full fight with a full belt must play with no engine errors.
- Combat rules stay in `scripts/combat.gd` with no UI. Relic data lives beside `SKILLS` and `MARKS` as a const
  table there, or in its own rules script.
- Damage goes through `damage_to`, `skill_share`, `resolve_player` and the preview. All of them must use the
  same Mult, so the preview never disagrees with the hit.
- The run save (`Combat.SAVED`, `RunSave`) keeps the belt, its order and every growth counter. An old run save
  loads with an empty belt.
- Relic icons are drawn in pxl (`art/pxl/`), in the game's palette and pixel size, with a glyph that reads
  without colour, as the marks do.
- The dice count stays at 3. No relic adds a die. That would change the tray, every skill pattern and the bury
  rules, so it belongs in its own design.

## Left to the builder

- Exact numbers and rarity weights.
- How the belt and the relic pick look, within the screens above.
- Where relic hooks sit in the code (one hook per event, or a single pass at resolve).
- How the relic flash and the preview breakdown animate.
