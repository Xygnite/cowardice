// The mother moss's frame-by-frame animations, built from its rig parts (mother_moss_parts.px.js) by lib.px.js's standard moves.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/mother_moss.px.js
include("mother_moss_parts.px.js")
include("lib.px.js")

RIG.head.still = true
standard("mother_moss", { lunge: 4 })
