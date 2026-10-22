extends SceneTree
## Turns the reference paintings in art/reference/ into game sprites: crop to the figure,
## shrink to game pixels, cut out the flat background, and snap every sprite to one shared palette.
## Run: godot --headless --path . -s tools/make_sprites.gd [-- --preview=<png path>]

const REF := "res://art/reference/"
const OUT := "res://assets/sprites/"
const PALETTE_PATH := "res://assets/palette.png"
const PALETTE_SIZE := 32
const BG_TOLERANCE := 0.14  # how close to the background colour a pixel must be to be cut out

## h: figure height in game pixels (the game runs at 320x180, scaled up).
## crop: part of the reference to use, as fractions [x0, y0, x1, y1].
## flip: mirror it, so enemies face left toward the hero.
## cell: the reference is already pixel art, blown up by this factor; it is read back one cell per
## pixel instead of shrunk to h, and left out of the palette fit so adding it never recolours the others.
## pad: empty pixels kept around the figure, for rig parts that swing past its edge.
const SPRITES := [
	{"src": "deserter", "out": "deserter", "h": 48},
	{"src": "skeleton_and_rotwood", "out": "skeleton", "h": 44, "crop": [0.0, 0.0, 0.5, 1.0], "flip": true},
	{"src": "skeleton_and_rotwood", "out": "rotwood_treant", "h": 50, "crop": [0.5, 0.0, 1.0, 1.0]},
	{"src": "bone_warden", "out": "bone_warden", "h": 60},
	{"src": "mother_moss", "out": "mother_moss", "h": 60},
	{"src": "foreman_grieve", "out": "foreman_grieve", "h": 60},
	{"src": "archivist", "out": "archivist", "h": 60},
	{"src": "gambler", "out": "gambler", "h": 48},
	{"src": "monk", "out": "monk", "h": 48},
	{"src": "plague_doctor.webp", "out": "plague_doctor", "cell": 10.24, "flip": true, "pad": 2},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sprites := {}
	var bgs: Array[Color] = []
	for s in SPRITES:
		var cut := _cut(s)
		sprites[s.out] = cut[0]
		bgs.append(cut[1])
	var palette := _palette(SPRITES.filter(func(s): return not s.has("cell")).map(func(s): return sprites[s.out]))
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


## Returns [sprite Image with transparent background, background colour].
func _cut(s: Dictionary) -> Array:
	var src: String = s.src if "." in s.src else s.src + ".jpg"
	var img := Image.load_from_file(ProjectSettings.globalize_path(REF + src))
	img.convert(Image.FORMAT_RGBA8)
	if s.has("cell"):
		img = _read_cells(img, s.cell)
		var bg_px := _corner_color(img)
		_cut_background(img, bg_px)
		if s.get("flip", false):
			img.flip_x()
		return [img.get_region(img.get_used_rect().grow(s.get("pad", 0))), bg_px]
	var c: Array = s.get("crop", [0.0, 0.0, 1.0, 1.0])
	var full := img.get_size()
	img = img.get_region(Rect2i(int(c[0] * full.x), int(c[1] * full.y), int((c[2] - c[0]) * full.x), int((c[3] - c[1]) * full.y)))
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
	return [img.get_region(img.get_used_rect().grow(s.get("pad", 0))), bg]


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


## Flood-fills the background from the edges, so dark areas inside the outline are kept.
func _cut_background(img: Image, bg: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var stack: Array[Vector2i] = []
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
		if col.a == 0.0 or _dist(col, bg) > BG_TOLERANCE:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])


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
