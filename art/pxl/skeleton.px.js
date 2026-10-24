// The skeleton's frame-by-frame animations, built from its rig parts (skeleton_parts.px.js).
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/skeleton.px.js
// lib.px.js pads every frame: room for the arm raised over the skull and the lunge left.
// Its blow must land 0.2 s into the attack (STRIKE_DELAY in scripts/combat_screen.gd): the impact frame starts there.
include("skeleton_parts.px.js")
include("lib.px.js")

// The back thigh, hip (26, 32) to knee (31, 38): the blade was painted over it, so the cut took it.
RIG.under = [26, 32, `
0450
.0450
.04590
..0450
..02590
...0450`]
// The shield's bottom rim fell just outside the rig outline (the body keeps a copy of the top leg rows).
claim("shield", "legs", [7, 34, 12, 35])
claim("shield", "body", [7, 34, 12, 35])
const { smear, F, RED, opts } = kit()
const BLADE = { r: [24, 29], band: 2, rest: Math.atan2(27, -10) }  // shoulder to blade tip, hanging down-left

// Bones settle and rattle: the torso drops, the skull lands a beat later and clicks back.
anim("skeleton_idle", opts,
  F(400, {}),
  F(200, { t: [0, 1] }),
  F(400, { t: [0, 1], h: [0, 1] }),
  F(100, { t: [0, 1], h: [1, 1] }),
  F(300, { h: [0, 1] }))

// Hunch, swing the arm back and up behind the skull, hack over the top (smear), bite at 0.2 s, hold, pull back.
anim("skeleton_attack", { ...opts, loop: false },
  F(80, { x: -1, t: [0, 1], a: -0.6 }),
  F(80, { x: -1, t: [-1, 0], a: -3.0, behind: true, h: [-1, 0] }),
  F(40, { x: 3, a: -4.2, over: true }, (c) => smear(c, { ...BLADE, from: -3.2, to: -4.2, dx: 3 })),
  F(100, { x: 5, t: [1, 1], a: -5.2, h: [1, 1], over: true }, (c) => smear(c, { ...BLADE, from: -4.6, to: -5.2, dx: 5, dy: 1 })),
  F(100, { x: 5, t: [1, 1], a: -5.25, h: [1, 1], over: true }),
  F(100, { x: 2, a: -5.8, over: true }),
  F(60, { x: 1 }))

// Shield jerked up (not out: its flat-cut edge tucks behind the ribs), skull ducking behind it.
anim("skeleton_block", { ...opts, loop: false },
  F(60, { x: -1, s: [0, -2] }),
  F(240, { x: -1, t: [0, 1], s: [0, -4], h: [-1, 1] }),
  F(100, { s: [0, -1] }))

// Knocked back with a red flash; the skull snaps back and the sword arm flails.
anim("skeleton_hurt", { ...opts, loop: false },
  F(70, { x: -3, h: [-1, 1], a: -0.3, tint: RED }),
  F(130, { x: -3, t: [-1, 1], h: [-2, 1], a: -0.25 }),
  F(100, { x: -2, t: [0, 1], h: [-1, 0], a: -0.1 }),
  F(100, { x: -1 }))

sheet("skeleton_frames", ["skeleton_idle", "skeleton_attack", "skeleton_block", "skeleton_hurt"], { cols: 99 })
