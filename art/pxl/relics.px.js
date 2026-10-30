// Relic icons (Combat.RELICS): one object per relic, 12x12 under the marks' dark rim, in the kit palette's tones.
// Rares get a second rim in gold, so every icon is 16x16. Each shape reads without its colour.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/relics.px.js, then copy out/sprites/relic_*.png
// into assets/ui/cut/ at 2x (nearest-neighbour), like the marks; the same for the loops, out/anims/relic_*_anim.png.
// The build also writes out/_preview/relics_sheet.png, all 16 side by side, and relics_anim_sheet.png, a loop a row.

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

// Each relic's 4-frame loop (relic_<id>_anim, about 6 fps): frame 0 is the still, then three patches over its
// 12x12 grid ("_" erases). The motion is small so the shape reads at rest.
const LOOPS = {
  // The sparks cool, a fresh one strikes at the edge, then flies off.
  whetstone: [
    [grid(10, 0, "y\n.y\n..\ny")],
    [grid(10, 0, "_\n._\nW\n_")],
    [grid(10, 0, ".\n._\n_W\n_")]],
  // A glint runs over one halo, then the other.
  twin_saints: [
    [grid(1, 0, "H")],
    [grid(2, 0, "H"), grid(8, 0, "H")],
    [grid(9, 0, "H")]],
  // The smoke curls up a row each frame; the embers breathe.
  rusted_censer: [
    [grid(8, 0, "x_\n_x\nx_\n_x"), grid(4, 5, "y")],
    [grid(6, 7, "y")],
    [grid(8, 0, "x_\n_x\nx_\n_x"), grid(6, 5, "y")]],
  // The bottom teeth grind right, back, left.
  clenched_jaw: [
    [grid(1, 7, "YYYYkYYkYY\n.xxxkxxkx")],
    [],
    [grid(1, 7, "YYkYYkYYYY\n.xkxxkxxx")]],
  // The coin drops through the slot; the brass coin on the front catches the light.
  tithe_box: [
    [grid(5, 0, "__\nHG\nGg\nGg")],
    [grid(5, 0, "__\n__\nHG\nGg\nGg")],
    [grid(5, 0, "__\n__\n__"), grid(6, 6, "H")]],
  // A glint slides down the blade's edge.
  gravedigger: [
    [grid(2, 6, "4")],
    [grid(2, 8, "4")],
    [grid(3, 10, "4")]],
  // The right page's corner lifts and settles.
  miners_ledger: [
    [grid(10, 0, "Y")],
    [grid(9, 0, "YY")],
    [grid(10, 0, "Y")]],
  // The lit end sputters: a cross of sparks, a star, a small ember.
  spare_fuse: [
    [grid(8, 0, "W_W\n_y_")],
    [grid(8, 0, "_W_\nWyW\n_y_")],
    [grid(8, 0, "___\n_W_")]],
  // A light passes through the shield's heart.
  ward_icon: [
    [grid(5, 5, "Y")],
    [grid(5, 5, "YY")],
    [grid(6, 5, "Y")]],
  // The bell swings from its handle: rest, right, rest, left.
  hungry_bell: [
    [grid(0, 6, "___23334332_\n___23334332_\n__2333333332\n_22222222222\n__YkYkkkkYkY\n__Y_Y____Y_Y")],
    [],
    [grid(0, 6, "_23334332___\n_23334332___\n2333333332__\n22222222222_\nYkYkkkkYkY__\nY_Y____Y_Y__")]],
  // A glint crosses the crown's points.
  cursed_crown: [
    [grid(1, 1, "W")],
    [grid(5, 1, "W")],
    [grid(10, 1, "W")]],
  // The gilded pip glints and the shine rolls off.
  gilded_pip: [
    [grid(5, 4, "W")],
    [grid(5, 4, "WH\n.H")],
    [grid(6, 5, "H")]],
  // The cross sways under the beads: rest, right, rest, left.
  rosary: [
    [grid(2, 8, "..._XX\n._XXXXXX\n..._XX\n..._XX")],
    [],
    [grid(2, 8, "..XX_\nXXXXXX_\n..XX_\n..XX_")]],
  // The flame leans and a bead of wax runs down.
  black_candle: [
    [grid(5, 0, "_W"), grid(6, 7, "m\nM\nM")],
    [grid(4, 1, "yWy"), grid(6, 7, "m\nm\nM")],
    [grid(4, 0, "W_"), grid(6, 7, "M\nm")]],
  // The flame flickers in the glass: up, down to a small core, flaring.
  pit_lantern: [
    [grid(4, 4, "yWWy\nyWWy\nyyyy")],
    [grid(4, 5, "yyWy\nyWyy")],
    [grid(4, 6, "yWWy\nyyyy")]],
  // A glint runs down the shard's edge.
  mirror_shard: [
    [grid(5, 1, "Y")],
    [grid(4, 3, "Y")],
    [grid(2, 7, "Y")]],
}

for (const [id, [rare, grid]] of Object.entries(ICONS)) {
  sprite("_" + id, { outline: "k" }, grid)
  anim("_" + id + "_anim", { outline: "k" }, grid, frame(), ...LOOPS[id].map((patch) => frame(...patch)))
  const [o, size] = rare ? [0, { w: 14, h: 14, outline: "G" }] : [1, { w: 16, h: 16 }]
  sprite("relic_" + id, size, stamp("_" + id, o, o))
  anim("relic_" + id + "_anim", { ...size, fps: 6 }, ...[0, 1, 2, 3].map((n) => frame(stamp("_" + id + "_anim", o, o, { frame: n }))))
}

sheet("relics_sheet", Object.keys(ICONS).map((id) => "relic_" + id), { pad: 2 })
sheet("relics_anim_sheet", Object.keys(ICONS).map((id) => "relic_" + id + "_anim"), { cols: 4, pad: 2 })
