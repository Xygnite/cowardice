// Style test: the reference "corner shop" built in the Hollow Mine's palette. A shut company lamp store
// at the foot of a dead shaft: one lantern lit at the door, everything else falls to the shadow swatches.
// Palette copied from art/pxl/kit.px.js (art/events/art-direction-brief.md).
pal({
  k: "#030304", 0: "#0c1115", 1: "#181a20",
  2: "#232c35", 3: "#2c343a", 4: "#3c4147", 5: "#4c4e55", 6: "#5d5f66",
  b: "#3c312e", B: "#644f41", D: "#8c6452",
  x: "#8c8270", X: "#bfb39a",
  M: "#3a0f12",
  g: "#7a5a24", G: "#c89a40",
  r: "#7a3a20",
  R: "#a76236", o: "#e0782a", y: "#ffb24a", w: "#ffe08a",
})
ramps("k0123456", "kbBD", "kRoyw", "krR", "kgG", "kxX")

// ---------------------------------------------------------------- small parts
sprite("_plank", `
  BBBBBBBBBBBB
  BBBBBBBBBBBB
  BBBBBBBBBBBB
  bbbbbbbbbbbb`)
sprite("_tin", `
  4433
  4433
  4433
  4433`)
sprite("_board", `
  BBBBBBBBBBBBBBB
  bbbbbbbbbbbbbbb`)
sprite("_ore", `
  ..55.
  .5644
  54443`)
sprite("_bone", `
  X..X
  .XX.
  X..X`)
sprite("_rat", `
  ...00.
  .0000k
  000000
  1.1.1.`)

// the one light: a hanging miner's lantern
sprite("lantern", { w: 7, h: 12, outline: "k" },
  vline(3, 0, 3, "4"), rect(1, 3, 5, 1, "4"),
  rect(1, 4, 5, 6, "o"), rect(2, 5, 3, 4, "y"), px(3, 6, "w"), px(3, 7, "w"),
  vline(1, 4, 6, "r"), vline(5, 4, 6, "r"), rect(1, 10, 5, 2, "4"))
sprite("dead_lantern", { base: "lantern", swap: { o: "1", y: "2", w: "3" } })

sprite("cart", { w: 30, h: 20, outline: "k" },
  poly([0, 4, 29, 4, 26, 15, 3, 15], "r"), hline(0, 4, 30, "b"),
  (c) => { for (let x = 6; x < 26; x += 6) c.vline(x, 6, 8, "M") },
  stamp("_ore", 3, 0), stamp("_ore", 10, -1), stamp("_ore", 17, 0), stamp("_ore", 23, 1),
  circ(7, 17, 2, "3"), circ(22, 17, 2, "3"), px(7, 17, "5"), px(22, 17, "5"))

sprite("crate", { w: 14, h: 12, outline: "k" },
  rect(0, 0, 14, 12, "b"), box(0, 0, 14, 12, "B"), line(1, 1, 12, 10, "B"), hline(0, 5, 14, "B"))

sprite("pick", { w: 14, h: 26, outline: "k" },
  line(9, 2, 4, 25, "B"), line(0, 4, 13, 0, "4"), px(13, 0, "6"), px(0, 4, "5"))

// ---------------------------------------------------------------- 3/4 view (same build as moon_bakery_3d)
const FX0 = 24, FX1 = 112, TOP = 60, BOT = 146, D = 30
const sp = (u, y) => [FX1 + u, y - u / 2]
const sidePoly = (u0, u1, y0, y1) => [...sp(u0, TOP + y0), ...sp(u1, TOP + y0), ...sp(u1, TOP + y1), ...sp(u0, TOP + y1)]
const box3 = (x, y, w, h, d, f, s, t) => (c) => {
  c.poly([x + w, y, x + w + d, y - d / 2, x + w + d, y + h - d / 2, x + w, y + h], s)
  c.poly([x, y, x + w, y, x + w + d, y - d / 2, x + d, y - d / 2], t)
  c.rect(x, y, w, h, f)
}
const sideLines = (y0, y1, step, col) => (c) => {
  for (let y = y0; y <= y1; y += step) c.line(FX1, y, FX1 + D - 1, y - (D - 1) / 2, col)
}
const SIDE = [FX1, TOP, FX1 + D, TOP - D / 2, FX1 + D, BOT - D / 2, FX1, BOT]
const ROOF = [FX0 - 4, TOP, FX1 + 2, TOP, FX1 + D + 2, TOP - D / 2, FX0 + D - 4, TOP - D / 2]
const DOOR_X = FX0 + 62, DOOR_Y = TOP + 44   // lantern hangs left of the door

scene("mine_store", { w: 192, h: 170, bg: "k", layers: true },
  // cave: rock strata behind, darker toward the top; rough stone is granular, so sparse noise is allowed
  layer("cave",
    rect(0, 30, 192, 110, "0"), rect(0, 70, 192, 70, "1"),
    poly([0, 30, 40, 22, 90, 34, 150, 20, 192, 28, 192, 0, 0, 0], "k"),
    poly([0, 96, 30, 88, 70, 98, 120, 86, 192, 94, 192, 100, 0, 100], "2"),
    noise(0, 70, 192, 60, "2", 0.03, 7),
    // dead headframe of the shaft behind the store
    line(150, 120, 162, 30, "2"), line(186, 120, 174, 30, "2"), hline(160, 30, 17, "2"),
    hline(154, 70, 28, "2"), hline(157, 50, 22, "2"), circ(168, 26, 5, "2"), ring(168, 26, 5, "3")),

  layer("ground",
    rect(0, 138, 192, 32, "2"), hline(0, 138, 192, "3"), noise(0, 140, 192, 30, "1", 0.06, 3),
    // rails
    (c) => { for (let x = 2; x < 192; x += 9) c.rect(x, 156, 5, 3, "b") },
    hline(0, 155, 192, "4"), hline(0, 159, 192, "4"), hline(0, 154, 192, "5")),

  // ---- roof: rusted corrugated tin
  layer("roof",
    poly(ROOF, "3"),
    clip(ROOF, pattern("_tin", 0, 0, 192, 60)),
    line(FX0 - 4, TOP, FX0 + D - 4, TOP - D / 2, "2"), line(FX1 + 2, TOP, FX1 + D + 2, TOP - D / 2, "2"),
    hline(FX0 - 4, TOP, FX1 - FX0 + 7, "4"),
    // rust runs where the tin overlaps
    clip(ROOF, (c) => { for (const x of [44, 71, 96]) c.line(x, TOP - 1, x + 10, TOP - 6, "r") }),
    // stovepipe, cold
    box3(84, 26, 6, 26, 4, "3", "2", "4"), rect(83, 22, 9, 4, "4"),
    stamp("_bone", 52, 48)),

  // ---- side face: weathered planks, one boarded window
  layer("side",
    poly(SIDE, "b"),
    sideLines(TOP + 4, BOT - 2, 5, "1"),
    poly(sidePoly(6, 24, 22, 44), "0"),
    poly(sidePoly(4, 26, 26, 29), "B"), poly(sidePoly(4, 26, 36, 39), "B"),
    poly(sidePoly(0, D, 80, 86), "1"),
    shade(SIDE, 1)),

  // ---- front face (local coords)
  layer("front", { x: FX0, y: TOP },
    pattern("_plank", 0, 0, 88, 86),
    // splash-back grime fading up from the ground
    dither(0, 74, 88, 12, "b", ".", 0.5), rect(0, 82, 88, 4, "1"),
    // sign: painted letters faded on a plank board, a nail at each end
    rect(6, 6, 54, 15, "b"), box(6, 6, 54, 15, "1"),
    text(33, 9, "LAMPS", "x", { align: "c", shadow: "1" }),
    px(8, 8, "5"), px(57, 8, "5"),
    // company scrip notice
    rect(66, 7, 15, 14, "x"), box(66, 7, 15, 14, "B"), hline(68, 11, 11, "1"), hline(68, 14, 9, "1"), hline(68, 17, 10, "1"),
    // shop window: dark inside, a few lamps left on the shelf, boards nailed across
    rect(4, 30, 46, 34, "1"), rect(6, 32, 42, 30, "0"),
    hline(6, 47, 42, "b"), stamp("dead_lantern", 10, 35), stamp("dead_lantern", 22, 35), stamp("dead_lantern", 36, 35),
    line(4, 34, 50, 58, "B"), line(4, 35, 50, 59, "b"), line(4, 58, 50, 38, "B"), line(4, 59, 50, 39, "b"),
    rect(2, 64, 50, 3, "B"), hline(2, 66, 50, "b"),
    // door, a crack of light under it
    rect(58, 34, 22, 52, "1"), rect(60, 36, 18, 50, "b"),
    (c) => { for (let x = 64; x < 78; x += 5) c.vline(x, 36, 50, "1") },
    px(74, 60, "G"), hline(61, 85, 16, "o"),
    // rust run under the door hinge brackets
    rect(60, 42, 4, 2, "4"), rect(60, 72, 4, 2, "4"), vline(61, 44, 5, "r"), vline(61, 74, 4, "r")),

  // lantern light: only the door and the nearest boards, then a pool on the ground
  layer("light", { light: true, density: 0.5 }, circ(DOOR_X - 2, DOOR_Y + 8, 22, "k")),
  layer("light2", { light: true }, circ(DOOR_X - 2, DOOR_Y + 8, 12, "k")),
  layer("cast", { shade: true },
    poly([FX1, BOT, FX1 + D, BOT - D / 2, FX1 + D + 26, BOT - D / 2, FX1 + 26, BOT], "k")),

  layer("props",
    wire(DOOR_X - 8, TOP + 30, DOOR_X - 2, TOP + 30, 0, "4"),
    vline(DOOR_X - 5, TOP + 30, 6, "4"), stamp("lantern", DOOR_X - 8, TOP + 36),
    stamp("crate", 6, 128), stamp("crate", 12, 118), stamp("pick", 116, 116),
    stamp("cart", 142, 139), stamp("_rat", 40, 140, { flip: "x" }),
    stamp("_ore", 128, 146), stamp("_ore", 60, 150)),

  layer("pool", { light: true, density: 0.5 },
    ellipse(DOOR_X - 2, BOT + 4, 30, 6, "k")),

  // falloff: the further from the lantern, the closer to the shadow swatches
  layer("falloff", { shade: true, density: 0.5 },
    clip((x, y) => Math.hypot(x - DOOR_X, (y - DOOR_Y) * 1.1) > 78, rect(0, 0, 192, 170, "k"))),
  layer("falloff2", { shade: true },
    clip((x, y) => Math.hypot(x - DOOR_X, (y - DOOR_Y) * 1.1) > 104, rect(0, 0, 192, 170, "k"))),

  glow("wyo", { r: 6, strength: 0.45 }),
)
