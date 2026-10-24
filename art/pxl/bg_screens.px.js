// The stills behind the title menu, camp, campfire, forge and the two end-of-run notices, drawn with the same
// perspective kit as the "?" events (kit.px.js; art/events/art-direction-brief.md). 512x286 pxl pixels, 2 image px
// each in the game (1024x572). The menu's swaying chains are BackdropLife strips drawn here too; the menu and camp
// flames are painted here from screen_flames.px.js and looped by life.px.js.
// Layout, in pxl pixels (1280x720 screen, 2.517 screen px a pixel, the image cropped 1.8 px each side):
// - menu: logo x 93-419, y 75-131; buttons x 200-312, y 165-255. The gate sits behind the buttons, braziers and
//   chains beside them, the moat (and its fog) along the bottom.
// - camp: perk cards x 10-500, y 78-235; buttons y 258-276; the strip y 235-258 and the top band are what shows.
// - notices (campfire, forge's free upgrade, victory, defeat): title and lines y 85-170, buttons to y 195, centred.
// - forge: heading and three rows of die faces x 160-350, y 75-210.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/bg_screens.px.js --out <scratch>
// then each <scratch>/scenes/bg_<name>.png doubled (nearest) and saved lossless as assets/ui/bg_<name>.webp, and
// <scratch>/anims/chain_menu_*.png + .json copied to assets/ui/life/ (drawn at 2 image px a pixel already).
include("kit.px.js")
include("screen_flames.px.js")

// The rows of a grid string, trimmed.
const rowsOf = (g) => g.trim().split("\n").map((r) => r.trim())
// Paints a grid string with its top-left at (x, y), skipping ".".
function paint(c, g, x, y) {
  rowsOf(g).forEach((r, j) => [...r].forEach((k, i) => k !== "." && c.px(x + i, y + j, k)))
}
// A painted flame mask standing on (x, y), its bottom row's middle there; returns its top-left (for LIFE).
function maskAt(c, g, x, y) {
  const r = rowsOf(g), x0 = x - (r[0].length >> 1), y0 = y - r.length
  paint(c, g, x0, y0)
  return [x0, y0]
}
// Runs draw() and gives only the pixels it changed inside [x, y, w, h] the world point p and normal n, so the
// relight treats a prop painted on screen as standing there (place() for the pixels it actually covers).
function prop(c, G, [x, y, w, h], p, n, draw) {
  const before = []
  for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) before.push(c.get(xx, yy))
  draw()
  let i = 0
  for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) if (c.get(xx, yy) !== before[i++]) place(G, xx, yy, 1, 1, p, n)
}
const mix = (a, b, t) => "#" + [0, 1, 2].map((j) => Math.round(parseInt(a.substr(1 + j * 2, 2), 16) * (1 - t) + parseInt(b.substr(1 + j * 2, 2), 16) * t).toString(16).padStart(2, "0")).join("")
// A sky over whatever the render left unhit: `stops` [[y, hex]...] blended in dithered bands, stars above
// `starsTo`.
function sky(c, G, stops, { starsTo = 0, star = "#4c4e55" } = {}) {
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      if (G.hit[y * W + x]) continue
      let i = 0
      while (i < stops.length - 2 && y > stops[i + 1][0]) i++
      const [y0, a] = stops[i], [y1, b] = stops[i + 1]
      const t = Math.max(0, Math.min(1, (y - y0) / (y1 - y0)))
      const q = Math.floor(t * 6 + BAYER[(y & 3) * 4 + (x & 3)] / 16) / 6
      c.px(x, y, mix(a, b, Math.min(1, q)))
      if (y < starsTo && hash(x, y * 3) < 0.0035) c.px(x, y, star)
    }
}

// ======== Title menu: the Sunken Chapel across its moat at night. A landing over black water, steps down into
// it; the chapel front close behind it: a broad round-headed gate whose dark crown shows between the logo and the
// buttons, its passage going down into the dark; a steep gable with a round window over it and a square tower either
// side, rising past the logo into the sky; braziers either side of the gate, gravestones; near-black piers in the moat
// at the frame's edges; four chains hanging into the frame, a pair before each tower; the moon. ========
const M = { water: -0.8, quay: 5.6, face: 7.5, gate: { hw: 1.93, spring: 0.52 }, brazier: [[-2.75, 6.2], [2.75, 6.2]], bowl: 1.12, tower: { x0: 4.9, x1: 6.9, z0: 6.6, top: 5.0 } }
// The swaying chains: x of their middle, y of their top row (they hang into the frame from above).
const MENU_CHAINS = [[42, 0], [70, 0], [442, 0], [470, 0]]
const MOON = [386, 34, 9]
function waterMat(p, n, s) {
  const row = Math.floor(p[2] / 0.16), seg = Math.floor((p[0] + hash(row, 1) * 3) / 0.6)
  return hash(row, seg) > 0.82 && p[2] - row * 0.16 < s * 1.1 ? "A" : "a"
}
// The chapel front between the towers: a steep gable over the gate, coursed wall either side with a ragged top.
function facadeTop(x) {
  return Math.max(5.0 - Math.abs(x) * 0.85, 3.25 + (hash(Math.floor(x / 0.5), 3) - 0.5) * 0.5)
}
still("bg_menu", (C) => {
  const { water, quay, face, gate, tower: T } = M
  const FACE = stone({ seed: 71, calm: 99, crack: 0.08 })
  const QUAY = stone({ course: 0.4, len: 0.9, face: "3", dark: "2", mortar: "1", lit: "4", seed: 72 })
  const ROSE = [0, 4.25, 0.4]  // the gable's round window: x, y, radius
  const wall = (p, n, s) => {
    const r = Math.hypot(p[0] - ROSE[0], p[1] - ROSE[1])
    if (r < ROSE[2]) return r < ROSE[2] - 0.1 ? (Math.abs(p[0]) < s || Math.abs(p[1] - ROSE[1]) < s ? "2" : "0") : r > ROSE[2] - s ? "1" : "4"
    return FACE(p, n, s)
  }
  const arch = archFace(gate.hw, gate.spring, wall, { ring: 0.46, jamb: 0.36 })
  // archFace runs its jambs all the way up; above the ring the wall goes on as wall
  const front = (p, n, s) => (Math.hypot(p[0], p[1] - gate.spring) > gate.hw + 0.46 && p[1] > gate.spring ? wall(p, n, s) : arch(p, n, s))
  const towerMat = (p, n, s) => {
    const cx = Math.sign(p[0]) * (T.x0 + T.x1) / 2
    if (n[2] < -0.5 && Math.abs(p[0] - cx) < 0.09 && p[1] > 2.6 && p[1] < 3.4) return "0"  // an arrow slit
    return FACE(p, n, s)
  }
  const steps = []
  for (let k = 1; k <= 4; k++) steps.push(box([-1.7, water, quay - 0.3 * k], [1.7, -0.2 * k, quay], DRESSED, { cast: false }))
  const inner = []
  for (let k = 1; k <= 9; k++) inner.push(box([-gate.hw, -6, face + 0.6 + 0.4 * (k - 1)], [gate.hw, -0.24 * k, 18], RECESS, { cast: false }))
  const stand = ([x, z]) => [
    box([x - 0.05, 0, z - 0.05], [x + 0.05, M.bowl - 0.2, z + 0.05], flat("1")),
    box([x - 0.16, 0, z - 0.16], [x + 0.16, 0.08, z + 0.16], flat("2")),
    cylinder(x, z, 0.3, M.bowl - 0.22, M.bowl, (p, n) => (n[1] > 0.5 ? "R" : hash(Math.round(p[1] * 40), 1) < 0.3 ? "r" : "1")),
  ]
  const grave = (x, z, w, h) => {
    const m = stone({ course: 0.3, len: 2, face: "4", dark: "3", lit: "5", seed: 73 + x })
    return [box([x - w / 2, 0, z], [x + w / 2, h, z + 0.16], m), mound([x, h, z + 0.08], [w / 2, w * 0.4, 0.08], m)]
  }
  const towers = [-1, 1].flatMap((k) => {
    const a = k * T.x0, b = k * T.x1, lo = Math.min(a, b), hi = Math.max(a, b)
    const out = [box([lo, 0, T.z0], [hi, T.top, face + 0.6], towerMat)]
    for (let i = 0; i < 4; i++) out.push(box([lo + i * 0.55, T.top, T.z0], [lo + i * 0.55 + 0.32, T.top + 0.4, T.z0 + 0.4], towerMat))  // merlons
    return out
  })
  return {
    prims: [
      floorPlane((x, z) => z < quay + 0.5, waterMat, water),
      box([-14, water, quay], [14, 0, face + 1.2], (p, n, s) => (n[1] > 0.5 ? FLAGS(p, n, s) : QUAY(p, n, s)), { cast: false }),
      plane(2, face, (x, y) => Math.abs(x) < T.x0 && y < facadeTop(x) && !archHole(gate.hw, gate.spring)(x, y), front),
      ...towers,
      ...steps,
      box([-2.05, water, quay - 1.3], [-1.7, 0.25, quay], DRESSED), box([1.7, water, quay - 1.3], [2.05, 0.25, quay], DRESSED),  // the stair's cheeks
      // through the gate: a passage, its stair going down into the dark
      ...inner,
      sideWall(-gate.hw, face, 18, gate.spring + gate.hw, RECESS), sideWall(gate.hw, face, 18, gate.spring + gate.hw, RECESS),
      vault(0, gate.spring, gate.hw, face, 18, vaultStone()),
      backWall(18, gate.hw, gate.spring + gate.hw, flat("0")),
      ...M.brazier.flatMap(stand),
      ...grave(-4.0, 6.6, 0.6, 0.6), ...grave(-4.45, 7.15, 0.5, 0.45), ...grave(4.0, 6.7, 0.6, 0.55), ...grave(4.45, 7.2, 0.5, 0.4),
      box([-8, water, 4.3], [-4.4, 20, 4.8], FRAME, { fg: 2 }), box([4.4, water, 4.3], [8, 20, 4.8], FRAME, { fg: 2 }),  // piers in the moat
    ],
    lamps: M.brazier.map(([x, z]) => ({ p: [x, M.bowl + 0.25, z - 0.1], reach: 5.2, power: 1.1, lift: 3.4 })),
  }
}, (c, C, G) => {
  sky(c, G, [[0, "#07090c"], [60, "#0f141a"], [130, "#1a2029"]], { starsTo: 120 })
  // the moon and its halo: dithered steps toward a pale slate, thinning out with distance
  const [mx, my, mr] = MOON
  for (let y = my - 40; y <= my + 40; y++)
    for (let x = mx - 40; x <= mx + 40; x++) {
      if (y < 0 || G.hit[y * W + x]) continue
      const d = Math.hypot(x - mx, y - my), th = BAYER[(y & 3) * 4 + (x & 3)] / 16
      const here = "#" + ((c.get(x, y) >>> 8) & 0xffffff).toString(16).padStart(6, "0")
      if (d <= mr) c.px(x, y, Math.hypot(x - mx + 3, y - my - 2) < 3 || Math.hypot(x - mx - 3, y - my + 3) < 2 ? "#7f98a0" : "#b4ccd0")
      else if (d < mr + 6 && th < 1 - (d - mr) / 6) c.px(x, y, mix(here, "#3c4a54", 0.75))  // a close step round the disc
      else if (d < 38 && th < 0.55 * (1 - (d - mr) / (38 - mr)) ** 1.4) c.px(x, y, mix(here, "#2c3640", 0.7))  // then a thinning checker
    }
  for (const [x, z] of M.brazier) {
    const [bx, by] = project(C, x, M.bowl, z)
    maskAt(c, TORCH_MASK, bx, by)
    const [, wy] = project(C, x, M.water, z - 1.4)  // the fire caught in the moat
    for (let i = 0; i < 7; i++) c.hline(bx - 2 + (i % 2), wy + i * 2, 3 - (i > 3 ? 1 : 0), i < 3 ? "o" : "R")
  }
  for (let i = 0; i < 6; i++) c.hline(mx - 3 + (i % 3), 266 + i * 3, 4, "c")  // and the moon
}, { amb: 0.95, near: [0.74, 0.82, 0.96], far: [0.64, 0.72, 0.98], fog: 14 })

// The menu's chains: links alternating face-on and edge-on, hanging into the frame from above, a pair before each
// tower, ending in hooks and shackles. Coloured as they'd be lit there: cold iron, warmer toward the braziers.
function links(n, w) {
  const pad = (s) => ".".repeat((w - s.length) >> 1) + s + ".".repeat(w - s.length - ((w - s.length) >> 1))
  const out = []
  for (let i = 0; i < n; i++) out.push(...(i % 2 ? [".6.", ".5.", ".5.", ".2."] : [".66.", "6..4", "5..4", "5..3", ".23."]).map(pad))
  return out.join("\n")
}
const HOOK = ".6...\n.5...\n.5..4\n.5..4\n.5.43\n..42."
const SHACKLE = ".6664.\n6....4\n5....4\n5....3\n.2..2."
const BRAZIERS_ON_SCREEN = M.brazier.map(([x, z]) => project(EYE, x, M.bowl, z))
// A BackdropLife sway strip: 5 frames, each sheared about its top row so the bottom row sits -2..+2 pxl pixels
// off (frame 2 hangs straight), drawn at 2 image px a pixel with 2 pxl pixels of room either side. LIFE.menu sets
// it at image px (2 * (x - half - 2), 2 * y), half being half the grid's width rounded down.
function chain(name, g, [cx, cy]) {
  const rows = rowsOf(g), w = rows[0].length, h = rows.length, half = w >> 1
  anim(name, { w: (w + 4) * 2, h: h * 2, frames: 5, fps: 8 }, (c) => {
    for (let y = 0; y < h; y++) {
      const shift = Math.round(((c.frame - 2) * y) / (h - 1))
      for (let x = 0; x < w; x++) {
        if (rows[y][x] === ".") continue
        const sy = cy + y, sx = cx - half + x
        const [bx, by] = BRAZIERS_ON_SCREEN[sx < 256 ? 0 : 1]
        const warm = Math.max(0, 1 - Math.hypot(sx - bx, sy - by) / 190) ** 2
        const amb = 0.85 * Math.min(1, 0.5 + sy / 200)
        c.rect((x + 2 + shift) * 2, y * 2, 2, 2, rows[y][x])
        const p = c.get((x + 2 + shift) * 2, y * 2) >>> 0
        const ch = (sh, j) => Math.min(255, Math.round(((p >>> sh) & 255) * (amb * [0.74, 0.84, 1][j] + warm * 1.6 * FIRE[j])))
        c.rect((x + 2 + shift) * 2, y * 2, 2, 2, "#" + [24, 16, 8].map((sh, j) => ch(sh, j).toString(16).padStart(2, "0")).join(""))
      }
    }
  })
}
chain("chain_menu_0", links(26, 6) + "\n" + SHACKLE, MENU_CHAINS[0])
chain("chain_menu_1", links(19, 5) + "\n" + HOOK, MENU_CHAINS[1])
chain("chain_menu_2", links(21, 5) + "\n" + HOOK, MENU_CHAINS[2])
chain("chain_menu_3", links(27, 6) + "\n" + SHACKLE, MENU_CHAINS[3])

// A sloped plane n.p = d (n unit), kept where bounds(x, y, z) holds: tent canvas, a lean-to.
const slope = (n, d, bounds, mat, opts = {}) => ({ kind: "slope", n, d, bounds, mat, cast: true, ...opts })
HIT.slope = (P, o, dir) => {
  const nd = P.n[0] * dir[0] + P.n[1] * dir[1] + P.n[2] * dir[2]
  if (Math.abs(nd) < 1e-9) return null
  const t = (P.d - (P.n[0] * o[0] + P.n[1] * o[1] + P.n[2] * o[2])) / nd
  if (t <= 1e-4) return null
  const p = [o[0] + t * dir[0], o[1] + t * dir[1], o[2] + t * dir[2]]
  if (!P.bounds(p[0], p[1], p[2])) return null
  return { t, p, n: nd > 0 ? P.n.map((v) => -v) : P.n }
}
// A ridge tent along z: ridge at x = xc, `h` high, `b` either side of it, from z0 to z1; its open front a dark
// triangle a little way in.
function tent(xc, b, h, z0, z1, mat) {
  const l = Math.hypot(h, b), out = []
  for (const k of [-1, 1]) {
    const n = [(k * h) / l, b / l, 0]
    out.push(slope(n, n[0] * (xc + k * b), (x, y, z) => z >= z0 && z <= z1 && y >= 0 && y <= h && k * (x - xc) >= 0, mat))
  }
  out.push(plane(2, z0 + 0.4, (x, y) => y >= 0 && y <= h * (1 - Math.abs(x - xc) / b), flat("k")))
  return out
}
// Bare ground: packed earth, a few darker patches of leaf rot, a stone now and then.
function earth(p, n, s) {
  const f = Math.sin(p[0] * 1.3 + p[2] * 0.7) + Math.sin(p[2] * 2.1 - p[0] * 0.5) + 0.5 * Math.sin(p[0] * 4.1 + p[2] * 3.3)
  const j = Math.floor(p[2] / 0.07), i = Math.floor(p[0] / 0.09 + hash(j, 2) * 3), h = hash(i, j)
  if (h > 0.985) return "4"  // a stone
  if (h < 0.05) return "B"  // a dead leaf
  return f > 1.1 ? "1" : h < 0.3 ? "b" : "2"
}
// Dead bark: deep furrows running up the trunk, the ridges between them catching what light there is, a knot here
// and there.
function bark(p, n, s) {
  const a = Math.atan2(n[2], n[0]) * 7 + Math.sin(p[1] * 2.3 + p[0]) * 0.5, f = a - Math.floor(a), col = Math.floor(a)
  if (f < 0.2) return "0"
  if (f < 0.32) return "1"
  if (hash(col, Math.floor(p[1] / 0.5)) < 0.06) return "1"  // a knot
  return f > 0.82 ? "4" : hash(col, 3) < 0.4 ? "b" : "3"
}

// ======== Camp: a clearing in a dead wood at night, behind the perk board. Seen from low down, so the ground and
// everything on it sits in the strip between the cards and the buttons (screen y 590-650): a fire low on the left,
// the trunk bases round it lit warm; a log with a shield propped on it; a low ridge tent; a ruined wall either side
// beyond. Near trunks crop the frame's edges, farther ones sink into the dark; bare branches over the top band. ========
const CAMP_EYE = camera(256, 236, 256, 0.6)
const CAMP = { fire: [-4.4, 7.6], log: [-3.35, 7.15], tent: [1.6, 7.8],
  trees: [[-2.75, 3.0, 0.5, 1], [2.95, 3.2, 0.5, 1], [-7.2, 9.0, 0.34], [-5.7, 10.8, 0.3], [-2.5, 9.6, 0.28], [0.2, 12.5, 0.26], [3.7, 11.6, 0.3],
    [6.4, 9.4, 0.36], [-1.4, 16, 0.22], [2.2, 17.5, 0.2], [5.4, 16.5, 0.22], [-4.6, 18, 0.2], [-8.6, 15, 0.24]] }
still("bg_camp", (C) => {
  const [fx, fz] = CAMP.fire
  const canvas = (p, n, s) => {
    const seam = Math.abs(((p[2] + 0.02) % 0.7)) < s * 1.1
    return seam ? "b" : hash(Math.floor(p[2] / 0.7), Math.floor(p[1] / 0.3)) < 0.2 ? "b" : "B"
  }
  const ruin = (x0, x1, z, seed) => {  // a broken run of wall: blocks of uneven height
    const out = []
    for (let x = x0, i = 0; x < x1; x += 0.6, i++) out.push(box([x, 0, z], [Math.min(x1, x + 0.6), 0.9 + hash(i, seed) * 1.4, z + 0.5], stone({ seed: seed + i, calm: 99, crack: 0.1 })))
    return out
  }
  return {
    prims: [
      floorPlane((x, z) => z < 40, earth),
      ...Array.from({ length: 8 }, (_, i) => cylinder(-16 + i * 4.2 + hash(i, 1) * 2, 21 + hash(i, 2) * 9, 0.18 + hash(i, 3) * 0.12, 0, 40, bark)),
      ...CAMP.trees.map(([x, z, r, near]) => cylinder(x, z, r, 0, 40, bark, near ? { fg: 1 } : {})),
      ...ruin(3.0, 7.8, 13, 91), ...ruin(-10.6, -7.6, 13.5, 95),
      ...tent(CAMP.tent[0], 1.0, 0.68, CAMP.tent[1], CAMP.tent[1] + 2, canvas),
      ...[0, 1, 2, 3, 4, 5, 6, 7].map((i) => { const a = (i / 8) * Math.PI * 2; return box([fx + Math.cos(a) * 0.45 - 0.07, 0, fz + Math.sin(a) * 0.26 - 0.05], [fx + Math.cos(a) * 0.45 + 0.07, 0.1, fz + Math.sin(a) * 0.26 + 0.05], (p, n) => (n[1] > 0.5 ? "4" : "2"), { cast: false }) }),  // the fire's ring of stones
    ],
    lamps: [{ p: [fx, 0.45, fz], reach: 8.5, power: 1.8, lift: 6 }, { p: [fx, 1.2, fz], reach: 5, power: 0.4, lift: 6 }],
  }
}, (c, C, G) => {
  sky(c, G, [[0, "#0a0c0f"], [60, "#14181d"], [150, "#1d2229"]])
  for (let y = 4; y < 80; y++)  // a cloud bank, barely lit
    for (let x = 0; x < W; x++) {
      if (G.hit[y * W + x]) continue
      const e = 36 + 9 * Math.sin(x * 0.03) + 6 * Math.sin(x * 0.071 + 1)
      if (Math.abs(y - e) < 7 + 4 * Math.sin(x * 0.05)) c.px(x, y, Math.abs(y - e) < 2 ? "#2a2f35" : "#22272d")
    }
  // bare branches off every trunk, the near ones thick and black, the far ones thinner
  // forking: each limb splits in two, thinner, bending away and up
  const limb = (x, y, a, len, w, col, seed, depth) => {
    const x1 = x + Math.cos(a) * len, y1 = y - Math.sin(a) * len
    c.line(Math.round(x), Math.round(y), Math.round(x1), Math.round(y1), col, Math.max(1, Math.round(w)))
    if (depth === 0 || len < 4) return
    for (const k of [-1, 1]) limb(x1, y1, a + k * (0.35 + hash(seed, k + depth) * 0.4), len * (0.55 + hash(seed + k, depth) * 0.25), w * 0.6, col, seed * 3 + k, depth - 1)
  }
  for (const [x, z, r, near] of CAMP.trees) {
    const [tx] = project(C, x, 0, z), d = 1 / z, half = Math.round((r * 256) / z)
    const col = near ? "k" : "0", w = near ? 5 : Math.max(1, d * 26)
    for (let i = 0; i < (near ? 4 : 3); i++) {
      const side = (i + (x > 0 ? 1 : 0)) % 2 ? 1 : -1, y0 = Math.round((near ? 8 : 20) + i * (near ? 24 : 18) + hash(x, i) * 10)
      const a = side > 0 ? 0.35 + hash(i, x) * 0.5 : Math.PI - 0.35 - hash(i, x) * 0.5
      limb(tx + side * (half - 1), y0, a, (near ? 46 : 80 * d * 6) * (0.7 + hash(x, i + 7) * 0.5), w, col, i + x * 10, near ? 3 : 2)
    }
  }
  const [fx, fz] = CAMP.fire
  const [lx, ly] = project(C, fx, 0.04, fz)
  logFire(c, lx, ly, 24, 3)
  place(G, lx - 12, ly - 5, 25, 7, [fx, 0.08, fz - 0.2])
  maskAt(c, CAMPFIRE_MASK, lx, ly - 2)
  const [gx, gy] = project(C, CAMP.log[0], 0, CAMP.log[1])  // a log to sit on, its cut end toward the fire
  prop(c, G, [gx - 6, gy - 12, 44, 14], [CAMP.log[0] + 0.4, 0.15, CAMP.log[1]], [-0.6, 0.6, -0.5], () => {
    c.rect(gx, gy - 10, 32, 10, "b")
    c.hline(gx, gy - 10, 32, "B"); c.hline(gx, gy - 9, 32, "B"); c.hline(gx, gy - 2, 32, "1"); c.hline(gx, gy - 1, 32, "1")
    c.hline(gx - 1, gy, 35, "0")  // its contact shadow
    for (const [k, l] of [[4, 9], [15, 12], [24, 6]]) c.hline(gx + k, gy - 6 + (k % 3), l, "1")  // bark splits
    c.ellipse(gx, gy - 5, 4, 5, "D"); c.ellipse(gx, gy - 5, 2, 3, "B"); c.px(gx, gy - 5, "b")  // the cut end, lit
  })
  const [sx, sy] = project(C, CAMP.log[0] + 1.0, 0, CAMP.log[1] + 0.05)
  shield(c, G, sx, sy - 1, 10, [CAMP.log[0] + 1.0, 0.3, CAMP.log[1]], [-0.7, 0.2, -0.68])
}, { amb: 0.75, near: [0.8, 0.82, 0.9], far: [0.66, 0.7, 0.84], fog: 14 }, null, CAMP_EYE)

// A fire of a few tongues standing on (x, y), `h` tall and `w` wide at its base: R rim, o, y, w core.
function bigFlame(c, x, y, h, w, seed = 0) {
  const tongues = [[-0.55, 0.55], [-0.25, 0.85], [0.05, 1], [0.32, 0.75], [0.58, 0.5]]
  for (const [band, k, shrink] of [["R", 0, 0], ["o", 1, 0.18], ["y", 2, 0.38], ["w", 3, 0.6]])
    for (const [u, th] of tongues) {
      const hh = Math.round(h * th * (1 - shrink * 0.9) * (0.85 + 0.3 * hash(u * 9 + seed, k)))
      const bw = Math.max(1, Math.round((w / 2) * (1 - shrink) * 0.55))
      const cx = Math.round(x + u * w * 0.5 * (1 - shrink * 0.6))
      if (hh < 1) continue
      c.poly([cx - bw, y, cx + bw, y, cx + Math.round(bw * 0.25) + (hash(u, seed) < 0.5 ? 1 : -1), y - hh, cx - Math.round(bw * 0.2), y - hh + 1], band)
    }
}
// Burning logs crossed over a bed of embers, standing on (x, y).
function logFire(c, x, y, w, seed = 0) {
  embers(c, x - (w >> 1), y - 2, w, 3, seed)
  c.line(x - (w >> 1), y + 1, x + (w >> 1) - 2, y - 4, "b", 3)
  c.line(x - (w >> 1) + 2, y - 4, x + (w >> 1), y + 1, "1", 3)
  c.line(x - (w >> 1) + 1, y, x + (w >> 1) - 3, y - 5, "B", 1)
}
// A rolled bedroll lying across the floor, its end toward the right, bottom-left at (x, y), `len` long.
function bedroll(c, G, x, y, len, p, n) {
  prop(c, G, [x, y - 13, len + 6, 15], p, n, () => {
    c.rect(x, y - 12, len, 12, "3")
    c.hline(x + 1, y + 1, len + 2, "0"); c.hline(x, y, len, "0")  // its contact shadow
    c.hline(x + 1, y - 12, len - 2, "4"); c.hline(x, y - 11, len, "4"); c.hline(x, y - 10, len, "4")
    c.hline(x, y - 4, len, "2"); c.hline(x, y - 3, len, "2"); c.hline(x, y - 2, len, "1"); c.hline(x + 1, y - 1, len - 2, "1")
    for (const k of [Math.round(len * 0.22), Math.round(len * 0.74)]) { c.rect(x + k, y - 12, 2, 12, "b"); c.vline(x + k + 1, y - 12, 12, "1"); c.px(x + k, y - 11, "B") }  // the ties
    c.ellipse(x + len, y - 6, 4, 6, "4")
    c.ellipse(x + len, y - 6, 3, 4, "2")
    c.ellipse(x + len, y - 6, 1, 2, "4")
  })
}
// A round wooden shield standing on its rim at (x, y), radius r: iron rim, planks, a boss.
function shield(c, G, x, y, r, p, n) {
  prop(c, G, [x - r - 1, y - 2 * r - 2, 2 * r + 3, 2 * r + 3], p, n, () => {
    c.ellipse(x, y - r, r, r + 1, "0")
    c.ellipse(x, y - r, r - 1, r, "3")
    c.ellipse(x, y - r, r - 3, r - 2, "b")
    c.ellipse(x - 1, y - r - 1, r - 5, r - 4, "B")
    c.ellipse(x + 1, y - r, r - 5, r - 4, "b")
    for (const k of [-0.45, 0, 0.45]) c.vline(x + Math.round(k * r), y - 2 * r + 4, 2 * r - 6, "1")
    c.px(x - r + 1, y - r - 2, "5"); c.px(x - r + 1, y - r - 1, "4")
    c.ellipse(x, y - r, 2, 2, "4"); c.px(x - 1, y - r - 1, "5")
  })
}

// ======== Campfire: a resting spot in the crypt. A low fire on the flags in the middle of a short vaulted hall, a
// bedroll and a shield beside it; behind, an arched apse whose stair climbs away into the dark; a doorway off the
// left wall; framing piers. The fire is the only light. ========
still("bg_campfire", (C) => {
  const HW = 3.0, BACK = 8.2, A = { hw: 1.15, spring: 1.9, depth: 12 }
  const door = (z, y) => z > 5.0 && z < 6.1 && (y < 1.6 || Math.hypot(z - 5.55, y - 1.6) < 0.55)
  const climb = []
  for (let k = 0; k < 7; k++) climb.push(box([-A.hw, 0, BACK + 0.6 + k * 0.38], [A.hw, 0.18 * (k + 1), A.depth], RECESS, { cast: false }))
  return {
    prims: [
      ...nave({ hw: HW, back: BACK, top: 3.6, backMat: archFace(A.hw, A.spring, WALL), hole: archHole(A.hw, A.spring), frame: false }),
      ceiling(3.6, (x, z) => Math.abs(x) < HW && z < BACK, stone({ course: 0.9, len: 0.6, face: "4", dark: "3", mortar: "1", lit: "4" })),
      floorPlane((x, z) => z >= BACK && z < A.depth && Math.abs(x) < A.hw, RECESS),
      sideWall(-A.hw, BACK, A.depth, A.spring + A.hw + 2, RECESS), sideWall(A.hw, BACK, A.depth, A.spring + A.hw + 2, RECESS),
      vault(0, A.spring + 1.3, A.hw, BACK, A.depth, vaultStone()),
      backWall(A.depth, A.hw, A.spring + A.hw + 2, flat("0")),
      ...climb,
      sideWall(-HW, 0, BACK, 3.6, WALL, door),
      floorPlane((x, z) => x < -HW && x > -HW - 2 && z > 5.0 && z < 6.1, RECESS),
      plane(2, 5.0, (x, y) => x < -HW && x > -HW - 2 && y < 2.2, RECESS), plane(2, 6.1, (x, y) => x < -HW && x > -HW - 2 && y < 2.2, RECESS),
      sideWall(-HW - 2, 5.0, 6.1, 2.2, flat("0")),
      ceiling(2.15, (x, z) => x < -HW && x > -HW - 2 && z > 5.0 && z < 6.1, flat("0")),
      pillar(-HW, 6.6, 0.45, 0.5, PIER), pillar(HW - 0.45, 6.6, 0.45, 0.5, PIER),
      ...framing(-2.15, 2.15, 2.2, 0.3, true),
      ...[0, 1, 2, 3, 4, 5, 6, 7].map((i) => { const a = (i / 8) * Math.PI * 2; return box([Math.cos(a) * 0.4 - 0.07, 0, 4.0 + Math.sin(a) * 0.26 - 0.05], [Math.cos(a) * 0.4 + 0.07, 0.1, 4.0 + Math.sin(a) * 0.26 + 0.05], (p, n) => (n[1] > 0.5 ? "4" : "2"), { cast: false }) }),
    ],
    lamps: [{ p: [0, 0.35, 4.0], reach: 6, power: 1.4, lift: 3 }, { p: [0, 0.9, 4.0], reach: 3.4, power: 0.4, lift: 3 }],
  }
}, (c, C, G) => {
  const [x, y] = project(C, 0, 0.04, 4.0)
  logFire(c, x, y, 32, 5)
  bigFlame(c, x, y - 2, 46, 30, 3)
  const [rx, ry] = project(C, 0.62, 0, 3.9)  // the bedroll beside it, the shield propped at its end
  bedroll(c, G, rx, ry, 44, [0.95, 0.12, 3.85], [-0.4, 0.6, -0.7])
  const [sx, sy] = project(C, 1.62, 0, 4.15)
  shield(c, G, sx, sy, 14, [1.62, 0.35, 4.1], [-0.6, 0.25, -0.75])
}, { amb: 0.75 })

// The forge's tool rack, on the left wall: a board, and hanging from it hammers, tongs and a file.
function rackMat(p, n, s) {
  const z = p[2], y = p[1]
  if (z < 2.9 || z > 5.3 || y < 0.85 || y > 1.95) return null
  if (y > 1.74) return y > 1.93 - s ? "D" : y < 1.74 + s * 1.5 ? "1" : "B"  // the board
  const i = Math.floor((z - 3.0) / 0.38), u = z - 3.0 - i * 0.38 - 0.19, kind = i % 3
  if (i < 0 || i > 5) return null
  if (Math.abs(u) < 0.02 && y > 1.7) return "1"  // its peg
  if (kind === 0) {  // a hammer, head down
    if (y < 1.12 && y > 0.94 && Math.abs(u) < 0.11) return y > 1.12 - s * 1.5 ? "5" : u < -0.08 ? "3" : "4"
    if (Math.abs(u) < 0.022 && y >= 1.12 && y < 1.72) return u < 0 ? "D" : "B"
  } else if (kind === 1) {  // tongs: two long jaws, crossed at a rivet
    const w = Math.abs(u) - Math.abs(1.38 - y) * 0.09
    if (Math.abs(w) < 0.016 && y > 0.92 && y < 1.72) return y < 1.12 ? "4" : "3"
    if (Math.hypot(u, y - 1.38) < 0.025) return "5"
  } else if (Math.abs(u) < 0.03 && y > 0.98 && y < 1.72) return y > 1.5 ? (u < 0 ? "D" : "b") : u < 0 ? "4" : "3"  // a file
  return null
}
// The forge's floor: smaller flags than the halls', so the floor reads as laid stone in the hearth's light.
const TILES = stone({ course: 0.5, len: 0.5, face: "3", dark: "2", mortar: "0", lit: "4", seed: 84 })
// Brick for the hearth: small courses, a sooty top.
const BRICK = stone({ course: 0.14, len: 0.28, face: "b", dark: "3", mortar: "1", lit: "B", seed: 81 })
function coals(p, n, s) {
  const i = Math.floor(p[0] / 0.06 + hash(Math.floor(p[2] / 0.05), 1) * 2), j = Math.floor(p[2] / 0.05), v = hash(i, j)
  const hot = 0.5 + 0.5 * Math.sin(p[0] * 9 + 1) * Math.sin(p[2] * 7)  // a hot heart under the nozzle, cooler at the edges
  return v < 0.18 * hot ? "y" : v < 0.5 * hot + 0.1 ? "o" : v < 0.8 ? "R" : "b"
}

// ======== Forge: a smithy cut into the crypt. The hearth on the right, coals glowing under an iron hood, bellows
// beside it; an anvil on a stump on the left, tools racked on the wall above it; a quench barrel cropped at the
// right edge; a dark doorway at the back. The middle, where the die faces sit, is plain wall and floor. ========
still("bg_forge", (C) => {
  const HW = 3.0, BACK = 7.6, TOP = 3.6
  const wallL = (p, n, s) => rackMat(p, n, s) || WALL(p, n, s)
  const iron = (p, n, s) => (n[1] > 0.5 ? "4" : n[0] < -0.5 ? "4" : n[2] < -0.5 ? (p[1] % 0.2 < s ? "1" : "3") : "2")
  const grain = planks({ w: 0.09, face: "b", dark: "1", lit: "B", seed: 82 })
  const wood = (p, n, s) => (n[1] > 0.5 ? (Math.hypot(p[0] + 1.75, p[2] - 3.5) % 0.07 < s ? "b" : "B") : grain([p[1], p[0], 0], [0, 0, -1], s))
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, TILES),
      sideWall(-HW, 0, BACK, TOP, wallL), sideWall(HW, 0, BACK, TOP, BRICK),
      backWall(BACK, HW, TOP, archFace(0.6, 1.45, WALL, { cx: -0.6, ring: 0.26, jamb: 0.2 }), archHole(0.6, 1.45, -0.6)),
      floorPlane((x, z) => Math.abs(x + 0.6) < 0.6 && z >= BACK && z < BACK + 3, RECESS), sideWall(-1.2, BACK, BACK + 3, 2.1, RECESS), sideWall(0, BACK, BACK + 3, 2.1, RECESS), backWall(BACK + 3, 3, 2.1, flat("0")),
      ceiling(TOP, (x, z) => Math.abs(x) < HW && z < BACK, stone({ course: 1.1, len: 0.9, face: "3", dark: "3", mortar: "2", lit: "3", seed: 83 })),
      // the hearth: a brick block, its coals in a firepot, an iron hood and flue over it
      box([2.15, 0, 3.7], [HW, 0.88, 5.6], BRICK),
      box([2.38, 0.88, 3.95], [2.85, 0.96, 5.0], coals, { cast: false }),
      box([2.1, 1.95, 3.55], [HW, 2.45, 5.75], iron), box([2.4, 2.45, 4.2], [HW, TOP, 5.1], iron),
      // the bellows' trestle beside the hearth (the bellows themselves are painted on it)
      box([1.55, 0.5, 3.95], [2.15, 0.58, 4.85], planks({ w: 0.1, face: "b", dark: "1", lit: "B" })),
      box([1.6, 0, 4.0], [1.68, 0.5, 4.08], flat("1")), box([1.6, 0, 4.72], [1.68, 0.5, 4.8], flat("1")),
      box([2.02, 0, 4.0], [2.1, 0.5, 4.08], flat("1")), box([2.02, 0, 4.72], [2.1, 0.5, 4.8], flat("1")),
      // the anvil on its stump
      cylinder(-1.75, 3.5, 0.3, 0, 0.48, wood),
      box([-2.0, 0.48, 3.38], [-1.5, 0.58, 3.62], iron), box([-1.88, 0.58, 3.43], [-1.62, 0.74, 3.57], iron),
      box([-2.15, 0.74, 3.38], [-1.42, 0.86, 3.62], iron), box([-1.42, 0.77, 3.43], [-1.18, 0.85, 3.57], iron), box([-1.18, 0.79, 3.47], [-1.06, 0.83, 3.53], iron),
      // the quench barrel at the right edge
      cylinder(2.05, 2.75, 0.36, 0, 0.72, (p, n, s) => {
        if (n[1] > 0.5) return Math.hypot(p[0] - 2.05, p[2] - 2.75) > 0.31 ? "b" : "a"
        if ([0.08, 0.36, 0.64].some((h) => Math.abs(p[1] - h) < 0.03)) return "1"
        const st = Math.floor(Math.atan2(p[2] - 2.75, p[0] - 2.05) * 7)
        return hash(st, 3) < 0.3 ? "b" : "B"
      }),
      ...framing(-2.15, 2.15, 2.2, 0.3, true),
    ],
    lamps: [{ p: [2.62, 1.15, 4.45], color: EMBER, reach: 7.2, power: 1.45, lift: 3 }, { p: [2.62, 0.99, 4.45], color: FIRE, reach: 2.4, power: 0.6, lift: 3 }],
  }
}, (c, C, G) => {
  for (let i = 0; i < 26; i++) {  // sparks going up the flue's mouth
    const [px, py] = project(C, 2.4 + hash(i, 1) * 0.45, 1.0 + hash(i, 2) * 0.9, 3.9)
    if (hash(i, 3) < 0.5) c.px(px, py, hash(i, 4) < 0.3 ? "y" : "o")
  }
  // contact shadows: where the stump and the trestle's legs meet the floor
  for (const [x, z, rx] of [[-1.75, 3.5, 0.42], [1.85, 4.04, 0.36], [1.85, 4.76, 0.36]]) {
    const [cx, cy] = project(C, x, 0, z), [ex] = project(C, x + rx, 0, z)
    for (let dy = -2; dy <= 2; dy++) for (let dx = -(ex - cx); dx <= ex - cx; dx++)
      if ((dx / (ex - cx)) ** 2 + (dy / 2.5) ** 2 < 1 && G.hit[(cy + dy) * W + cx + dx]) c.px(cx + dx, cy + dy, "0")
  }
  const [bx, by] = project(C, 1.58, 0.58, 4.0)  // the bellows: two boards and a leather bag in folds, the nozzle at the coals
  prop(c, G, [bx - 2, by - 22, 40, 23], [1.85, 0.7, 4.3], [-0.5, 0.3, -0.8], () => {
    c.poly([bx, by - 2, bx + 32, by - 7, bx + 32, by - 4, bx, by], "b")  // the lower board
    c.poly([bx, by - 16, bx + 32, by - 9, bx + 32, by - 7, bx, by - 13], "B")  // the upper one, raised
    for (let i = 0; i < 4; i++) c.line(bx + 1, by - 12 + i * 3, bx + 30, by - 7 + Math.round(i * 0.7), i % 2 ? "1" : "b")  // the leather folds
    c.line(bx, by - 13, bx - 1, by - 20, "B", 2)  // the handle
    c.rect(bx + 31, by - 8, 6, 3, "4")  // the nozzle
  })
  const [hx, hy] = project(C, -1.78, 0.86, 3.45)  // a hammer left on the anvil's face, a bar of iron by it
  prop(c, G, [hx - 13, hy - 6, 33, 7], [-1.78, 0.9, 3.45], [0, 1, 0], () => {
    c.rect(hx - 3, hy - 3, 6, 3, "4"); c.hline(hx - 3, hy - 3, 6, "5")
    c.line(hx + 3, hy - 2, hx + 18, hy - 4, "B")
    c.line(hx - 12, hy - 1, hx - 4, hy - 1, "R")
  })
}, { amb: 0.75 })

// ======== Victory: the way out of the Mine at dawn. An adit runs straight away between timber sets, its rails
// converging on the mouth, where the dawn shows over the hills and its light comes down the drift toward us; a
// lantern set down and left; the nearest set near-black. The horizon sits below the text. ========
const DAWN_EYE = camera(256, 206)
still("bg_victory", (C) => {
  const HW = 1.55, TOP = 2.5, END = 17
  const sets = []
  // squared timbers, the grain running along them: across u on a post, across v on the cap
  const grain = (up) => (p, n, s) => {
    const [u, v] = uv(p, n), a = up ? u : v, b = up ? v : u, f = (a / 0.045) % 1, row = Math.floor(a / 0.045)
    if (f < s / 0.045 && hash(row, Math.floor(b * 2)) < 0.6) return "b"
    return hash(row, 7) < 0.25 ? "b" : n[0] > 0.5 || n[2] < -0.5 ? "B" : "b"
  }
  for (let z = 1.3; z < END - 0.5; z += 2.2) {
    const near = z < 2 ? { fg: 2 } : {}
    sets.push(box([-HW, 0, z], [-HW + 0.22, TOP, z + 0.24], grain(true), near), box([HW - 0.22, 0, z], [HW, TOP, z + 0.24], grain(true), near), box([-HW, TOP - 0.24, z], [HW, TOP, z + 0.24], grain(false), near))
  }
  // cut rock in broad slabs, two values only; the dawn and the dark do the rest
  const side = (p, n, s) => (hash(Math.floor(p[2] / 1.1 + Math.floor(p[1] / 0.8) * 0.5), Math.floor(p[1] / 0.8)) < 0.45 ? "2" : "3")
  const ground = (p, n, s) => {
    const sl = (p[2] % 0.62) < 0.12 && Math.abs(p[0]) < 0.75
    if (Math.abs(Math.abs(p[0]) - 0.45) < Math.max(0.025, s * 0.6)) return "5"
    if (sl) return (p[2] % 0.62) < s ? "1" : "B"
    const v = hash(Math.round(p[0] * 30), Math.round(p[2] * 30))
    return v < 0.1 ? "1" : v > 0.94 ? "4" : "2"
  }
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < END, ground),
      sideWall(-HW, 0, END, TOP, side), sideWall(HW, 0, END, TOP, side),
      ceiling(TOP, (x, z) => Math.abs(x) < HW && z < END, planks({ w: 0.18, face: "1", dark: "0", seam: "k", lit: "1" })),
      ...sets,
      // the hills outside the mouth, against the sky
      plane(2, END + 40, (x, y) => y < 0.6 + 1.6 * Math.sin(x * 0.09 + 0.6) + 0.5 * Math.sin(x * 0.31), flat("3")),
      floorPlane((x, z) => z >= END && z < END + 40, (p) => (hash(Math.round(p[0] * 3), Math.round(p[2] * 2)) < 0.3 ? "4" : "3")),
    ],
    lamps: [{ p: [0, 1.5, END + 0.5], color: [1, 0.84, 0.66], reach: 17, power: 1.7, lift: 9 }, { p: [-0.7, 0.2, 4.8], reach: 1.8, power: 0.55 }],
  }
}, (c, C, G) => {
  sky(c, G, [[170, "#2c3a4c"], [186, "#8c6a62"], [198, "#e0a070"], [206, "#ffe0a0"]])
  const [lx, ly] = project(C, -0.7, 0, 4.8)  // the lantern, set down on the sleepers and left
  c.rect(lx - 3, ly - 9, 7, 9, "1"); c.rect(lx - 2, ly - 7, 5, 6, "y"); c.vline(lx, ly - 7, 6, "w")
  c.hline(lx - 4, ly - 10, 9, "1"); c.grid(lx - 2, ly - 13, ".111.\n1...1")
  place(G, lx - 4, ly - 13, 9, 13, [-0.7, 0.1, 4.75])
  const [px, py] = project(C, 0.95, 0, 4.2)  // a pick dropped by the rail
  prop(c, G, [px - 13, py - 10, 25, 14], [0.95, 0.05, 4.2], [0, 1, 0], () => {
    c.line(px - 12, py - 1, px + 8, py - 4, "B", 2)
    c.line(px + 6, py - 9, px + 10, py + 2, "4", 2)
  })
}, { amb: 0.5, near: [0.8, 0.82, 0.9], far: [0.9, 0.86, 0.85], fog: 30 }, (c) => {
  // Darkens in dithered steps: the ceiling fades into the black of the nearest set (no edge where they meet), and
  // the middle band behind the centred text sinks a little.
  for (let y = 0; y < 200; y++)
    for (let x = 0; x < W; x++) {
      const top = Math.max(0, Math.min(1, (125 - y) / 50)), mid = Math.max(0, 1 - Math.hypot((x - 256) / 150, (y - 128) / 60)) * 0.55
      const k = Math.min(1, Math.max(top, mid)), th = BAYER[(y & 3) * 4 + (x & 3)] / 16
      const f = 1 - Math.floor(k * 4 + th) / 4 * 0.92
      if (f >= 1) continue
      const p = c.get(x, y) >>> 0
      c.px(x, y, "#" + [24, 16, 8].map((sh) => Math.round(((p >>> sh) & 255) * f).toString(16).padStart(2, "0")).join(""))
    }
}, DAWN_EYE)

// ======== Defeat: what was left behind. At the end of a short passage a portcullis comes down, two thirds closed,
// a faint cold glow from the dark beyond it; on the flags in front a dropped shield and a sword, by a fire burnt
// down to embers, the only warmth. ========
still("bg_defeat", (C) => {
  const HW = 2.4, BACK = 7.6, G0 = { hw: 1.3, spring: 1.9 }, DROP = 0.75
  const bars = []
  for (let x = -G0.hw + 0.12; x < G0.hw; x += 0.26) bars.push(box([x - 0.03, DROP, BACK - 0.08], [x + 0.03, 4, BACK - 0.02], (p, n) => (n[0] < -0.5 ? "4" : n[2] < -0.5 ? "3" : "1")))
  for (const y of [1.15, 1.75, 2.35, 2.95]) bars.push(box([-G0.hw, y, BACK - 0.1], [G0.hw, y + 0.06, BACK - 0.06], (p, n) => (n[1] > 0.5 ? "4" : "2")))
  return {
    prims: [
      ...nave({ hw: HW, back: BACK, top: 3.2, backMat: archFace(G0.hw, G0.spring, WALL, { ring: 0.34, jamb: 0.26 }), hole: archHole(G0.hw, G0.spring), frame: false }),
      vault(0, 3.2, HW, 0, BACK, vaultStone({ rib: 2.2, seed: 4, face: "4", dark: "3", mortar: "1", lit: "5" })),
      floorPlane((x, z) => Math.abs(x) < G0.hw && z >= BACK && z < BACK + 6, RECESS),
      sideWall(-G0.hw, BACK, BACK + 6, 4, RECESS), sideWall(G0.hw, BACK, BACK + 6, 4, RECESS),
      vault(0, G0.spring, G0.hw, BACK, BACK + 6, vaultStone({ seed: 9 })), backWall(BACK + 6, G0.hw, 4, flat("0")),
      ...bars,
      ...framing(-2.15, 2.15, 2.2, 0.3, true),
    ],
    lamps: [{ p: [0.15, 0.16, 3.7], color: EMBER, reach: 4.2, power: 0.95, lift: 2 }, { p: [0, 0.9, BACK + 2.2], color: COLD, reach: 4, power: 0.45, lift: 9 }],
  }
}, (c, C, G) => {
  const [ex, ey] = project(C, 0.15, 0, 3.7)  // the embers in a ring of stones, two low flames left
  for (let i = 0; i < 9; i++) {
    const a = (i / 9) * Math.PI * 2, [sx, sy] = project(C, 0.15 + Math.cos(a) * 0.34, 0, 3.7 + Math.sin(a) * 0.2)
    c.rect(sx - 2, sy - 2, 4, 3, "3")
    c.hline(sx - 2, sy - 2, 4, "4")
  }
  embers(c, ex - 12, ey - 3, 24, 5, 7)
  c.line(ex - 12, ey + 1, ex + 8, ey - 3, "1", 3)
  c.line(ex - 7, ey - 3, ex + 12, ey + 1, "0", 3)
  for (const [x, y] of [[-8, -1], [-2, -3], [4, -1], [9, -2], [0, 0]]) c.px(ex + x, ey + y, "o")
  smallFlame(c, ex - 3, ey - 3)
  c.grid(ex + 4, ey - 4, "R\no")
  const [sx, sy] = project(C, -0.95, 0, 3.55)  // the shield, dropped on its back, its rim catching the embers
  prop(c, G, [sx - 31, sy - 16, 63, 21], [-0.95, 0.05, 3.55], [0.3, 0.9, -0.3], () => {
    c.ellipse(sx, sy - 5, 29, 11, "0")
    c.ellipse(sx, sy - 6, 28, 10, "3")
    c.ellipse(sx + 1, sy - 6, 25, 8, "1")
    for (const k of [-16, -6, 4, 14]) c.line(sx + k - 1, sy - 13, sx + k + 1, sy + 1, "b")
    c.ellipse(sx, sy - 6, 6, 3, "4"); c.hline(sx - 3, sy - 8, 5, "5")
    c.hline(sx + 8, sy - 16, 14, "4")  // the rim's far edge, toward the fire
  })
  const [wx, wy] = project(C, 0.85, 0, 3.4)  // the sword, dropped
  prop(c, G, [wx - 36, wy - 10, 74, 16], [0.85, 0.03, 3.4], [0, 1, 0], () => {
    c.line(wx - 32, wy - 7, wx + 12, wy + 1, "4", 3)
    c.line(wx - 32, wy - 8, wx + 12, wy, "6")
    c.px(wx - 33, wy - 7, "4")
    c.line(wx + 12, wy - 4, wx + 15, wy + 6, "1", 3)
    c.line(wx + 15, wy + 1, wx + 28, wy + 4, "b", 3)
    c.line(wx + 15, wy, wx + 28, wy + 3, "B")
    c.rect(wx + 28, wy + 2, 4, 4, "4")
  })
}, { amb: 0.65, near: [0.66, 0.76, 0.95] })
