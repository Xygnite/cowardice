// The miner's frame-by-frame animations, built from its rig parts (miner_parts.px.js) by lib.px.js's standard moves.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/miner.px.js
include("miner_parts.px.js")
include("lib.px.js")

// Pixels the rig patched into the far arm's hole, smeared out into the air beside him.
claim(null, "body", [33, 24, 42, 38])
standard("miner")
