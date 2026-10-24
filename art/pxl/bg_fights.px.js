// The two fight backdrops, drawn with the perspective kit (kit.px.js; art/events/art-direction-brief.md), and their
// BackdropLife parts (scripts/backdrop_life.gd LIFE.fight and LIFE.mine). 512x286 pxl pixels, 2 image px each in the
// game (1024x572).
// Layout, in pxl pixels: the fighters stand on a floor ledge (CombatScreen.LEDGES), the hero at x 16-75, the
// enemies at x 340-500; the picture slides so the ledge sits under their feet, which crops about y 0-32 under the HUD;
// the dice tray covers y 217 down. So both scenes share a standing eye (FIGHT_EYE, horizon y 128) and a front zone
// as wide as the frame, its floor ending at a ledge: a step up into the nave (fight), a ground sill (Mine). Behind
// it the space recedes to a lit recess at the centre; a near arch or timber set frames the top and the edges.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/bg_fights.px.js --out <scratch>
// then <scratch>/scenes/bg_fight.png and bg_mine.png doubled (nearest) and saved lossless as assets/ui/bg_<name>.webp;
// <scratch>/anims/chain_fight_*, chain_mine_*, lantern (.png + .json) and <scratch>/sprites/dust.png copied to
// assets/ui/life/. The chain strips are drawn at 2 image px a pixel already; the flames and dust are not.
// The build prints each scene's LIFE spots (flames, chains) in image px.
include("kit.px.js")

const FIGHT_EYE = camera(256, 128, 256, 1.6)
const ledgeY = (z) => FIGHT_EYE.vy + (FIGHT_EYE.f * FIGHT_EYE.eye) / z  // the screen row a floor line at depth z sits on

// The rows of a grid string, trimmed.
const rowsOf = (g) => g.trim().split("\n").map((r) => r.trim())
// Paints a grid string with its top-left at (x, y), skipping ".".
function paint(c, g, x, y) {
  rowsOf(g).forEach((r, j) => [...r].forEach((k, i) => k !== "." && c.px(x + i, y + j, k)))
}
// Runs draw() and gives only the pixels it changed inside [x, y, w, h] the world point p and normal n, so the
// relight treats a prop painted on screen as standing there.
function prop(c, G, [x, y, w, h], p, n, draw) {
  const before = []
  for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) before.push(c.get(xx, yy))
  draw()
  let i = 0
  for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) if (c.get(xx, yy) !== before[i++]) place(G, xx, yy, 1, 1, p, n)
}
// Prints a LIFE spot: pxl pixel (x, y) as image px.
const spot = (what, x, y) => console.log(`LIFE ${what} at Vector2(${2 * x}, ${2 * y})`)
// A plain darkening in dithered steps over the lit result: `k(x, y)` 0..1 is how far toward black.
function sink(c, k) {
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const f = 1 - Math.floor(k(x, y) * 4 + BAYER[(y & 3) * 4 + (x & 3)] / 16) / 4 * 0.9
      if (f >= 1) continue
      const p = c.get(x, y) >>> 0
      c.px(x, y, "#" + [24, 16, 8].map((sh) => Math.round(((p >>> sh) & 255) * f).toString(16).padStart(2, "0")).join(""))
    }
}

// ---- Swaying chains (BackdropLife strips) ----
// Links alternating face-on and edge-on, `n` of them in `w`-wide rows.
function links(n, w) {
  const pad = (s) => ".".repeat((w - s.length) >> 1) + s + ".".repeat(w - s.length - ((w - s.length) >> 1))
  const out = []
  for (let i = 0; i < n; i++) out.push(...(i % 2 ? [".5.", ".4.", ".4.", ".2."] : [".55.", "5..4", "4..3", "4..3", ".23."]).map(pad))
  return out.join("\n")
}
const HOOK = ".5...\n.4...\n.4..4\n.4..3\n.4.43\n..32."
const SHACKLE = ".5554.\n5....4\n4....3\n4....3\n.2..2."
// A lantern gone out, on a chain.
const DEAD = "..242..\n.24442.\n2444442\nk41314k\nk43114k\nk41114k\nk41314k\n2r444r2\n.24442.\n..k2k.."
// A sway strip: 5 frames, each sheared about its top row so the bottom row sits -2..+2 pxl pixels off (frame 2
// hangs straight), drawn at 2 image px a pixel with 2 pxl pixels of room either side, lit by `amb` and the warm
// screen points `lamps` ([x, y, reach]). Its LIFE spot is image px (2 * (x - half - 2), 2 * y), half being half the
// grid's width rounded down.
function chain(name, g, [cx, cy], lamps, amb) {
  const rows = rowsOf(g), w = rows[0].length, h = rows.length, half = w >> 1
  spot(name + " (chain)", cx - half - 2, cy)
  anim(name, { w: (w + 4) * 2, h: h * 2, frames: 5, fps: 8 }, (c) => {
    for (let y = 0; y < h; y++) {
      const shift = Math.round(((c.frame - 2) * y) / (h - 1))
      for (let x = 0; x < w; x++) {
        if (rows[y][x] === ".") continue
        const sx = cx - half + x, sy = cy + y
        let warm = 0
        for (const [lx, ly, r] of lamps) warm += Math.max(0, 1 - Math.hypot(sx - lx, sy - ly) / r) ** 2
        const a = amb * Math.min(1, 0.45 + sy / 220)
        c.rect((x + 2 + shift) * 2, y * 2, 2, 2, rows[y][x])
        const p = c.get((x + 2 + shift) * 2, y * 2) >>> 0
        const ch = (sh, j) => Math.min(255, Math.round(((p >>> sh) & 255) * (a * [0.74, 0.84, 1][j] + Math.min(1.2, warm) * 1.4 * FIRE[j])))
        c.rect((x + 2 + shift) * 2, y * 2, 2, 2, "#" + [24, 16, 8].map((sh, j) => ch(sh, j).toString(16).padStart(2, "0")).join(""))
      }
    }
  })
}

// ======== Fight: a nave of the Sunken Chapel. The fighters stand in the crossing; behind them one step goes up into
// the nave, whose side walls run back in bays to a chancel arch, a broken lancet window shining cold at its end. In
// every bay an arched niche: a bone shelf, skulls, candles. Near-black, the crossing's arch frames the top and the
// edges; three chains hang from it. ========
const F = { step: 6.08, rise: 0.22, hw: 5, back: 17, spring: 4.0, piers: [6.5, 9.1, 11.7, 14.3], pierD: 0.45, niche: { hw: 0.7, d: 0.55, sill: 0.8, spring: 1.75 },
  chancel: { hw: 1.5, spring: 2.6, end: 19.5 }, window: { hw: 0.62, sill: 1.7, top: 3.9 }, near: { z: 2.6, hw: 2.5, spring: 2.0, rise: 0.6 } }
// The bays' niches, nearest first: their middle z.
const BAYS = F.piers.map((z, i) => ((z + F.pierD) + (F.piers[i + 1] ?? F.back)) / 2)
const NICHE_SILL = F.rise + F.niche.sill, NICHE_SPRING = F.rise + F.niche.spring
// Where the near arch's underside is at screen column x (its intrados), for the chains' hooks.
function nearArchY(x) {
  const { z, hw, spring, rise } = F.near, X = ((x - 256) * z) / 256
  return Math.floor(128 - (256 * (spring + rise * Math.sqrt(Math.max(0, 1 - (X / hw) ** 2)) - 1.6)) / z)
}
const FIGHT_CHAINS = [[52, nearArchY(52) + 1], [304, nearArchY(304) + 1], [482, nearArchY(482) + 1]]
// The niches' candlelight on screen, for the chains' light: [x, y, reach].
const FIGHT_LIGHTS = [-1, 1].flatMap((k) => BAYS.map((zc, i) => [...project(FIGHT_EYE, k * (F.hw + 0.2), NICHE_SILL + 0.25, zc), i < 2 ? 70 : 40]))

// A lancet window, broken: leaded panes shining cold, some gone (night behind), a mullion and a stone frame.
function windowMat(p, n, s) {
  const { hw, sill, top } = F.window, x = p[0], y = p[1] - F.rise
  const arch = y > top - hw * 1.3 ? Math.hypot(Math.abs(x) + hw * 0.7, y - (top - hw * 1.3)) < hw * 1.7 : true
  if (y < sill || Math.abs(x) > hw || !arch) return RECESS(p, n, s)
  const inside = y > sill + s * 1.5 && Math.abs(x) < hw - s * 1.5 && (y < top - hw * 1.3 || Math.hypot(Math.abs(x) + hw * 0.7, y - (top - hw * 1.3)) < hw * 1.7 - s * 1.5)
  if (!inside) return "4"
  if (Math.abs(x) < s) return "2"  // the mullion
  const a = (x + y) / 0.2, b = (y - x) / 0.2
  if (Math.abs(a - Math.round(a)) * 0.2 < s * 0.5 || Math.abs(b - Math.round(b)) * 0.2 < s * 0.5) return "1"  // the leading
  const cell = hash(Math.round(a), Math.round(b))
  if (y > top - 0.9 && x > -0.1 && cell < 0.7) return "0"  // the broken corner
  return cell < 0.18 ? "0" : cell < 0.6 ? "C" : "c"
}

still("bg_fight", (C) => {
  const { step, rise, hw, back, spring, piers, pierD, niche, chancel: ch, near } = F
  const inNiche = (z, y) => BAYS.some((zc) => Math.abs(z - zc) < niche.hw && y > NICHE_SILL && (y < NICHE_SPRING || Math.hypot(z - zc, y - NICHE_SPRING) < niche.hw))
  // the side walls: coursed stone, each niche ringed by voussoirs and dressed jambs, the shelf's lip lit
  const wall = (p, n, s) => {
    const zc = BAYS.reduce((a, b) => (Math.abs(p[2] - b) < Math.abs(p[2] - a) ? b : a))
    const r = Math.hypot(p[2] - zc, p[1] - NICHE_SPRING)
    if (p[1] > NICHE_SPRING && r > niche.hw + 0.3) return WALL(p, n, s)
    if (Math.abs(p[2] - zc) < niche.hw + 0.24 && p[1] > NICHE_SILL - 0.12 && p[1] < NICHE_SILL) return p[1] > NICHE_SILL - s * 1.5 ? "5" : "4"  // the shelf's stone lip
    return archFace(niche.hw, NICHE_SPRING, WALL, { cx: zc, ring: 0.3, jamb: 0.24, sill: NICHE_SILL })(p, n, s)
  }
  const niches = []
  for (const k of [-1, 1])
    for (const zc of BAYS) {
      const xin = k * hw, xback = k * (hw + niche.d), lo = Math.min(xin, xback), hi = Math.max(xin, xback), crown = NICHE_SPRING + niche.hw
      niches.push(
        plane(0, xback, (_, y, z) => Math.abs(z - zc) < niche.hw && y > NICHE_SILL && y < crown, RECESS),
        plane(1, NICHE_SILL, (x, _, z) => x > lo && x < hi && Math.abs(z - zc) < niche.hw, DRESSED),
        plane(1, crown, (x, _, z) => x > lo && x < hi && Math.abs(z - zc) < niche.hw, flat("0")),
        plane(2, zc - niche.hw, (x, y) => x > lo && x < hi && y > NICHE_SILL && y < crown, RECESS),
        plane(2, zc + niche.hw, (x, y) => x > lo && x < hi && y > NICHE_SILL && y < crown, RECESS),
      )
    }
  const RISER = stone({ course: 0.22, len: 0.7, face: "4", dark: "3", mortar: "1", lit: "5", seed: 31 })
  const upper = (p, n, s) => (p[2] < step + 0.06 ? (p[2] < step + s * 1.2 ? "5" : "4") : FLAGS(p, n, s))  // the step's lit nosing
  const NEAR = stone({ course: 0.8, len: 0.8, face: "3", dark: "2", mortar: "1", lit: "4", seed: 32 })
  const nearArch = (x, y) => Math.abs(x) < near.hw && (y < near.spring || (x / near.hw) ** 2 + ((y - near.spring) / near.rise) ** 2 < 1)
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < 9 && z < step, NEAR),
      plane(2, step, (x, y) => Math.abs(x) < hw && y < rise, RISER),
      floorPlane((x, z) => Math.abs(x) < hw && z >= step && z < back, upper, rise),
      // the crossing's far side: wall either side of the nave and over its vault
      plane(2, step, (x, y) => y < 14 && Math.abs(x) < 12 && (Math.abs(x) >= hw || y > spring + Math.sqrt(Math.max(0, hw * hw - x * x))), WALL),
      sideWall(-hw, step, back, spring, wall, inNiche), sideWall(hw, step, back, spring, wall, inNiche),
      ...niches,
      vault(0, spring, hw, step, back, (p, n, s) => vaultStone({ rib: 2.6, seed: 33 })([p[0], p[1], p[2] - piers[0] + 26], n, s)),
      ...piers.flatMap((z) => [box([-hw, rise, z], [-hw + 0.32, spring, z + pierD], PIER), box([hw - 0.32, rise, z], [hw, spring, z + pierD], PIER)]),
      // the chancel: an arch in the end wall, a short vaulted bay behind it, the window at its end
      { ...backWall(back, hw, 14, archFace(ch.hw, rise + ch.spring, WALL, { ring: 0.34, jamb: 0.26, sill: rise }), archHole(ch.hw, rise + ch.spring, 0, rise)), cast: true },
      floorPlane((x, z) => Math.abs(x) < ch.hw && z >= back && z < ch.end, RECESS, rise),
      sideWall(-ch.hw, back, ch.end, rise + ch.spring, RECESS), sideWall(ch.hw, back, ch.end, rise + ch.spring, RECESS),
      vault(0, rise + ch.spring, ch.hw, back, ch.end, vaultStone({ seed: 34 })),
      backWall(ch.end, ch.hw, 8, windowMat),
      // the near arch, framing the top and the edges
      plane(2, near.z, (x, y) => Math.abs(x) < 12 && y < 12 && !nearArch(x, y), FRAME, { fg: 2 }),
    ],
    lamps: [
      ...[-1, 1].flatMap((k) => BAYS.map((zc, i) => ({ p: [k * (hw - 0.05), NICHE_SILL + 0.22, zc], reach: i < 2 ? 3.4 : 2.6, power: i < 2 ? 1.0 : 0.7, lift: 2 }))),
      { p: [0, rise + 2.4, ch.end - 0.4], color: COLD, reach: 11, power: 0.85, lift: 9 },
    ],
  }
}, (c, C, G) => {
  // Each niche's shelf: candles, a skull or two, bones; the near two bays a side get the flickering flames.
  const { hw, niche } = F
  for (const k of [-1, 1])
    BAYS.forEach((zc, bay) => {
      const at = (t, depth = 0.18) => project(C, k * (hw + depth), NICHE_SILL, zc - niche.hw + 0.12 + t * (niche.hw * 2 - 0.24))
      const scale = 256 / zc  // px a metre here
      const n = [-k * 0.55, 0.35, -0.75], p = [k * (hw + 0.2), NICHE_SILL + 0.1, zc]
      const [x0, y0] = at(0), [x1, y1] = at(1)
      prop(c, G, [Math.min(x0, x1) - 6, Math.min(y0, y1) - 26, Math.abs(x1 - x0) + 12, Math.abs(y1 - y0) + 30], p, n, () => {
        // bones lying along the shelf, a skull on them
        for (const [t0, t1, d, key] of [[0.3, 0.62, 0.3, "x"], [0.42, 0.8, 0.12, "X"], [0.55, 0.9, 0.26, "x"]]) {
          const [ax, ay] = at(t0, d), [bx, by] = at(t1, d)
          c.line(ax, ay - 1, bx, by - 1, key)
          c.px(ax, ay - 2, key); c.px(bx, by - 2, key)
        }
        const [sx, sy] = at(0.5, 0.3)
        if (bay < 2) paint(c, bay === 0 ? SKULL : ".xXx.\nXkXkX\nxXbXx\n.bxb.", sx - (bay === 0 ? 3 : 2), sy - (bay === 0 ? 8 : 5))
        else paint(c, "xXx\nkXk\n.x.", sx - 1, sy - 4)
        // candles: tallow sticks, wax run down onto the lip
        const sticks = bay < 2 ? [[0.12, 0.26, 0.2], [0.78, 0.15, 0.3], [0.92, 0.2, 0.12]].slice(0, bay === 0 ? 3 : 2) : [[0.15, 0.2, 0.2]]
        for (const [t, tall, d] of sticks) {
          const [cx, cy] = at(t, d), h = Math.max(2, Math.round(tall * scale)), wide = scale > 26 ? 2 : 1
          c.rect(cx - (wide >> 1), cy - h, wide, h, "x")
          c.px(cx - (wide >> 1), cy - h, "X")
          c.px(cx + 1, cy - Math.round(h * 0.4), "x")  // a run of wax
          c.vline(cx - (wide >> 1), cy, 2, "x")
          if (bay < 2) {
            const fx = cx - 1, fy = cy - h - 5  // the flame's body, as life.px.js's candle covers it
            paint(c, ".o.\noyo\nywy\nywy\nRyR", fx, fy)
            spot("candle flame", fx, fy - 2)
          } else smallFlame(c, cx, cy - h - 1)
        }
      })
    })
}, { amb: 0.85, fog: 12, near: [0.72, 0.82, 1], far: [0.5, 0.64, 1.0] }, (c, C) => {
  // the top band sinks toward black behind the HUD, the near arch's spandrels with it
  sink(c, (x, y) => Math.max(0, Math.min(1, (62 - y) / 40)))
  for (const [x, y] of FIGHT_CHAINS) {
    c.px(x - 1, y - 1, "#3c4147"); c.px(x, y - 1, "#4c4e55"); c.px(x + 1, y - 1, "#3c4147")  // an iron eye under the arch
  }
  // cobwebs in the near arch's corners and across the first niches
  const web = (x, y, sx, sy, r, col) => {
    for (const a of [0, 0.35, 0.75, 1.15, 1.5]) c.line(x, y, Math.round(x + sx * Math.cos(a) * r), Math.round(y + sy * Math.sin(a) * r), col)
    for (const f of [0.45, 0.75]) {
      let px = null
      for (const a of [0, 0.35, 0.75, 1.15, 1.5]) {
        const q = [Math.round(x + sx * Math.cos(a) * r * f), Math.round(y + sy * Math.sin(a) * r * f + 1)]
        if (px) c.line(px[0], px[1], q[0], q[1], col)
        px = q
      }
    }
  }
  web(11, 89, 1, -1, 18, "#262b31")
  web(500, 89, -1, -1, 18, "#262b31")
}, FIGHT_EYE)

chain("chain_fight_0", links(9, 5) + "\n" + HOOK, FIGHT_CHAINS[0], FIGHT_LIGHTS, 0.5)
chain("chain_fight_1", links(15, 6) + "\n" + SHACKLE, FIGHT_CHAINS[1], FIGHT_LIGHTS, 0.6)
chain("chain_fight_2", links(6, 5) + "\n" + HOOK, FIGHT_CHAINS[2], FIGHT_LIGHTS, 0.5)
console.log(`LEDGE bg_fight ${((2 * ledgeY(F.step)) / 572).toFixed(3)} (the step's foot, image y ${(2 * ledgeY(F.step)).toFixed(1)})`)

// ======== Mine: a gallery of the Hollow Mine. The fighters stand on the gravel before a ground sill laid across the
// floor; behind it the gallery runs back between timber sets to a rock face, where the adit goes on into the dark, its
// rails converging on nothing. Lanterns on the sets are the only light; water drips down the rock into puddles.
// The nearest set, near-black, frames the top and the edges; three chains hang from the caps, one with a dead
// lantern. ========
const MN = { sill: 6.41, sillH: 0.2, sillD: 0.3, hw: 5.2, top: 3.6, back: 12.5, sets: [10.0], post: 0.28, rail: 0.45,
  adit: { hw: 1.4, top: 2.5, end: 34, every: 1.8 }, near: { z: 2.6, hw: 2.5, cap: 2.45 } }
const MN_FRONT = MN.sill + MN.sillD  // the gallery's mouth: the front face and its set
// The lanterns: [x, y, z] of their flames, two on the adit's mouth, two on the gallery's set.
const LANTERNS = [[-(MN.adit.hw + 0.16), 2.2, MN.back - 0.3], [MN.adit.hw + 0.16, 2.2, MN.back - 0.3], [-(MN.hw - MN.post - 0.12), 2.3, MN.sets[0] + 0.14], [MN.hw - MN.post - 0.12, 2.3, MN.sets[0] + 0.14]]
const DEEP = [0.95, 1.9, 19.2]  // a small lantern far down the adit, still lit: it shows the sets going on
const LANTERNS_ON_SCREEN = LANTERNS.map(([x, y, z]) => project(FIGHT_EYE, x, y, z))
const capY = (z) => Math.ceil(FIGHT_EYE.vy - (FIGHT_EYE.f * (MN.top - 0.3 - FIGHT_EYE.eye)) / z)  // a set's cap's underside on screen
const MINE_CHAINS = [[118, capY(MN_FRONT - MN.post)], [404, capY(MN_FRONT - MN.post)], [300, capY(MN.sets[0])]]
// Water down the rock: [x, z] of each leak, on the face or the gallery's wall.
const DRIPS = [[-2.4, MN.back], [2.9, MN.back], [MN.hw, 8.4]]

// Rough rock: irregular stones (nearest of jittered points), dark seams, the top of some stones catching light.
function rockMat({ cell = 0.55, face = "3", dark = "2", seam = "1", lit = "4", seed = 0 } = {}) {
  return (p, n, s) => {
    const [u, v] = uv(p, n), gu = u / cell, gv = v / (cell * 0.72), iu = Math.floor(gu), iv = Math.floor(gv)
    let d1 = 9, d2 = 9, id = 0, up = 0
    for (let a = -1; a <= 1; a++)
      for (let b = -1; b <= 1; b++) {
        const cu = iu + a, cv = iv + b, qx = cu + 0.15 + 0.7 * hash(cu + seed, cv), qy = cv + 0.15 + 0.7 * hash(cv * 3, cu + seed)
        const d = Math.hypot(gu - qx, gv - qy)
        if (d < d1) { d2 = d1; d1 = d; id = hash(cu * 7 + seed, cv * 13); up = gv - qy } else if (d < d2) d2 = d
      }
    if ((d2 - d1) * cell * 0.5 < s * 0.9) return seam
    if (up > 0.28 && id > 0.45) return lit
    return id < 0.35 ? dark : face
  }
}
const ROCK = rockMat({ seed: 41 })
const LAG = planks({ w: 0.18, face: "b", dark: "1", seam: "k", lit: "B", seed: 42 })
const mineWall = (p, n, s) => (p[1] > 2.1 + 0.3 * hash(Math.floor(p[0] + p[2]), 3) ? LAG(p, n, s) : ROCK(p, n, s))
// Squared timbers, the grain running along them (up a post, across a cap).
const grain = (up) => (p, n, s) => {
  const [u, v] = uv(p, n), a = up ? u : v, b = up ? v : u, f = (a / 0.045) % 1, row = Math.floor(a / 0.045)
  if (f < s / 0.045 && hash(row, Math.floor(b * 2)) < 0.6) return "b"
  return hash(row, 7) < 0.25 ? "b" : n[0] > 0.5 || n[0] < -0.5 || n[2] < -0.5 ? "B" : "b"
}
const POST = grain(true), CAP = grain(false)
// Gravel, two rails and their sleepers running back into the adit.
function mineFloor(p, n, s) {
  const ax = Math.abs(p[0])
  if (Math.abs(ax - MN.rail) < Math.max(0.03, s * 0.6)) return ax < MN.rail ? "5" : "4"
  const f = ((p[2] % 0.62) + 0.62) % 0.62
  if (ax < 0.78 && f < 0.14) return f < s ? "1" : "B"
  const v = hash(Math.round(p[0] * 24), Math.round(p[2] * 24))
  return v < 0.05 ? "1" : v > 0.975 ? "4" : "2"
}
// A timber set at z: two posts and a cap, half-width hw, `top` high, `w` thick.
const set = (z, hw, top, w, opts = {}) => [
  box([-hw, 0, z], [-hw + w, top, z + w], POST, opts), box([hw - w, 0, z], [hw, top, z + w], POST, opts), box([-hw, top - w - 0.02, z], [hw, top, z + w], CAP, opts)]
// A miner's lantern with its flame's middle at (x, y): iron cap and base, glass round the flame (where life.px.js's
// lantern plays, its 3x4 top-left at (x - 1, y - 2)).
function lanternAt(c, x, y) {
  paint(c, "..242..\n.24442.\n2444442\nk4wyw4k\nk4yyy4k\nk4yoy4k\nk4RoR4k\n2r444r2\n.24442.\n..k2k..", x - 3, y - 5)
  c.vline(x, y - 8, 3, "4")
}

still("bg_mine", (C) => {
  const { sill, sillH, sillD, hw, top, back, post, adit, near } = MN
  const SILL = (p, n, s) => (n[1] > 0.5 ? (p[2] > sill + sillD - s * 1.2 ? "1" : "D") : CAP(p, n, s))
  const face = (p, n, s) => (Math.abs(p[0]) < adit.hw + 0.3 ? ROCK(p, n, s) : mineWall(p, n, s))
  const aditSets = []
  for (let z = back + 0.9; z < adit.end - 1; z += adit.every) aditSets.push(...set(z, adit.hw, adit.top, 0.2))
  return {
    prims: [
      floorPlane((x, z) => Math.abs(x) < 9 && z < MN_FRONT, mineFloor),
      floorPlane((x, z) => Math.abs(x) < hw && z >= MN_FRONT && z < back, mineFloor),
      box([-9, 0, sill], [9, sillH, sill + sillD], SILL, { cast: false }),
      plane(2, MN_FRONT, (x, y) => Math.abs(x) >= hw && Math.abs(x) < 12 && y < top, mineWall),
      ceiling(top, (x, z) => Math.abs(x) < 9 && z < back, LAG),
      sideWall(-hw, MN_FRONT, back, top, mineWall), sideWall(hw, MN_FRONT, back, top, mineWall),
      ...set(MN_FRONT - post, hw + 0.1, top, post),
      ...MN.sets.flatMap((z) => set(z, hw, top, post)),
      // the rock face at the back and the adit going on into the dark
      { ...backWall(back, hw, top, face, (x, y) => Math.abs(x) < adit.hw && y < adit.top), cast: true },
      box([-adit.hw - 0.28, 0, back - 0.26], [-adit.hw, adit.top + 0.3, back], POST), box([adit.hw, 0, back - 0.26], [adit.hw + 0.28, adit.top + 0.3, back], POST),
      box([-adit.hw - 0.4, adit.top, back - 0.26], [adit.hw + 0.4, adit.top + 0.3, back], CAP),
      floorPlane((x, z) => Math.abs(x) < adit.hw && z >= back && z < adit.end, mineFloor),
      sideWall(-adit.hw, back, adit.end, adit.top, ROCK), sideWall(adit.hw, back, adit.end, adit.top, ROCK),
      ceiling(adit.top, (x, z) => Math.abs(x) < adit.hw && z >= back && z < adit.end, LAG),
      ...aditSets,
      backWall(adit.end, adit.hw, adit.top, flat("k")),
      // the nearest set, near-black, framing the top and the edges
      box([-near.hw - 2, 0, near.z], [-near.hw, top, near.z + 0.32], POST, { fg: 2, cast: false }), box([near.hw, 0, near.z], [near.hw + 2, top, near.z + 0.32], POST, { fg: 2, cast: false }),
      box([-near.hw - 2, near.cap, near.z], [near.hw + 2, top, near.z + 0.32], CAP, { fg: 2, cast: false }),
    ],
    lamps: [
      ...LANTERNS.map(([x, y, z]) => ({ p: [x * 0.9, y, z - 0.15], reach: 3.5, power: 1.05, lift: 2.4 })),
      { p: [DEEP[0] - 0.1, DEEP[1], DEEP[2] - 0.1], reach: 3.2, power: 0.75, lift: 2 },  // one left burning deep in the adit
      { p: [0, 1.2, 24], color: COLD, reach: 6, power: 0.2, lift: 9 },  // a faint cold breath from deeper still
    ],
  }
}, (c, C, G) => {
  // the leaks: a wet streak down the rock, drops on the way, a puddle where they land
  for (const [x, z] of DRIPS) {
    const onWall = Math.abs(x) === MN.hw, zz = onWall ? z : z - 0.01
    const [sx, y0] = project(C, x, MN.top, zz), [, y1] = project(C, x, 0, zz)
    for (let y = y0; y < y1; y++) {
      if (c.is(sx, y, "234b1")) c.px(sx, y, "a")
      if (y > y0 + 10 && hash(sx, y) < 0.5 && c.is(sx + 1, y, "234b1")) c.px(sx + 1, y, "a")
    }
    for (let y = y0 + 6; y < y1 - 4; y += 14 + Math.floor(hash(sx, y) * 16)) c.px(sx, y, "A")
    const [px, py] = project(C, onWall ? x - Math.sign(x) * 0.5 : x, 0, onWall ? z : z - 0.5)
    const rw = Math.round(1.2 * (256 / z))
    c.ellipse(px, py, rw >> 1, 1, "a")
    c.hline(px - 1, py, 3, "A")
  }
  for (const [x, y] of LANTERNS_ON_SCREEN) lanternAt(c, x, y)
  const [dx, dy] = project(C, ...DEEP)
  paint(c, ".4.\nkyk\nkok\n.4.", dx - 1, dy - 1)
  // the lanterns' iron arms out from their posts
  LANTERNS_ON_SCREEN.forEach(([x, y], i) => c.hline(i % 2 ? x : x - (i < 2 ? 5 : 8), y - 8, i < 2 ? 6 : 9, "4"))
}, { amb: 0.42, fog: 9, near: [0.66, 0.76, 0.95], far: [0.45, 0.55, 0.85] }, (c, C) => {
  sink(c, (x, y) => Math.max(0, Math.min(1, (58 - y) / 36)))
  // drops on their way down the wet streaks, and the puddles they land in, catching the lamplight
  for (const [x, z] of DRIPS) {
    const onWall = Math.abs(x) === MN.hw, [sx, y0] = project(C, x, MN.top, onWall ? z : z - 0.01), [, y1] = project(C, x, 0, onWall ? z : z - 0.01)
    for (const t of [0.3, 0.55, 0.8]) c.px(sx + (onWall ? 0 : 1), Math.round(y0 + (y1 - y0) * t), "#5f7f8c")
    const [px, py] = project(C, onWall ? x - Math.sign(x) * 0.5 : x, 0, onWall ? z : z - 0.5)
    c.hline(px - 1, py, 3, "#4f6f7c"); c.px(px + 2, py + 1, "#3f5763")
  }
  for (const [x, y] of MINE_CHAINS) { c.px(x - 1, y - 1, "#3c4147"); c.px(x, y - 1, "#4c4e55"); c.px(x + 1, y - 1, "#3c4147") }  // eye bolts
  for (const [x, y] of LANTERNS_ON_SCREEN) spot("lantern flame", x - 1, y - 2)
}, FIGHT_EYE)
console.log(`LEDGE bg_mine ${((2 * ledgeY(MN.sill)) / 572).toFixed(3)} (the sill's foot, image y ${(2 * ledgeY(MN.sill)).toFixed(1)})`)

const MINE_WARM = LANTERNS_ON_SCREEN.map(([x, y]) => [x, y, 80])
chain("chain_mine_0", links(10, 5) + "\n" + HOOK, MINE_CHAINS[0], MINE_WARM, 0.45)
chain("chain_mine_1", links(7, 7) + "\n" + DEAD, MINE_CHAINS[1], MINE_WARM, 0.45)
chain("chain_mine_2", links(4, 5) + "\n" + HOOK, MINE_CHAINS[2], MINE_WARM, 0.45)

// The lanterns' flames, looping over the glass (2 image px a pixel).
anim("lantern", { w: 3, h: 4, fps: 6 }, grid(0, 0, "wyw\nyyy\nyoy\nRoR"),
  frame(),
  frame(grid(0, 0, "ywy\nywy")),
  frame(grid(0, 0, "yyw\nyyy\noyo")),
  frame(grid(0, 0, "ywy\nwyy\nyoy\nooR")),
  frame(grid(0, 0, "yyy\nyoy\nRoo")))

// Dust hanging in the lantern light over the gallery: a still band two `period`s wide that tiles seamlessly, as
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
