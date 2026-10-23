extends SceneTree
## Turns the reference paintings in art/reference/ into game sprites: crop to the figure,
## shrink to game pixels, cut out the flat background, and snap every sprite to one shared palette.
## Run: godot --headless --path . -s tools/make_sprites.gd [-- --preview=<png path>]

const REF := "res://art/reference/"
const OUT := "res://assets/sprites/"
const PALETTE_PATH := "res://assets/palette.png"
const PALETTE_SIZE := 40  # 32 left no straw yellow or bronze once the dummy and the bell joined
const BG_TOLERANCE := 0.14  # how close to the background colour a pixel must be to be cut out
const MAGENTA_TINT := 0.08  # on a magenta background, a pixel whose red and blue beat its green by this is background
const POCKET_TOLERANCE := 0.04  # --pockets: the flat background itself, not dark parts of the figure near it

## h: figure height in game pixels (the game runs at 320x180, scaled up).
## crop: part of the reference to use, as fractions [x0, y0, x1, y1].
## flip: mirror it, so enemies face left toward the hero.
## cell: the reference is already pixel art, blown up by this factor (measure it with
## .claude/skills/rigging-pixel-sprites/measure_cells.gd); it is read back one cell per pixel instead
## of shrunk to h.
## shrink: after cutting out at full detail, keep 1 pixel per shrink x shrink block, so references
## drawn at finer detail match the others' pixel size. Shrinking blends the outline into the background, and the cut-out then leaks
## through the gaps into the figure.
## pad: empty pixels kept around the figure, for rig parts that swing past its edge.
## holes: points in the finished sprite (after flip and pad, read off its zoom) inside pockets of background
## the edge fill can't reach, like the gap between an arm and the body; each is flood-filled out.
## Find them with --pockets, which lists patches of the exact background colour (check each against the reference).
## body: an edit of the same reference with the moving parts removed and what was behind them drawn in
## (see art/character_prompts.md). Saved as <out>_body.png on the same canvas, for tools/rig_sprites.gd.
## Cell sources only.
const SPRITES := [
	{"src": "deserter.webp", "out": "deserter", "cell": 10.24, "shrink": 1.22, "pad": 2, "body": "deserter_body.webp"},  # 78 px tall at its own grid; the hero stands about 64
	{"src": "skeleton_and_rotwood", "out": "skeleton", "cell": 10.0, "shrink": 2, "crop": [0.0, 0.0, 0.5, 1.0], "flip": true, "pad": 2,
		"holes": [Vector2i(29, 24), Vector2i(21, 23)]},  # between the sword arm and the ribs; at the waist
	{"src": "skeleton_and_rotwood", "out": "rotwood_treant", "cell": 10.0, "shrink": 2, "crop": [0.5, 0.0, 1.0, 1.0], "pad": 2,
		"holes": [Vector2i(31, 14), Vector2i(34, 27), Vector2i(14, 32), Vector2i(21, 34), Vector2i(11, 37)]},  # between branches
	{"src": "bone_warden", "out": "bone_warden", "cell": 10.0, "shrink": 2, "flip": true, "pad": 2,
		"holes": [Vector2i(50, 73), Vector2i(58, 40), Vector2i(63, 44), Vector2i(14, 16), Vector2i(56, 21), Vector2i(3, 30), Vector2i(6, 62),
			Vector2i(36, 50), Vector2i(43, 53), Vector2i(43, 56)]},  # between the legs; arm and ribs; shield rim; belt
	{"src": "mother_moss", "out": "mother_moss", "cell": 10.0, "shrink": 2, "flip": true, "pad": 2,
		"holes": [Vector2i(42, 17), Vector2i(76, 41), Vector2i(60, 65), Vector2i(57, 67), Vector2i(26, 74)]},  # between roots
	{"src": "foreman_grieve", "out": "foreman_grieve", "cell": 20.83, "pad": 2,
		"holes": [Vector2i(54, 15), Vector2i(16, 21), Vector2i(46, 57), Vector2i(41, 60)]},  # between spikes and tatters; not the lantern glass
	{"src": "archivist", "out": "archivist", "cell": 10.0, "shrink": 2, "pad": 2},
	{"src": "gambler", "out": "gambler", "cell": 20.0, "pad": 2},
	{"src": "monk", "out": "monk", "cell": 20.0, "pad": 2},
	{"src": "plague_doctor.webp", "out": "plague_doctor", "cell": 10.24, "flip": true, "pad": 2,
		"holes": [Vector2i(37, 15), Vector2i(23, 18), Vector2i(13, 27), Vector2i(41, 29), Vector2i(47, 37)]},  # slivers between arms, coat and pauldrons
	{"src": "dummy.webp", "out": "dummy", "cell": 10.24, "shrink": 2, "pad": 2},
	{"src": "bone_rat.webp", "out": "bone_rat", "cell": 4.27, "shrink": 4, "pad": 2},
	{"src": "acolyte.webp", "out": "acolyte", "cell": 5.12, "shrink": 3, "pad": 2},
	# Drawn without a real pixel grid (measure_cells finds none), so it is shrunk like a painting.
	{"src": "grave_bell.png", "out": "grave_bell", "h": 56, "pad": 2},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sprites := {}
	var bgs: Array[Color] = []
	for s in SPRITES:
		var cut := _cut(s)
		sprites[s.out] = cut[0]
		bgs.append(cut[1])
		if s.has("body"):
			sprites[s.out + "_body"] = _cut(s.merged({"src": s.body}, true), cut[2])[0]
	var palette := _palette(sprites.values())
	for i in SPRITES.size():  # after the palette, so cutting a pocket doesn't shift every sprite's colours
		if SPRITES[i].has("holes"):
			_cut_background(sprites[SPRITES[i].out], bgs[i], SPRITES[i].holes)
		if "--pockets" in OS.get_cmdline_user_args():
			_report_pockets(SPRITES[i].out, sprites[SPRITES[i].out], bgs[i])
	for name in sprites:
		_snap(sprites[name], palette)
		sprites[name].save_png(OUT + name + ".png")
	var strip := Image.create_empty(palette.size(), 1, false, Image.FORMAT_RGBA8)
	for i in palette.size():
		strip.set_pixel(i, 0, palette[i])
	strip.save_png(PALETTE_PATH)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			_preview(sprites, palette, bgs[0]).save_png(arg.trim_prefix("--preview="))
	for name in sprites:
		print("%s: %dx%d" % [name, sprites[name].get_width(), sprites[name].get_height()])
	quit()


## Returns [sprite Image with transparent background, background colour, the canvas rect it was cut to].
## `canvas` forces that rect, so a body layer lands on the same canvas as its sprite.
func _cut(s: Dictionary, canvas := Rect2i()) -> Array:
	var src: String = s.src if "." in s.src else s.src + ".jpg"
	var img := Image.load_from_file(ProjectSettings.globalize_path(REF + src))
	img.convert(Image.FORMAT_RGBA8)
	var c: Array = s.get("crop", [0.0, 0.0, 1.0, 1.0])
	var full := img.get_size()
	img = img.get_region(Rect2i(int(c[0] * full.x), int(c[1] * full.y), int((c[2] - c[0]) * full.x), int((c[3] - c[1]) * full.y)))
	if s.has("cell"):
		img = _read_cells(img, s.cell)
		var bg_px := _corner_color(img)
		_cut_background(img, bg_px)
		if s.has("shrink"):
			img = _shrink(img, s.shrink)
		if s.get("flip", false):
			img.flip_x()
		var rect := canvas if canvas.has_area() else img.get_used_rect().grow(s.get("pad", 0))
		img = img.get_region(rect)
		return [img, bg_px, rect]
	var bg := _corner_color(img)

	# Find the figure on a thumbnail, then crop the full image to it plus a band of background.
	var thumb: Image = img.duplicate()
	thumb.resize(200, int(200.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	var fig := _figure_box(thumb, bg)
	var k := float(img.get_width()) / thumb.get_width()
	var padded := fig.grow(4).intersection(Rect2i(Vector2i.ZERO, thumb.get_size()))
	img = img.get_region(Rect2i(Vector2i(Vector2(padded.position) * k), Vector2i(Vector2(padded.size) * k)))

	# Shrink in halves first so every game pixel averages its whole block, not a few samples.
	var scale: float = s.h / (fig.size.y * k)
	var target := Vector2i(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)))
	while img.get_width() >= target.x * 2:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)

	_cut_background(img, bg)
	if s.get("flip", false):
		img.flip_x()
	var rect := img.get_used_rect().grow(s.get("pad", 0))
	img = img.get_region(rect)
	return [img, bg, rect]


## One pixel per cell of an upscaled pixel-art image, averaged over the cell's middle so blur and
## compression noise at the cell edges (the factor is rarely a whole number) never leak in.
func _read_cells(img: Image, cell: float) -> Image:
	var size := Vector2i((Vector2(img.get_size()) / cell).floor())
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var inner := maxi(1, int(cell / 2))
	for y in size.y:
		for x in size.x:
			var corner := Vector2i(Vector2((x + 0.5) * cell, (y + 0.5) * cell)) - Vector2i.ONE * (inner / 2)
			var sum := Color(0, 0, 0, 0)
			for dy in inner:
				for dx in inner:
					sum += img.get_pixelv(corner + Vector2i(dx, dy))
			out.set_pixel(x, y, Color(sum.r / (inner * inner), sum.g / (inner * inner), sum.b / (inner * inner)))
	return out


## Each k x k block becomes its most common opaque colour (near-equal colours count as one, ties go
## to the one nearest the block's average), or transparent if fewer than half of it is opaque.
## Averaging instead would blend 1-pixel outlines into the fill.
## k may be uneven (1.22): then blocks are 1 or 2 pixels wide, by where the k-steps fall.
func _shrink(img: Image, k: float) -> Image:
	var out := Image.create_empty(int(img.get_width() / k), int(img.get_height() / k), false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var groups := {}  # quantised colour -> [count, a real colour from the block]
			var mean := Color(0, 0, 0, 0)
			var opaque := 0
			var block := Rect2i(int(x * k), int(y * k), maxi(1, int((x + 1) * k) - int(x * k)), maxi(1, int((y + 1) * k) - int(y * k)))
			for by in range(block.position.y, block.end.y):
				for bx in range(block.position.x, block.end.x):
					var c := img.get_pixel(bx, by)
					if c.a > 0.5:
						var key := Vector3i(roundi(c.r * 12), roundi(c.g * 12), roundi(c.b * 12))
						groups[key] = [groups.get(key, [0, c])[0] + 1, c]
						mean += c
						opaque += 1
			if opaque * 2 < block.get_area():
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			mean /= opaque
			var best: Array = []
			for g in groups.values():
				if best.is_empty() or g[0] > best[0] or (g[0] == best[0] and _dist(g[1], mean) < _dist(best[1], mean)):
					best = g
			out.set_pixel(x, y, Color(best[1], 1))
	return out


func _corner_color(img: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	var size := img.get_size()
	for corner in [Vector2i(0, 0), Vector2i(size.x - 16, 0), Vector2i(0, size.y - 16), Vector2i(size.x - 16, size.y - 16)]:
		for y in 16:
			for x in 16:
				sum += img.get_pixelv(corner + Vector2i(x, y))
				n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n)


func _figure_box(thumb: Image, bg: Color) -> Rect2i:
	var lo := thumb.get_size()
	var hi := Vector2i(-1, -1)
	for y in thumb.get_height():
		for x in thumb.get_width():
			if _dist(thumb.get_pixel(x, y), bg) > BG_TOLERANCE * 1.5:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Prints each patch of 6+ opaque pixels nearly the exact background colour: candidates for "holes".
## Some are dark parts of the figure that only look like the background, so check each against the reference.
func _report_pockets(name: String, img: Image, bg: Color) -> void:
	var seen := {}
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2i(x, y)
			if seen.has(p) or img.get_pixelv(p).a == 0.0 or _dist(img.get_pixelv(p), bg) > POCKET_TOLERANCE:
				continue
			var patch: Array[Vector2i] = []
			var stack: Array[Vector2i] = [p]
			seen[p] = true
			while not stack.is_empty():
				var q: Vector2i = stack.pop_back()
				patch.append(q)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = q + d
					if Rect2i(Vector2i.ZERO, img.get_size()).has_point(n) and not seen.has(n) \
							and img.get_pixelv(n).a > 0.0 and _dist(img.get_pixelv(n), bg) <= POCKET_TOLERANCE:
						seen[n] = true
						stack.append(n)
			if patch.size() >= 6:
				var box := Rect2i(patch[0], Vector2i.ONE)
				for q in patch:
					box = box.expand(q).expand(q + Vector2i.ONE)
				print("%s pocket: seed Vector2i(%d, %d), %d px in %s" % [name, patch[0].x, patch[0].y, patch.size(), box])


## Flood-fills the background from the edges, so dark areas inside the outline are kept.
## Given `seeds`, fills from those points only (pockets the edge fill missed), and only the flat background.
func _cut_background(img: Image, bg: Color, seeds: Array = []) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var stack: Array[Vector2i] = []
	for p in seeds:
		stack.append(Vector2i(p))
	if seeds.is_empty():
		for x in w:
			stack.append(Vector2i(x, 0))
			stack.append(Vector2i(x, h - 1))
		for y in h:
			stack.append(Vector2i(0, y))
			stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var col := img.get_pixelv(p)
		if col.a == 0.0 or _dist(col, bg) > (POCKET_TOLERANCE if seeds else BG_TOLERANCE):
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])
	# A key colour like magenta is in no figure, so pockets of it the fill can't reach (between an arm
	# and the body) are background too. A dark background is not: it matches dark parts of the figure.
	if bg.s < 0.5:
		return
	# Edges shrunk or blended into magenta keep its hue (green well below red and blue), which no art uses.
	var magenta := bg.r > 0.6 and bg.b > 0.6 and bg.g < 0.4
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if _dist(c, bg) <= BG_TOLERANCE or (magenta and minf(c.r, c.b) - c.g > MAGENTA_TINT):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


## K-means over every opaque pixel of every sprite, so all characters share one palette.
func _palette(images: Array) -> Array[Color]:
	var pixels: Array[Color] = []
	for img in images:
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5:
					pixels.append(c)
	pixels.sort_custom(func(a, b): return a.get_luminance() < b.get_luminance())
	var centers: Array[Color] = []
	for i in PALETTE_SIZE:  # start spread across brightness, darkest to lightest
		centers.append(pixels[int((i + 0.5) * pixels.size() / PALETTE_SIZE)])
	for iteration in 12:
		var sums: Array[Vector4] = []
		sums.resize(PALETTE_SIZE)
		sums.fill(Vector4.ZERO)
		for c in pixels:
			var i := _nearest(c, centers)
			sums[i] += Vector4(c.r, c.g, c.b, 1)
		for i in PALETTE_SIZE:
			if sums[i].w > 0:
				centers[i] = Color(sums[i].x / sums[i].w, sums[i].y / sums[i].w, sums[i].z / sums[i].w)
	centers.sort_custom(func(a, b): return a.get_luminance() < b.get_luminance())
	return centers


func _snap(img: Image, palette: Array[Color]) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, palette[_nearest(c, palette)] if c.a > 0.5 else Color(0, 0, 0, 0))


func _nearest(c: Color, palette: Array[Color]) -> int:
	var best := 0
	var best_d := INF
	for i in palette.size():
		var d := _dist(c, palette[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## All sprites side by side at 4x on the reference background, palette strip underneath.
func _preview(sprites: Dictionary, palette: Array[Color], bg: Color) -> Image:
	const S := 4
	var width := 8
	var height := 0
	for img in sprites.values():
		width += img.get_width() * S + 8
		height = maxi(height, img.get_height() * S)
	var sheet := Image.create_empty(width, height + 48, false, Image.FORMAT_RGBA8)
	sheet.fill(bg)
	var x := 8
	for img in sprites.values():
		var big: Image = img.duplicate()
		big.resize(img.get_width() * S, img.get_height() * S, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, height - big.get_height()))
		x += big.get_width() + 8
	for i in palette.size():
		sheet.fill_rect(Rect2i(8 + i * 24, height + 16, 24, 24), palette[i])
	return sheet
