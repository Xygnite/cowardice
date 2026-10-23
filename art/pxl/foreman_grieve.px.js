// The foreman grieve's frame-by-frame animations, built from its rig parts (foreman_grieve_parts.px.js) by lib.px.js's standard moves.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/foreman_grieve.px.js
include("foreman_grieve_parts.px.js")
include("lib.px.js")

// The apron at the waist, painted under the pick's handle, so the cut took it (the dark cloth of row 51).
RIG.under = [24, 52, `
0111111111111111h
0111111111111111h
0111111111111111h
0111111111111111h
0111111111111111h
0111111111111111h
0111111111111111h`]
standard("foreman_grieve")
