// The Hollow Mine's cast as still sprites, in the game's shared palette (assets/palette.png). Each one is saved
// straight to assets/sprites/<name>.png, then rigged (tools/rig_sprites.gd) and animated (art/pxl/<name>.px.js).
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/mine_cast.px.js --out <scratch>
// then copy <scratch>/sprites/<name>.png to assets/sprites/. Enemies face left, toward the hero.
pal({
  k: "#0e0613",                                     // outline
  1: "#1d202c", 2: "#2a303a", 3: "#333f4c", 4: "#3f4f56", 5: "#4a5e64",  // cold stone, cloth, dead skin
  6: "#56676a", 7: "#627a7c", 8: "#758d8c", 9: "#88a2a0", w: "#c9c5a8",
  b: "#2b2a23", B: "#412e26", d: "#4b4239", D: "#664835", e: "#655a50",  // leather, wood, earth
  E: "#7c7367", t: "#9a7b5f", T: "#ab977a",
  r: "#975131", o: "#e69652",                       // rust, lamp fire
  g: "#3a5240", G: "#4c544b", h: "#67695b",         // damp moss
})
ramps("k123456789w", "kbBDtTw", "kdeE")

// A faceted stone with its own dark rim (so stacked stones read apart): dark body, lit top-left facet.
// `seed` turns its corners so no two stones match.
function rock(c, cx, cy, rx, ry, [dark, mid, lit] = ["3", "5", "7"], seed = 0) {
  const n = 7, pts = []
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + seed, j = 0.82 + 0.18 * Math.abs(Math.sin(i * 12.9898 + seed * 78.233))
    pts.push([Math.cos(a) * rx * j, Math.sin(a) * ry * j])
  }
  const at = (k, dx = 0, dy = 0, grow = 0) =>
    pts.flatMap(([x, y]) => [Math.round(cx + dx + x * k + Math.sign(x) * grow), Math.round(cy + dy + y * k + Math.sign(y) * grow)])
  c.poly(at(1, 0, 0, 1), "k")
  c.poly(at(1), dark)
  c.poly(at(0.7, -rx * 0.15, -ry * 0.2), mid)
  c.poly(at(0.3, -rx * 0.35, -ry * 0.4), lit)
}

// A limb or haft with a dark rim, so it reads in front of a body of the same colour.
function oline(c, x0, y0, x1, y1, col, w = 1) {
  c.line(x0, y0, x1, y1, "k", w + 2)
  c.line(x0, y0, x1, y1, col, w)
}

// Lantern-Eye Miner: a dead miner, skull under a cracked helmet, two lamp-fire eyes, pick hanging from his far hand.
sprite("_miner", { w: 42, h: 48, outline: "k" }, (c) => {
  // Legs and boots.
  c.rect(14, 35, 4, 9, "B"); c.vline(17, 35, 9, "b"); c.vline(14, 36, 6, "d")
  c.rect(22, 35, 4, 9, "B"); c.vline(25, 35, 9, "b"); c.px(23, 39, "D"); c.px(23, 40, "D")
  c.rect(10, 43, 8, 3, "2"); c.hline(11, 43, 5, "4"); c.px(10, 45, "1")
  c.rect(20, 43, 7, 3, "1"); c.hline(21, 43, 4, "3")
  // Far arm behind the body.
  c.line(27, 17, 30, 25, "2", 3); c.line(30, 25, 32, 30, "1", 3)
  // Torso: torn work shirt, suspenders, ribs showing through the rip, belt, ragged hem.
  c.poly([12, 16, 28, 16, 27, 35, 13, 35], "3")
  c.poly([21, 16, 28, 16, 27, 35, 23, 35], "2")
  c.poly([12, 16, 16, 16, 15, 33, 13, 33], "4"); c.line(13, 17, 13, 26, "5")
  c.vline(16, 17, 16, "D"); c.vline(24, 17, 16, "B")
  c.poly([18, 20, 22, 19, 23, 27, 18, 28], "k")
  for (let y = 21; y <= 26; y += 2) c.hline(19, y, 3, "8")
  c.px(19, 21, "9"); c.px(19, 23, "9")
  c.line(25, 20, 26, 28, "1"); c.line(14, 28, 16, 31, "2")
  c.rect(13, 33, 15, 2, "b"); c.rect(17, 33, 2, 2, "E"); c.px(17, 34, "e")
  c.px(13, 35, "3"); c.px(20, 35, "2"); c.px(26, 35, "2")
  // Near arm hanging toward the hero, bony claw.
  c.line(13, 17, 10, 25, "4", 3); c.line(12, 18, 10, 23, "5"); c.line(10, 25, 9, 30, "3", 2)
  c.rect(7, 31, 3, 3, "8"); c.px(7, 34, "7"); c.px(9, 34, "7"); c.px(6, 32, "9"); c.px(9, 31, "7")
  // Hard hat dome (the skull covers its lower half), then neck and skull.
  c.ellipse(19, 7, 7, 5, "B"); c.ellipse(18, 5, 5, 3, "D"); c.ellipse(17, 4, 2, 1, "t")
  c.rect(18, 14, 4, 3, "6"); c.px(18, 15, "4")
  c.ellipse(19, 11, 5, 4, "7"); c.ellipse(18, 10, 3, 2, "8"); c.px(17, 9, "9"); c.px(18, 9, "9")
  c.vline(23, 10, 4, "5"); c.vline(24, 11, 2, "4")
  c.rect(15, 13, 7, 3, "6"); c.hline(15, 14, 7, "k"); for (let x = 15; x < 22; x += 2) c.px(x, 14, "w")
  c.rect(14, 10, 3, 2, "k"); c.rect(19, 10, 3, 2, "k"); c.px(17, 12, "k")
  c.px(15, 10, "o"); c.px(16, 10, "o"); c.px(19, 10, "o"); c.px(20, 10, "o"); c.px(15, 11, "r"); c.px(20, 11, "r")
  // Brim and the dead lamp at the front.
  c.hline(11, 8, 17, "b"); c.hline(13, 7, 13, "B"); c.hline(10, 8, 1, "b")
  c.rect(9, 4, 3, 3, "4"); c.px(9, 5, "1"); c.px(10, 4, "8"); c.px(11, 6, "2")
  // The pick: haft down to the curved head by his back foot.
  c.line(32, 29, 36, 41, "B"); c.line(33, 29, 37, 41, "t"); c.px(34, 34, "D")
  c.line(30, 45, 33, 43, "5", 2); c.line(33, 43, 37, 42, "6", 2); c.line(37, 42, 41, 40, "5", 2)
  c.line(31, 44, 37, 41, "8"); c.px(40, 40, "8"); c.px(35, 43, "r"); c.px(34, 43, "r")
  c.rect(31, 28, 3, 3, "7"); c.px(31, 30, "6"); c.px(32, 28, "8")
})


// Tunnel Crawler: a pale, blind grub, segmented, tail curled up, a ring of mandibles out toward the hero.
sprite("_crawler", { w: 40, h: 22, outline: "k" }, (c) => {
  const segs = [[36, 6, 2], [34, 10, 3], [30, 13, 4], [24, 14, 5], [17, 14, 5]]
  for (const [x, y, r] of segs) {
    c.circ(x, y, r + 1, "k"); c.circ(x, y, r, "t"); c.circ(x - 1, y - 1, r - 1, "T"); c.ellipse(x - 1, y - r + 2, Math.max(1, r - 3), 0, "w")
    c.hline(x - r + 1, y + r - 1, 2 * r - 1, "E")
  }
  for (const x of [13, 17, 21, 25, 29]) { c.vline(x, 19, 2, "e"); c.px(x - 1, 20, "e") }
  c.px(21, 12, "E"); c.px(27, 11, "E"); c.px(15, 16, "E")
  // Head: smooth and eyeless, the mouth a dark round hole ringed with mandibles.
  c.circ(9, 14, 6, "k"); c.circ(9, 14, 5, "t"); c.circ(9, 13, 4, "T"); c.ellipse(9, 10, 2, 1, "w")
  c.rect(3, 13, 3, 4, "k"); c.px(4, 14, "B"); c.px(4, 15, "r")
  c.line(1, 11, 5, 12, "t", 2); c.px(0, 12, "w"); c.px(1, 13, "T")
  c.line(1, 18, 5, 17, "t", 2); c.px(0, 17, "w"); c.px(1, 16, "T")
  c.px(6, 19, "e"); c.px(9, 19, "e"); c.px(12, 12, "E")
})

// Rubble: what is left of a Hulk, a heap of stones still trying to stand, two embers in the cracks.
sprite("_rubble", { w: 30, h: 24, outline: "k" }, (c) => {
  rock(c, 20, 18, 8, 4, ["2", "4", "6"], 1)
  rock(c, 11, 19, 6, 3, ["3", "5", "7"], 2)
  rock(c, 22, 11, 5, 4, ["3", "5", "7"], 3)
  rock(c, 15, 10, 6, 5, ["3", "6", "8"], 4)
  c.px(12, 11, "o"); c.px(15, 11, "o"); c.px(12, 12, "r"); c.px(15, 12, "r")
  c.px(20, 15, "r"); c.px(17, 16, "r")
  // A loose stone it shoves forward like a fist.
  rock(c, 5, 14, 4, 3, ["3", "5", "8"], 5)
  c.px(25, 8, "g"); c.hline(13, 5, 3, "G"); c.px(14, 4, "g")
})

// Rubble Hulk: loose stone holding itself together. Flat slabs stacked into broad shoulders, a slab head with a
// glowing seam for eyes, ember light in the gaps, and a long arm ending in a block of a fist.
sprite("_hulk", { w: 46, h: 54, outline: "k" }, (c) => {
  // A slab: a skewed four-sided stone with its own dark rim, dark face, lit top edge and upper-left facet.
  const slab = (x0, y0, x1, y1, [dark, mid, lit] = ["3", "5", "7"], s = 1) => {
    const p = [x0 + s, y0, x1, y0 + s, x1 - s, y1, x0, y1 - s]
    c.poly([p[0], p[1] - 1, p[2] + 1, p[3], p[4], p[5] + 1, p[6] - 1, p[7]], "k")
    c.poly(p, dark)
    c.poly([x0 + s, y0, x1 - 1, y0 + s, x1 - 2, Math.round((y0 + y1) / 2), x0 + 1, Math.round((y0 + y1) / 2) - s], mid)
    c.line(x0 + s, y0, x1 - 1, y0 + s, lit)
  }
  // Far arm, hanging behind.
  slab(32, 11, 42, 20, ["2", "3", "5"]); slab(35, 20, 43, 30, ["2", "3", "4"], 2); slab(35, 30, 44, 38, ["2", "4", "5"])
  // Legs: two short pillars.
  slab(12, 40, 21, 47, ["2", "4", "6"]); slab(10, 46, 21, 53, ["2", "4", "6"], 2)
  slab(25, 40, 33, 47, ["2", "3", "5"]); slab(25, 46, 35, 53, ["2", "3", "5"], 2)
  // Hips, belly and the wide chest slab, ember light showing in the gaps.
  slab(12, 33, 34, 41, ["2", "4", "5"], 2)
  slab(13, 25, 33, 34, ["3", "4", "6"])
  slab(9, 14, 37, 26, ["3", "5", "7"], 2)
  c.hline(15, 25, 16, "k"); for (const x of [16, 19, 24, 28]) c.px(x, 25, "r"); c.px(21, 25, "o"); c.px(26, 25, "o")
  c.hline(15, 33, 16, "k"); c.px(18, 33, "r"); c.px(23, 33, "o"); c.px(29, 33, "r")
  c.line(22, 15, 20, 24, "k"); c.px(21, 19, "r"); c.px(21, 20, "o")
  // Far shoulder slab, mossy.
  slab(29, 10, 41, 17, ["3", "5", "7"], 2); c.hline(31, 10, 6, "G"); c.px(33, 9, "g")
  // Head: a squat slab sunk between the shoulders, a seam of fire for eyes.
  slab(15, 4, 28, 14, ["3", "6", "8"], 1)
  c.hline(15, 9, 12, "k"); c.px(16, 9, "o"); c.px(17, 9, "o"); c.px(21, 9, "o"); c.px(22, 9, "r"); c.px(19, 9, "r")
  c.hline(17, 4, 6, "G"); c.px(19, 3, "g")
  // Near arm: shoulder slab, forearm and the block fist it slams with.
  slab(3, 11, 15, 20, ["3", "5", "7"], 2); c.hline(5, 11, 5, "G"); c.px(6, 10, "g")
  slab(3, 20, 11, 31, ["3", "5", "6"], 2)
  slab(0, 31, 13, 43, ["3", "5", "8"], 2)
  c.line(1, 37, 11, 37, "k"); c.px(5, 37, "r"); c.line(6, 32, 6, 36, "2")
})

// Canary Wraith: the mine's dead canary come back as a cold spectral shape, a little canary yellow left on its
// crest and breast, beak open, tail fraying into mist.
// Its tail, unoutlined so it frays into the dark: three wisps thinning out to nothing (stamped under the bird).
sprite("_canary_mist", { w: 32, h: 38 }, (c) => {
  c.poly([16, 22, 27, 21, 28, 27, 30, 32, 31, 37, 26, 33, 21, 30, 17, 27], "4")
  c.poly([18, 22, 26, 22, 27, 27, 28, 31, 24, 28, 20, 26], "5")
  c.line(21, 23, 26, 28, "6"); c.line(26, 28, 28, 32, "5")
  c.dither(16, 25, 7, 6, "3", ".", 0.5); c.dither(27, 32, 5, 6, "3", ".", 0.6)
  c.px(31, 37, "3"); c.px(25, 34, "3"); c.px(19, 30, "3")
})
sprite("_canary", { w: 32, h: 38, outline: "2" }, (c) => {
  // Body: spectral teal, a little canary yellow left on the breast.
  c.ellipse(17, 18, 8, 7, "5"); c.ellipse(16, 17, 7, 6, "6"); c.ellipse(14, 19, 4, 3, "7"); c.ellipse(13, 18, 2, 1, "8")
  c.px(12, 21, "t"); c.px(13, 22, "t"); c.px(11, 20, "T"); c.px(12, 20, "t")
  c.dither(20, 19, 6, 6, "4", ".", 0.5)
  // Wing, half raised, its tips frayed.
  c.poly([14, 14, 27, 9, 26, 15, 22, 21, 15, 20], "4")
  c.line(17, 15, 26, 10, "7"); c.line(18, 17, 25, 13, "5"); c.line(19, 19, 24, 16, "5"); c.px(26, 10, "8")
  c.px(28, 8, "6"); c.px(28, 12, "5")
  // Head, a yellow crest, the open beak, the eye an empty hole with a spark.
  c.circ(10, 10, 6, "2"); c.circ(10, 10, 5, "6"); c.circ(9, 9, 4, "7"); c.ellipse(8, 7, 2, 1, "8"); c.px(7, 6, "9")
  c.px(13, 13, "5"); c.px(14, 12, "5")
  c.poly([1, 9, 5, 8, 5, 10], "o"); c.poly([2, 12, 5, 11, 5, 12], "r"); c.px(1, 10, "k"); c.px(2, 10, "k"); c.px(3, 10, "k")
  c.rect(7, 8, 3, 3, "k"); c.px(8, 9, "o")
  c.hline(10, 4, 4, "T"); c.px(11, 3, "T"); c.px(13, 3, "t"); c.px(12, 2, "t")
})

// Shaft Foreman: a gaunt overseer in a bowler and frock coat, the ledger in one hand, a coiled whip in the other.
sprite("_shaft_foreman", { w: 46, h: 60, outline: "k" }, (c) => {
  // Legs and boots.
  c.rect(17, 48, 4, 8, "1"); c.rect(25, 48, 4, 8, "1"); c.vline(18, 48, 7, "3"); c.vline(26, 48, 7, "2")
  c.rect(14, 55, 7, 3, "k"); c.hline(15, 55, 4, "3"); c.rect(24, 55, 6, 3, "k"); c.hline(25, 55, 3, "2")
  // Far arm with the whip: handle, the coiled lash, its tail on the ground.
  oline(c, 31, 21, 35, 30, "1", 3); oline(c, 35, 30, 36, 36, "1", 2)
  c.ellipse(38, 44, 5, 4, "B", true); c.ellipse(37, 45, 4, 3, "D", true); c.ellipse(39, 43, 3, 3, "B", true)
  c.line(36, 36, 37, 41, "b", 2); c.px(36, 37, "D")
  c.line(42, 47, 41, 52, "D"); c.line(41, 52, 43, 56, "B"); c.line(43, 56, 39, 57, "B"); c.px(38, 57, "t")
  c.rect(35, 35, 3, 3, "7"); c.px(35, 37, "6")
  // Frock coat, open over a waistcoat with a watch chain.
  c.poly([13, 20, 31, 20, 33, 49, 26, 50, 22, 44, 18, 50, 11, 49], "2")
  c.poly([13, 20, 18, 20, 16, 48, 11, 49], "3"); c.line(13, 22, 12, 46, "4")
  c.poly([26, 20, 31, 20, 33, 49, 28, 49], "1")
  c.line(22, 44, 22, 49, "k"); c.line(15, 38, 16, 47, "2"); c.line(29, 30, 30, 46, "k")
  c.poly([18, 21, 25, 21, 24, 38, 19, 38], "D"); c.poly([22, 21, 25, 21, 24, 38, 22, 38], "B")
  c.line(19, 30, 22, 32, "t"); c.px(19, 29, "T")
  c.line(18, 21, 20, 32, "k"); c.line(25, 21, 23, 32, "k")
  c.px(21, 24, "t"); c.px(21, 28, "t"); c.px(21, 35, "t")
  // Collar, cravat, neck.
  c.rect(19, 18, 6, 3, "w"); c.rect(21, 19, 2, 3, "B")
  // Long dead face: sunken cheek, hollow eyes with pale points, grey side-whiskers.
  c.rect(17, 10, 8, 9, "7"); c.rect(18, 10, 4, 5, "8"); c.vline(24, 10, 8, "5"); c.vline(23, 14, 3, "6")
  c.px(16, 13, "7"); c.px(16, 14, "8"); c.px(17, 18, "6")
  c.rect(17, 12, 2, 2, "k"); c.rect(21, 12, 2, 2, "k"); c.px(17, 12, "9"); c.px(21, 12, "9"); c.hline(17, 11, 6, "5")
  c.hline(17, 17, 4, "k"); c.px(20, 16, "5"); c.px(19, 15, "6")
  c.vline(24, 14, 4, "E"); c.vline(25, 13, 4, "e"); c.px(24, 18, "e")
  // Bowler hat.
  c.ellipse(21, 6, 6, 4, "1"); c.ellipse(20, 5, 4, 2, "3"); c.px(18, 4, "4"); c.hline(13, 9, 16, "1"); c.hline(15, 8, 12, "B")
  // Near arm holding the open ledger out in front.
  oline(c, 14, 21, 11, 28, "3", 3); oline(c, 11, 28, 10, 32, "2", 3)
  c.rect(2, 25, 12, 12, "B"); c.rect(3, 26, 10, 10, "D"); c.vline(8, 25, 12, "B")
  c.rect(3, 26, 5, 9, "w"); c.rect(9, 26, 4, 9, "T")
  for (let y = 27; y < 35; y += 2) { c.hline(4, y, 3, "E"); c.hline(10, y, 2, "t") }
  c.px(5, 33, "r"); c.px(6, 33, "r")
  c.rect(9, 33, 3, 3, "7"); c.px(9, 35, "6")
})

// The Pit King: a mound of miners fused with ore and stone, crowned with pick heads, one great arm and its pick.
sprite("_pit_king", { w: 92, h: 92, outline: "k" }, (c) => {
  // The mound: earth and stone, buried miners breaking out of it.
  c.ellipse(42, 73, 38, 17, "k"); c.ellipse(42, 73, 37, 16, "B"); c.ellipse(40, 70, 33, 12, "d"); c.ellipse(32, 66, 19, 6, "e")
  c.noise(6, 58, 80, 30, "b", 0.05, 3, "d"); c.noise(6, 58, 80, 30, "B", 0.06, 4, "e")
  c.rect(0, 88, 92, 4, "_")
  rock(c, 14, 79, 8, 6, ["2", "4", "6"], 1); rock(c, 70, 79, 7, 6, ["2", "4", "6"], 2); rock(c, 50, 83, 9, 4, ["2", "3", "5"], 3)
  rock(c, 30, 84, 6, 3, ["2", "3", "5"], 4)
  // Ore: pale crystal clusters and rusty seams.
  for (const [x, y] of [[26, 74], [58, 71], [42, 81], [66, 61]]) {
    c.poly([x - 1, y + 1, x + 2, y - 6, x + 7, y + 1], "k")
    c.poly([x, y, x + 2, y - 5, x + 4, y], "9"); c.line(x + 1, y - 1, x + 2, y - 4, "w"); c.poly([x + 3, y, x + 5, y - 3, x + 6, y], "8")
  }
  c.line(30, 64, 38, 68, "r"); c.line(56, 76, 62, 78, "r"); c.px(34, 66, "o"); c.px(59, 77, "o")
  // Buried and fused miners: a hard hat, a skull with ember eyes, a reaching hand each.
  const miner = (x, y, flip) => {
    c.ellipse(x, y, 5, 4, "k"); c.ellipse(x, y, 4, 3, "B"); c.ellipse(x - 1, y - 1, 2, 1, "D"); c.hline(x - 5, y + 2, 10, "b"); c.px(x - 4 * flip, y, "9")
    c.rect(x - 4, y + 3, 8, 5, "k"); c.rect(x - 3, y + 3, 6, 4, "7"); c.rect(x - 2, y + 4, 2, 1, "k"); c.rect(x + 1, y + 4, 2, 1, "k")
    c.px(x - 2, y + 4, "o"); c.px(x + 1, y + 4, "o"); c.hline(x - 2, y + 6, 4, "k")
    oline(c, x + 6 * flip, y + 4, x + 9 * flip, y - 1, "6", 2); c.px(x + 10 * flip, y - 2, "8"); c.px(x + 9 * flip, y - 3, "8")
  }
  miner(22, 62, -1); miner(60, 66, 1); miner(36, 76, 1)
  // Hunched body of fused stone and flesh.
  c.ellipse(44, 42, 25, 18, "k"); c.ellipse(44, 42, 24, 17, "3"); c.ellipse(42, 39, 20, 13, "4"); c.ellipse(36, 34, 10, 6, "5")
  c.noise(22, 26, 46, 32, "3", 0.05, 5, "4"); c.noise(22, 26, 46, 32, "2", 0.05, 6, "3")
  c.line(28, 50, 40, 44, "2"); c.line(48, 30, 56, 46, "2"); c.line(56, 46, 62, 50, "2"); c.line(26, 36, 30, 46, "2")
  for (const [x, y] of [[31, 30], [33, 33]]) { c.hline(x, y, 7, "8"); c.hline(x + 1, y + 1, 5, "2") }  // fused ribs
  c.line(52, 34, 58, 38, "r"); c.px(55, 36, "o"); c.px(56, 37, "o")
  miner(54, 46, 1); miner(36, 48, -1)
  // Near arm: a thick knot of arms reaching down to a claw on the ground.
  oline(c, 24, 38, 14, 56, "4", 7); oline(c, 14, 56, 10, 69, "3", 6); c.line(21, 40, 13, 55, "5", 2); c.line(16, 46, 18, 50, "2")
  c.rect(5, 68, 11, 6, "k"); c.rect(6, 69, 9, 4, "7"); c.hline(7, 69, 6, "8")
  oline(c, 7, 72, 4, 78, "8", 2); oline(c, 10, 73, 9, 79, "8", 2); oline(c, 13, 72, 15, 78, "7", 2)
  oline(c, 18, 50, 12, 44, "6", 2); c.px(11, 43, "8"); c.px(10, 44, "8")
  // Great head: a skull of many, lantern eyes, jaw hanging.
  c.ellipse(40, 21, 11, 10, "k"); c.ellipse(40, 21, 10, 9, "5"); c.ellipse(39, 20, 8, 7, "6"); c.ellipse(36, 17, 4, 3, "7")
  c.px(34, 15, "8"); c.px(35, 15, "8"); c.hline(30, 17, 16, "4")
  c.rect(31, 18, 5, 3, "k"); c.rect(40, 18, 5, 3, "k"); c.px(32, 19, "o"); c.px(33, 19, "o"); c.px(41, 19, "o"); c.px(42, 19, "o")
  c.px(33, 20, "r"); c.px(42, 20, "r"); c.px(37, 23, "k"); c.px(38, 23, "k"); c.px(36, 24, "4")
  c.rect(30, 26, 14, 6, "k"); c.rect(31, 26, 12, 5, "6"); c.hline(32, 27, 10, "k"); for (let x = 32; x < 42; x += 2) c.px(x, 27, "w")
  c.hline(31, 30, 12, "4"); c.hline(32, 29, 10, "5")
  // Crown of pick heads round a rusted band.
  for (const x of [29, 35, 41, 47]) c.poly([x - 1, 11, x + 2, 1, x + 5, 11], "k")
  c.rect(28, 9, 24, 6, "k"); c.rect(29, 10, 22, 4, "D"); c.hline(29, 10, 22, "t"); c.hline(29, 13, 22, "B")
  for (const x of [29, 35, 41, 47]) { c.poly([x, 10, x + 2, 2, x + 4, 10], "t"); c.line(x + 2, 3, x + 2, 9, "T"); c.px(x + 3, 9, "D") }
  c.px(31, 2, "w"); c.px(43, 2, "w"); c.rect(33, 11, 2, 2, "o"); c.rect(39, 11, 2, 2, "9"); c.rect(45, 11, 2, 2, "o")
  // Far arm and the great pick, hanging down his back side toward the ground.
  c.ellipse(64, 30, 8, 6, "k"); c.ellipse(64, 30, 7, 5, "4"); c.ellipse(62, 28, 4, 2, "6")
  oline(c, 64, 32, 74, 43, "3", 6); oline(c, 74, 43, 79, 53, "2", 5); c.line(66, 34, 72, 41, "4", 2)
  oline(c, 79, 53, 86, 80, "B", 2); c.line(80, 53, 87, 79, "t")
  c.line(77, 86, 83, 81, "k", 5); c.line(83, 81, 88, 79, "k", 5); c.line(88, 79, 91, 72, "k", 4)
  c.line(78, 85, 83, 81, "5", 3); c.line(83, 81, 88, 79, "6", 3); c.line(88, 79, 90, 73, "5", 2)
  c.line(79, 84, 87, 79, "8"); c.px(90, 72, "8"); c.px(77, 86, "7"); c.px(84, 83, "r"); c.px(85, 83, "r")
  c.rect(75, 50, 8, 7, "k"); c.rect(76, 51, 6, 5, "7"); c.px(76, 55, "6"); c.hline(77, 51, 4, "8")
})

// Each figure above is drawn as a part, then set on its sprite canvas with 2 empty pixels all round
// (the outline already grew it by 1 on every side).
for (const [name, w, h] of [["miner", 42, 48], ["crawler", 40, 22], ["rubble", 30, 24], ["hulk", 46, 54], ["canary", 32, 38], ["shaft_foreman", 46, 60], ["pit_king", 92, 92]])
  sprite(name, { w: w + 6, h: h + 6 }, ...(name === "canary" ? [stamp("_canary_mist", 3, 3)] : []), stamp("_" + name, 2, 2))
