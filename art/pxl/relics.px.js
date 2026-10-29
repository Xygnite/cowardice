// Relic icons (Combat.RELICS): one object per relic, 12x12 under the marks' dark rim, in the kit palette's tones.
// Rares get a second rim in gold, so every icon is 16x16. Each shape reads without its colour.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/relics.px.js, then copy out/sprites/relic_*.png
// into assets/ui/cut/ at 2x (nearest-neighbour), like the marks.
// The build also writes out/_preview/relics_sheet.png, all 16 side by side.

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

const ICONS = {
  // A blade drawn across a stone, sparks off the edge.
  whetstone: [false, `
  ..........W.
  ........44.W
  .......443..
  ......443.W.
  .....443....
  ....443.....
  ..2222222...
  .233333332..
  2344444433..
  2333333332..
  .22222222...
  ............`],
  // Two hooded saints, haloed, hands folded.
  twin_saints: [false, `
  .GGG...GGG..
  G.B.G.G.B.G.
  .BXB...BXB..
  .BXB...BXB..
  BBBBB.BBBBB.
  BBXBB.BBXBB.
  BBBBB.BBBBB.
  BDBDB.BDBDB.
  BDBDB.BDBDB.
  BDBDB.BDBDB.
  BBBBB.BBBBB.
  ............`],
  // A hanging censer, embers showing through its holes, smoke curling off.
  rusted_censer: [false, `
  .....1...x..
  .....2..x...
  .....1...x..
  ....rRr.x...
  ...rRRRr....
  ..rRoRoRr...
  ..rRRRRRr...
  ..rRoRoRr...
  ...rRRRr....
  ....rrr.....
  ...rrrrr....
  ............`],
  // Clenched teeth between lips, bitten shut.
  clenched_jaw: [false, `
  ............
  ............
  ............
  ..rrrrrrrr..
  .rxxkxxkxxr.
  rYYYkYYkYYYr
  rkkkkkkkkkkr
  rYYYkYYkYYYr
  .rxxkxxkxxr.
  ..rrrrrrrr..
  ............
  ............`],
  // A wooden box with a coin slot, a coin going in.
  tithe_box: [false, `
  .....HG.....
  .....Gg.....
  .....Gg.....
  .BBBBBBBBBB.
  BDDDDkkDDDDB
  BBBBBBBBBBBB
  BbBBBHGBBBbB
  BbBBBGgBBBbB
  BbBBBBBBBBbB
  BbBBBBBBBBbB
  BbbbbbbbbbbB
  ............`],
  // A shovel, four tally marks scratched on the blade.
  gravedigger: [false, `
  ...DDDDDD...
  .....DB.....
  .....DB.....
  .....DB.....
  .....DB.....
  ....2222....
  ..23333332..
  ..3k3k3k32..
  ..3k3k3k32..
  ..33333332..
  ...333332...
  ....3332....`],
  // An open ledger, ruled lines on both pages.
  miners_ledger: [false, `
  ............
  .YYYY..YYYY.
  YYYYYxxYYYYY
  YkkkYxxYkkkY
  YYYYYxxYYYYY
  YkkYYxxYkkkY
  YYYYYxxYYYYY
  YkkkYxxYkkYY
  YYYYYxxYYYYY
  BBBBBBBBBBBB
  .bbbbbbbbbb.
  ............`],
  // A coiled fuse, its end lit.
  spare_fuse: [false, `
  .........W..
  ........WyW.
  .........o..
  ........D...
  .......DD...
  ..DDDDDD....
  .DD.........
  .DD.........
  ..DDDDDDDD..
  .........DD.
  .........DD.
  ..DDDDDDDD..`],
  // A painted icon on wood: a shield under an arch.
  ward_icon: [false, `
  ....BBBB....
  ..BBMMMMBB..
  .BMMMMMMMMB.
  .BMXXXXXXMB.
  .BMXYYYYXMB.
  .BMXYXXYXMB.
  .BMXYYYYXMB.
  .BMMXYYXMMB.
  .BMMMXXMMMB.
  .BMMMMMMMMB.
  .BBBBBBBBBB.
  ............`],
  // An iron bell whose mouth is lined with teeth.
  hungry_bell: [true, `
  .....11.....
  ....1..1....
  ...223322...
  ..23333332..
  ..23334332..
  ..23334332..
  ..23334332..
  ..23334332..
  .2333333332.
  222222222222
  .YkYkkkkYkY.
  .Y.Y....Y.Y.`],
  // A crown, cracked, a cursed gem in its band.
  cursed_crown: [true, `
  ............
  .G...G....G.
  .GG.GHG..GG.
  .GGGGHGkGGG.
  .GGGGGGkGGG.
  .GHGGGkGGHG.
  .GgggpkggGG.
  .GggpppkggG.
  .GgggpggkgG.
  .GGGGGGGkGG.
  .gggggggggg.
  ............`],
  // A die past six: six black pips and a seventh, gilded, in the middle.
  gilded_pip: [true, `
  ............
  .YYYYYYYYYX.
  .YkYYYYYYkX.
  .YYYYggYYYX.
  .YYYgHGgYYX.
  .YkYgGGgYkX.
  .YYYYggYYYX.
  .YYYYYYYYYX.
  .YkYYYYYYkX.
  .YYYYYYYYYX.
  .xxxxxxxxxx.
  ............`],
  // A loop of beads and a hanging cross.
  rosary: [true, `
  ...DXDXDX...
  ..X......D..
  .D........X.
  .X........D.
  .D........X.
  ..X......D..
  ...DX..XD...
  .....XD.....
  .....XX.....
  ...XXXXXX...
  .....XX.....
  .....XX.....`],
  // A black candle, wax running, a small flame.
  black_candle: [true, `
  .....W......
  ....WyW.....
  ....yoy.....
  .....k......
  ...m2mmm....
  ..mm2mmmm...
  ...m2mmm....
  ...m2mMm....
  ...m2mMm....
  ...m2mmm....
  .1111111....
  ............`],
  // A miner's lantern: handle, cap, a lit glass.
  pit_lantern: [true, `
  ....2222....
  ...2....2...
  ...2....2...
  ..33333333..
  ...3yyyy3...
  ...3yWWy3...
  ...3yWWy3...
  ...3oyyo3...
  ...3oooo3...
  ..33333333..
  ...222222...
  ............`],
  // A jagged shard of mirror glass, a glint on its edge.
  mirror_shard: [true, `
  ......4.....
  .....4C.....
  .....CCc....
  ....4CCc....
  ....CCCcc...
  ...4CCccc...
  ...CCcCcc...
  ..4CCcccc...
  ..CCCccccc..
  .4CCcccc....
  .CCccc......
  ............`],
}

for (const [id, [rare, grid]] of Object.entries(ICONS)) {
  sprite("_" + id, { outline: "k" }, grid)
  if (rare) sprite("relic_" + id, { w: 14, h: 14, outline: "G" }, stamp("_" + id, 0, 0))
  else sprite("relic_" + id, { w: 16, h: 16 }, stamp("_" + id, 1, 1))
}

sheet("relics_sheet", Object.keys(ICONS).map((id) => "relic_" + id), { pad: 2 })
