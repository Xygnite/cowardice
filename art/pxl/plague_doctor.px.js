// The plague doctor's frame-by-frame animations, built from its rig parts (plague_doctor_parts.px.js) by lib.px.js's standard moves.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/plague_doctor.px.js
include("plague_doctor_parts.px.js")
include("lib.px.js")

// The coat at the waist, painted under the saw, so the cut took it.
RIG.under = [27, 46, `
..........bfh76
...ntpffbfh76bbb
n66ntpffbfbhh76bb7`]
standard("plague_doctor", {
  // Breathing with the chest or trailing the skirt opens 1 px gaps where they were cut out; bob and swing instead.
  idle: [[500, {}], [300, { t: [0, 1], l: 1 }], [500, { t: [0, 1], g: "dim" }], [300, { l: -1 }]],
})
