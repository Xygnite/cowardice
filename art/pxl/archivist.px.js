// The archivist's frame-by-frame animations, built from its rig parts (archivist_parts.px.js) by lib.px.js's standard moves.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/archivist.px.js
include("archivist_parts.px.js")
include("lib.px.js")

// The rig smeared the sleeve's hole out to the floating debris; past the robe it is air.
claim(null, "body", [53, 22, 70, 36])
standard("archivist")
