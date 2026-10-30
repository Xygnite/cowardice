// Large relic art (Combat.RELICS) for the shop's offer cards: the same 16 objects as relics.px.js, drawn 28x28 under
// the marks' dark rim with more detail (shading, highlights, small parts). Commons sit on a 32x32 canvas; rares get the
// second rim in gold, so every image is 32x32. Same palette; each shape still reads without its colour.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/relics_big.px.js, then copy out/sprites/relic_*_big.png
// into assets/ui/cut/ at 2x (nearest-neighbour), so each file is 64x64.
// The build also writes out/_preview/relics_big_sheet.png, all 16 side by side.

pal({
  k: "#1a1412",                                                   // the marks' rim
  1: "#2c343a", 2: "#4c4e55", 3: "#8a8c92", 4: "#c8c8cc",          // iron and stone, dark -> light
  b: "#3c312e", B: "#644f41", D: "#8c6452",                       // wood
  x: "#8c8270", X: "#bfb39a", Y: "#e8dfc6",                       // tallow, bone
  g: "#7a5a24", G: "#c89a40", H: "#f0d070",                       // gold
  r: "#7a3a20", R: "#a76236",                                     // rust
  m: "#140506", M: "#3a0f12", p: "#6a2a5a",                       // black wax, curse
  o: "#e0782a", y: "#ffb24a", W: "#ffe08a",                       // fire
  c: "#475f6b", C: "#9cc0c8",                                     // glass
})

ramps("mM")                                                       // the candle flame lights the wax

// One hooded saint, written as its left half (mirrored about the middle column).
sprite("_saint_big", { mx: "c", w: 13, h: 28 }, `
  ...GGHH
  .GG....
  G....bb
  G...bBB
  G..bBBB
  G..bBBB
  G.bBxxx
  .GbBXXX
  ..bBXkX
  ..bBXXX
  ..bBBxX
  .bBBBBB
  .bBBBBB
  bBBBBBB
  bBBDxXX
  bBBDXYY
  bBBBxXX
  bBDBBBB
  bBDBBDB
  bBDBBDB
  bBDBBDB
  bBDBBDB
  bBDBBDB
  bBDBBDB
  bBDBBDB
  bBDBBDB
  bBDBBDB
  bbbbbbb`)

// A sunken pip: shadow on its upper-left wall, light on the lower-right.
sprite("_pip_big", `
  .kk.
  kkkk
  kkkx
  .kx.`)

// The shard's outline (polygon on pixel corners), shared by its fill and its clips.
const SHARD = [15, 0, 17, 0, 19, 6, 21, 8, 20, 11, 24, 15, 26, 21, 22, 22, 19, 25, 14, 25, 10, 27, 6, 27, 4, 28, 0, 28, 3, 21, 6, 15, 9, 9, 12, 4]

// [rare, opts, ...items] on a 28x28 canvas. opts.mx mirrors the left half; opts.after runs once the mirror is done
// (light from the upper left, so the two halves differ).
const BIG = {
  // A blade drawn across a stone, sparks off the edge.
  whetstone: [false, {},
    ellipse(13, 21, 13, 5, "2"),
    ellipse(13, 20, 12, 4, "3"),
    ellipse(12, 19, 10, 2, "4"),
    hline(4, 25, 18, "1"),
    // grinding scratches across the worn top, the way the blade runs
    grid(6, 19, "3\n.3"), grid(15, 18, "3\n.3"), grid(19, 19, "3\n.3"), grid(10, 20, "3"),
    // the blade: bright edge down-left, dark spine up-right
    (c) => {
      const tip = ["4", "44", "443", "4432", "44323", "443233"]
      for (let r = 1; r <= 15; r++) {
        const s = 24 - r, row = tip[r - 1] ?? "4432332"
        for (let i = 0; i < row.length; i++) c.px(s + i, r, row[i])
      }
    },
    grid(23, 0, "...W\n.y..\nWyW.\n.W..\n....\n...y"),
    grid(3, 12, "W..\n..y\n.y."),
  ],
  // Two hooded saints, haloed, hands folded.
  twin_saints: [false, {},
    stamp("_saint_big", 0, 0), stamp("_saint_big", 15, 0),
    recolor({ B: "b", D: "B", X: "x", Y: "X", H: "G", G: "g" }, [9, 0, 4, 28], 0.5),
    recolor({ B: "b", D: "B", X: "x", Y: "X", H: "G", G: "g" }, [24, 0, 4, 28], 0.5),
  ],
  // A hanging censer, embers showing through its holes, smoke curling off.
  rusted_censer: [false, {},
    grid(11, 0, ".2.\n2.1\n2.1\n.2.\n.1.\n.1.\n.2.\n2.1\n.2."),
    circ(12, 18, 7, "r"),
    circ(12, 18, 6, "R"),
    grid(8, 13, "DD\nD.\nD"),
    hline(6, 18, 13, "r"),
    px(7, 18, "D"), px(12, 18, "D"), px(17, 18, "D"),
    // pierced holes, embers behind them
    ...[[8, 15], [12, 15], [16, 15], [10, 21], [14, 21]].map(([x, y]) => grid(x - 1, y - 1, ".o.\noyo\n.o.")),
    // the lid, its knob on the chain
    ellipse(12, 12, 6, 2, "r"),
    ellipse(12, 11, 5, 2, "R"),
    hline(9, 10, 3, "D"),
    grid(11, 8, "rRr"),
    // the foot
    rect(10, 24, 5, 1, "r"), rect(8, 25, 9, 2, "R"), hline(8, 25, 9, "D"), hline(7, 27, 11, "r"),
    // smoke off the lid
    grid(16, 0, "......xX\n.....x..\n....x...\n....x...\n.....xX.\n.......X\n......x.\n....xx..\n...x....\n..x....."),
  ],
  // Clenched teeth between lips, bitten shut.
  clenched_jaw: [false, { mx: true }, `
    ..............
    ..............
    ..............
    ..............
    ..............
    ........rrrr..
    .....rrrRRRRrr
    ...rrRRRRRRRRR
    ..rRRRDDRRRRRR
    .rRRRRRRRRRRRR
    rRRRrrrrrrrrrr
    rrxxxkxxxkxxxx
    rrXXXkYYYkYYYX
    rrXXXkYYYkYYYX
    rrxXXkXYYkXYYX
    rkkkkkkkkkkkkk
    rrXXXkYYYkYYYX
    rrXXXkYYYkYYYX
    rrxxxkxxxkxxxx
    rRrrrrrrrrrrrr
    .rRRRRRRRRRRRR
    ..rRRRRRDDDRRR
    ...rrRRRRRRRRR
    .....rrrrrrrrr`],
  // A wooden box with a coin slot, a coin going in.
  tithe_box: [false, {},
    // lid: lit top face, the slot, the front lip
    rect(1, 7, 26, 5, "D"), hline(1, 7, 26, "B"),
    hline(3, 9, 6, "B"), hline(19, 9, 6, "B"),
    rect(9, 9, 10, 2, "k"),
    `
    ............HHG
    ...........HHGGg
    ...........HGGGg
    ...........HGgGg
    ...........HGgGg
    ...........HGGGg
    ...........GGGgg
    ...........GGggg
    ...........GGggg
    ...........gggg`,
    hline(9, 10, 10, "k"), hline(9, 11, 10, "B"),
    rect(0, 12, 28, 2, "B"), hline(0, 12, 28, "D"), hline(1, 14, 26, "b"),
    // the box: planks, iron corners, the brass lock plate
    rect(1, 15, 26, 12, "B"), hline(1, 27, 26, "b"),
    hline(1, 19, 26, "b"), hline(1, 23, 26, "b"),
    px(7, 17, "D"), px(20, 21, "D"), px(9, 25, "D"), px(18, 17, "D"),
    rect(1, 12, 3, 16, "2"), vline(1, 12, 16, "3"), px(2, 16, "4"), px(2, 24, "4"),
    rect(24, 12, 3, 16, "2"), vline(26, 12, 16, "1"), px(25, 16, "4"), px(25, 24, "4"),
    rect(11, 16, 6, 7, "G"), hline(11, 16, 6, "H"), vline(11, 16, 7, "H"), hline(11, 22, 6, "g"), vline(16, 17, 6, "g"),
    grid(13, 18, "kk\nkk\n.k"),
  ],
  // A shovel, four tally marks scratched on the blade.
  gravedigger: [false, {}, `
    ........DDDDDDDDDDDD........
    .......DBBBBBBBBBBBBb.......
    ........bbbbDBBbbbbb........
    ............DBBb............
    ............DBBb............
    ............DBbb............
    ............DBBb............
    ............DBBb............
    ............DbBb............
    ............DBBb............
    ............DBBb............
    ............DBbb............
    ..........23333332..........
    ..........24333432..........
    ...........233332...........`,
    // the blade: straight shoulders, a point; lit left edge, shaded right
    (c) => {
      for (let y = 15; y < 28; y++) {
        const a = 6 + Math.max(0, y - 20), b = 21 - Math.max(0, y - 20)
        c.hline(a, y, b - a + 1, "3"); c.px(a, y, "4"); c.px(b, y, "2"); if (b - a > 3) c.px(b - 1, y, "2")
      }
      c.hline(6, 15, 15, "4")
    },
    // four tallies scratched in, rust at the edges, earth caked on the point
    ...[8, 10, 12, 14].map((x) => grid(x, 18, "1\n1\n14")),
    px(7, 20, "r"), px(19, 22, "r"), px(20, 18, "r"), px(10, 24, "r"),
    grid(12, 24, ".bb\nbbbb\n.bb"),
  ],
  // An open ledger, ruled lines on both pages.
  miners_ledger: [false, {}, `
    ............................
    ............................
    ...YYYYYYYY......YYYYYYYY...
    .YYYYYYYYYYYX..XYYYYYYYYYYY.
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    YYYYYYYYYYYYXxxXYYYYYYYYYYYY
    XYYYYYYYYYYYXxxXYYYYYYYYYYYX
    XXXXXXXXXXXXxxxxXXXXXXXXXXXX
    xXxXxXxXxXxXxxxxXxXxXxXxXxXx
    BBBBBBBBBBBBBbbBBBBBBBBBBBBB
    .bbbbbbbbbbbbbbbbbbbbbbbbbb.`,
    // red money columns, entries and sums
    vline(9, 5, 15, "r"), vline(23, 5, 15, "r"),
    (c) => {
      const L = ["kkk.kk", "kk.kkk", "k.kkkk", "kkkk.k", "kk.kk", "kkk.kk", "kk.kkk"]
      const R = ["kk.kkkk", "kkk.kk", "k.kkk", "kkkk.kk", "kk.kk", "kkk.k"]
      const N = ["kk", ".k", "k.", "kk", ".k", "kk", "k."]
      const put = (x, y, s) => { for (let i = 0; i < s.length; i++) if (s[i] !== ".") c.px(x + i, y, s[i]) }
      put(1, 5, "kkkkkk"), c.hline(1, 6, 7, "x")
      L.forEach((s, i) => { put(1, 8 + i * 2 - (i > 0 ? 1 : 0), s); put(10, 8 + i * 2 - (i > 0 ? 1 : 0), N[i]) })
      put(16, 5, "kkkkk"), c.hline(16, 6, 6, "x")
      R.forEach((s, i) => { put(16, 7 + i * 2, s); put(24, 7 + i * 2, N[i]) })
      c.hline(24, 18, 3, "k"), c.hline(24, 19, 3, "x")
    },
  ],
  // A coiled fuse, its end lit.
  spare_fuse: [false, {},
    (c) => {
      const pts = [[21, 6], [18, 9], [16, 11], [7, 11]]
      for (let i = 1; i < 8; i++) { const a = -Math.PI / 2 - (i * Math.PI) / 8; pts.push([7 + 3.5 * Math.cos(a), 14.5 + 3.5 * Math.sin(a)]) }
      pts.push([7, 18], [20, 18])
      for (let i = 1; i < 8; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 8; pts.push([20 + 3.5 * Math.cos(a), 21.5 + 3.5 * Math.sin(a)]) }
      pts.push([20, 25], [5, 25])
      for (let i = 1; i < pts.length; i++) c.line(Math.round(pts[i - 1][0]), Math.round(pts[i - 1][1]), Math.round(pts[i][0]), Math.round(pts[i][1]), "B", 3)
    },
    // twisted cord: dark turns across it, its top lit
    recolor({ B: "b" }, (x, y) => (x + y) % 3 === 0),
    (c) => { for (let y = 1; y < 28; y++) for (let x = 0; x < 28; x++) if (c.is(x, y, "B") && !c.is(x, y - 1, "*")) c.px(x, y, "D") },
    // the cut end, and the lit one
    grid(3, 24, "x\nX\nx"),
    grid(20, 0, "...W..\n.W.y..\n..yWy.\n.WyoyW\n..oyo.\n.o.o.."),
  ],
  // A painted icon on wood: a shield under an arch.
  ward_icon: [false, {
    mx: true,
    after: [recolor({ D: "B", B: "b" }, [15, 0, 13, 28]), recolor({ Y: "X" }, [14, 9, 6, 13], 0.5), grid(5, 22, "b\n.b"), px(21, 6, "b")],
  },
    circ(14, 13, 13, "B"), rect(1, 13, 13, 15, "B"),
    clip([0, 0, 28, 13], ring(14, 13, 13, "D")), vline(1, 13, 15, "D"),
    circ(14, 13, 11, "b"), rect(3, 13, 11, 13, "b"),
    circ(14, 13, 10, "M"), rect(4, 13, 10, 12, "M"),
    clip([0, 0, 28, 13], ring(14, 13, 8, "x")),
    hline(1, 27, 13, "b"),
    grid(7, 8, `
      XXXXXXX
      XYYYYYY
      XYYYYrr
      XYYYYrr
      XYrrrrr
      XYrrrrr
      XYYYYrr
      XYYYYrr
      .XYYYrr
      .XYYYrr
      ..XYYYY
      ...XYYY
      ....XXY
      ......X`),
  ],
  // An iron bell whose mouth is lined with teeth.
  hungry_bell: [true, {
    mx: true,
    after: [recolor({ 3: "4" }, [7, 5, 2, 15]), recolor({ 3: "2" }, [20, 4, 8, 17]), recolor({ 2: "1" }, [23, 4, 5, 18])],
  }, `
    ...........222
    ..........2...
    ..........2...
    ........222222
    ......22333333
    .....233333333
    .....233333333
    .....233333333
    .....233333333
    ....2333333333
    ....2333333333
    ....2333333333
    ....2333333333
    ...12222222222
    ...23444444444
    ...23333333333
    ...23333333333
    ..233333333333
    ..233333333333
    .2333333333333
    23333333333333
    22222222222222
    11111111111111
    .YYXmYYXmYYXmm
    .YYX.YYX..YX..
    ..YX..YX...X..
    ..Y....Y......`],
  // A crown, cracked, a cursed gem in its band.
  cursed_crown: [true, {},
    poly([1, 3, 3, 3, 6, 10, 1, 10], "G"),
    poly([7, 6, 9, 6, 11, 10, 5, 10], "G"),
    poly([12, 4, 16, 4, 19, 10, 9, 10], "G"),
    poly([19, 6, 21, 6, 23, 10, 17, 10], "G"),
    poly([25, 3, 27, 3, 27, 10, 22, 10], "G"),
    rect(1, 10, 26, 15, "G"),
    grid(1, 1, "HG\nGg"), grid(25, 1, "HG\nGg"), grid(7, 4, "HG\nGg"), grid(19, 4, "HG\nGg"),
    grid(12, 0, ".HG.\nHHGg\nHGGg\n.gg."),
    // round band: lit on the left, dark on the right
    recolor({ G: "H" }, [3, 0, 3, 28]), recolor({ G: "g" }, [22, 0, 5, 28]), recolor({ H: "G" }, [22, 0, 5, 28]),
    hline(1, 14, 26, "g"), hline(1, 20, 26, "g"), hline(1, 22, 26, "H"), hline(1, 24, 26, "g"),
    ...[4, 8, 20, 24].map((x) => grid(x, 16, "H.\nGg\n.g")),
    grid(11, 15, "..pp..\n.ppMM.\npXMMMm\n.MMmm.\n..mm.."),
    // the crack, the curse seeping out of it
    grid(16, 5, `
      ...k
      ...k
      ..k.
      ...k
      ..k.
      .k..
      .k..
      ..k.
      .k..
      .kp.
      k.p.
      k...
      .k..
      .k..
      k...
      k...
      .k..
      .k..
      k...
      k...`),
  ],
  // A die past six: six black pips and a seventh, gilded, in the middle.
  gilded_pip: [true, {},
    rect(0, 0, 24, 24, "Y"),
    poly([24, 1, 28, 4, 28, 27, 24, 24], "X"),
    poly([1, 24, 24, 24, 28, 28, 4, 28], "x"),
    grid(0, 0, "_\n"), grid(0, 23, "_"), grid(23, 0, "_"),
    vline(23, 1, 23, "X"), hline(1, 23, 22, "X"),
    ...[[3, 3], [17, 3], [3, 10], [17, 10], [3, 17], [17, 17]].map(([x, y]) => stamp("_pip_big", x, y)),
    grid(8, 8, "..gggg..\n.gHHGGg.\ngHWHGGGg\ngHHGGGGg\ngGGGGGgg\ngGGGGGgg\n.gGGggg.\n..gggg.."),
    grid(25, 8, "k\nk"), grid(25, 18, "k\n.k"),
    px(5, 0, "X"), px(0, 14, "X"),
  ],
  // A loop of beads and a hanging cross.
  rosary: [true, {},
    (c) => {
      const n = 16, at = []
      for (let i = 0; i < n; i++) {
        const a = Math.PI / 2 + ((i + 0.5) * 2 * Math.PI) / n
        at.push([Math.round(13.5 + 11.5 * Math.cos(a)), Math.round(8.5 + 7.5 * Math.sin(a))])
      }
      at.forEach(([x, y], i) => { const [nx, ny] = at[(i + 1) % n]; c.line(x, y, nx, ny, "x") })
      at.forEach(([x, y], i) => {
        const [hi, mid, lo] = i % 2 ? ["Y", "X", "x"] : ["D", "B", "b"]
        c.rect(x - 1, y - 1, 3, 3, mid); c.px(x - 1, y - 1, "_"); c.px(x + 1, y + 1, lo)
        c.px(x - 1, y, hi); c.px(x, y - 1, hi); c.px(x + 1, y - 1, mid); c.px(x - 1, y + 1, mid)
      })
    },
    grid(12, 15, ".XX.\nXYXx\nXXxx\n.xx."),
    grid(13, 19, "Xx"),
    grid(8, 20, `
      ....YXXx....
      ....YXXx....
      YYYYYXXXXXXX
      YXXXXXXXXXXx
      xxxxYXXxxxxx
      ....YXXx....
      ....YXXx....
      ....YXXx....`),
  ],
  // A black candle, wax running, a small flame.
  black_candle: [true, {},
    `
    ..............W
    .............WW
    ............yWWy
    ............yWWy
    ...........yyWWyy
    ...........yWWWWy
    ...........oyWWyo
    ............oyyo
    .............ok
    ..............k`,
    rect(8, 10, 12, 13, "m"),
    hline(8, 10, 12, "M"), hline(10, 11, 8, "k"),
    vline(10, 12, 10, "2"), vline(11, 13, 8, "M"),
    // wax running over the rim
    grid(6, 10, ".M\nmM\nmm\nmm\nmM\n.m"),
    grid(14, 11, "MM\nMm\nMm\nMm\nmm\n.m"),
    grid(17, 11, "M\nm\nm"),
    grid(19, 10, "M.\nmM\nmm\nmM\nmm\nmM\nmm\nm."),
    // the dish, a pool of wax on it, its ring handle
    rect(3, 23, 22, 2, "2"), hline(3, 23, 22, "3"), rect(5, 25, 18, 2, "1"), hline(4, 25, 1, "1"), hline(23, 25, 1, "1"),
    hline(5, 22, 4, "m"), hline(6, 23, 4, "m"),
    grid(24, 21, "22.\n..2\n.22"),
    glow("Wy", { r: 4, ramp: 1, where: [0, 0, 28, 12] }),
  ],
  // A miner's lantern: handle, cap, a lit glass.
  pit_lantern: [true, {
    mx: true,
    after: [recolor({ 3: "2", 4: "3" }, [19, 0, 9, 28]), grid(7, 11, "W\nW\nY\nW")],
  }, `
    ..........2222
    ........22....
    .......2......
    ......2.......
    ......2....333
    ......4..33333
    .......2333333
    ......23k3k3k3
    .....233333333
    ....2222222222
    ....23oyyyyyyy
    ....23oy2yyyyy
    ....23oy2yyyyW
    ....23oy2yyyWW
    ....23oy2yyWWW
    ....23oy2yyWWW
    ....23oy2yyyWW
    ....23oo2yyyyo
    ....23oo2oyyoo
    ....23oo2o2222
    ....23oo222222
    ....3444444444
    ....2333333333
    ....2343333333
    ....2333333333
    .....222222222
    ......11111111`],
  // A jagged shard of mirror glass, a glint on its edge.
  mirror_shard: [true, {},
    poly(SHARD, "C"),
    clip(SHARD, poly([16, 0, 28, 0, 28, 28, 11, 28], "c")),
    // the bevel: lit left edge, dark bottom edge
    (c) => {
      for (let y = 0; y < 28; y++) for (let x = 0; x < 28; x++) {
        if (!c.is(x, y, "Cc")) continue
        if (!c.is(x - 1, y, "*")) c.px(x, y, "4")
        else if (!c.is(x, y + 1, "*") && c.is(x, y, "C")) c.px(x, y, "c")
      }
    },
    // reflections running across both faces, a hairline crack
    clip(SHARD, line(3, 26, 15, 6, "4"), line(6, 26, 16, 10, "4"), line(16, 22, 22, 13, "C")),
    recolor({ "4": "C" }, (x, y) => x > 13 && y > 8),
    grid(7, 18, "c\n.c\n.c\n..c"),
    grid(10, 3, ".4.\n4W4\n.4."),
  ],
}

for (const [id, [rare, { after, ...opts }, ...items]] of Object.entries(BIG)) {
  const part = "_" + id + "_big"
  if (after) {
    sprite(part + "_half", { w: 28, h: 28, ...opts }, ...items)
    sprite(part, { w: 28, h: 28, outline: "k" }, stamp(part + "_half", 0, 0), ...after)
  } else sprite(part, { w: 28, h: 28, outline: "k", ...opts }, ...items)
  const [o, size] = rare ? [0, { w: 30, h: 30, outline: "G" }] : [1, { w: 32, h: 32 }]
  sprite("relic_" + id + "_big", size, stamp(part, o, o))
}

sheet("relics_big_sheet", Object.keys(BIG).map((id) => "relic_" + id + "_big"), { pad: 2 })
