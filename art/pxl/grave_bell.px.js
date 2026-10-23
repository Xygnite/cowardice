// The grave bell's frame-by-frame animations, built from its rig parts (grave_bell_parts.px.js).
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/grave_bell.px.js
// Only the bell moves, swinging from the top of its chain; the gallows never does. Its toll must land
// 0.2 s into the attack (STRIKE_DELAY in scripts/combat_screen.gd): the impact frame starts there.
include("grave_bell_parts.px.js")
include("lib.px.js")

const [back, out] = RIG.weapon.swing
standard("grave_bell", {
  // A slow pendulum.
  idle: [[400, { a: 0.06 }], [400, {}], [400, { a: -0.06 }], [400, {}]],
  // Drawn back, flung out (smear), tolls at 0.2 s and shudders, swings back through.
  attack: [
    [80, { a: back * 0.4 }],
    [80, { a: back }],
    [40, { a: (back + out) / 2 }, { from: back, to: (back + out) / 2 }],
    [60, { a: out, g: "flare" }, { from: (back + out) / 2, to: out }],
    [60, { a: out - 0.08 }],
    [60, { a: out }],
    [100, { a: back * 0.4 }],
    [80, { a: 0.1 }],
  ],
  // Struck: it jolts aside with a red flash and rocks back.
  hurt: [[70, { a: -0.3, tint: "red" }], [130, { a: -0.2 }], [100, { a: 0.12 }], [100, { a: -0.04 }]],
})
