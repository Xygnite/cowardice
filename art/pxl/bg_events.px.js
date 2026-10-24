// One still per "?" event (scripts/events.gd IDS), behind the event screen's title, text, buttons and, for the dice
// events, the tray (art/events/art-direction-brief.md). 512x286 pxl pixels, 2 image px each in the game (1024x572).
// Every scene is a small one-point-perspective set: a camera, a list of planes, boxes, cylinders, vaults and mounds
// in metres (floor, receding walls, framing pillars, the subject), each painted per pixel by a material, then
// relit in 3D by its own lamps with real distance falloff, cast shadows and contact shadows. The perspective kit
// below is shared by every scene (and meant for the fight, Mine and menu backdrops too).
// Layout (event screen at 1280x720, 2.517 screen px per pxl pixel): title and text sit at about y 115-135, the
// buttons down to y 169, so lights and subject tops stay below that; on the dice events the tray covers x 63-449,
// y 132-211, so their subjects sit below y 211 or beside it.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/bg_events.px.js --out <scratch>
// then each <scratch>/scenes/event_<id>.png doubled (nearest) and saved lossless as assets/ui/bg_event_<id>.webp.
pal({
  k: "#030304", 0: "#0c1115", 1: "#181a20",                       // shadow
  2: "#232c35", 3: "#2c343a", 4: "#3c4147", 5: "#4c4e55", 6: "#5d5f66",  // wall slate, stone near the light
  b: "#3c312e", B: "#644f41", D: "#8c6452",                       // warm earth, wood, brass gone dark
  x: "#8c8270", X: "#bfb39a",                                     // tallow, bone
  m: "#140506", M: "#3a0f12",                                     // black wax / dark tears
  g: "#7a5a24", G: "#c89a40",                                     // coin
  r: "#7a3a20",                                                   // rust
  a: "#18282f", A: "#2f424c",                                     // drowned water
  c: "#475f6b", C: "#9cc0c8",                                     // cold light: C glows, only at its source
  R: "#a76236", o: "#e0782a", y: "#ffb24a", w: "#ffe08a",         // fire: glows, only at a light source
})

const W = 512, H = 286
const EMIT = "wyoRC"  // keys that give light: the relight leaves them alone
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const FIRE = [1, 0.52, 0.24], EMBER = [1, 0.36, 0.12], COLD = [0.62, 0.78, 0.95]

// 0..1, the same for the same (a, b).
function hash(a, b) {
  const s = Math.sin(a * 127.1 + b * 311.7) * 43758.5453
  return s - Math.floor(s)
}

// ---- Perspective kit ----
// World in metres: X right, Y up, Z away from the eye at (0, eye, 0). The vanishing point (vx, vy) is the horizon
// at eye height; f is the focal length in pxl pixels. Every event shares EYE so the family sits at one height.
function camera(vx = 256, vy = 164, f = 256, eye = 1.4) {
  return { vx, vy, f, eye }
}
const EYE = camera()
function project(C, X, Y, Z) {
  return [Math.round(C.vx + (C.f * X) / Z), Math.round(C.vy - (C.f * (Y - C.eye)) / Z)]
}

// Primitives. `mat(p, n, s)` returns a palette key for the world point p with outward normal n, s being the size of
// one pixel there in metres (so joints stay a pixel wide at any depth). Options on any primitive: `fg` keeps
// foreground framing near black; `cast` makes it throw shadows (boxes, cylinders and mounds do by default).
const plane = (axis, at, bounds, mat, opts = {}) => ({ kind: "plane", axis, at, bounds, mat, ...opts })
const box = (min, max, mat, opts = {}) => ({ kind: "box", min, max, mat, cast: true, ...opts })
// An upright cylinder (barrel, brazier bowl) standing at (x, z), radius r, from y0 to y1, capped on top.
const cylinder = (x, z, r, y0, y1, mat, opts = {}) => ({ kind: "cyl", x, z, r, y0, y1, mat, cast: true, ...opts })
// A round room seen from inside: an upright cylinder wall round (x, z), radius r, up to `top` (opts.hole(x, y, z)
// cuts openings).
const rotunda = (x, z, r, top, mat, opts = {}) => ({ kind: "rot", x, z, r, top, mat, ...opts })
// A barrel vault seen from inside: half a cylinder along Z, its axis at (x, spring), radius r, from z0 to z1.
const vault = (x, spring, r, z0, z1, mat, opts = {}) => ({ kind: "vault", x, spring, r, z0, z1, mat, ...opts })
// A half-ellipsoid mound on the ground (heaps, rubble, a body under a cloak): centre c, radii rad.
const mound = (c, rad, mat, opts = {}) => ({ kind: "mound", c, rad, mat, cast: true, ...opts })

// The set pieces every scene is built from.
const floorPlane = (where, mat, y = 0) => plane(1, y, (x, _, z) => where(x, z), mat)
const ceiling = (y, where, mat, opts = {}) => plane(1, y, (x, _, z) => where(x, z), mat, opts)
const sideWall = (x, z0, z1, top, mat, hole = null) => plane(0, x, (_, y, z) => z >= z0 && z < z1 && y < top && !(hole && hole(z, y)), mat)
const backWall = (z, hw, top, mat, hole = null) => plane(2, z, (x, y) => Math.abs(x) < hw && y < top && !(hole && hole(x, y)), mat)
// A square pillar (or pier) on the floor, `fg` for a darker one cropped by the frame.
const pillar = (x, z, w, d, mat, opts = {}) => box([x, 0, z], [x + w, 20, z + d], mat, opts)
// The near piers either side of the frame, part of the room, running off the frame's edges so the room fills it:
// inner faces at x = l and x = r, `dark` for near-black ones.
const framing = (l, r, z, d = 0.5, dark = false) => [pillar(l - 6, z, 6, d, dark ? FRAME : PIER, { fg: dark ? 2 : 1 }), pillar(r, z, 6, d, dark ? FRAME : PIER, { fg: dark ? 2 : 1 })]
// The opening of a round-headed arch: half-width hw, springing at `spring`, above `sill`.
const archHole = (hw, spring, cx = 0, sill = -1) => (x, y) => y > sill && Math.abs(x - cx) < hw && (y < spring || Math.hypot(x - cx, y - spring) < hw)

function hitPlane(P, o, d) {
  const a = P.axis
  if (d[a] === 0) return null
  const t = (P.at - o[a]) / d[a]
  if (t <= 1e-4) return null
  const p = [o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2]]
  if (P.bounds && !P.bounds(p[0], p[1], p[2])) return null
  const n = [0, 0, 0]
  n[a] = d[a] > 0 ? -1 : 1
  return { t, p, n }
}
function hitBox(B, o, d) {
  let t0 = -Infinity, t1 = Infinity, ax = 0
  for (let a = 0; a < 3; a++) {
    if (d[a] === 0) {
      if (o[a] < B.min[a] || o[a] > B.max[a]) return null
      continue
    }
    let ta = (B.min[a] - o[a]) / d[a], tb = (B.max[a] - o[a]) / d[a]
    if (ta > tb) [ta, tb] = [tb, ta]
    if (ta > t0) { t0 = ta; ax = a }
    if (tb < t1) t1 = tb
  }
  if (t0 > t1 || t0 <= 1e-4) return null
  const n = [0, 0, 0]
  n[ax] = d[ax] > 0 ? -1 : 1
  return { t: t0, p: [o[0] + t0 * d[0], o[1] + t0 * d[1], o[2] + t0 * d[2]], n }
}
// Roots of a t^2 + b t + c = 0, smaller first, or null.
function roots(a, b, c) {
  const disc = b * b - 4 * a * c
  if (disc < 0 || a === 0) return null
  const s = Math.sqrt(disc)
  return [(-b - s) / (2 * a), (-b + s) / (2 * a)]
}
function hitCyl(P, o, d) {
  let best = null
  const ox = o[0] - P.x, oz = o[2] - P.z
  const r = roots(d[0] * d[0] + d[2] * d[2], 2 * (ox * d[0] + oz * d[2]), ox * ox + oz * oz - P.r * P.r)
  if (r && r[0] > 1e-4) {
    const t = r[0], y = o[1] + t * d[1]
    if (y >= P.y0 && y <= P.y1) best = { t, p: [o[0] + t * d[0], y, o[2] + t * d[2]], n: [(ox + t * d[0]) / P.r, 0, (oz + t * d[2]) / P.r] }
  }
  if (d[1] < 0) {  // the cap
    const t = (P.y1 - o[1]) / d[1], x = o[0] + t * d[0], z = o[2] + t * d[2]
    if (t > 1e-4 && Math.hypot(x - P.x, z - P.z) <= P.r && (!best || t < best.t)) best = { t, p: [x, P.y1, z], n: [0, 1, 0] }
  }
  return best
}
function hitRot(P, o, d) {
  const ox = o[0] - P.x, oz = o[2] - P.z
  const r = roots(d[0] * d[0] + d[2] * d[2], 2 * (ox * d[0] + oz * d[2]), ox * ox + oz * oz - P.r * P.r)
  if (!r || r[1] <= 1e-4) return null
  const t = r[1], p = [o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2]]
  if (p[1] > P.top || p[1] < 0 || (P.hole && P.hole(p[0], p[1], p[2]))) return null
  return { t, p, n: [(P.x - p[0]) / P.r, 0, (P.z - p[2]) / P.r] }
}
function hitVault(P, o, d) {
  const ox = o[0] - P.x, oy = o[1] - P.spring
  const r = roots(d[0] * d[0] + d[1] * d[1], 2 * (ox * d[0] + oy * d[1]), ox * ox + oy * oy - P.r * P.r)
  if (!r || r[1] <= 1e-4) return null
  const t = r[1]  // from inside: the far root
  const p = [o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2]]
  if (p[1] < P.spring || p[2] < P.z0 || p[2] > P.z1) return null
  return { t, p, n: [(P.x - p[0]) / P.r, (P.spring - p[1]) / P.r, 0] }
}
function hitMound(P, o, d) {
  const [cx, cy, cz] = P.c, [rx, ry, rz] = P.rad
  const O = [(o[0] - cx) / rx, (o[1] - cy) / ry, (o[2] - cz) / rz], D = [d[0] / rx, d[1] / ry, d[2] / rz]
  const r = roots(D[0] ** 2 + D[1] ** 2 + D[2] ** 2, 2 * (O[0] * D[0] + O[1] * D[1] + O[2] * D[2]), O[0] ** 2 + O[1] ** 2 + O[2] ** 2 - 1)
  if (!r || r[0] <= 1e-4) return null
  const t = r[0], p = [o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2]]
  if (p[1] < cy) return null
  const n = [(p[0] - cx) / rx ** 2, (p[1] - cy) / ry ** 2, (p[2] - cz) / rz ** 2], l = Math.hypot(...n)
  return { t, p, n: n.map((v) => v / l) }
}
const HIT = { plane: hitPlane, box: hitBox, cyl: hitCyl, rot: hitRot, vault: hitVault, mound: hitMound }

// Casts a ray through every pixel, paints the nearest surface with its material and keeps its world point, normal
// and flags in G for the relight. Pixels that hit nothing stay as the scene's bg (black).
function render(c, C, prims) {
  const G = { C, pos: new Float32Array(W * H * 3), nrm: new Float32Array(W * H * 3), fg: new Uint8Array(W * H), hit: new Uint8Array(W * H) }
  const o = [0, C.eye, 0]
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const d = [(x + 0.5 - C.vx) / C.f, -(y + 0.5 - C.vy) / C.f, 1]
      let best = null, bp = null
      for (const P of prims) {
        const h = HIT[P.kind](P, o, d)
        if (h && (!best || h.t < best.t)) { best = h; bp = P }
      }
      if (!best) continue
      c.px(x, y, bp.mat(best.p, best.n, best.t / C.f))
      const i = y * W + x
      G.pos.set(best.p, i * 3)
      G.nrm.set(best.n, i * 3)
      G.fg[i] = bp.fg === 2 ? 2 : bp.fg ? 1 : 0
      G.hit[i] = 1
    }
  return G
}
// Gives the pixels of a screen rect a world point and normal, for props painted over the render (a skull laid on
// a heap, a candle stub) so the relight treats them as standing there.
function place(G, x, y, w, h, p, n = [0, 0, -1]) {
  for (let yy = Math.max(0, y); yy < Math.min(H, y + h); yy++)
    for (let xx = Math.max(0, x); xx < Math.min(W, x + w); xx++) {
      const i = yy * W + xx
      G.pos.set(p, i * 3)
      G.nrm.set(n, i * 3)
      G.hit[i] = 1
    }
}

// The face's own 2D coordinates: along it and up it (or across and into it, for floors and tops).
function uv(p, n) {
  const ax = Math.abs(n[0]), ay = Math.abs(n[1]), az = Math.abs(n[2])
  return ax >= ay && ax >= az ? [p[2], p[1]] : ay >= az ? [p[0], p[2]] : [p[0], p[1]]
}

// ---- Materials ----
// Coursed stone for any face: courses `course` m deep, stones `len` m long, staggered row to row, a lit arris on
// some top edges. Above `calm` m the courses give out raggedly into plain dark wall (quiet behind the title).
// `crack` (0..1) is the share of stones split by a jagged crack.
function stone({ course = 0.42, len = 0.85, face = "3", dark = "2", mortar = "1", lit = "4", calm = 99, seed = 0, crack = 0, along = null } = {}) {
  return (p, n, s) => {
    let [u, v] = uv(p, n)
    if (along) u = along(p)
    const row = Math.floor(v / course), fv = v - row * course
    const uu = u + hash(row, seed) * len
    const col = Math.floor(uu / len), fu = uu - col * len
    if (v > calm + hash(col, row) * 0.9) return dark
    if (fv < s || fu < s * 0.9) return mortar
    if (crack && hash(col * 3 + seed, row * 5) < crack) {
      const cx = 0.3 + hash(col, row + seed) * 0.4
      if (Math.abs(fu / len - cx - 0.05 * Math.sin((fv / course) * 7 + col)) * len < s * 0.8) return mortar
    }
    const d = hash(col * 7 + seed, row) < 0.3
    if (fv > course - s * 1.1 && hash(row, col + seed) > 0.5) return d ? face : lit
    return d ? dark : face
  }
}
const WALL = stone({ calm: 3.4, seed: 1 })
const FLAGS = stone({ course: 0.8, len: 0.8, face: "3", dark: "2", mortar: "1", lit: "4", seed: 2 })
const DRESSED = stone({ course: 0.62, len: 0.36, face: "4", dark: "3", mortar: "1", lit: "5", seed: 4 })
const RECESS = stone({ course: 0.42, len: 0.7, face: "2", dark: "1", mortar: "0", lit: "3", seed: 5 })
const PIER = stone({ course: 0.55, len: 2, face: "3", dark: "3", mortar: "1", lit: "4", seed: 6 })
const FRAME = stone({ course: 0.6, len: 2, face: "2", dark: "2", mortar: "0", lit: "3", seed: 7 })
// Vault stone: courses run along the vault (u = distance round the curve), ribs every `rib` m.
function vaultStone({ rib = 0, ribW = 0.24, ...o } = {}) {
  const st = stone({ course: 0.5, len: 0.9, face: "2", dark: "1", mortar: "0", lit: "3", ...o, along: (p) => p[2] })
  return (p, n, s) => {
    if (rib && (p[2] % rib) < ribW) return (p[2] % rib) < s || (p[2] % rib) > ribW - s ? "1" : "3"
    const a = Math.atan2(-n[1], -n[0])  // round the curve
    return st([0, a * 2, p[2]], [1, 0, 0], s)
  }
}
// Planks: boards `w` m wide running along x (or up, on an upright face).
function planks({ w = 0.2, face = "B", dark = "b", seam = "k", lit = "D", seed = 0 } = {}) {
  return (p, n, s) => {
    const [u, v] = uv(p, n)
    const row = Math.floor(v / w), f = v - row * w
    if (f < s) return seam
    if (f > w - s && hash(row, seed) > 0.4) return lit
    return hash(row, Math.floor(u * 2.5 + hash(row, 1) * 3)) < 0.25 ? dark : face
  }
}
const flat = (k) => () => k

// Relights the rendered scene in 3D. Each lamp { p: [x, y, z], color, reach, power } lights a surface by its
// distance (to nothing at `reach` m), the angle it meets the surface and whether a caster stands between them
// (cast shadow); floors and tops darken round whatever stands on them (contact shadow). A cold ambient sinks to
// black with height and distance and turns cooler far away (the recess). Banded in dithered steps so light lies
// in flat pixel-art shades.
function light3d(c, G, lamps, casters, { amb = 0.9, warm = 5.5, fog = 11, near = [0.74, 0.84, 1], far = [0.55, 0.7, 1.05], step = 0.07, shadow = 0.3, bounce = 0.55, ao = 0.22, up = 3 } = {}) {
  const band = (v, x, y) => Math.floor(v / step + BAYER[(y & 3) * 4 + (x & 3)] / 16) * step
  const hex = (v) => v.toString(16).padStart(2, "0")
  const feet = casters.filter((B) => B.kind === "box" || B.kind === "cyl")
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const i = y * W + x
      if (!G.hit[i] || c.is(x, y, EMIT)) continue
      const p = [G.pos[i * 3], G.pos[i * 3 + 1], G.pos[i * 3 + 2]], n = [G.nrm[i * 3], G.nrm[i * 3 + 1], G.nrm[i * 3 + 2]]
      const depth = 1 - Math.exp(-Math.max(0, p[2] - 2.5) / fog)
      let a = amb * (1 - depth) * Math.min(1, Math.max(0.12, 1.15 - p[1] / 4.5))
      const q = [p[0] + n[0] * 0.01, p[1] + n[1] * 0.01, p[2] + n[2] * 0.01]
      const wc = [0, 0, 0]
      for (const { p: L, color = FIRE, reach = 4.8, power = 1, lift = up } of lamps) {
        const dx = L[0] - q[0], dy = L[1] - q[1], dz = L[2] - q[2], d = Math.hypot(dx, dy, dz)
        let f = Math.max(0, 1 - d / reach) * Math.max(0, 1 - Math.max(0, -dy) / lift)  // fading above the light keeps the top dark
        if (!f) continue
        f *= f * power * (0.45 + 0.55 * Math.max(0, (n[0] * dx + n[1] * dy + n[2] * dz) / d))
        // a shadowed upright face still gets light thrown back off the lit floor
        const dir = [dx, dy, dz]
        if (casters.some((B) => { const h = HIT[B.kind](B, q, dir); return h && h.t < 1 })) f *= n[1] < 0.9 ? Math.max(shadow, bounce) : shadow
        for (let j = 0; j < 3; j++) wc[j] += f * color[j]
      }
      if (n[1] > 0.99) {  // contact shadow round anything standing on this surface
        let k = 1
        for (const B of feet) {
          const base = B.kind === "box" ? B.min[1] : B.y0
          if (Math.abs(base - p[1]) > 0.02) continue
          const e = B.kind === "box"
            ? Math.hypot(Math.max(B.min[0] - p[0], 0, p[0] - B.max[0]), Math.max(B.min[2] - p[2], 0, p[2] - B.max[2]))
            : Math.max(0, Math.hypot(p[0] - B.x, p[2] - B.z) - B.r)
          k = Math.min(k, 0.35 + 0.65 * Math.min(1, e / ao))
        }
        a *= k
        for (let j = 0; j < 3; j++) wc[j] *= k
      }
      if (G.fg[i]) {  // framing: 2 near black, 1 a shade darker than the room it belongs to
        const [fa, fw] = G.fg[i] === 2 ? [0.35, 0.2] : [0.75, 0.6]
        a *= fa
        for (let j = 0; j < 3; j++) wc[j] *= fw
      }
      a = band(a, x, y)
      const peak = Math.max(...wc) * warm, keep = peak > 2.4 ? 2.4 / peak : 1  // cap the light without shifting its hue
      const px = c.get(x, y) >>> 0
      const cold = near.map((v, j) => v + (far[j] - v) * depth)
      const ch = (sh, j) => Math.min(255, Math.round(((px >>> sh) & 255) * (a * cold[j] + band(wc[j] * warm * keep, x, y))))
      c.px(x, y, "#" + hex(ch(24, 0)) + hex(ch(16, 1)) + hex(ch(8, 2)))
    }
}

// ---- Props painted on screen ----
// A candle flame standing on the screen point (x, y) (the wick's top): EMIT keys, left unlit and glowing.
function flame(c, x, y) {
  c.px(x, y, "k")
  c.grid(x - 1, y - 7, ".w.\n.w.\nwyw\nyyy\nywy\noyo\n.R.")
}
function smallFlame(c, x, y) {
  c.px(x, y, "k")
  c.grid(x - 1, y - 4, ".w.\nwyw\nyoy\n.R.")
}
// A bed of embers over a screen rect: glowing keys with ash between.
function embers(c, x, y, w, h, seed = 0) {
  for (let yy = y; yy < y + h; yy++)
    for (let xx = x; xx < x + w; xx++) {
      const v = hash(xx + seed, yy)
      c.px(xx, yy, v < 0.1 ? "y" : v < 0.36 ? "o" : v < 0.66 ? "R" : v < 0.84 ? "b" : "k")
    }
}
// A 7x7 skull, facing us.
const SKULL = ".xXXXx.\nxXXXXXx\nXkkXkkX\nxkkxkkx\n.xXbXx.\n.bxbxb.\n..xxx.."
// A die seen face-on: n pips on a w-px square, its shadowed sides `edge`.
function dieFace(c, x, y, w, n, face = "X", pip = "k", edge = "x") {
  c.rect(x, y, w, w, face)
  c.hline(x, y + w - 1, w, edge)
  c.vline(x + w - 1, y, w, edge)
  const q = Math.max(1, Math.round(w / 4)), lo = x + q - 1, hi = x + w - q - 1, mid = x + (w >> 1) - 1, top = y + q - 1, bot = y + w - q - 1, mv = y + (w >> 1) - 1
  const pips = { 1: [[mid, mv]], 2: [[lo, top], [hi, bot]], 3: [[lo, top], [mid, mv], [hi, bot]], 4: [[lo, top], [hi, top], [lo, bot], [hi, bot]],
    5: [[lo, top], [hi, top], [mid, mv], [lo, bot], [hi, bot]], 6: [[lo, top], [hi, top], [lo, mv], [hi, mv], [lo, bot], [hi, bot]] }
  for (const [px, py] of pips[n]) c.px(px, py, pip)
}

// An event room: `build(C)` returns { prims, lamps, casters? }; `decorate(c, C, G)` paints what is easier drawn on
// screen than modelled (flames, small props) before the relight; `after(c, C)` paints over the lit result (a shaft
// of light in the dust). Casters default to every primitive that casts.
function room(id, build, decorate = () => {}, lit = {}, after = null, C = EYE) {
  const set = build(C)
  const casters = set.casters || set.prims.filter((P) => P.cast)
  scene("event_" + id, { w: W, h: H, bg: "k" },
    (c) => {
      const G = render(c, C, set.prims)
      decorate(c, C, G)
      light3d(c, G, set.lamps, casters, lit)
      if (after) after(c, C)
    },
    glow("oyw", { r: 36, strength: 0.18, bands: 5, color: "#e0782a" }),
    glow("yw", { r: 10, strength: 0.3, bands: 2, color: "#ffb24a" }),
    glow("C", { r: 30, strength: 0.22, bands: 4, color: "#9cc0c8" }))
}

// The nave every chapel event shares the bones of: floor, side walls to `top`, a back wall with an optional hole,
// near-black framing pillars at the frame's edges.
function nave({ hw, back, top = 8, floor = FLAGS, wall = WALL, backMat = wall, hole = null, frame = true, frameZ = 1.9 }) {
  const prims = [
    floorPlane((x, z) => Math.abs(x) < hw && z < back, floor),
    sideWall(-hw, 0, back, top, wall),
    sideWall(hw, 0, back, top, wall),
    backWall(back, hw, top, backMat, hole),
  ]
  if (frame) prims.push(...framing(-hw + 0.5, hw - 0.5, frameZ, 0.6))
  return prims
}
// An arch's voussoirs and jambs painted round an opening on a wall (hw, spring as archHole), `ring` m deep.
function archFace(hw, spring, wall, { ring = 0.36, jamb = 0.3, cx = 0, sill = -1 } = {}) {
  return (p, n, s) => {
    const [u, v] = uv(p, n), x = (Math.abs(n[2]) > 0.5 ? p[0] : u) - cx, r = Math.hypot(x, v - spring)
    if (v > spring && r < hw + ring) {
      if (r > hw + ring - s) return "1"
      const ang = (Math.atan2(v - spring, x) / Math.PI) * 11
      if (Math.abs(ang - Math.round(ang)) * ((r * Math.PI) / 11) < s * 0.9) return "1"
      return r < hw + s * 1.5 ? "5" : Math.round(ang) % 2 ? "4" : "3"
    }
    if (Math.abs(x) < hw + jamb && v > sill) {
      if (v > spring - 0.14) return v > spring - s ? "5" : "4"
      return DRESSED([x + 9, v, 0], [0, 0, -1], s)
    }
    return wall(p, n, s)
  }
}

// ======== Weeping Altar: a stone altar in the midground of a short nave, an apse opening behind it into a darker
// recess, black wax weeping down its face into a pool, two tall candles the only light. ========
const ALTAR = { hw: 1.0, z0: 4.1, z1: 5.0, top: 0.72, slab: 0.12, dais: 0.12 }
const CANDLES = [[-0.82, 4.23], [0.84, 4.27]]  // x, z on the slab
const CANDLE_H = 0.2
const TEARS = [-0.15, 0.15]  // x of the two blind sockets the wax weeps from
// Each socket's runs: [x offset, where it stops (v), seed]. Uneven on purpose: one runs to the pool, one stops short
// in a fat drop, thin ones wander off sideways.
const RUNS = [[[0, 0, 1], [-0.07, 0.36, 4]], [[0, 0.27, 8], [0.08, 0, 11], [-0.06, 0.43, 13]]]

// A stream of wax down a face from v0 to v1 at u = cx: wandering, thin at its source, swelling into beads.
// Returns "k" for its core, "m" for its lit edge, null outside.
function tear(u, v, cx, v0, v1, s, seed) {
  if (v > v0 || v < v1) return null
  const t = v0 - v
  const c = cx + 0.006 * Math.sin(t * 17 + seed) + 0.004 * Math.sin(t * 43 + seed * 3)
  let w = (0.007 + 0.013 * Math.min(1, t / 0.25)) * (0.7 + 0.3 * Math.sin(t * 11 + seed * 5))
  const bead = (t * 3.5 + hash(seed, 2)) % 1
  if (bead > 0.85) w += 0.014 * Math.sin(((bead - 0.85) / 0.15) * Math.PI)
  w = Math.max(w, s * 0.8)
  const du = u - c
  if (Math.abs(du) < w) return du > w - s ? "m" : "k"
  return null
}
const EYES = ALTAR.top - 0.12  // where the sockets sit
function altarMat(p, n, s) {
  const [u, v] = uv(p, n)
  if (n[2] === -1) {  // the face toward us
    for (const [k, cx] of TEARS.entries()) {
      const e = Math.hypot((u - cx) / 0.045, (v - EYES) / 0.03)
      if (e < 1) return e < 0.6 ? "k" : "m"  // the blind socket
      for (const [dx, end, seed] of RUNS[k]) {
        const t = tear(u, v, cx + dx, EYES - 0.01, end || ALTAR.dais, s, seed)
        if (t) return t
        if (end && Math.hypot((u - cx - dx) / 0.024, (v - end) / 0.03) < 1) return "k"  // where it stopped, a drop
      }
    }
    // wax run off the slab's lip, uneven lengths
    const col = Math.round(u / 0.055), len = hash(col, 9) * (Math.abs(u) > 0.4 ? 0.2 : 0.08)
    if (v > ALTAR.top - len && Math.abs(u - col * 0.055 - (hash(col, 3) - 0.5) * 0.02) < Math.max(s * 0.55, v < ALTAR.top - len + 0.012 ? 0.011 : 0.006)) return "m"
    if (Math.abs(u) > ALTAR.hw - s * 1.2) return u < 0 ? "5" : "3"
    if (v < ALTAR.dais + 0.08) return v > ALTAR.dais + 0.08 - s ? "2" : "3"  // foot course
    for (const [x0, x1] of [[-0.3, 0.3], [-0.86, -0.44], [0.44, 0.86]]) {
      const y0 = ALTAR.dais + 0.15, y1 = ALTAR.top - 0.06
      if (!(u > x0 && u < x1 && v > y0 && v < y1)) continue
      if (v > y1 - s * 1.5 || u < x0 + s * 1.5) return "2"  // the sunk panel's shadowed edges
      if (v < y0 + s * 1.2 || u > x1 - s * 1.2) return "5"
      return "3"
    }
    return "4"
  }
  if (n[1] === 1) return "5"
  return "3"
}
function slabMat(p, n, s) {
  const [u, v] = uv(p, n)
  if (n[1] === 1) return p[2] < ALTAR.z0 - 0.1 + s * 1.2 ? "6" : "5"  // the front arris catches the flames
  if (n[2] === -1) {
    if (v > ALTAR.top + ALTAR.slab - s) return "6"
    return hash(Math.round(u / 0.045), 5) < 0.2 ? "m" : "4"  // smears of black wax over the lip
  }
  return "3"
}
function daisMat(p, n, s) {
  const [u, v] = uv(p, n)
  for (const [k, cx] of TEARS.entries())  // the runs that reach the dais go on over it, spreading
    for (const [dx, end, seed] of RUNS[k]) {
      if (end) continue
      const t = EYES - 0.01 - ALTAR.dais, c = cx + dx + 0.006 * Math.sin(t * 17 + seed) + 0.004 * Math.sin(t * 43 + seed * 3)
      const w = 0.02 + (n[1] === 1 ? (ALTAR.z0 - p[2]) * 0.06 : 0.018)
      if (Math.abs(u - c) < Math.max(w, s)) return Math.abs(u - c) > w - s ? "m" : "k"
    }
  if (n[1] === 1) return Math.abs(p[2] - (ALTAR.z0 - 0.3)) < s * 1.2 ? "5" : "4"
  if (n[2] === -1) return v > ALTAR.dais - s ? "5" : "3"
  return "2"
}
// The pool in front of the dais: an uneven blot in the floor's plane (so it lies in perspective), a dull red rim.
function inPool(x, z, s) {
  const dx = x / 0.72, dz = (z - (ALTAR.z0 - 0.52)) / 0.27, a = Math.atan2(dz, dx)
  const r = 1 + 0.12 * Math.sin(a * 3 + 1) + 0.08 * Math.sin(a * 5 + 2), d = Math.hypot(dx, dz)
  if (d >= r) return null
  if (d > r - s * 2) return dz < 0 ? "M" : "m"  // the near rim catches the light
  return d < r * 0.55 ? "k" : "m"
}

room("altar", () => {
  const BACK = 9.2, A = { hw: 1.45, spring: 2.3, depth: 12.4 }  // back wall, apse
  const top = ALTAR.top + ALTAR.slab
  const dais = box([-1.42, 0, ALTAR.z0 - 0.3], [1.42, ALTAR.dais, ALTAR.z1 + 0.35], daisMat)
  const body = box([-ALTAR.hw, ALTAR.dais, ALTAR.z0], [ALTAR.hw, ALTAR.top, ALTAR.z1], altarMat)
  const slab = box([-ALTAR.hw - 0.12, ALTAR.top, ALTAR.z0 - 0.1], [ALTAR.hw + 0.12, top, ALTAR.z1 + 0.1], slabMat)
  const candles = CANDLES.map(([x, z]) => box([x - 0.05, top, z - 0.05], [x + 0.05, top + CANDLE_H, z + 0.05],
    (p, n) => (n[0] === -1 || (n[2] === -1 && p[0] < x - 0.02) ? "X" : n[0] === 1 ? "b" : "x"), { cast: false }))
  return {
    prims: [
      ...nave({ hw: 3.3, back: BACK, floor: (p, n, s) => inPool(p[0], p[2], s) || FLAGS(p, n, s), backMat: archFace(A.hw, A.spring, WALL), hole: archHole(A.hw, A.spring) }),
      floorPlane((x, z) => z >= BACK && z < A.depth && Math.abs(x) < A.hw, RECESS),
      sideWall(-A.hw, BACK, A.depth, A.spring + A.hw, RECESS),
      sideWall(A.hw, BACK, A.depth, A.spring + A.hw, RECESS),
      backWall(A.depth, A.hw, A.spring + A.hw, RECESS),
      vault(0, A.spring, A.hw, BACK, A.depth, vaultStone()),
      box([-A.hw, 0, BACK - 0.35], [A.hw, 0.14, A.depth], RECESS, { cast: false }),  // steps up into the apse
      box([-A.hw, 0.14, BACK + 0.6], [A.hw, 0.28, A.depth], RECESS, { cast: false }),
      dais, body, slab, ...candles,
      pillar(-2.95, 6.0, 0.6, 0.6, PIER), pillar(2.35, 6.0, 0.6, 0.6, PIER),
    ],
    lamps: CANDLES.map(([x, z]) => ({ p: [x, top + CANDLE_H + 0.05, z] })),
  }
}, (c, C) => {
  const top = ALTAR.top + ALTAR.slab
  for (const [x, z] of CANDLES) {
    const [fx, fy] = project(C, x, top + CANDLE_H, z)
    flame(c, fx, fy)
    for (const k of [-1, 1]) c.px(fx + k * 2, project(C, x, top + CANDLE_H - 0.03, z)[1], "x")  // wax lipped round the wick
  }
  // Offerings on the slab: a clay bowl and a stack of coins between the candles, dried flowers laid along the edge.
  const [bx, by] = project(C, -0.3, top, 4.45)
  c.rect(bx - 6, by - 3, 13, 3, "b")
  c.hline(bx - 5, by - 4, 11, "B")
  c.hline(bx - 3, by - 4, 7, "M")
  c.hline(bx - 4, by, 9, "b")
  const [cx, cy] = project(C, 0.2, top, 4.4)
  for (let i = 0; i < 4; i++) c.hline(cx, cy - 1 - i, 5, i % 2 ? "G" : "g")
  c.hline(cx + 6, cy - 1, 4, "g")
  c.hline(cx + 7, cy - 2, 3, "G")
  const [lx, ly] = project(C, 0.45, top, 4.17)
  c.line(lx, ly, lx + 15, ly - 2, "b")
  c.line(lx + 1, ly, lx + 14, ly, "b")
  c.grid(lx + 14, ly - 4, ".M.\nMMm\n.M.")
  c.grid(lx + 15, ly - 1, "Mm\nm.")
  for (const [x, z] of [[-1.25, 3.95], [-1.15, 3.87], [1.2, 3.93]]) {  // a few coins left on the dais
    const [px, py] = project(C, x, ALTAR.dais, z)
    c.hline(px, py, 3, "G")
  }
})

// ======== Cracked Shrine: a ribbed barrel-vaulted chapel; at its middle a stone shrine split down the middle, cold
// light leaking out of the crack, the only light; a low doorway at the far end. ========
room("shrine", () => {
  const HW = 2.0, SPRING = 2.2, BACK = 10, Z = 4.6
  const ribs = [2.6, 4.4, 6.2, 8.0, 9.8]
  const half = (x0, x1, h) => [
    box([x0, 0.25, Z - 0.18], [x1, h, Z + 0.18], DRESSED),
    box([x0 + Math.sign(x0 + x1) * 0.02, h, Z - 0.14], [x1 - Math.sign(x0 + x1) * 0.12, h + 0.12, Z + 0.14], DRESSED),
    box([x0 + Math.sign(x0 + x1) * 0.04, h + 0.12, Z - 0.1], [x1 - Math.sign(x0 + x1) * 0.26, h + 0.22, Z + 0.1], DRESSED),
  ]
  // the face of the shrine: a carved ring split by the crack, cracks spreading from it
  const shrineFace = stone({ course: 0.3, len: 0.5, face: "3", dark: "2", mortar: "1", lit: "4", seed: 9, crack: 0.5 })
  const faceMat = (p, n, s) => {
    if (n[2] === -1) {
      const r = Math.hypot(p[0], p[1] - 0.72)
      if (Math.abs(r - 0.2) < s * 1.2) return "2"
      if (Math.abs(r - 0.2 - s * 1.5) < s * 0.8) return "5"
    }
    return shrineFace(p, n, s)
  }
  const halves = [...half(-0.52, -0.035, 1.06), ...half(0.035, 0.5, 0.99)]
  for (const b of halves) b.mat = faceMat
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, FLAGS),
      sideWall(-HW, 0, BACK, SPRING, WALL),
      sideWall(HW, 0, BACK, SPRING, WALL),
      vault(0, SPRING, HW, 0, BACK, vaultStone({ rib: 1.8 })),
      backWall(BACK, HW, SPRING + HW, archFace(0.55, 1.4, RECESS), archHole(0.55, 1.4)),
      ...ribs.flatMap((z) => [box([-HW, 0, z], [-HW + 0.16, SPRING, z + 0.24], PIER), box([HW - 0.16, 0, z], [HW, SPRING, z + 0.24], PIER)]),
      box([-0.68, 0, Z - 0.32], [0.68, 0.25, Z + 0.32], DRESSED),  // plinth
      ...halves,
      box([-0.035, 0.25, Z + 0.02], [0.035, 1.0, Z + 0.08], (p) => (hash(Math.round(p[1] * 40), 3) < 0.7 ? "C" : "c"), { cast: false }),  // light in the crack
      ...framing(-HW + 0.45, HW - 0.45, 1.8),
    ],
    lamps: [
      ...[0.4, 0.7, 0.95].map((y) => ({ p: [0, y, Z - 0.45], color: COLD, reach: 2.1, power: 0.24 })),
      { p: [0.55, 0.36, Z - 0.3], reach: 1.6, power: 0.3 },  // one stub still alight: a small warm note
    ],
  }
}, (c, C, G) => {
  // the crack's glow seeping onto the face either side, and dead candle stubs on the plinth
  for (const [x, h] of [[-0.45, 0.07], [-0.32, 0.05], [0.4, 0.06], [0.55, 0.04]]) {
    const [sx, sy] = project(C, x, 0.25, 4.32)
    c.rect(sx - 1, sy - Math.round(h * 70), 3, Math.round(h * 70), "x")
    c.px(sx, sy - Math.round(h * 70) - 1, "k")
    if (x === 0.55) smallFlame(c, sx, sy - Math.round(h * 70) - 1)
  }
}, { amb: 0.85, near: [0.8, 0.84, 0.9], far: [0.72, 0.78, 0.9] })

// ======== Drowned Pilgrim: a low vaulted passage flooded with black water; a pilgrim face down in it, satchel
// drifting; a candle stub guttering on the stone ledge along the right wall, the only light. ========
const BODY = [-0.25, 3.75]  // x, z of the body's middle
function waterMat(p, n, s) {
  const row = Math.floor(p[2] / 0.11), seg = Math.floor((p[0] + hash(row, 1) * 3) / 0.45)
  const ring = Math.abs(Math.hypot((p[0] - BODY[0]) / 1.05, (p[2] - BODY[1]) / 0.55) - 1.1 - 0.25 * Math.floor(hash(seg, 4) * 2))
  if (ring < s * 0.9) return "A"  // ripples round the body
  return hash(row, seg) > 0.8 && p[2] - row * 0.11 < s * 1.1 ? "A" : "a"
}
const cloth = (p, n, s) => {
  if (n[1] > 0.55 && p[0] > BODY[0] + 0.2 && p[0] < BODY[0] + 0.5 && hash(Math.round(p[0] * 40), Math.round(p[2] * 40)) < 0.7) return "b"  // the shoulder, catching the candle
  const f = Math.floor(p[0] / 0.22 + Math.sin(p[2] * 9) * 0.4)
  return hash(f, 7) < 0.3 && (p[0] / 0.22 + Math.sin(p[2] * 9) * 0.4) % 1 < 0.25 ? "1" : "2"
}
room("pilgrim", () => {
  const HW = 1.6, SPRING = 1.5, BACK = 15
  const [bx, bz] = BODY
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, waterMat),
      sideWall(-HW, 0, BACK, SPRING, stone({ seed: 11, crack: 0.15 })),
      sideWall(HW, 0, BACK, SPRING, stone({ seed: 12 })),
      vault(0, SPRING, HW, 0, BACK, vaultStone({ rib: 2.4, seed: 3 })),
      box([1.05, 0, 0], [HW, 0.38, BACK], stone({ course: 0.38, len: 0.6, face: "4", dark: "3", lit: "5", seed: 13 }), { cast: false }),  // the ledge
      mound([bx, 0, bz], [0.62, 0.2, 0.27], cloth),  // back and cloak
      mound([bx + 0.62, 0, bz - 0.04], [0.16, 0.15, 0.15], flat("1")),  // hood
      mound([bx - 0.72, 0, bz + 0.04], [0.32, 0.1, 0.17], cloth),  // legs
      box([bx + 0.2, 0, bz - 0.36], [bx + 0.62, 0.05, bz - 0.27], cloth),  // an arm flung forward
      box([bx + 0.62, 0, bz - 0.38], [bx + 0.72, 0.04, bz - 0.29], flat("x")),  // the hand
      box([bx - 0.95, 0, bz - 0.55], [bx - 0.62, 0.15, bz - 0.36], planks({ w: 0.05, face: "1", dark: "0", lit: "b" })),  // the satchel, adrift
      pillar(-HW - 0.3, 1.7, 0.6, 0.5, FRAME, { fg: 2 }), pillar(HW - 0.3, 1.7, 0.6, 0.5, FRAME, { fg: 2 }),
    ],
    lamps: [{ p: [1.25, 0.5, 3.5], reach: 4.4, power: 0.85 }],
  }
}, (c, C) => {
  const [sx, sy] = project(C, 1.25, 0.38, 3.5)
  c.rect(sx - 2, sy - 5, 4, 5, "x")  // the stub in its own puddle of wax
  c.hline(sx - 4, sy, 8, "x")
  smallFlame(c, sx, sy - 6)
  const [rx, ry] = project(C, 1.0, -0.4, 3.5)  // the flame caught in the water below the ledge
  for (let i = 0; i < 6; i++) c.px(rx + (i % 2), ry + i * 2, i < 2 ? "o" : "R")
  const [cx, cy] = project(C, BODY[0] - 0.75, 0, BODY[1] - 0.48)  // coins spilled from the satchel, under the water
  for (const [dx, dy] of [[0, 0], [5, 2], [-4, 3]]) c.hline(cx + dx, cy + dy, 2, "g")
}, { amb: 0.8 })

// ======== Ember-lit Niche: a small plain chamber; a round-headed alcove in its far wall holds a bed of glowing
// embers, the only light; ash spilt below it, soot above; a dark doorway off the left wall. ========
room("niche", () => {
  const HW = 2.6, BACK = 5.4, N = { hw: 0.8, spring: 1.75, sill: 0.6, d: 0.8 }
  const door = (z, y) => z > 3.0 && z < 4.1 && (y < 1.7 || Math.hypot(z - 3.55, y - 1.7) < 0.55)
  const back = archFace(N.hw, N.spring, (p, n, s) => {
    const soot = Math.abs(p[0]) < 0.75 - (p[1] - 2.5) * 0.4 && p[1] > 2.4 && p[1] < 3.3 - hash(Math.round(p[0] * 20), 1) * 0.4
    return soot ? "1" : WALL(p, n, s)
  }, { sill: N.sill })
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, FLAGS),
      sideWall(-HW, 0, BACK, 3.4, WALL, door),
      sideWall(HW, 0, BACK, 3.4, WALL),
      backWall(BACK, HW, 3.4, back, archHole(N.hw, N.spring, 0, N.sill)),
      ceiling(3.4, (x, z) => Math.abs(x) < HW && z < BACK, stone({ course: 0.9, len: 0.6, face: "2", dark: "1", mortar: "0", lit: "2" })),
      // the passage beyond the doorway, a few steps deep and sinking into the dark
      floorPlane((x, z) => x < -HW && x > -HW - 2.4 && z > 3.0 && z < 4.1, RECESS),
      plane(2, 3.0, (x, y) => x < -HW && x > -HW - 2.4 && y < 2.25, RECESS), plane(2, 4.1, (x, y) => x < -HW && x > -HW - 2.4 && y < 2.25, RECESS),
      sideWall(-HW - 2.4, 3.0, 4.1, 2.25, RECESS),
      ceiling(2.25, (x, z) => x < -HW && x > -HW - 2.4 && z > 3.0 && z < 4.1, flat("0")),
      // a stone bench along the right wall, a cracked jar on it
      box([HW - 0.45, 0, 2.9], [HW, 0.42, 4.7], DRESSED),
      cylinder(HW - 0.24, 3.55, 0.13, 0.42, 0.72, (p, n) => (n[1] > 0.5 ? "0" : hash(Math.round(p[1] * 25), 2) < 0.2 ? "b" : "B")),
      cylinder(HW - 0.2, 4.15, 0.09, 0.42, 0.58, (p, n) => (n[1] > 0.5 ? "0" : "b")),
      floorPlane((x, z) => Math.abs(x) < N.hw && z >= BACK && z < BACK + N.d, flat("1"), N.sill),  // the niche's floor
      sideWall(-N.hw, BACK, BACK + N.d, N.spring + N.hw, RECESS),
      sideWall(N.hw, BACK, BACK + N.d, N.spring + N.hw, RECESS),
      backWall(BACK + N.d, N.hw, N.spring + N.hw, RECESS),
      vault(0, N.spring, N.hw, BACK, BACK + N.d, vaultStone()),
      box([-N.hw - 0.12, N.sill - 0.08, BACK - 0.12], [N.hw + 0.12, N.sill, BACK], flat("5"), { cast: false }),  // the sill
      mound([0.05, 0, BACK - 0.05], [0.7, 0.16, 0.3], (p) => (hash(Math.round(p[0] * 50), Math.round(p[2] * 50)) < 0.2 ? "b" : "1")),  // spilt ash
      ...framing(-HW + 0.4, HW - 0.4, 1.9, 0.55),
    ],
    lamps: [-0.45, 0, 0.45].map((x) => ({ p: [x, N.sill + 0.12, BACK + 0.35], color: EMBER, reach: 4.2, power: 0.5, lift: 2.4 })),
  }
}, (c, C) => {
  const BACK = 5.4
  const [x0, y0] = project(C, -0.78, 0.6, BACK + 0.2), [x1, y1] = project(C, 0.78, 0.6, BACK + 0.75)
  const [, yt] = project(C, 0, 0.72, BACK + 0.45)
  embers(c, x0, yt, x1 - x0, y0 - yt + 1, 3)
  for (let x = x0; x < x1; x++) if (hash(x, 9) < 0.5) c.px(x, yt - 1, hash(x, 2) < 0.3 ? "o" : "R")  // the heap's ragged top
  for (const [x, z] of [[-0.3, 4.9], [0.35, 5.0], [0.6, 4.7]]) {  // stray embers in the ash on the floor
    const [px, py] = project(C, x, 0, z)
    c.px(px, py, "R")
  }
}, { amb: 0.8 })

// ======== Bone Pile (dice): the dead end of an ossuary under a low vault; its walls laid with skulls and stacked
// long bones; a heap of bones on the floor in front; a torch stub on the right wall, the only light. ========
function ossuary(top, upper) {
  return (p, n, s) => {
    const [u, v] = uv(p, n)
    if (v > top) return upper(p, n, s)
    const rowH = 0.26, row = Math.floor(v / rowH), fv = (v - row * rowH) / rowH
    if (row % 3 === 2) {  // a course of long bones laid end-on
      const cw = 0.11, uu = u + row * 0.05, col = Math.floor(uu / cw), fu = (uu - col * cw) / cw, d = Math.hypot(fu - 0.5, (fv - 0.5) * 1.4)
      return d < 0.34 ? (fv > 0.62 ? "X" : "x") : d < 0.46 ? "b" : "0"
    }
    const cw = 0.28, uu = u + (row % 2) * 0.14, col = Math.floor(uu / cw), fu = (uu - col * cw) / cw
    if (hash(col, row) < 0.08) return "0"  // one missing
    if (Math.hypot((fu - 0.5) / 0.42, (fv - 0.55) / 0.44) > 1 || fv < 0.1) return "0"
    if (Math.hypot((fu - 0.32) / 0.12, (fv - 0.55) / 0.13) < 1 || Math.hypot((fu - 0.68) / 0.12, (fv - 0.55) / 0.13) < 1) return "0"
    if (Math.abs(fu - 0.5) < 0.05 && fv > 0.3 && fv < 0.42) return "0"
    if (fv < 0.24) return Math.floor(fu * 9) % 2 ? "x" : "b"
    return fv > 0.78 ? "X" : fu < 0.3 ? "D" : "x"
  }
}
// A heap of bones: capsules lying every which way in an oblique grid over the mound, dark gaps between.
function bonesMat(p, n, s) {
  const q = 0.2, U = p[0] / q, V = (p[1] * 1.3 + p[2] * 0.6) / q, i = Math.floor(U), j = Math.floor(V), h = hash(i * 13 + 5, j)
  const ang = h * Math.PI, dx = Math.cos(ang), dy = Math.sin(ang), px = U - i - 0.5, py = V - j - 0.5
  const along = px * dx + py * dy, across = Math.abs(-px * dy + py * dx)
  if (across < 0.15 && Math.abs(along) < 0.44) return across < 0.05 ? "X" : h > 0.7 ? "D" : "x"
  if (Math.hypot(Math.abs(along) - 0.44, across) < 0.19) return "X"
  return h > 0.5 ? "b" : "0"
}
const HEAP = [0.0, 3.85]
room("bone_pile", () => {
  const HW = 2.2, BACK = 6.4, SPRING = 1.9
  const upper = stone({ seed: 21, calm: 2.6 })
  const [hx, hz] = HEAP
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, FLAGS),
      sideWall(-HW, 0, BACK, SPRING, ossuary(1.7, upper)),
      sideWall(HW, 0, BACK, SPRING, ossuary(1.7, upper)),
      backWall(BACK, HW, SPRING + HW, ossuary(1.7, upper)),
      vault(0, SPRING, HW, 0, BACK, vaultStone({ rib: 2.0, seed: 8 })),
      // a heap that rises to one side and slumps to the other, spilling forward in lumps
      mound([hx - 0.2, 0, hz], [0.95, 0.68, 0.62], bonesMat),
      mound([hx + 0.55, 0, hz + 0.1], [0.7, 0.46, 0.55], bonesMat),
      mound([hx - 1.0, 0, hz - 0.2], [0.45, 0.28, 0.4], bonesMat),
      mound([hx + 1.2, 0, hz - 0.15], [0.4, 0.22, 0.35], bonesMat),
      mound([hx + 0.2, 0, hz - 0.6], [0.32, 0.16, 0.22], bonesMat),
      mound([hx - 0.55, 0, hz - 0.62], [0.22, 0.12, 0.18], bonesMat),
      box([HW - 0.1, 1.15, 2.55], [HW, 1.32, 2.65], flat("B"), { cast: false }),  // the torch's bracket
      ...framing(-HW + 0.35, HW - 0.35, 1.7),
    ],
    lamps: [{ p: [HW - 0.18, 1.45, 2.6], color: [1, 0.68, 0.42], reach: 3.8, power: 0.6, lift: 2.2 }],
  }
}, (c, C, G) => {
  const [tx, ty] = project(C, 2.2 - 0.14, 1.32, 2.6)  // the torch stub: a charred stick, a low flame
  c.rect(tx - 1, ty, 3, 8, "b")
  c.vline(tx - 1, ty, 8, "B")
  flame(c, tx, ty - 1)
  // skulls lying on the heap, where they read at a glance
  for (const [x, y, z] of [[-0.35, 0.52, 3.55], [0.25, 0.58, 3.6], [0.85, 0.3, 3.4], [-1.0, 0.24, 3.35], [0.0, 0.25, 3.15], [1.25, 0.12, 3.35]]) {
    const [sx, sy] = project(C, x, y, z)
    place(G, sx - 3, sy - 6, 7, 7, [x, y, z - 0.1], [0, 0.5, -0.87])
    c.grid(sx - 3, sy - 6, SKULL)
  }
  // loose bones strewn on the flags round the heap, breaking its edge
  for (const [x, z, len, k] of [[-1.55, 3.2, 9, 1], [-1.2, 3.0, 7, -1], [1.55, 3.05, 8, -1], [1.0, 2.95, 6, 1], [-0.4, 2.95, 7, 1], [0.55, 3.1, 5, -1], [1.75, 3.5, 6, 1], [-1.75, 3.6, 5, -1]]) {
    const [bx, by] = project(C, x, 0, z), dy = k * Math.round(len / 4)
    c.line(bx, by, bx + len, by + dy, "x")
    c.line(bx, by - 1, bx + len, by + dy - 1, "X")
    c.px(bx - 1, by - 1, "X")
    c.px(bx + len + 1, by + dy - 1, "X")
    place(G, Math.min(bx, bx + len) - 1, Math.min(by, by + dy) - 2, len + 3, Math.abs(dy) + 3, [x, 0.04, z], [0, 1, 0])
  }
}, { amb: 0.5 })

// ======== Collapsing Corridor (dice): a cut-stone corridor running away into the dark, narrowed by collapse further
// on. Its ceiling is broken through, cold light falling through the hole onto the heap of stones that came down;
// a snapped timber beam sags across the top of the frame. The vanishing point sits low (below the dice tray) so the
// way on, the shaft and the heap all show under it. ========
const LOW_EYE = camera(256, 215)
const HOLE = (x, z) => Math.hypot((x - 0.1) / 0.75, (z - 7.0) / 0.6) + 0.18 * Math.sin(Math.atan2(z - 7.0, x - 0.1) * 5) < 1
// Broken blocks every which way with dark gaps (an oblique grid, so no courses), now and then a rusted iron scrap.
function rubbleMat(p, n, s) {
  const U = p[0] / 0.2 + p[2] * 1.3, V = (p[1] * 1.3 + p[2] * 0.6) / 0.16, i = Math.floor(U), j = Math.floor(V), h = hash(i * 7 + 3, j)
  if (h < 0.2) return "1"
  if (h > 0.975) return "r"
  return V - j > 0.78 ? "5" : h > 0.62 ? "4" : "3"
}
room("corridor", () => {
  const HW = 1.5, TOP = 2.6, BACK = 24
  const cracked = stone({ seed: 31, crack: 0.2, calm: 2.3 })
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, FLAGS),
      sideWall(-HW, 0, BACK, TOP, cracked),
      sideWall(HW, 0, BACK, TOP, cracked),
      ceiling(TOP, (x, z) => Math.abs(x) < HW && z < BACK && !HOLE(x, z), stone({ course: 0.6, len: 0.5, face: "2", dark: "1", mortar: "0", lit: "3", seed: 33, crack: 0.3 })),
      ceiling(3.4, (x, z) => Math.abs(x) < 2 && Math.abs(z - 7) < 1.5, (p) => (hash(Math.round(p[0] * 10), Math.round(p[2] * 10)) < 0.55 ? "c" : "A")),  // what shows through the hole
      // collapse further on: rubble banked against the walls, a slab jammed across, the way narrowing to a gap
      mound([-1.25, 0, 11], [0.8, 1.2, 1.4], rubbleMat), mound([1.3, 0, 12.6], [0.8, 1.4, 1.5], rubbleMat),
      box([-1.5, 0, 15.5], [-0.4, 2.6, 16], cracked), box([0.5, 0, 15.5], [1.5, 2.6, 16], cracked),
      box([-0.9, 1.6, 14], [1.0, 1.85, 14.3], DRESSED),
      // what came down through the hole: a shaped heap, big blocks on its flanks, a rusted bar sticking out
      mound([0.05, 0, 6.7], [1.05, 0.78, 0.8], rubbleMat),
      mound([-0.75, 0, 6.15], [0.5, 0.42, 0.45], rubbleMat), mound([0.8, 0, 6.05], [0.45, 0.34, 0.42], rubbleMat),
      box([-0.55, 0, 5.55], [-0.12, 0.24, 5.85], DRESSED), box([0.32, 0, 5.4], [0.7, 0.17, 5.65], DRESSED), box([-1.15, 0, 5.8], [-0.85, 0.14, 6.05], DRESSED),
      box([0.25, 0.42, 6.05], [1.0, 0.48, 6.1], flat("r"), { cast: false }),
      ...framing(-HW, HW, 1.6, 0.5, true),
    ],
    lamps: [{ p: [0.1, 2.5, 7.0], color: COLD, reach: 4.6, power: 0.6, lift: 9 }, { p: [0.1, 0.9, 6.0], color: COLD, reach: 2.2, power: 0.25, lift: 9 }],
  }
}, () => {}, { amb: 0.95, near: [0.84, 0.86, 0.9], far: [0.78, 0.82, 0.9] }, (c, C) => {
  const hex = (v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")
  const tint = (x, y, f, add) => {
    const p = c.get(x, y) >>> 0
    c.px(x, y, "#" + hex(((p >>> 24) & 255) * f + add[0]) + hex(((p >>> 16) & 255) * f + add[1]) + hex(((p >>> 8) & 255) * f + add[2]))
  }
  // the shaft of cold light from the hole to the floor: a dithered cone, the only blue in the room
  const [hx, hy] = project(C, 0.1, 2.6, 7.0), [, fy] = project(C, 0.1, 0, 7.0)
  for (let y = hy; y <= fy; y++) {
    const t = (y - hy) / (fy - hy), hw = 14 + t * 24
    for (let x = Math.round(hx - hw); x <= hx + hw; x++) {
      const e = 1 - Math.abs(x - hx) / hw
      if (BAYER[(y & 3) * 4 + (x & 3)] / 16 < 0.6 * e) tint(x, y, 1.2, [10, 18, 28])
    }
  }
  // dust hanging in it and settling round the heap
  for (let i = 0; i < 70; i++) {
    const t = hash(i, 2), x = hx + Math.round((hash(i, 1) - 0.5) * (28 + t * 44)), y = Math.round(hy + t * (fy - hy + 14))
    tint(x, y, 1, [70, 80, 88])
  }
  // the beam: a near-black timber sagging diagonally from the upper left, snapped, its broken end hanging; the
  // other half still lodged high on the right
  const timber = (pts, rim) => {
    c.poly(pts, "#1a1716")
  }
  timber([-10, 2, 140, 36, 142, 50, -10, 18], true)
  for (const [x0, y0, x1, y1] of [[10, 9, 110, 29], [30, 14, 130, 36]]) c.line(x0, y0, x1, y1, "#262120")  // grain
  c.line(-10, 19, 142, 51, "#3c4147")  // its underside, rimmed by the shaft
  timber([132, 36, 146, 42, 128, 84, 118, 80], false)
  c.line(119, 81, 128, 85, "#2c343a")  // the splintered end catches the shaft's light
  timber([522, 10, 360, 28, 360, 40, 522, 24], true)
  c.line(360, 41, 520, 25, "#2c343a")
}, LOW_EYE)

// ======== Rusted Chest (dice): a small barrel-vaulted strongroom; an iron-banded chest on a stone plinth in front;
// a lantern on the floor beside it, the only light; empty arched niches in the far wall. ========
const CHEST = { x0: -0.55, x1: 0.55, y0: 0.15, y1: 0.47, z0: 3.35, z1: 3.77 }
function chestMat(p, n, s) {
  const [u, v] = uv(p, n)
  const across = Math.abs(n[0]) > 0.5 ? p[2] : p[0]
  for (const b of [-0.38, 0, 0.38]) {
    if (Math.abs(across - b) < 0.035) {
      if (Math.abs(across - b) > 0.035 - s) return "1"
      return hash(Math.round(v * 14), b * 9) < 0.25 ? "5" : hash(Math.round(v * 40), b) < 0.1 ? "r" : "2"  // rivets on the rusted iron band
    }
  }
  if (n[2] === -1 && Math.abs(p[0]) < 0.09 && p[1] > 0.27 && p[1] < 0.42) return Math.abs(p[0]) < 0.025 && p[1] < 0.37 ? "k" : "5"  // the lock plate
  if (n[2] === -1 && p[1] > CHEST.y1 - 0.03 && p[1] < CHEST.y1) return "1"  // the lid's seam
  const pl = planks({ w: 0.08, face: "b", dark: "1", lit: "b", seed: 41 })(p, n, s)
  return hash(Math.round(across * 30), Math.round(v * 8)) < 0.03 ? "r" : pl  // rust bled into the wood
}
room("chest", () => {
  const HW = 1.9, SPRING = 1.7, BACK = 5.6
  const C0 = CHEST
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, FLAGS),
      sideWall(-HW, 0, BACK, SPRING, WALL),
      sideWall(HW, 0, BACK, SPRING, WALL),
      vault(0, SPRING, HW, 0, BACK, vaultStone({ rib: 1.6, seed: 6 })),
      backWall(BACK, HW, SPRING + HW, archFace(0.45, 1.15, WALL, { ring: 0.24, jamb: 0.18 }), archHole(0.45, 1.15)),  // a low door out
      sideWall(-0.45, BACK, BACK + 2, 1.6, RECESS), sideWall(0.45, BACK, BACK + 2, 1.6, RECESS), backWall(BACK + 2, 0.45, 1.6, RECESS),
      floorPlane((x, z) => Math.abs(x) < 0.45 && z >= BACK && z < BACK + 2, RECESS),
      box([-0.78, 0, 3.2], [0.78, 0.15, 3.95], DRESSED),  // plinth
      box([C0.x0, C0.y0, C0.z0], [C0.x1, C0.y1, C0.z1], chestMat),
      box([C0.x0 - 0.03, C0.y1, C0.z0 - 0.03], [C0.x1 + 0.03, C0.y1 + 0.1, C0.z1 + 0.03], chestMat),  // lid
      box([C0.x0, C0.y1 + 0.1, C0.z0 + 0.06], [C0.x1, C0.y1 + 0.16, C0.z1 - 0.06], chestMat),  // its rounded top
      box([0.86, 0, 3.08], [1.04, 0.04, 3.26], flat("1"), { cast: false }),  // lantern base
      box([0.96, 0, 3.4], [1.3, 0.05, 3.7], flat("b"), { cast: false }),  // a rotten board fallen off something
      ...framing(-HW + 0.3, HW - 0.3, 1.7),
    ],
    lamps: [{ p: [0.95, 0.16, 3.17], reach: 4.2, power: 0.55, lift: 2.2 }],
  }
}, (c, C, G) => {
  const [lx, ly] = project(C, 0.95, 0.04, 3.17)  // the lantern: iron frame, glowing panes, ring handle
  c.rect(lx - 4, ly - 13, 9, 13, "1")
  c.rect(lx - 3, ly - 11, 3, 9, "y")
  c.rect(lx + 1, ly - 11, 3, 9, "o")
  c.vline(lx - 2, ly - 9, 5, "w")
  c.hline(lx - 5, ly - 14, 11, "1")
  c.hline(lx - 3, ly - 15, 7, "1")
  c.grid(lx - 2, ly - 19, ".111.\n1...1\n1...1")
  place(G, lx - 5, ly - 19, 11, 19, [0.95, 0.12, 3.12])
  for (const [x, z, k] of [[-0.3, 3.15, "G"], [-0.62, 3.05, "g"], [0.4, 3.2, "G"], [0.2, 3.02, "g"]]) {  // coins round the plinth
    const [px, py] = project(C, x, 0, z)
    c.hline(px, py, 3, k)
  }
}, { amb: 0.8 })

// ======== Gambler's Skull (dice): a cramped corner under a low beamed ceiling; a barrel at the right edge with the
// skull on it, its own three dice and a candle; an empty chair pushed back on the left; dice and coins on the flags;
// a doorway at the back going on into the dark. ========
const BARREL = [0, 3.2]
room("gambler", () => {
  const HW = 2.6, BACK = 6.2, TOP = 2.7
  const beams = [2.4, 3.6, 4.8].map((z) => box([-HW, TOP - 0.22, z], [HW, TOP, z + 0.2], planks({ w: 0.07, face: "1", dark: "0", lit: "b" }), { cast: false }))
  const [bx, bz] = BARREL
  const staves = (p, n, s) => {
    if (n[1] > 0.9) return Math.hypot(p[0] - bx, p[2] - bz) > 0.27 ? "b" : "B"
    const a = Math.atan2(p[2] - bz, p[0] - bx), st = Math.floor(a * 6)
    if ([0.06, 0.22, 0.39].some((h) => Math.abs(p[1] - h) < 0.025)) return "1"  // hoops
    return Math.abs(a * 6 - st) < 0.1 ? "b" : hash(st, 5) < 0.3 ? "b" : "B"
  }
  const wood = planks({ w: 0.06, face: "B", dark: "b", lit: "D", seam: "0", seed: 51 })
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < HW && z < BACK, FLAGS),
      sideWall(-HW, 0, BACK, TOP, WALL),
      sideWall(HW, 0, BACK, TOP, WALL),
      backWall(BACK, HW, TOP, archFace(0.55, 1.5, WALL, { cx: -0.7 }), archHole(0.55, 1.5, -0.7)),
      sideWall(-1.25, BACK, BACK + 3, 2.1, RECESS), sideWall(-0.15, BACK, BACK + 3, 2.1, RECESS),  // the passage beyond
      ceiling(TOP, (x, z) => Math.abs(x) < HW && z < BACK, planks({ w: 0.18, face: "0", dark: "k", seam: "k", lit: "1" })),
      ...beams,
      cylinder(bx, bz, 0.3, 0, 0.45, staves),
      // the empty chair, pushed back from the barrel
      box([-1.25, 0.42, 3.55], [-0.82, 0.47, 3.95], wood),
      box([-1.25, 0.47, 3.91], [-0.82, 0.95, 3.95], wood),
      ...[[-1.25, 3.55], [-0.87, 3.55], [-1.25, 3.9], [-0.87, 3.9]].map(([x, z]) => box([x, 0, z], [x + 0.05, 0.42, z + 0.05], wood)),
      ...framing(-HW + 0.3, HW - 0.3, 1.7),
    ],
    lamps: [{ p: [bx + 0.17, 0.62, bz - 0.2], reach: 4, power: 0.9 }],
  }
}, (c, C, G) => {
  const [bx, bz] = BARREL, top = 0.45
  const [sx, sy] = project(C, bx - 0.02, top, bz + 0.06)  // the skull on the barrel, three dice before it, the candle
  const big = ".xXXXXx.\nxXXXXXXx\nXXXXXXXX\nXkkXXkkX\nXkkxXkkX\nxXXbbXXx\n.xXXXXx.\n.bxbxbx.\n..xxxx.."
  big.split("\n").forEach((row, j) => [...row].forEach((k, i) => k !== "." && c.rect(sx - 8 + i * 2, sy - 18 + j * 2, 2, 2, k)))  // drawn at double size: it is the subject
  place(G, sx - 8, sy - 18, 16, 18, [bx, top + 0.1, bz])
  const [kx, ky] = project(C, bx + 0.17, top, bz - 0.2)
  c.rect(kx - 1, ky - 6, 3, 6, "x")
  c.vline(kx - 1, ky - 6, 6, "X")
  place(G, kx - 1, ky - 6, 3, 6, [bx + 0.17, top + 0.06, bz - 0.22])
  flame(c, kx, ky - 7)
  for (const [x, z, n] of [[bx - 0.2, bz - 0.18, 2], [bx - 0.04, bz - 0.24, 2], [bx + 0.06, bz - 0.12, 2]]) {
    const [dx, dy] = project(C, x, top, z)
    dieFace(c, dx - 2, dy - 4, 4, n)
  }
  // dice and coins spilled across the lit flags round the barrel
  for (const [x, z, n] of [[0.55, 3.55, 5], [0.85, 3.85, 3], [-0.6, 3.6, 1]]) {
    const [dx, dy] = project(C, x, 0, z)
    dieFace(c, dx - 3, dy - 5, 6, n)
    place(G, dx - 3, dy - 5, 6, 6, [x, 0.06, z])
  }
  for (const [x, z] of [[0.4, 3.3], [1.0, 3.5], [1.2, 3.9], [-0.45, 3.35], [-0.2, 3.9], [0.7, 4.1]]) {
    const [px, py] = project(C, x, 0, z)
    c.hline(px, py, 3, hash(x, z) < 0.5 ? "G" : "g")
  }
}, { amb: 0.8 })

// ======== Cursed Die Cast: a round ritual chamber; a stone table at its middle with the open mould, a large die
// and a carving knife on it; a ring of black wax sigils on the floor round it; a brazier burning low and red at
// the right, the only light. ========
function sigils(p, n, s) {
  const r = Math.hypot(p[0], (p[2] - 4.6) * 1.0), a = Math.atan2(p[2] - 4.6, p[0])
  if (Math.abs(r - 1.25) < s * 1.1 || Math.abs(r - 1.45) < s * 1.1) return "m"
  if (r > 1.25 && r < 1.45) {  // runes between the rings
    const k = Math.floor(a * 4), f = a * 4 - k, g = (r - 1.25) / 0.2
    if (hash(k, 1) < 0.85 && ((Math.abs(f - 0.5) < 0.08 && g > 0.2 && g < 0.8) || (Math.abs(g - (0.3 + hash(k, 2) * 0.4)) < 0.08 && Math.abs(f - 0.5) < 0.25))) return "m"
  }
  return FLAGS(p, n, s)
}
function dieMat(min, max, faces) {  // a big die: pips by face
  return (p, n, s) => {
    const f = n[1] > 0.5 ? faces[0] : n[2] < -0.5 ? faces[1] : faces[2]
    const [u, v] = uv(p, n), [u0, v0] = uv(min, n), [u1, v1] = uv(max, n)
    const fu = (u - Math.min(u0, u1)) / Math.abs(u1 - u0), fv = (v - Math.min(v0, v1)) / Math.abs(v1 - v0)
    const at = { 1: [[0.5, 0.5]], 3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]], 6: [[0.27, 0.22], [0.27, 0.5], [0.27, 0.78], [0.73, 0.22], [0.73, 0.5], [0.73, 0.78]], 9: [0.22, 0.5, 0.78].flatMap((a) => [0.22, 0.5, 0.78].map((b) => [a, b])) }[f]
    if (at.some(([a, b]) => Math.hypot(fu - a, fv - b) < 0.09)) return f === 9 ? "M" : "k"
    return fu < 0.06 || fv < 0.06 || fu > 0.94 || fv > 0.94 ? "x" : "X"
  }
}
room("cursed_cast", () => {
  const R = 4.6, CZ = 4.3
  const DOOR = { hw: 0.6, spring: 1.55 }
  const door = (x, y, z) => z > CZ && archHole(DOOR.hw, DOOR.spring)(x, y)
  const arch = archFace(DOOR.hw, DOOR.spring, () => null, { ring: 0.3, jamb: 0.22 })
  const ring = (p, n, s) => {  // engaged pilasters round the wall, plain stone between, an arched doorway at the back
    if (p[2] > CZ && Math.abs(p[0]) < 1.2) {
      const k = arch([p[0], p[1], 0], [0, 0, -1], s)
      if (k) return k
    }
    const a = Math.atan2(p[2] - CZ, p[0] - 0) * 7 / Math.PI
    if (Math.abs(a - Math.round(a)) < 0.12) return Math.abs(a - Math.round(a)) > 0.1 ? "1" : p[1] > 2.4 ? "1" : "4"
    return stone({ seed: 61, calm: 2.6 })([0, p[1], a * 1.6], [1, 0, 0], s)
  }
  const t = { x0: -0.62, x1: 0.62, y1: 0.8, z0: 4.3, z1: 4.95 }
  const dmin = [-0.05, t.y1, 4.42], dmax = [0.22, t.y1 + 0.27, 4.69]
  return {
    prims: [
      floorPlane((x, z) => Math.hypot(x, z - CZ) < R, sigils),
      rotunda(0, CZ, R, 4.2, ring, { hole: door }),
      // the passage beyond the door, going on into the dark
      floorPlane((x, z) => Math.abs(x) < DOOR.hw && z > CZ + 3 && z < CZ + 8, RECESS),
      sideWall(-DOOR.hw, CZ + 3, CZ + 8, DOOR.spring, RECESS), sideWall(DOOR.hw, CZ + 3, CZ + 8, DOOR.spring, RECESS),
      vault(0, DOOR.spring, DOOR.hw, CZ + 3, CZ + 8, vaultStone()),
      backWall(CZ + 8, DOOR.hw, DOOR.spring + DOOR.hw, RECESS),
      box([t.x0, 0, t.z0], [t.x1, t.y1 - 0.1, t.z1], DRESSED),  // the table, a block under a thicker top
      box([t.x0 - 0.08, t.y1 - 0.1, t.z0 - 0.08], [t.x1 + 0.08, t.y1, t.z1 + 0.08], (p, n, s) => (n[1] > 0.5 && hash(Math.round(p[0] * 30), Math.round(p[2] * 30)) < 0.05 ? "m" : "5")),
      box(dmin, dmax, dieMat(dmin, dmax, [9, 6, 3])),
      box([-0.5, t.y1, 4.45], [-0.28, t.y1 + 0.08, 4.7], flat("4")), box([-0.25, t.y1, 4.45], [-0.12, t.y1 + 0.05, 4.7], (p, n) => (n[1] > 0.5 ? "1" : "4")),  // the mould, open
      // the brazier: a bowl on three legs, its coals on top
      cylinder(1.35, 3.55, 0.26, 0.5, 0.68, (p, n) => (n[1] > 0.5 ? (hash(Math.round(p[0] * 60), Math.round(p[2] * 60)) < 0.5 ? "R" : hash(Math.round(p[0] * 50), 2) < 0.4 ? "o" : "b") : hash(Math.round(p[1] * 30), 1) < 0.3 ? "r" : "1")),
      ...[[1.2, 3.45], [1.5, 3.45], [1.35, 3.7]].map(([x, z]) => box([x - 0.025, 0, z - 0.025], [x + 0.025, 0.5, z + 0.025], flat("1"))),
      ...framing(-1.7, 1.7, 1.7),
    ],
    lamps: [{ p: [1.35, 0.85, 3.55], color: EMBER, reach: 4.6, power: 0.9, lift: 2.4 }],
  }
}, (c, C, G) => {
  const [bx, by] = project(C, 1.35, 0.68, 3.55)  // low flames licking over the coals
  for (const [dx, h] of [[-5, 3], [-2, 5], [1, 4], [4, 2]]) for (let i = 0; i < h; i++) c.px(bx + dx + (i % 2), by - 1 - i, i === h - 1 ? "R" : "o")
  const [kx, ky] = project(C, -0.05, 0.8, 4.36)  // the carving knife laid by the die
  c.line(kx - 22, ky, kx - 8, ky - 1, "6")
  c.line(kx - 30, ky + 1, kx - 23, ky, "b")
  place(G, kx - 30, ky - 2, 23, 4, [-0.25, 0.82, 4.36], [0, 1, 0])
}, { amb: 0.8 })
