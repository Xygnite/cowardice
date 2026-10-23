// The dummy's frame-by-frame animations, built from its rig parts (dummy_parts.px.js) by lib.px.js's standard moves.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/dummy.px.js
include("dummy_parts.px.js")
include("lib.px.js")

RIG.anchored = true  // the post and stone base stay put; the straw body only rocks on it
standard("dummy", { lunge: 2 })
