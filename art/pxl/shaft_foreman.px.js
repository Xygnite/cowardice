// The shaft foreman's frame-by-frame animations, built from its rig parts (shaft_foreman_parts.px.js) by lib.px.js's standard moves.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/shaft_foreman.px.js
include("shaft_foreman_parts.px.js")
include("lib.px.js")

// Pixels the rig patched into the whip arm's hole, smeared out into the air beside him.
claim(null, "body", [37, 24, 48, 42])
standard("shaft_foreman")
