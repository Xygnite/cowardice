// Face-mark glyphs (Combat.MARKS): white and light grey under a dark rim, so the dice tray and Forge can tint
// them with UI.MARK_COLORS and the rim keeps them readable on bone and on the dark dice.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/marks.px.js, then copy
// out/sprites/mark_*.png into assets/ui/cut/ at 2x (nearest-neighbour), like the rest of the cut art.

pal({ k: "#1a1412", w: "#ffffff", s: "#b8b8b8" })

// A blade, point up.
sprite("mark_sharp", { mx: true, outline: "k" }, `
  ..w
  .sw
  .sw
  www
  ..s`)

// A flame, leaning left.
sprite("mark_ember", { outline: "k" }, `
  ..w..
  .ww..
  .wsw.
  wsssw
  .www.`)

// A shield.
sprite("mark_ward", { mx: true, outline: "k" }, `
  www
  wss
  wss
  .ws
  ..w`)

// A crystal.
sprite("mark_shard", { mx: true, outline: "k" }, `
  ..w
  .ws
  wss
  .ws
  ..w`)
