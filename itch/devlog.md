# Devlog #1: From a dice prototype to two floors in nine days

Cowardice started on October 21 as a single question: what if a dice game made you *react*, too? Rolling well should matter, but so should pressing SPACE at the right moment when a skeleton swings at you. Here is everything that went in up to this build.

## Day 1: Dice, a block and a parry

The first prototype had three dice and three places to put them: Attack, Guard, or a two-dice Cleave that splits damage across every enemy. When an enemy attacks, a bar runs across the screen and you press SPACE as it hits. A good block cuts the damage and a perfect one cancels it. Unblockable attacks can't be blocked at all, only parried in a tighter window.

The same day the game got its run loop: a floor map, a forge to raise your dice faces, campfires to heal, an end-of-run tally and a perk board to spend what you earn between runs.

## Days 2–3: Making it look like a game

Then came the art. Every character is pixel art, rigged and animated frame by frame: the hero, the Bone Warden and the whole cast of the Sunken Chapel. Skeletons, Shield Acolytes, a Plague Doctor, Grave Bells, a Rotwood Treant, Mother Moss, Foreman Grieve and the Archivist.

The dice moved into a 3D physics tray, so they tumble and bounce for real. Pixel fonts, a themed UI, a title screen and backgrounds followed, along with music for each screen and sound for every hit and click.

## Day 3: A map worth reading

The first floors were rows of buttons. Now every run deals a new branching map on old parchment, read left to right, and you can only walk along the lines. That makes the route a decision: past the forge, around the hard fight, or through the **"?"**.

"?" rooms are short events with a trade-off: a shrine, a pilgrim, an altar, a gambler, a cursed cast. Many of them ask you to roll your own dice, so the faces you forged pay off outside fights too. Some are ambushes.

This was also when the block and parry bar got faster, with the moment of impact landing somewhere different on every attack, so you can't just learn the rhythm.

## Day 4: Seven new perks and backgrounds that move

Seven new perks joined the board, each with its own badge: Lucky Charm, Iron Nerve, Grit Teeth, Hex Ward, Lantern Bearer and more. Sound got its own settings panel, and your volume is remembered between launches.

The backgrounds came alive: candle flames flicker, fog drifts across the floor and chains sway overhead.

## Day 4, continued: The Hollow Mine

Beating the Bone Warden no longer ends the run. Below the Chapel lies **the Hollow Mine**, where Foreman Grieve's dead crew still dig. It's a full second floor with five new enemies, each built around one twist you can read and plan for:

- **Tunnel Crawlers** hit harder for every other crawler still alive.
- The **Rubble Hulk** crumbles into Rubble when it dies, so a kill isn't the end of it.
- The **Canary Wraith** sings, making another enemy's attack unblockable.
- The **Shaft Foreman** rallies the crew, adding to everyone else's attacks.
- The **Lantern-Eye Miner** saves its strongest hit for an unblockable swing.

At the bottom waits the **Pit King**. His cave-ins **bury your dice** under rubble so you can't use them next turn, and in his second phase every attack brings the roof down.

Go straight down from the Warden and you pick a bonus perk for the rest of the run. Once you've reached the Mine, you can start a run there directly.

Every place in the game was then redrawn with real depth: the menu, camp, campfire, forge, the end-of-run screens, the Chapel, the Mine (lit only by its lanterns), and a scene of its own for every "?" event.

## Day 4, last bits: Real rolls and a campfire save

The dice now roll for real. The face that lands on top *is* the value you get, with no number picked behind the scenes. Fights got a pause menu, and you can **save at any campfire**, quit, and pick the run back up later.

## Days 5–8: Face marks (and an exe)

Day 5 brought a Windows export: one self-contained exe, nothing to install.

The forge used to do one thing: +2 on a face. Now, for the same 4 Shards, you can forge a **mark** onto a face instead:

- **Sharp**: in Attack, it cuts through enemy Guard and the Warden's Bone Wall
- **Ember**: placed anywhere, it heals 2 HP
- **Ward**: in Guard, it counts double
- **Shard**: placed anywhere, it pays a Shard

A marked face keeps its number. Campfires let you add one for free. A mark only works when that face is the one that comes up, so a run becomes a slow bet on your own dice. Load one die with Wards and it becomes your shield. Spread Embers around and you heal a little every turn. Marked faces show a colour and a small glyph, so you can read your dice at a glance.

## Day 9: Skills, a forge throw and new dice controls

**Cleave has company.** The Cleave slot became a **Skill** slot, and it fires every skill your dice make, all at once. Cleave is free. The rest you unlock for good with Embers at camp:

- **Sunder**: three matching dice, x2.5 their total to every enemy
- **Flurry**: three in a row like 2-3-4, three hits on the target
- **Cower**: three dice that are each a 1 or 2, and every enemy attack this turn misses you
- **Oath**: three odd dice hit, three even dice heal
- **Gambit**: a 1 and a 6, a flat 12 damage that pays a Shard if it kills

Dice that would complete a skill now glow, so you can see a combo coming before you place it.

**The forge is a throw.** Spend 4 Shards and throw a die at the anvil. A 1 gives +1, a 6 gives +4, and 2 to 5 give Sharp, Ember, Ward or Shard. Then you pick the face it goes on. Campfires give you one free throw.

**Dice feel better in the hand.** Rolling is a held wind-up: hold R or the Roll button, then let go to throw. Placing is quicker too: click a die to send it to the next slot, right-click to bring it back, hold to lock it. If you prefer, switch Dice control to Menu in Settings to use the old click-for-a-menu way.

## This build

- Two floors: the Sunken Chapel and the Hollow Mine
- 15 enemies and 2 bosses
- Branching maps with 9 "?" events, forges and campfires
- Timed block and parry
- 6 combo skills
- A forge throw for face marks: Sharp, Ember, Ward, Shard
- 10 perks to unlock between runs
- Campfire saves
- Windows, a single exe with nothing to install

## What's next

Relics: things you find during a run that make it snowball, so a good run *feels* like it's taking off. The design is written. Now it needs building.

Thanks for playing. If something breaks or a fight feels unfair, leave a comment. I read them all.
