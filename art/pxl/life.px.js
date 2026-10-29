// Flames and fog laid over the backdrops (scripts/backdrop_life.gd). One pxl pixel is the backdrop's own pixel:
// 2 image px each. The fight and Mine chains and the Mine's lantern and dust are in bg_fights.px.js; the menu's chains in bg_screens.px.js.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/life.px.js
// then copy out/anims/<name>.png + .json (flames) and out/sprites/<name>.png (fog) to assets/ui/life/.
include("screen_flames.px.js")  // the menu's and camp's flame masks, painted into their backdrops by bg_screens.px.js

// A looping flame over a painted one. `mask` is the painted flame's silhouette, read off the backdrop at
// its pxl pixel size: every frame keeps all of it opaque, so the still painting never shows through.
// Tongues lick up to `tongue` px above it into `top` rows of headroom, the hot core sways inside, and
// `sparks` ({x, y, off}) rise from (x, y) and fade, each `off` frames into its climb.
function flame(name, { mask, top, tongue, fps, frames = 8, sparks = [] }) {
	const rows = mask.trim().split("\n").map((r) => r.trim())
	const W = rows[0].length, H = rows.length + top
	const inMask = (x, y) => y >= top && (rows[y - top][x] ?? ".") !== "."
	const topOf = []  // first painted row per column, Infinity when the column is empty
	for (let x = 0; x < W; x++) {
		let t = Infinity
		for (let y = top; y < H && t === Infinity; y++) if (inMask(x, y)) t = y
		topOf.push(t)
	}
	anim(name, { w: W, h: H, frames, fps }, (c) => {
		const k = c.phase * Math.PI * 2
		const on = Array.from({ length: H }, (_, y) => Array.from({ length: W }, (_, x) => inMask(x, y)))
		for (let x = 0; x < W; x++) {
			const t = topOf[x]
			if (t === Infinity) continue
			const peak = t <= Math.min(topOf[x - 1] ?? Infinity, topOf[x + 1] ?? Infinity)
			const s = 0.5 + 0.3 * Math.sin(k + x * 1.9) + 0.2 * Math.sin(2 * k + x * 0.7 + 1)
			const len = Math.round(tongue * s * (peak ? 1 : 0.5))
			for (let y = Math.max(0, t - len); y < t; y++) on[y][x] = true
		}
		// Steps in from the silhouette's edge; the canvas bottom counts as inside (the fire goes on below).
		const depth = on.map((r) => r.map((v) => (v ? Infinity : 0)))
		for (let d = 1, changed = true; changed; d++) {
			changed = false
			for (let y = 0; y < H; y++)
				for (let x = 0; x < W; x++) {
					if (depth[y][x] !== Infinity) continue
					const n = [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]
					if (n.some(([a, b]) => b < H && (a < 0 || a >= W || b < 0 || depth[b][a] === d - 1))) {
						depth[y][x] = d
						changed = true
					}
				}
		}
		// The painted colours, sampled a little off to the side (more towards the top) and from a row
		// lower on some frames, so the bands sway and climb; never hotter than the edge allows.
		const lift = Math.sin(2 * k) > 0 ? 1 : 0
		for (let y = 0; y < H; y++)
			for (let x = 0; x < W; x++) {
				if (!on[y][x]) continue
				const high = (H - 1 - y) / (H - top)  // 0 at the base, 1 at the painted top
				const sx = x + Math.round(1.2 * Math.sin(k + y * 0.6) * high)
				const sy = Math.min(H - 1, y + lift)
				let heat = inMask(sx, sy) ? "Royw".indexOf(rows[sy - top][sx]) : 1
				if (!inMask(x, y)) heat = y > 0 && on[y - 1][x] ? 1 : 0  // a tongue: orange, its tip dark
				const lvl = Math.min(heat, depth[y][x])
				c.px(x, y, "Royw"[lvl])
			}
		for (const sp of sparks) {
			const age = (c.frame + sp.off) % frames
			const y = sp.y - Math.round(age * 1.5)
			const col = ["w", "y", "y", "o", "o", "R"][age]
			if (col && y >= 0) c.px(sp.x + Math.round(Math.sin(age * 0.9 + sp.x)), y, col)
		}
	})
}

// Menu: the braziers either side of the gate; camp: its fire, sparks drifting up out of it. Both are painted with
// kit.px.js's fire colours.
pal({ R: "#a76236", o: "#e0782a", y: "#ffb24a", w: "#ffe08a" })
flame("torch", { top: 4, tongue: 3, fps: 10, mask: TORCH_MASK })
flame("campfire", { top: 6, tongue: 4, fps: 8, sparks: [{ x: 10, y: 6, off: 0 }, { x: 5, y: 9, off: 3 }, { x: 15, y: 8, off: 5 }], mask: CAMPFIRE_MASK })

// Fight: one small candle flame for every candle on the ledges (2 image px a pixel).
pal({ R: "#a76236", o: "#e0782a", y: "#ffb24a", w: "#ffe08a" })  // kit.px.js's fire, as painted on bg_fight's candles
// Too small for flame(): the body (rows 2-6) stays put and covers any painted candle flame up to 6x10
// image px; the tip flickers and leans above it.
anim("candle", { w: 3, h: 7, fps: 8 }, grid(0, 2, `
	.o.
	oyo
	ywy
	ywy
	RyR`),
	frame(grid(1, 1, "R")),
	frame(grid(1, 0, "R\no")),
	frame(grid(1, 0, ".R\no.")),
	frame(grid(1, 1, "o"), grid(0, 3, "oww\nyyy")),
	frame(grid(0, 0, "R.\n.o")),
	frame(grid(1, 1, "R"), grid(0, 4, "wwy")))

// A still fog band two `period`s wide that tiles seamlessly: BackdropLife scrolls it one pxl pixel at a
// time and wraps at `period`. A bank lying on the ground: thickest low down, thinning upward to a soft,
// billowing top, never a hard line. Keys a/b/c/d are its tones, faint to thick (alpha baked in, kept low
// so the scene shows through); `foot` rows at the bottom thin out again so it can end above a ledge.
function fog(name, { period, h, seed, foot = 0 }) {
	sprite(name, { w: period * 2, h }, (c) => {
		// Whole cycles per period, evaluated on x mod period, so both halves are bit-identical.
		const wave = (x, f, ph) => Math.sin((2 * Math.PI * f * (x % period)) / period + ph)
		for (let x = 0; x < c.w; x++) {
			const surf = h * (0.3 + 0.18 * wave(x, 1, seed) + 0.1 * wave(x, 3, seed * 2))  // the bank's top
			for (let y = 0; y < h; y++) {
				let d = (y - surf) / (h - surf)  // 0 at the top, 1 at the bottom
				d += 0.12 * wave(x, 2, seed + y * 0.35)  // slow puffs inside, leaning, several rows tall
				if (foot) d *= Math.min(1, 0.45 + (h - 1 - y) / foot / 2)
				const lvl = Math.floor(d * 4.5)
				if (lvl > 0) c.px(x, y, "abcd"[Math.min(3, lvl - 1)])
			}
		}
	})
}

// Menu: across the moat (2 image px a pixel), moonlit.
pal({ a: "#6a828c2c", b: "#7189934a", c: "#7a929c68", d: "#86a0aa84" })
fog("moat", { period: 96, h: 28, seed: 1 })

// Camp: low ground fog in the strip between the perk board and the buttons.
pal({ a: "#5f758520", b: "#667c8c34", c: "#6f85954a", d: "#7a8e9c60" })
fog("ground", { period: 128, h: 22, seed: 2 })

// Fight: mist along the foot of the back wall, ending above the floor ledge (2 image px a pixel); paler
// than the others, as the floor there is already the fog's grey.
pal({ a: "#7f97a420", b: "#869eab34", c: "#90a8b44a", d: "#9cb3bf60" })
fog("floor", { period: 96, h: 24, seed: 3, foot: 4 })
