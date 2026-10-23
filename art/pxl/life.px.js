// Flames laid over the backdrop paintings (scripts/backdrop_life.gd). One pxl pixel is the painting's
// own pixel: 2 image px on menu and fight, 4 on camp.
// Build: node .claude/skills/pxl-pixel-art/bin/pxl.js build art/pxl/life.px.js
// then copy out/anims/<name>.png + .json to assets/ui/life/.

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

// Menu: the two torch braziers flanking the stairs (2 image px a pixel).
pal({ R: "#a8522e", o: "#e8743c", y: "#f6b45e", w: "#fce290" })
flame("torch", { top: 4, tongue: 3, fps: 10, mask: `
	..................
	.........oo.......
	........ooyR......
	......oooooR......
	.....ooyoooR......
	.....ooyoyyRR.....
	.....Ryyyyooo.....
	.....Royywyyoo....
	...oooyywwyyyoo...
	.oooooyywwwyyooR..
	.ooyyyywwwwyyoyRo.
	.oyoyywwwwwyyoyoo.
	Ryooyywwwwwwyyyoo.
	.yyyywwwoywwwwyyoo
	ooyywwww..wwwwyyyo
	..oywww....wwwyoo.
	..yyww.....wwwyRo.
	..yyyy......yyo...` })
flame("torch_r", { top: 4, tongue: 3, fps: 10, mask: `
	..........RR........
	.........oooR.......
	........Royoo.......
	..o.....Roooo.......
	..oyyo..RoyyoR......
	..ooyooooyyyoR......
	...ooooyyyyyoR......
	....oooyyyyyooo.....
	....ooyyywwwooo.....
	.ooooyyyywwwoooo....
	.ooooyywwwwwyoooo...
	.ooyywwwwwwwyooyoo..
	.yoyywwwwwwwyyoooo..
	.ooyywwww.wwwyyyoo..
	.yowwwwwo.wwwwyyoo..
	.Rowwwyo..owwwyyR...
	.Rowwww....wwwyy....
	..oyy.......wyyo....` })

// Camp: the campfire (4 image px a pixel), sparks drifting up out of it.
pal({ R: "#9a3f14", o: "#d3621f", y: "#fa903e", w: "#ffd47a" })
flame("campfire", { top: 6, tongue: 3, fps: 8, sparks: [{ x: 10, y: 7, off: 0 }, { x: 5, y: 9, off: 3 }, { x: 13, y: 10, off: 5 }], mask: `
	.........o........
	........ooR.......
	........ooR.......
	........oooR......
	...oo...oooR......
	...oo...oooo......
	..ooo.Ro.yyoo.....
	..oooooooyyoo.....
	.oooooooyyyoo.oo..
	.ooooooywyyoo.oo..
	..ooooyywyyoo.ooo.
	...oooyywwyyooooo.
	...oyyyywwyyooooo.
	..ooyyyywwyyoooR..
	.Royyyywwwwyyooo..
	.oyyyywwwwwyyyyo..
	oyyywwwwoowwyyyoo.
	oyywwwwwR.wwwwyyo.
	oyywwwwwwwwwwwyyo.
	oywwwwwwwwwwwwyyo.
	oyywwwwwwwwwwyyyoo` })

// Fight: one small candle flame for every candle on the ledges (2 image px a pixel).
pal({ R: "#8a5a30", o: "#d49a5c", y: "#efbe7c", w: "#fbe0a8" })
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
