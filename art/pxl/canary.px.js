// The canary's frame-by-frame animations, built from its rig parts (canary_parts.px.js) by lib.px.js's moves,
// plus a wing that flaps: cut out of the body here, turned about the shoulder in every frame.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/canary.px.js
include("canary_parts.px.js")
include("lib.px.js")

// The folded wing, shoulder to tip, lifted out of the body into its own part.
const WING = [[15, 11], [20, 12], [31, 26], [31, 30], [24, 30], [16, 22], [14, 16]]
const inWing = (x, y) => {
  let inside = false
  for (let i = 0, j = WING.length - 1; i < WING.length; j = i++) {
    const [xi, yi] = WING[i], [xj, yj] = WING[j]
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside
  }
  return inside
}
// ponytail: the hole the raised wing leaves is one flat body colour; a drawn wingless body layer
// (art/character_prompts.md, like deserter_body) would show real feathers there.
const body = PARTS.body.split("\n"), wing = [], under = []
const fill = body[1 + 22][12]  // the body's mid tone, below the breast
for (let y = 1; y < body.length; y++) {
  let w = "", u = ""
  for (let x = 0; x < body[y].length; x++) {
    const k = body[y][x], take = k !== "." && inWing(x + 0.5, y - 0.5)
    w += take ? k : "."; u += take ? fill : "."
  }
  if (/[^.]/.test(w)) body[y] = [...body[y]].map((k, x) => (w[x] !== "." ? "." : k)).join("")
  wing.push(w); under.push(u)
}
PARTS.body = body.join("\n")
PARTS.wing = "\n" + wing.join("\n")
RIG.under = [0, 0, under.join("\n")]
RIG.wing = { pivot: [16, 13] }

// Each frame's pose, with the wing turned `w` radians (negative lifts it) on top, riding with the torso.
const K = kit()
const f = RIG.facing
const W = (ms, p = {}, w = 0, extra) => [ms, p, (c) => {
  const x = p.x ?? 0, t = p.t ?? [0, 0], ch = p.ch ?? [0, 0]
  K.turn(c, "wing", w, f * (x + t[0] + ch[0]), t[1] + ch[1], p.tint && retint({ rgb: [255, 70, 70], k: 0.55 }))
  if (extra) K.smear(c, { dx: x + t[0], dy: t[1], ...extra })
}]
const [sw, ss] = RIG.weapon.swing, mid = (sw + ss) / 2

standard("canary", {
  // A slow beat: wing up on the breath in, down on the breath out.
  idle: [
    W(400, {}, 0),
    W(200, { t: [0, 1], ch: [0, -1], k: 1 }, -0.35),
    W(300, { t: [0, 1] }, -0.7),
    W(200, { h: [0, 1], k: 0 }, -0.35),
  ],
  // Wings flare up on the wind-up and beat down with the peck (impact at 0.2 s).
  attack: [
    W(80, { x: -1, t: [0, 1], a: sw * 0.2 }, -0.4),
    W(80, { x: -1, t: [-1, 0], a: sw, h: [-1, 0], k: 1 }, -0.9),
    W(40, { x: 3, a: mid }, -0.3, { from: sw + (ss - sw) * 0.2, to: mid }),
    W(100, { x: 5, t: [1, 1], a: ss, h: [1, 1], k: -1 }, 0.15, { from: mid + (ss - mid) * 0.3, to: ss }),
    W(100, { x: 5, t: [1, 1], a: ss, h: [1, 1] }, 0.1),
    W(100, { x: 3, a: ss / 2 }, -0.2),
    W(60, { x: 1 }, 0),
  ],
  // Flinch: the wing jerks up and settles.
  hurt: [
    W(70, { x: -3, h: [-1, 1], a: -sw * 0.1, tint: "red" }, -0.6),
    W(130, { x: -3, t: [-1, 1], h: [-2, 1], a: -sw * 0.08, k: 1 }, -0.8),
    W(100, { x: -2, t: [0, 1], h: [-1, 0] }, -0.3),
    W(100, { x: -1 }, 0),
  ],
})
