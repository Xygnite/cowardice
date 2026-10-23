// The deserter's frame-by-frame animations, built from his rig parts (deserter_parts.px.js).
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/deserter.px.js
// lib.px.js pads every frame so the sword has room
// to rise behind his head and to land in front of him after the lunge.
include("deserter_parts.px.js")
include("lib.px.js")

const { smear, F, RED, opts } = kit()
const BLADE = { r: [36, 47], rest: Math.PI / 2 + 0.15 }  // the blade hangs ~0.15 rad off straight down

// Breathing: the torso sinks 1 px, the shield follows a beat later.
anim("deserter_idle", opts,
  F(500, {}),
  F(300, { t: [0, 1], s: [0, -1] }),
  F(500, { t: [0, 1] }),
  F(300, { s: [0, 1] }))

// Draw back, raise the blade over his back shoulder, chop through (smear), bite in, hold, recover.
anim("deserter_attack", { ...opts, loop: false },
  F(80, { x: -1, t: [0, 1], a: 0.4 }),
  F(120, { x: -2, t: [-1, 0], a: 2.3, behind: true, h: [-1, 0] }),
  F(60, { x: 4, t: [1, 0], a: 4.2 }, (c) => smear(c, { ...BLADE, from: 3.0, to: 4.2, dx: 5 })),
  F(80, { x: 7, t: [1, 1], a: 5.5, h: [1, 0] }, (c) => smear(c, { ...BLADE, from: 4.6, to: 5.5, dx: 8, dy: 1 })),
  F(120, { x: 7, t: [1, 1], a: 5.55, h: [1, 0] }),
  F(100, { x: 4, a: 6.0 }),
  F(80, { x: 1 }))

// Shield snaps up and out, he leans back behind it.
anim("deserter_block", { ...opts, loop: false },
  F(60, { x: -1, s: [2, -3] }),
  F(240, { x: -1, s: [3, -3], h: [-1, 0] }),
  F(100, { s: [1, -1] }))

// Knocked back with a red flash; head snaps back and the sword arm flops.
anim("deserter_hurt", { ...opts, loop: false },
  F(70, { x: -3, h: [-1, 1], a: -0.25, tint: RED }),
  F(130, { x: -3, t: [-1, 1], h: [-1, 1], a: -0.2 }),
  F(100, { x: -2, t: [0, 1], a: -0.1 }),
  F(100, { x: -1 }))

sheet("deserter_frames", ["deserter_idle", "deserter_attack", "deserter_block", "deserter_hurt"], { cols: 99 })
