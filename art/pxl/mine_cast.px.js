// Rubble: what is left of a Rubble Hulk, drawn to match its sprite (art/reference/hulk.webp via tools/make_sprites.gd),
// in the Hulk's own colours from the shared palette. The rest of the Hollow Mine cast comes from art/reference/.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/mine_cast.px.js --out <scratch>
// then copy <scratch>/sprites/rubble.png to assets/sprites/, rig it (tools/rig_sprites.gd) and animate it (art/pxl/rubble.px.js).
// Enemies face left, toward the hero.
pal({
  k: "#000016",                                          // outline
  1: "#1d202c", 2: "#242933", 3: "#333f49", 4: "#485a60", 5: "#50646a", 6: "#748787",  // wet slate, dark to lit
  b: "#1e1a1c", B: "#3a3735",                            // shadowed slag
  r: "#7a4228", R: "#ad6b44", o: "#ea9650",              // ember: deep, glow, hot
  u: "#5b3f2f",                                          // rust
  g: "#3d5442",                                          // damp moss
})
ramps("k123456", "kbB", "kruRo")

// A flat slate slab like the Hulk's: its own dark rim, dark body, mid face, lit top edge.
// `tilt` skews its top and bottom edges so stacked slabs don't line up.
function slab(c, x0, y0, x1, y1, tilt = 0, [dark, mid, lit] = ["3", "4", "6"]) {
  const p = [x0, y0 + Math.max(0, tilt), x1, y0 + Math.max(0, -tilt), x1, y1 - Math.max(0, tilt), x0, y1 - Math.max(0, -tilt)]
  c.poly(p, dark)
  c.poly([p[0], p[1], p[2], p[3], x1, Math.round((y0 + y1) / 2), x0, Math.round((y0 + y1) / 2)], mid)
  c.line(p[0], p[1], p[2], p[3], lit)
  c.line(p[4], p[5], p[6], p[7], "k")
}

sprite("_rubble", { w: 30, h: 24, outline: "k" }, (c) => {
  // Ember light under the heap, showing through every gap.
  c.poly([6, 22, 28, 22, 27, 9, 12, 7], "r"); c.poly([10, 20, 25, 20, 24, 11, 14, 10], "R")
  // The heap: bottom slabs, then the leaning ones, the head slab with its seam of eyes on top.
  slab(c, 7, 18, 18, 23, 1, ["2", "3", "5"])
  slab(c, 17, 17, 29, 23, -1, ["2", "3", "4"])
  slab(c, 19, 10, 27, 17, 1, ["2", "4", "5"])
  slab(c, 9, 12, 19, 18, -1)
  slab(c, 12, 4, 22, 11, 1, ["3", "4", "6"])
  c.hline(13, 8, 8, "k"); c.px(14, 8, "o"); c.px(15, 8, "o"); c.px(18, 8, "o"); c.px(16, 8, "R")
  // Ember in the cracks between slabs, rust on a bolt, moss on the top edges.
  c.px(18, 15, "o"); c.px(18, 16, "R"); c.px(16, 18, "o"); c.px(22, 17, "R"); c.px(23, 17, "o"); c.px(12, 11, "R")
  c.px(25, 12, "u"); c.px(26, 13, "u"); c.px(26, 12, "6")
  c.hline(14, 4, 4, "g"); c.hline(21, 10, 3, "g"); c.px(10, 12, "g")
  // The rusted cable that bound the Hulk's chest, now slack across the heap.
  c.line(9, 14, 17, 19, "u"); c.line(17, 19, 27, 14, "u"); c.line(20, 11, 24, 18, "u"); c.px(17, 19, "R")
  // The loose stone it shoves forward like a fist (the rig's weapon).
  slab(c, 1, 11, 9, 18, 1, ["3", "4", "6"])
  c.px(3, 15, "R"); c.px(4, 15, "o"); c.line(5, 12, 7, 16, "2")
  // Rough slate, pitted like the Hulk's: darker pits on the faces, lighter grit on the lit edges.
  c.noise(0, 0, 30, 24, "3", 0.18, 7, "4"); c.noise(0, 0, 30, 24, "2", 0.15, 8, "3"); c.noise(0, 0, 30, 24, "5", 0.25, 9, "6")
})

// Set on its sprite canvas with 2 empty pixels all round (the outline already grew it by 1 on every side).
sprite("rubble", { w: 36, h: 30 }, stamp("_rubble", 2, 2))
