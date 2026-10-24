// The perspective kit every pxl background shares (art/events/art-direction-brief.md): the palette, a one-point
// camera, primitives in metres (planes, boxes, cylinders, vaults, mounds), materials, a 3D relight with distance
// falloff, cast and contact shadows, a few props painted on screen, and still()/room() that turn a set into a
// 512x286 scene. Included by bg_events.px.js (the nine "?" events) and bg_screens.px.js (menu, camp, campfire,
// forge, victory, defeat).
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

// A background still named `name`: `build(C)` returns { prims, lamps, casters? }; `decorate(c, C, G)` paints what
// is easier drawn on screen than modelled (flames, small props) before the relight; `after(c, C)` paints over the
// lit result (a shaft of light in the dust). Casters default to every primitive that casts.
function still(name, build, decorate = () => {}, lit = {}, after = null, C = EYE) {
  const set = build(C)
  const casters = set.casters || set.prims.filter((P) => P.cast)
  scene(name, { w: W, h: H, bg: "k" },
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
// An event room, scene "event_<id>".
const room = (id, ...rest) => still("event_" + id, ...rest)

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
