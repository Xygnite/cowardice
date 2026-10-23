// Shared helpers for frame-by-frame character animations built from rig parts.
// A character file includes its <name>_parts.px.js (PAL, PARTS, RIG from tools/pxl_parts.gd), then this, then
// either calls standard(name, overrides) for the usual four moves, or kit() to build its own frames.
// Every frame is the sprite with the same empty margin M on all four sides, wide enough for the weapon to swing
// all the way round its pivot; tools/frames_scene.gd recovers M from the frame and sprite sizes.
// Offsets passed to pose() are in "forward" pixels: +x moves toward the target, whichever way RIG.facing points.
// Angles are real clockwise radians, as in the rig's "swing" values.

// Moves the pixels inside [x0, y0, x1, y1) from one part to another, for cuts the rig outline got wrong;
// with `to` null they are just deleted (hole patches the rig smeared across empty air). Call before kit().
function claim(to, from, [x0, y0, x1, y1]) {
  const a = PARTS[from].split("\n"), b = to && PARTS[to].split("\n")  // row 0 is the empty line after the backtick
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
    if (a[y + 1][x] === ".") continue
    if (b) b[y + 1] = b[y + 1].slice(0, x) + a[y + 1][x] + b[y + 1].slice(x + 1)
    a[y + 1] = a[y + 1].slice(0, x) + "." + a[y + 1].slice(x + 1)
  }
  PARTS[from] = a.join("\n")
  if (b) PARTS[to] = b.join("\n")
}

// Every palette colour mixed toward `rgb` by `k` (0..1), or scaled by `mul` (glow dim/flare).
function retint({ rgb, k = 0, mul }) {
  return Object.fromEntries(Object.entries(PAL).map(([key, hex]) => {
    const n = parseInt(hex.slice(1), 16), c = [n >> 16, (n >> 8) & 255, n & 255]
    const out = c.map((v, i) => Math.min(255, Math.round(mul ? v * mul[i] : v + (rgb[i] - v) * k)))
    return [key, "#" + out.map((v) => v.toString(16).padStart(2, "0")).join("")]
  }))
}

function kit(margin) {
  const f = RIG.facing
  const P = Object.fromEntries(Object.entries(PARTS).map(([k, g]) => [k, g.split("\n").slice(1)]))
  const SW = P.body[0].length, SH = P.body.length
  const pivot = (part) => RIG[part].pivot

  // The weapon's farthest pixel from its pivot: reach and resting angle, for the canvas and the smears.
  let reach = 0, rest = Math.PI / 2
  P.weapon?.forEach((row, y) => [...row].forEach((k, x) => {
    const [px, py] = pivot("weapon"), d = Math.hypot(x + 0.5 - px, y + 0.5 - py)
    if (k !== "." && d > reach) [reach, rest] = [d, Math.atan2(y + 0.5 - py, x + 0.5 - px)]
  }))
  const M = margin ?? (() => {
    const [px, py] = P.weapon ? pivot("weapon") : [SW / 2, SH / 2]
    return Math.ceil(Math.max(0, reach + 2 - Math.min(px, py, SW - px, SH - py))) + 8  // + lunge and knockback
  })()
  const W = SW + 2 * M, H = SH + 2 * M, OX = M, OY = M

  // Copies a part at a whole-pixel offset; `tint` maps each key to another colour (hurt flash).
  // `shear` swings it like a hanging thing: rows below its pivot shift up to `shear` px at its bottom.
  function put(c, part, dx = 0, dy = 0, tint, shear = 0) {
    const g = P[part]
    if (!g) return
    const top = shear ? pivot("lantern")[1] : 0, bottom = g.findLastIndex((row) => /[^.]/.test(row))
    g.forEach((row, y) => {
      const sx = shear ? Math.round(shear * Math.min(1, Math.max(0, (y - top) / (bottom - top)))) : 0
      ;[...row].forEach((k, x) => { if (k !== ".") c.px(OX + x + dx + sx, OY + y + dy, tint ? tint[k] : k) })
    })
  }

  // A part turned `a` radians clockwise about its rig pivot, nearest-neighbour, like the rig does it,
  // but baked so each pose can be touched up and drawn behind or in front.
  function turn(c, part, a, dx = 0, dy = 0, tint) {
    const g = P[part]
    if (!g) return
    const [px, py] = pivot(part), cos = Math.cos(a), sin = Math.sin(a), R = g.length + g[0].length
    for (let y = -R; y < R; y++) for (let x = -R; x < R; x++) {
      const cx = x + 0.5, cy = y + 0.5  // sample at pixel centres
      const sx = Math.floor(px + cx * cos + cy * sin), sy = Math.floor(py - cx * sin + cy * cos)
      const k = g[sy]?.[sx]
      if (k && k !== ".") c.px(OX + px + x + dx, OY + py + y + dy, tint ? tint[k] : k)
    }
  }

  // The arc a weapon swept from angle `from` to `to` about its pivot: a pale crescent between radii r0 and r1,
  // bright at the leading end, thin and dithered at its tail. `rest` is the weapon's own angle at rotation 0.
  // Both default to the weapon's farthest pixel. dx/dy are forward pixels like pose(); band: bright rim width.
  function smear(c, { from, to, r, rest: r0rest = rest, dx = 0, dy = 0, band, color = "#a9b8b2", dim = "#6f817f" }) {
    const [r0, r1] = r ?? [Math.max(4, Math.round(reach) - 6), Math.round(reach)]
    band ??= r ? 5 : Math.max(2, Math.round((r1 - r0) / 3))
    const [px, py] = pivot("weapon")
    for (let t = 0; t <= 1; t += 0.01) {
      const a = from + (to - from) * t + r0rest
      for (let rr = r0; rr <= r1; rr++) {
        const x = Math.round(OX + px + f * dx + Math.cos(a) * rr), y = Math.round(OY + py + dy + Math.sin(a) * rr)
        const outer = rr >= r1 - band + Math.round(Math.min(3, band - 1) * (1 - t)), fade = t < 0.4
        if (outer && !fade) c.px(x, y, color)
        else if ((x + y) % 2 === 0 && (outer || t > 0.6)) c.px(x, y, dim)
      }
    }
  }

  const TINTS = {
    red: retint({ rgb: [255, 70, 70], k: 0.55 }),
    dim: retint({ mul: [0.7, 0.6, 0.55] }),
    flare: retint({ mul: [1.5, 1.3, 1.1] }),
  }

  // One whole pose. x: everything; t: torso (body and all it carries) on top of x; ch: chest (breathing) on top
  // of t, carrying weapon, shield, head and lantern; s/h: shield/head extra; a: weapon angle; behind: weapon drawn
  // behind the body (raised over the back shoulder); over: weapon drawn over the shield (a far arm chopping down
  // in front of it); l: lantern sway in px at its bottom; g: glow "dim" or "flare"; k: skirt strips' trail in px;
  // tint: "red" for the hurt flash.
  function pose(c, { x = 0, t = [0, 0], ch = [0, 0], s = [0, 0], h = [0, 0], a = 0, behind = false, over = false,
      l = 0, g, k = 0, tint } = {}) {
    const T = tint && TINTS[tint]
    const tx = f * (x + t[0]), ty = t[1], cx = tx + f * ch[0], cy = ty + ch[1]
    if (behind) turn(c, "weapon", a, cx, cy, T)
    put(c, "legs", RIG.anchored ? 0 : f * x, 0, T)  // anchored: a post or gallows that never slides
    // Hand-painted pixels the weapon used to hide (RIG.under: [x, y, rows]), shown once it swings away.
    if (RIG.under) {
      const [ux, uy, rows] = RIG.under
      rows.split("\n").forEach((row, y) => [...row].forEach((key, i) => {
        if (key !== ".") c.px(OX + ux + i + f * x, OY + uy + y, T ? T[key] : key)
      }))
    }
    put(c, "body", tx, ty, T)
    for (let i = 0; P["skirt_" + i]; i++) put(c, "skirt_" + i, tx - f * k, ty, T)
    put(c, "chest", cx, cy, T)
    if (!behind && !over) turn(c, "weapon", a, cx, cy, T)
    put(c, "shield", cx + f * s[0], cy + s[1], T)
    if (over) turn(c, "weapon", a, cx, cy, T)
    if (RIG.head?.still) h = [0, 0]  // its cut-out hole shows round a head that moves on its own
    put(c, "head", cx + f * h[0], cy + h[1], T)
    put(c, "lantern", cx, cy, T, f * l)
    put(c, "glow", cx, cy, T ?? (g && TINTS[g]), f * l)
  }

  // A frame of `ms` showing pose(opts), then `extra` on top: a function, or smear() options (its dx/dy
  // default to where the frame put the torso).
  const F = (ms, opts = {}, extra) => frame({ ms }, (c) => {
    pose(c, opts)
    if (typeof extra === "function") extra(c)
    else if (extra) smear(c, { dx: (opts.x ?? 0) + (opts.t?.[0] ?? 0), ...extra, dy: (opts.t?.[1] ?? 0) + (extra.dy ?? 0) })
  })

  return { put, turn, smear, pose, F, RED: "red", reach, rest, opts: { w: W, h: H } }
}

// The usual four moves from RIG alone, each overridable with a list of [ms, pose options, extra] frames:
// idle (breathing; lantern and skirt drift), attack (anticipation, wind-up, smear, impact at exactly 0.2 s for
// the enemies' STRIKE_DELAY, hold, recover), block (only with a shield) and hurt (red flash, knockback).
// o.lunge: forward px at the impact; o.over: weapon in front of the shield while striking (default: has a shield);
// o.behind: weapon behind the body at the top of the wind-up.
function standard(name, o = {}) {
  const K = kit(o.margin)
  const [w, s] = RIG.weapon?.swing ?? [0, 0]
  const mid = (w + s) / 2, settle = s + (Math.round(s / (2 * Math.PI)) * 2 * Math.PI - s) / 2
  const L = o.lunge ?? 5, over = o.over ?? !!PARTS.shield, behind = o.behind ?? false
  const moves = {
    idle: o.idle ?? [
      [500, {}],
      [300, { t: [0, 1], ch: [0, -1], s: [0, -1], l: 1, k: 1 }],
      [500, { t: [0, 1], l: 0, g: "dim" }],
      [300, { s: [0, 1], h: [0, 1], l: -1, k: 0 }],
    ],
    attack: o.attack ?? [
      [80, { x: -1, t: [0, 1], a: w * 0.2, l: 1 }],
      [80, { x: -1, t: [-1, 0], a: w, behind, h: [-1, 0], l: 2, k: 1 }],
      [40, { x: L - 2, a: mid, over, l: 0 }, { from: w + (s - w) * 0.2, to: mid }],
      [100, { x: L, t: [1, 1], a: s, h: [1, 1], over, l: -2, k: -1, g: "flare" }, { from: mid + (s - mid) * 0.3, to: s }],
      [100, { x: L, t: [1, 1], a: s, h: [1, 1], over, l: -1, g: "flare" }],
      [100, { x: Math.round(L / 2), a: settle, over, l: 1 }],
      [60, { x: 1 }],
    ],
    block: o.block ?? (PARTS.shield ? [
      [60, { x: -1, s: [1, -2] }],
      [240, { x: -1, t: [0, 1], s: [1, -3], h: [-1, 1] }],
      [100, { s: [0, -1] }],
    ] : null),
    hurt: o.hurt ?? [
      [70, { x: -3, h: [-1, 1], a: -w * 0.1, l: 2, tint: "red" }],
      [130, { x: -3, t: [-1, 1], h: [-2, 1], a: -w * 0.08, l: 1, k: 1, g: "flare" }],
      [100, { x: -2, t: [0, 1], h: [-1, 0], l: -1 }],
      [100, { x: -1 }],
    ],
  }
  const names = []
  for (const [move, frames] of Object.entries(moves)) {
    if (!frames) continue
    anim(name + "_" + move, { ...K.opts, loop: move === "idle" }, ...frames.map(([ms, p, e]) => K.F(ms, p, e)))
    names.push(name + "_" + move)
  }
  sheet(name + "_frames", names, { cols: 99 })
  return K
}
