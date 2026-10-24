// The Hollow Mine's fight backdrop and its moving parts (scripts/backdrop_life.gd LIFE.mine). The scene is 512x286
// pxl pixels, 2 image px each in the game (1024x572), like the crypt. Lit by its lanterns, cold everywhere else.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/bg_mine.px.js --out <scratch>
// then: <scratch>/scenes/bg_mine.png doubled (nearest) and saved lossless as assets/ui/bg_mine.webp;
// <scratch>/anims/lantern.png + .json, <scratch>/anims/chain_mine_*.png + .json and <scratch>/sprites/dust.png
// copied to assets/ui/life/. The chain strips are drawn at 2 image px a pixel already (BackdropLife plays them
// unscaled), so they need no doubling.
pal({
  k: "#0e0613",
  1: "#1d202c", 2: "#2a303a", 3: "#333f4c", 4: "#3f4f56", 5: "#4a5e64",  // cold rock, iron
  6: "#56676a", 7: "#627a7c", 8: "#758d8c", 9: "#88a2a0",
  b: "#2b2a23", B: "#412e26", D: "#664835", t: "#7d5a3c",                  // timber
  r: "#975131",                                                            // rust
  a: "#24303c", A: "#6f93a3",                                              // wet rock, a water glint
  R: "#a8522e", o: "#e8743c", y: "#f6b45e", w: "#fce290",                  // lantern fire: glows, keep it to flames
})
ramps("k123456789", "kbBDt", "1aA")

const W = 512, H = 286
const LEDGE = 192  // the walkway's back edge, where the wall meets it: the fighters stand just in front
const BEAM = [18, 32]  // the cap beam across the top, rows
const POSTS = [[22, 12], [148, 10], [354, 10], [478, 12]]  // timber posts: x, width
const TUNNEL = { x0: 196, x1: 316, top: 58 }  // the drift mouth's timber set, outer edges
const LANTERNS = [[211, 72], [294, 72], [162, 94], [342, 94]]  // lit lanterns, top-left of their 7x12 body
const LAMPS = LANTERNS.map(([x, y]) => [x + 3, y + 5])  // the flames' centres, the only light
const DRIPS = [96, 270, 414]  // x of the leaks under the cap beam
// The eye bolts the swaying chains (chain_mine_<i>, below) hang from: x of the chain's middle, y of its top row.
// In LIFE.mine a strip sits at image px (2 * (x - half - 2), 2 * y), half being 1 for a hook, 3 for the lantern.
const CHAINS = [[100, BEAM[1] + 2], [404, BEAM[1] + 2], [256, TUNNEL.top + 12]]

// 0..1, the same for the same (a, b).
function hash(a, b) {
  const s = Math.sin(a * 127.1 + b * 311.7) * 43758.5453
  return s - Math.floor(s)
}

// Relights the finished scene (lantern flames, "wyoR", keep their colour): a cold ambient that sinks to near-black
// toward the roof and the far ends, plus a warm pool round each lamp falling off with the square of the distance
// (squashed above the lamp, whose cap shades the roof).
// Both are banded in dithered steps so the light lies in flat pixel-art shades, not a smooth airbrush.
// `at`/`px`: where the canvas sits in the scene and its image px per pxl pixel, so a BackdropLife strip drawn
// apart (the chains) is lit as it would be on its painted spot.
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
function light(c, lamps, { amb = 0.45, warm = 2.2, reach = 150, cold = [0.62, 0.74, 1], fire = [1, 0.84, 0.66], step = 0.08, deep = null, at = [0, 0], px = 1 } = {}) {
  const band = (v, x, y) => Math.floor(v / step + BAYER[(y & 3) * 4 + (x & 3)] / 16) * step
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++) {
      const p = c.get(x, y) >>> 0
      if ((p & 255) === 0 || c.is(x, y, "wyoR")) continue
      const sx = at[0] + x / px, sy = at[1] + y / px
      const edge = Math.min(1, Math.min(sx, W - sx) / 170), top = Math.min(1, Math.max(0, (sy - 12) / 110))
      const a = band(amb * (0.25 + 0.75 * edge) * (0.2 + 0.8 * top), sx | 0, sy | 0)
      let w = 0
      for (const [lx, ly] of lamps) {
        const f = Math.max(0, 1 - Math.hypot(sx - lx, (sy - ly) * (sy < ly ? 2 : 1.1)) / reach)
        w += f * f
      }
      w = band(Math.min(1.4, w * warm), sx | 0, sy | 0)
      let d = 0
      if (deep) d = band(Math.max(0, 1 - Math.hypot(sx - deep[0], sy - deep[1]) / deep[2]) * 0.5, sx | 0, sy | 0)
      const ch = (sh, i) => Math.min(255, Math.round(((p >>> sh) & 255) * (a * cold[i] + w * fire[i] + d * cold[i])))
      const hex = (v) => v.toString(16).padStart(2, "0")
      c.px(x, y, "#" + hex(ch(24, 0)) + hex(ch(16, 1)) + hex(ch(8, 2)))
    }
}

// A faceted stone with a dark rim (so packed stones read apart), its top-left facet lit.
function rock(c, cx, cy, rx, ry, [rim, dark, mid, lit], seed) {
  const n = 7, pts = []
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + seed, j = 0.82 + 0.18 * Math.abs(Math.sin(i * 12.9898 + seed * 78.233))
    pts.push([Math.cos(a) * rx * j, Math.sin(a) * ry * j])
  }
  const at = (k, dx = 0, dy = 0, grow = 0) =>
    pts.flatMap(([x, y]) => [Math.round(cx + dx + x * k + Math.sign(x) * grow), Math.round(cy + dy + y * k + Math.sign(y) * grow)])
  c.poly(at(1, 0, 0, 1), rim)
  c.poly(at(1), dark)
  c.poly(at(0.72, -rx * 0.12, -ry * 0.16), mid)
  if (lit) c.poly(at(0.3, -rx * 0.34, -ry * 0.4), lit)
}

// Rough rock packed in uneven courses, down to the walkway.
function wall(c) {
  c.rect(0, 0, W, LEDGE, "1")
  for (let row = 0, y = -2; y < LEDGE + 6; row++) {
    const ry = 8 + Math.floor(hash(row, 1) * 5)
    for (let x = -16 + Math.floor(hash(row, 2) * 14); x < W + 16; ) {
      const rx = 12 + Math.floor(hash(row, x) * 14)
      const lit = hash(x, row) > 0.86 ? "3" : null  // most faces turn away from the light; the lamps do the rest
      rock(c, x + rx, y + ry + Math.round((hash(x, 9) - 0.5) * 6), rx, ry + Math.floor(hash(x, 7) * 4), ["1", "2", "2", lit], hash(x, row) * 6)
      x += rx * 2 + 1
    }
    y += ry * 2 - 1
  }
}

// A squared timber, lit on its left (upper-left light), split along its grain.
function post(c, x, w, y0, y1) {
  const h = y1 - y0
  c.rect(x - 1, y0, w + 2, h, "k")
  c.rect(x, y0, w, h, "B")
  c.vline(x, y0, h, "D")
  c.vline(x + 1, y0, h, "D")
  c.vline(x + w - 1, y0, h, "b")
  for (let i = 0; i < 4; i++) {
    const gx = x + 2 + Math.floor(hash(x, i) * (w - 4)), gy = y0 + Math.floor(hash(i, x) * (h - 30))
    c.vline(gx, gy, 12 + Math.floor(hash(gx, gy) * 24), "b")
  }
}

function beam(c, x0, x1, y, h) {
  c.rect(x0, y - 1, x1 - x0, h + 2, "k")
  c.rect(x0, y, x1 - x0, h, "B")
  c.hline(x0, y, x1 - x0, "D")
  c.hline(x0, y + h - 1, x1 - x0, "b")
  for (let i = 0; i < 10; i++) {
    const gx = x0 + Math.floor(hash(y, i) * (x1 - x0 - 30)), gy = y + 2 + Math.floor(hash(i, y) * (h - 4))
    c.hline(gx, gy, 14 + Math.floor(hash(gx, gy) * 30), "b")
  }
}

// A knee brace from a post up into the beam.
function brace(c, x0, y0, x1, y1) {
  c.line(x0, y0, x1, y1, "k", 6)
  c.line(x0, y0, x1, y1, "B", 4)
  c.line(x0, y0 - 1, x1, y1 - 1, "D", 1)
}

// Boards laid behind the posts to hold the loose rock up; one has fallen, the rock shows through.
function lagging(c, x0, x1, y0, rows, gap) {
  for (let i = 0; i < rows; i++) {
    const y = y0 + i * 7
    if (i === gap) continue
    const ragged = Math.floor(hash(x0, i) * 6)
    c.rect(x0, y, x1 - x0 - ragged, 6, i % 2 ? "b" : "B")
    c.hline(x0, y, x1 - x0 - ragged, i % 2 ? "B" : "D")
    c.hline(x0, y + 6, x1 - x0 - ragged, "k")
    for (let j = 0; j < 3; j++) c.px(x0 + 6 + Math.floor(hash(i, j) * (x1 - x0 - 14)), y + 3, "k")  // nail heads
  }
}

// The drift running back into the dark: its mouth's timber set, smaller sets deeper in, rails into nothing.
function tunnel(c) {
  const { x0, x1, top } = TUNNEL
  c.rect(x0 + 8, top + 10, x1 - x0 - 16, LEDGE - top - 10, "1")
  const sets = [[16, 22, "b"], [30, 40, "b"], [40, 54, "1"]]
  for (const [inset, drop, col] of sets) {
    const l = x0 + 8 + inset, r = x1 - 8 - inset, t = top + 10 + drop
    c.rect(l, t, r - l, LEDGE - t, "k")
    c.rect(l - 3, t - 3, 3, LEDGE - t + 3, col)
    c.rect(r, t - 3, 3, LEDGE - t + 3, col)
    c.rect(l - 3, t - 3, r - l + 6, 3, col)
  }
  const l = x0 + 8 + 48, r = x1 - 8 - 48
  // The drift's floor and its rails, closing on the dark.
  c.poly([x0 + 8, LEDGE, x1 - 8, LEDGE, r + 4, LEDGE - 26, l - 4, LEDGE - 26], "1")
  c.line(232, LEDGE, 250, LEDGE - 24, "3")
  c.line(280, LEDGE, 262, LEDGE - 24, "3")
  for (let i = 0; i < 4; i++) {
    const y = LEDGE - 3 - i * 6, k = i * 4
    c.hline(232 + k - 1, y, 50 - 2 * k, "b")
  }
  post(c, x0, 8, top, LEDGE + 2)
  post(c, x1 - 8, 8, top, LEDGE + 2)
  beam(c, x0 - 4, x1 + 4, top, 10)
}

// The walkway the fighters stand on: packed gravel, sleepers and two rails, a sill beam at its front.
function walkway(c) {
  c.rect(0, LEDGE, W, 24, "3")
  c.noise(0, LEDGE, W, 24, "24", 0.06, 3)
  c.hline(0, LEDGE, W, "1")
  c.hline(0, LEDGE + 1, W, "2")
  for (let x = -8; x < W + 8; x += 18) {
    const lean = Math.round((x - W / 2) * 0.05)  // the sleepers run toward us, so they splay from the middle
    c.poly([x, LEDGE + 3, x + 7, LEDGE + 3, x + 8 + lean, LEDGE + 17, x + lean, LEDGE + 17], "B")
    c.line(x, LEDGE + 3, x + lean, LEDGE + 16, "D")
    c.hline(x + lean, LEDGE + 17, 9, "b")
  }
  c.hline(0, LEDGE + 5, W, "7")
  c.hline(0, LEDGE + 6, W, "5")
  c.hline(0, LEDGE + 7, W, "1")
  c.hline(0, LEDGE + 13, W, "8")
  c.hline(0, LEDGE + 14, W, "6")
  c.hline(0, LEDGE + 15, W, "5")
  c.hline(0, LEDGE + 16, W, "1")
  // The front sill, then the drop under it into the dark (the dice tray covers it).
  beam(c, 0, W, LEDGE + 24, 6)
  c.rect(0, LEDGE + 31, W, H - LEDGE - 31, "1")
  c.dither(0, LEDGE + 31, W, 4, "1", "k", 0.5)  // the sill's shadow
}

// A leak: a wet streak down from the beam (darker, glinting on its lit side), a drop on its way down, a puddle.
function drip(c, x) {
  c.recolor({ 1: "k", 2: "a", 3: "a", 4: "a", b: "k", B: "b", D: "B" }, [x - 1, BEAM[1] + 1, 2, LEDGE - BEAM[1] - 1])
  c.recolor({ 1: "k", 2: "a", 3: "a", 4: "a", b: "k", B: "b", D: "B" }, [x - 2, BEAM[1] + 20, 4, LEDGE - BEAM[1] - 20], 0.5)
  for (let y = BEAM[1] + 14; y < LEDGE - 4; y += 24 + Math.floor(hash(x, y) * 30)) c.px(x - 1, y, "A")
  c.px(x, BEAM[1] + 1, "A")
  c.px(x, BEAM[1] + 2, "9")
  c.vline(x, BEAM[1] + 40 + Math.floor(hash(x, 3) * 60), 2, "A")
  c.ellipse(x + 3, LEDGE + 10, 9, 2, "a")
  c.hline(x, LEDGE + 9, 3, "A")
  c.px(x + 6, LEDGE + 11, "A")
}

// A miner's lantern: iron cap and base, glass round the flame. Its 3x4 glass is where `lantern` plays.
function lantern(c, x, y) {
  c.px(x + 3, y - 1, "5")
  c.vline(x + 3, y - 4, 3, "4")
  c.grid(x, y, `
    ..252..
    .24442.
    2444442
    k5wyw5k
    k5yyy5k
    k5yoy5k
    k5RoR5k
    2r444r2
    .24442.
    ..k2k..`)
}

anim("lantern", { w: 3, h: 4, fps: 6 }, grid(0, 0, "wyw\nyyy\nyoy\nRoR"),
  frame(),
  frame(grid(0, 0, "ywy\nywy")),
  frame(grid(0, 0, "yyw\nyyy\noyo")),
  frame(grid(0, 0, "ywy\nwyy\nyoy\nooR")),
  frame(grid(0, 0, "yyy\nyoy\nRoo")))

scene("bg_mine", { w: W, h: H, bg: "1" },
  wall,
  (c) => {
    c.rect(0, 0, W, BEAM[0], "1")  // the roof over the beam, beyond the light
    for (let x = -10; x < W; x += 18 + Math.floor(hash(x, 4) * 20)) rock(c, x + 16, 6 + Math.floor(hash(x, 5) * 8), 14 + Math.floor(hash(x, 6) * 8), 6 + Math.floor(hash(x, 8) * 4), ["k", "1", "2", null], x)
    lagging(c, 34, 148, BEAM[1] + 1, 9, 4)
    lagging(c, 364, 478, BEAM[1] + 1, 9, 6)
    tunnel(c)
    for (const [x, w] of POSTS) post(c, x, w, BEAM[1], LEDGE + 2)
    beam(c, 0, W, BEAM[0], BEAM[1] - BEAM[0])
    brace(c, 36, 60, 56, BEAM[1] + 1)
    brace(c, 146, 58, 126, BEAM[1] + 1)
    brace(c, 160, 58, 180, BEAM[1] + 1)
    brace(c, 352, 58, 332, BEAM[1] + 1)
    brace(c, 366, 58, 386, BEAM[1] + 1)
    brace(c, 476, 60, 456, BEAM[1] + 1)
    // Iron arms off the middle posts for two of the lanterns; eye bolts under the beam for the swaying chains.
    c.hline(158, 89, 9, "4")
    c.hline(337, 89, 9, "4")
    c.px(165, 90, "2")
    c.px(345, 90, "2")
    for (const [x, y] of CHAINS) c.grid(x - 1, y - 1, "5.5\n.4.")
    for (const x of DRIPS) drip(c, x)
    walkway(c)
    for (const [x, y] of LANTERNS) lantern(c, x, y)
  },
  // Away from the lanterns the mine sinks into the dark: the roof, the far ends, the drift.
  layer("dark", { shade: true }, rect(0, 0, W, BEAM[0], "k"), rect(0, 0, 18, LEDGE, "k"), rect(W - 18, 0, 18, LEDGE, "k")),
  layer("dim", { shade: true, density: 0.5 }, rect(0, BEAM[0], W, 10, "k"), rect(18, 0, 30, LEDGE, "k"), rect(W - 48, 0, 30, LEDGE, "k")),
  // Only the lanterns light it: warm pools that fade into near-black, a faint cold breath from deep in the drift.
  (c) => light(c, LAMPS, { deep: [256, 166, 34] }),
  glow("oyw", { r: 36, strength: 0.2, bands: 5, color: "#e8743c" }),
  glow("oyw", { r: 9, strength: 0.25, bands: 2, color: "#f6b45e" }))

// A free-hanging chain as a BackdropLife sway strip: 5 frames, each sheared about its top row so the bottom row
// sits -2..+2 pxl pixels off (frame 2 hangs straight), drawn at 2 image px a pixel, with 2 pxl pixels of room
// either side. `rows` is the chain's pixel grid; its top row hangs from an eye bolt under the beam.
function chain(name, rows, [cx, cy], half) {
  const g = rows.trim().split("\n").map((r) => r.trim())
  const w = g[0].length, h = g.length
  anim(name, { w: (w + 4) * 2, h: h * 2, frames: 5, fps: 8 }, (c) => {
    for (let y = 0; y < h; y++) {
      const shift = Math.round(((c.frame - 2) * y) / (h - 1))
      for (let x = 0; x < w; x++) if (g[y][x] !== ".") c.rect((x + 2 + shift) * 2, y * 2, 2, 2, g[y][x])
    }
    light(c, LAMPS, { at: [cx - half - 2, cy], px: 2 })
  })
}

// Links, alternating face-on (a ring) and edge-on (a bar); `n` of them, `w` wide grids centred.
function links(n, w) {
  const pad = (s) => ".".repeat((w - s.length) >> 1) + s + ".".repeat(w - s.length - ((w - s.length) >> 1))
  const out = []
  for (let i = 0; i < n; i++) out.push(...(i % 2 ? [".4.", ".5.", ".2."] : [".5.", "5.4", "5.4", ".2."]).map(pad))
  return out.join("\n")
}

const HOOK = `
.5..
.5..
.5.4
.5.4
..42`.trim()
// A lantern that has gone out, on a long chain over the walkway's right.
const DEAD = `
..252..
.24442.
2444442
k51315k
k53115k
k51115k
k51315k
2r444r2
.24442.
..k2k..`

chain("chain_mine_0", links(10, 4) + "\n" + HOOK, CHAINS[0], 1)
chain("chain_mine_1", links(14, 7) + "\n" + DEAD.trim(), CHAINS[1], 3)
chain("chain_mine_2", links(5, 4) + "\n" + HOOK, CHAINS[2], 1)

// Dust hanging in the lantern light over the walkway: a still band two `period`s wide that tiles seamlessly, as
// BackdropLife scrolls it a pxl pixel at a time. Motes thin out upward; a faint haze lies along the bottom.
const DUST_PERIOD = 128
pal({ m: "#6e624e50", n: "#8e7e6270", h: "#24262c26" })  // dim: most of the band hangs out of the lamplight
sprite("dust", { w: DUST_PERIOD * 2, h: 40 }, (c) => {
  for (let x = 0; x < c.w; x++) {
    const px = x % DUST_PERIOD
    for (let y = 0; y < c.h; y++) {
      const v = hash(px, y)
      if (v < 0.006 + 0.012 * (y / c.h)) c.px(x, y, v < 0.004 ? "n" : "m")
    }
    const top = c.h - 8 + Math.round(2 * Math.sin((2 * Math.PI * px) / DUST_PERIOD) + Math.sin((6 * Math.PI * px) / DUST_PERIOD))
    for (let y = top; y < c.h; y++) if (!c.is(x, y, "*")) c.px(x, y, "h")
  }
})
