# The Hollow Mine: a second floor

## Why

Every run ends at the Bone Warden in the same chapel. A second floor with its own place, cast and boss
adds the most replay value: a deeper goal for strong runs, and a new set of fights. Below the Sunken
Chapel's crypts lies the Hollow Mine, where Foreman Grieve's dead crew still dig, ruled by the Pit King.

## Goals

- A second floor, **The Hollow Mine**, with its own background, five new enemies and a boss, the **Pit King**.
- Two ways in: straight down after beating the Warden (with a bonus perk for that run), or directly from a
  floor selector at camp once the Mine is unlocked.
- Every new character and the Mine background are drawn and animated with pxl, in the game's existing
  look (dark, cold palette, warm lantern accents, chunky pixels).
- Each new enemy has one clear twist the player can read and plan around.

## Non-goals

- The Gambler and the Monk: they are reserved as future unlockable heroes and appear nowhere here.
- New music (the Mine reuses the dungeon and boss tracks), new events, new perks (other than the bonus
  perk pick reusing existing perks), new hero art.
- Changes to the Sunken Chapel floor, its enemies, the tutorial or the hero.

## Anti-goals (a failure even if it works)

- The Mine looks pasted in: characters or background off the game's palette, pixel size or lighting.
- A Mine enemy whose twist can't be read from its intent and the fight log.
- A burying boss that leaves the player with no legal move (every die buried and nothing to do).
- A run state that breaks across the floor change: HP, Shards, forged faces, curses or perks lost or doubled.

## The run (decided)

- **Straight through:** beating the Warden no longer ends the run. A campfire stop follows (my call), then
  the Mine's floor is dealt and played to the Pit King. HP, Shards, dice (forged faces and lasting curses),
  equipped perks and seen events all carry over.
- **Bonus perk (decided: granted only on the straight-through route):** after the Warden, the player picks
  one of three perks (my call: drawn at random from all perks, owned or not, excluding the two equipped).
  It is active for the rest of that run only, on top of the equipped two.
- **Floor selector (decided):** once the Mine is unlocked (my call: by beating the Warden once), camp gets a
  floor choice before Start run: Sunken Chapel or Hollow Mine. Starting in the Mine never grants the bonus perk.
- **Run results (my call):** the end-of-run screen shows the floor reached and rooms cleared across both
  floors; Embers count rooms on both floors, and beating the Pit King pays more than the Warden (my call:
  +100 instead of +50). Boss damage % counts the boss of the floor the run ended on.

## The Mine floor (my calls)

- Same map rules as the Chapel (`Floor.deal`: ten columns, branching, "?" rooms, forges, campfires before
  the boss), titled "The Hollow Mine", with the Pit King's room labelled "The Pit King's Throne".
- Fights are random groups drawn only from the Mine's five enemies, sized by total HP like the Chapel but
  harder (my call: entrance 30–40, early 34–50, late 56–72).
- Events and ambushes work as on the Chapel floor; ambushes draw Mine enemies.

## The cast (decided outline; numbers are my first guesses, to tune in play)

Every enemy uses the existing intent kinds (attack, guard, unblockable, curse, ring) unless noted.

- **Lantern-Eye Miner** (~22 HP): a dead digger whose lantern is his eye. Pattern: attack, attack, then a
  lantern flare that makes his next attack unblockable (an "unblockable" intent every third turn).
- **Tunnel Crawler** (~8 HP): a blind, pale grub; comes in groups of 2–3. **New rule:** each other living
  Crawler adds +1 to its attacks; the intent shows the boosted number.
- **Rubble Hulk** (~30 HP): loose stone holding together; mostly guards, with a slow heavy attack.
  **New rule:** when it dies it leaves a **Rubble** (~8 HP, small attack) in its place, once.
- **Canary Wraith** (~12 HP): the ghost of a mine canary; its shriek is a "ring" (the Grave Bell's rule:
  another enemy's attack this turn becomes unblockable).
- **Shaft Foreman** (~26 HP): a whip-cracking overseer. **New rule:** while he lives, every other enemy's
  attack is +2; he attacks for little himself.
- **The Pit King** (boss, ~110 HP): a crowned mass of fused miners and ore. **New intent "cave-in":**
  stones fall and **bury** one of your dice for the next turn. A buried die keeps its value, can't be
  rerolled, unlocked or moved to another slot, and shows in a buried look. Phase 2 (at half HP): a
  cave-in every turn alongside an attack. A cave-in never buries your last unburied die.

## Settled after review (my calls)

- **Names:** the Shaft Foreman is a new enemy (key `shaft_foreman`), separate from Foreman Grieve, and
  drawn clearly different (an overseer with a whip and ledger, not a miner with a pick and lantern).
- **Attack bonuses:** the Foreman's +2 and each Crawler's +1 per other living Crawler add together, apply
  only to attack and unblockable values (not guards, curses or rings), are recomputed every turn from who
  is alive, and the intent shows the final number.
- **Buried dice:** a cave-in, during the enemy phase, buries one random unburied die. On the next turn that
  die is not rerolled: it keeps its value and its slot from the turn it was buried (a placed die acts
  again with the same value; an unplaced one stays out of play and gives no Grit), and it can't be
  rerolled, locked, unlocked or moved. It is free again the turn after. Phase 2 buries one die per turn;
  a cave-in never buries the last unburied die. The tray shows a buried die with rubble over it.
- **Rubble:** when a Rubble Hulk dies, a Rubble takes its place at the same position at once, with no
  intent until the next turn. Each counts as a kill; the fight goes on while the Rubble lives.
- **Crawler groups:** "comes in groups" is a tendency, not forced: the group dealer may pick Crawlers more
  than once like any enemy. Mine HP windows are set so groups always exist: entrance 24–36, early 34–50,
  late 56–72.
- **Bookkeeping:** rooms cleared add up across both floors; the stop after the Warden is a plain campfire
  (standard heal or a free upgrade) and is not counted as a room; the Mine's last column before the boss
  is all campfires like the Chapel's. A run that dies in the Mine still earns Embers for both floors.
  The victory screen shows only after the Pit King; boss damage % is against the boss of the floor the run
  ended on.
- **Bonus perk:** it may be one the player hasn't bought (that's the reward). Gained mid-run, it applies
  once: Thick Skin raises max HP and current HP by 10, the others just switch on.
- **Unlock:** the Mine unlocks by beating the Warden (which only a Chapel-start run can do).
- **Art delivery:** like the existing cast: pxl sources in `art/pxl/`, frame sheets as
  `assets/sprites/<name>_frames.png` + `.json`, scenes via `tools/frames_scene.gd`; colours sampled from
  the existing sprites and backdrops.

## Art (decided: pxl for everything)

- The five enemies, the Rubble and the Pit King are drawn with pxl directly as frame animations: idle,
  attack (impact at 0.2 s, for `STRIKE_DELAY`), block where they have a shield-like guard, and hurt,
  matching the existing `*_frames` scenes so `combat_screen.gd` plays them unchanged. Sizes match the
  Chapel cast's scale (normal enemies about as tall as the Skeleton; the Pit King about the Warden's size).
- The Mine fight background (`bg_mine`, 1024x572, same pixel size as the fight backdrop): timber
  supports, rails, hanging lanterns, dripping water, a floor ledge the fighters stand on. It gets
  BackdropLife: flickering lanterns, drifting dust in place of fog, swaying lantern chains.
- A buried-die look for the dice tray, and room art for the Mine map if the Chapel's doesn't fit.

## Constraints

- Godot 4.7, GDScript, screens built in code; tests `tests/test_combat.gd` and `tests/test_fight_flow.gd`
  (every new enemy and the boss must play through a real fight with no engine errors).
- Enemy types live in `Combat.TYPES`; fights are random groups (`Floor.group`); the fight backdrop is
  chosen in `combat_screen.gd` (today always "fight") and its floor ledge is `FLOOR_LEDGE`.
- pxl lives in `.claude/skills/pxl-pixel-art`; character frame sheets go through `tools/frames_scene.gd`
  into `scenes/<name>_frames.tscn` as the existing cast's do.
- Meta must save the Mine unlock; old saves load with it locked.

## Left to the builder

- Exact HP and attack numbers within the guesses above, and enemy patterns' order.
- How the floor is passed through Floor/game/map (a floor id, a per-floor table), the backdrop per floor,
  and the floor ledge per backdrop.
- How the floor selector looks at camp, and how the bonus perk choice screen looks (reusing the notice or
  perk card style).
- Whether the Mine map reuses the Chapel's room icons.
