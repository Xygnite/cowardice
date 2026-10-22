extends SceneTree
## Measures the cell size of upscaled pixel art (the "cell" value for tools/make_sprites.gd).
## Colour edges in real pixel art fall on a regular grid; this finds the spacing (and offset) that
## lines up the most edges. Works for non-whole factors like 10.24.
## Run: godot --headless --path . -s .claude/skills/rigging-pixel-sprites/measure_cells.gd -- <image>

const EDGE := 0.25  # colour jump (summed RGB) that counts as a pixel edge


func _init() -> void:
	var img := Image.load_from_file(OS.get_cmdline_user_args()[0])
	img.convert(Image.FORMAT_RGB8)
	var edges: Array[int] = []  # x of every edge along sampled rows, then y along sampled columns
	for y in range(0, img.get_height(), 7):
		for x in range(1, img.get_width()):
			if _jump(img.get_pixel(x, y), img.get_pixel(x - 1, y)):
				edges.append(x)
	for x in range(0, img.get_width(), 7):
		for y in range(1, img.get_height()):
			if _jump(img.get_pixel(x, y), img.get_pixel(x, y - 1)):
				edges.append(y)
	var scores := {}
	for i in range(200, 3201):  # cell sizes 2.00 .. 32.00
		var c := i / 100.0
		var sum := Vector2.ZERO
		for e in edges:
			sum += Vector2.from_angle(TAU * e / c)
		scores[c] = sum / edges.size()
	var cell := _peak(scores, 2.0, 32.0)
	# Half a cell lines edges up as well as a whole one, so try whole multiples of the peak too.
	var best: float = scores[cell].length()
	for k in [2, 3, 4]:
		var c := _peak(scores, cell * k * 0.98, cell * k * 1.02)
		if c > 0.0 and scores[c].length() >= best * 0.8:
			cell = c
	var offset := fposmod(scores[cell].angle() / TAU * cell, cell)
	print("cell %.2f  offset %.1f px  native %dx%d  (alignment %.2f)" % [cell, offset,
		int(img.get_width() / cell), int(img.get_height() / cell), scores[cell].length()])
	if offset > 1.0 and offset < cell - 1.0:
		print("grid does not start at 0: crop %.0f px off the left/top before using this cell size" % offset)
	quit()


## The cell size between lo and hi whose edges line up best; 0 if none was scored there.
func _peak(scores: Dictionary, lo: float, hi: float) -> float:
	var best := 0.0
	for c in scores:
		if c >= lo and c <= hi and (best == 0.0 or scores[c].length() > scores[best].length()):
			best = c
	return best


func _jump(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > EDGE
