extends SceneTree
## Turns the upscaled UI sheets in assets/ui/ (magenta background) into game-pixel pieces in assets/ui/cut/,
## blown back up by SCALE so they line up with the 4x sprites.
## Run: godot --headless --path . -s tools/make_ui.gd

const SRC := "res://assets/ui/"
const OUT := "res://assets/ui/cut/"
const SCALE := 2
const KEY := Color(1, 0, 1)
const KEY_TOLERANCE := 0.35
const TINT := 0.06

## cell/offset measured with .claude/skills/rigging-pixel-sprites/measure_cells.gd.
## names: one per piece, top to bottom (pieces side by side in a band get _0, _1 ...).
## pieces: names for the pieces side by side, left to right, in place of _0, _1 ... (a list per band if several).
## flat: per piece, redraw it as a flat die face (the 3D dice get their light from the scene, not the art):
## an outline, a fill, an optional frame inset by 2, and with cracks, the dark lines inside the original.
## crop: part of the sheet to use, as fractions [x0, y0, x1, y1].
## unbox: clear this many pixels in from the piece's edge (a frame box drawn round each piece).
## hollow: clear the piece's flat fill out from its middle, leaving only the frame (to lay over other art).
## shrink: make each piece this many times smaller once cut (pieces too close to cut apart at the small size).
## gap: pieces side by side less than this many pixels apart are one piece (icons made of loose bits).
const SHEETS := [
	{"src": "panel.png", "cell": 10.24, "offset": 0, "names": ["panel"]},
	{"src": "panel.png", "cell": 10.24, "offset": 0, "names": ["panel_frame"], "hollow": true},
	{"src": "button.png", "cell": 10.24, "offset": 0, "names": ["button_normal", "button_hover", "button_pressed", "button_disabled"]},
	{"src": "button.png", "cell": 10.24, "offset": 0, "names": ["button_frame", "button_frame_hover", "button_frame_pressed", "button_frame_disabled"], "hollow": true},
	{"src": "parry bar.png", "cell": 8.01, "offset": 6, "names": ["bar_frame", "bar_blue", "bar_orange", "bar_marker"]},
	{"src": "profile.png", "cell": 11.43, "offset": 3, "names": ["frame"]},
	{"src": "dice.png", "cell": 8.56, "offset": 6, "names": ["die"], "pieces": ["bone", "cursed", "empty", "locked", "placed"],
		"flat": {
			"bone": {"fill": Color("c1b59b")},
			"cursed": {"fill": Color("5a5148"), "cracks": true},
			"empty": {"fill": Color("18202b")},
			"locked": {"fill": Color("171a24"), "frame": Color("d37738")},
			"placed": {"fill": Color("151b27"), "frame": Color("567385")},
		}},
	{"src": "health bar.png", "cell": 4.31, "offset": 4, "names": ["hp"], "pieces": ["frame", "red", "blue", "heart", "shield"]},
	{"src": "map icon.png", "cell": 4.31, "offset": 4, "names": ["room"], "gap": 6,
		"pieces": ["fight", "forge", "campfire", "boss", "unknown", "cleared"]},
	# Read at twice the measured cell (4.28), so an icon is about 17 pixels: small enough to sit under a die.
	{"src": "icons.png", "cell": 9.0, "offset": 2, "names": ["icon", "icon"], "gap": 4, "pieces": [
		["sword", "shield", "broken_shield", "rune", "bell"],
		["bandage", "shard", "ember", "reroll", "skull"]]},
	# Shrunk 6x after cutting, so an icon is about 12 pixels: a badge for a die's corner.
	{"src": "slot icons.webp", "cell": 4.27, "offset": 4, "names": ["slot"], "gap": 2, "shrink": 6.0,
		"pieces": ["attack", "guard", "cleave"]},
	# A repeating tile for the dice tray's floor (scripts/dice_tray.gd).
	{"src": "bg_tray.webp", "cell": 8.66, "offset": 8, "names": ["tray_felt"]},
	{"src": "intents.webp", "cell": 10.5, "offset": 3, "names": ["intent"], "shrink": 1.5, "gap": 4,
		"pieces": ["attack", "guard", "unblockable", "curse", "ring"]},
	{"src": "ring.webp", "cell": 13.32, "offset": 13, "names": ["ring"], "pieces": ["arcs", "rune"]},
	# Each frame came drawn inside a black box; unbox clears it, keeping the frames on one canvas size.
	{"src": "effects_slash.webp", "cell": 5.35, "offset": 3, "names": ["slash"], "unbox": 2},
	# One per perk in Meta.PERKS order; shrunk so a medallion sits beside a card's name.
	{"src": "perks.webp", "cell": 4.27, "offset": 4, "names": ["perk"], "shrink": 2.5,
		"pieces": ["steady_hand", "thick_skin", "gamblers_heart"]},
	{"src": "map.png", "cell": 4.57, "offset": 0, "names": ["map"]},
	{"src": "logo.png", "cell": 4.28, "offset": 2, "names": ["logo"], "gap": 1000},
	# The middle of the sheet, read at the cell that makes it 40 pixels wide: a die's width at 2x, so it
	# lies on a die one pixel to one pixel (measured cell is 4.27).
	{"src": "chains.png", "cell": 7.65, "offset": 4, "crop": [0.35, 0.0, 0.65, 1.0], "names": ["chains"], "gap": 1000},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for s in SHEETS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + s.src))
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(Rect2i(Vector2i.ONE * s.offset, img.get_size() - Vector2i.ONE * s.offset))
		if s.has("crop"):
			var c: Array = s.crop
			var full := Vector2(img.get_size())
			img = img.get_region(Rect2i(Vector2i(Vector2(c[0], c[1]) * full), Vector2i(Vector2(c[2] - c[0], c[3] - c[1]) * full)))
		img = _read_cells(img, s.cell)
		var rows := _bands(img, true, Rect2i(Vector2i.ZERO, img.get_size()))
		assert(rows.size() == s.names.size(), "%s: found %d bands, expected %d" % [s.src, rows.size(), s.names.size()])
		for i in rows.size():
			var cols := _bands(img, false, rows[i], s.get("gap", 1))
			var row_pieces: Array = s.pieces[i] if s.has("pieces") and s.pieces[0] is Array else s.get("pieces", [])
			assert(cols.size() == 1 or row_pieces.is_empty() or cols.size() == row_pieces.size(),
				"%s band %d: found %d pieces, expected %d" % [s.src, i, cols.size(), row_pieces.size()])
			for j in cols.size():
				var piece := img.get_region(cols[j])
				piece = piece.get_region(piece.get_used_rect())
				if s.has("shrink"):
					piece = _shrink(piece, s.shrink)
				for k in s.get("unbox", 0):  # clear the outermost rings: a box drawn around the piece
					var inner := Rect2i(Vector2i.ONE * (k + 1), piece.get_size() - Vector2i.ONE * (k + 1) * 2)
					for y in piece.get_height():
						for x in piece.get_width():
							if not inner.has_point(Vector2i(x, y)):
								piece.set_pixel(x, y, Color(0, 0, 0, 0))
				if s.get("hollow", false):
					_hollow(piece)
				if s.has("flat"):
					piece = _flat_die(piece, s.flat[s.pieces[j]])
				piece.resize(piece.get_width() * SCALE, piece.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
				var name: String = s.names[i] + ("" if cols.size() == 1 else "_" + (row_pieces[j] if row_pieces else str(j)))
				piece.save_png(OUT + name + ".png")
				print("%s: %dx%d" % [name, piece.get_width() / SCALE, piece.get_height() / SCALE])
	quit()


## One pixel per cell, averaged over the cell's middle; magenta cells become transparent.
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
			var c := Color(sum.r / (inner * inner), sum.g / (inner * inner), sum.b / (inner * inner))
			var d := Vector3(c.r - KEY.r, c.g - KEY.g, c.b - KEY.b).length()
			# Edges blended into the magenta keep its hue (green well below red and blue); none of the art does.
			var tinted := minf(c.r, c.b) - c.g > TINT
			out.set_pixel(x, y, Color(0, 0, 0, 0) if d < KEY_TOLERANCE or tinted else c)
	return out


## The runs of non-empty rows (or columns) inside `area`, as rects; runs less than `gap` apart are joined.
func _bands(img: Image, by_row: bool, area: Rect2i, gap := 1) -> Array[Rect2i]:
	var runs: Array[Vector2i] = []  # [start, end) along the axis
	var n := area.size.y if by_row else area.size.x
	var start := -1
	for i in n + 1:
		var filled := false
		if i < n:
			for k in (area.size.x if by_row else area.size.y):
				var p := area.position + (Vector2i(k, i) if by_row else Vector2i(i, k))
				if img.get_pixelv(p).a > 0:
					filled = true
					break
		if filled and start < 0:
			start = runs.pop_back().x if not runs.is_empty() and i - runs.back().y < gap else i
		elif not filled and start >= 0:
			runs.append(Vector2i(start, i))
			start = -1
	var out: Array[Rect2i] = []
	for r in runs:
		out.append(Rect2i(area.position.x, area.position.y + r.x, area.size.x, r.y - r.x) if by_row
			else Rect2i(area.position.x + r.x, area.position.y, r.y - r.x, area.size.y))
	return out


func _flat_die(src: Image, look: Dictionary) -> Image:
	const SIZE := 20
	const OUTLINE := Color("070e10")
	var out := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	out.fill(OUTLINE)
	out.fill_rect(Rect2i(1, 1, SIZE - 2, SIZE - 2), look.fill)
	if look.has("frame"):
		out.fill_rect(Rect2i(2, 2, SIZE - 4, SIZE - 4), look.frame)
		out.fill_rect(Rect2i(3, 3, SIZE - 6, SIZE - 6), look.fill)
	if look.get("cracks", false):
		for y in range(3, mini(src.get_height(), SIZE) - 3):
			for x in range(3, mini(src.get_width(), SIZE) - 3):
				if src.get_pixel(x, y).get_luminance() < 0.22:
					out.set_pixel(x, y, OUTLINE)
	return out


## Makes `img` k times smaller: each block becomes its most common colour (near-equal colours count as
## one), or clear if under half of it is opaque. Averaging instead would blend the outlines into the fills.
func _shrink(img: Image, k: float) -> Image:
	var size := Vector2i((Vector2(img.get_size()) / k).round())
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var votes := {}  # colour rounded to 1/8 steps -> [count, a real colour of it]
			var opaque := 0
			var block := Rect2i(Vector2i(Vector2(x, y) * k), Vector2i.ONE * ceili(k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			for by in range(block.position.y, block.end.y):
				for bx in range(block.position.x, block.end.x):
					var c := img.get_pixel(bx, by)
					if c.a == 0:
						continue
					opaque += 1
					var key := Vector3i(roundi(c.r * 8), roundi(c.g * 8), roundi(c.b * 8))
					votes[key] = [votes.get(key, [0])[0] + 1, c]
			if opaque * 2 < block.get_area():
				continue
			var best: Array = votes.values().reduce(func(a, b): return b if b[0] > a[0] else a)
			out.set_pixel(x, y, best[1])
	return out


## Clears the fill a frame encloses: floods out from the middle through every pixel near its colour.
func _hollow(img: Image) -> void:
	const NEAR := 0.1
	var fill := img.get_pixelv(img.get_size() / 2)
	var stack: Array[Vector2i] = [img.get_size() / 2]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if not Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
			continue
		var c := img.get_pixelv(p)
		if c.a == 0 or Vector3(c.r - fill.r, c.g - fill.g, c.b - fill.b).length() > NEAR:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])
