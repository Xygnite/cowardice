# Reddit post for Cowardice v0.1.1

Video post: 00_throw_and_block.mp4 (9 s, with sound). The GIF is for subs that don't take video.
Gallery order: 01_relics_mult, 02_relic_pick, 03_chapel_fight, 04_bone_warden, 05_forge, 06_map.
Replace ITCH_LINK with the itch.io page URL before posting.

Posting notes:
- Lead with the video. Put the hook in the title and repeat it in the first line of the body.
- Reply to every comment in the first hour. Early comments push the post up.
- Check each sub's rules before posting. Some want the link in a comment, some want a flair or a title format.

---

## Titles

**r/roguelites** (Sunday or Monday)
- In my dice roguelite, three low dice make every enemy miss you. The move is called Cower.
- I made a dice roguelite where a bad roll can save you, but you still have to block every hit yourself
- Roll, place, parry: my dice roguelite makes you block the skeleton's swing in real time

**r/godot Screenshot Saturday / devlog subs**
- The dice in my roguelite roll in a real 3D tray, and the face that lands on top is the value you get

**Halloween (Saturday Oct 31: r/IndieGaming, Bluesky, X)**
- A dice roguelite set in a sunken chapel full of skeletons, just in time for Halloween. Free in the browser.

**r/WebGames** (check the sub's title format first)
- Cowardice: a dice roguelite where you roll, then block the enemy's swing yourself [browser, free]

---

## Body (main version, r/roguelites)

Three low dice usually cost you the turn. In Cowardice they make a **Cower**, and every enemy attack that turn misses. The game is named after that move.

**Play free in the browser (or grab the Windows exe):** ITCH_LINK

Each turn you throw three dice, reroll up to twice, and put each die in **Attack**, **Guard** or **Skill**. Pairs, triples and straights fire combos. Then the skeleton swings and you press SPACE on time: a good block cuts the damage, a perfect one cancels it, and a parry beats the attacks you can't block.

Version 0.1.1 adds 16 relics on a five-slot belt. Every hit deals base damage × Mult, and the relics grow the Mult, so a good belt snowballs. Mirror Shard copies the relic to its right, which makes belt order part of the build.

I'm making it solo in Godot. Which relic combo breaks it? I want to know before I balance the next floor.

---

## Short version (r/IndieGaming, r/WebGames)

Roll three dice, put each one in Attack, Guard or Skill, then block the enemy's swing with a timed press. Roll three low dice and you **Cower**: every attack that turn misses you. 16 relics, a forge where you throw a die at the anvil, two floors and two bosses. Free in the browser: ITCH_LINK

---

## Halloween version (Saturday)

You go down into a sunken chapel full of bone rats, shield acolytes and a Bone Warden, with three dice and 40 HP. You roll, place each die, then block every swing yourself with a timed press. Below the chapel a dead mining crew is still digging.

Free in the browser: ITCH_LINK

---

## Dev-angle version (r/godot, r/gamedev Screenshot Saturday)

The dice in Cowardice roll in a 3D physics tray, and the face that lands on top is the value. Early builds picked the number first and animated toward it. Now the physics decides. You hold R to wind up a throw and let go, and the dice tumble and bounce for real.

The characters are cut-out rigs. I split each sprite into head, body, legs, weapon and shield, then animate the parts in code, so idle, attack, block and hurt all come from one drawing per character.

Solo project in Godot 4.7. Play it in the browser: ITCH_LINK

Ask me anything about the tray or the rigs.

---

## GenAI disclosure (paste at the end of every version; r/IndieGaming requires it)

**AI disclosure:** I made this with a lot of AI help, and I want to be upfront about where.
- **Code:** written with Claude Code (an AI coding assistant). I designed the game, directed every feature and playtested it.
- **Art:** the characters, backdrops and relic icons are pixel art drawn with pxl, a tool that draws pixel art from code, and Claude wrote that code to my direction. Earlier versions of the characters and the reference images came from Gemini's image generator. Some UI pieces (buttons, panels, frames, the logo, map icons) came from ChatGPT/Gemini image generation and were then cut up and cleaned in-engine.
- **Audio:** music and sound effects were made in Strudel (a code-based music tool), with AI help writing the patterns.
- **Text:** the store page, devlogs and this post were drafted with Claude.
- **Fonts:** Alagard and m6x11, both made by people.
- The game itself doesn't use AI while you play.
