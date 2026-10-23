extends SceneTree
## Cuts the swaying chains out of the menu and fight paintings: each chain becomes a 5-frame sway strip in
## assets/ui/life/ (chain_<name>_<i>.png + .json, played by BackdropLife), and the backdrop is saved with the
## wall filled in behind it. Always reads the untouched art/reference/bg_<name>_still.webp, so reruns match.
## Run: godot --headless --path . -s tools/cut_chains.gd

const PX := 2  # image px per pxl pixel on these paintings
const SWING := 2 * PX  # how far the bottom row moves either way, in image px
## Per backdrop: the outline (image px, traced off zooms) of each free-hanging chain, and the point it hangs
## from; only rows below it sway. Outlines are plain Arrays: a PackedVector2Array can't be a constant.
const CHAINS := {
	"menu": [
		# The pair on the left wall, hanging from the bar under the dead tree.
		{"outline": [Vector2(219, 209), Vector2(232, 209), Vector2(232, 358), Vector2(235, 362),
			Vector2(235, 381), Vector2(214, 381), Vector2(214, 365), Vector2(219, 362)], "top": Vector2(226, 209)},
		{"outline": [Vector2(246, 207), Vector2(258, 207), Vector2(258, 388), Vector2(246, 388)],
			"top": Vector2(252, 207)},
		# Under the pillar cap right of the right torch.
		{"outline": [Vector2(775, 199), Vector2(789, 199), Vector2(789, 341), Vector2(775, 341)],
			"top": Vector2(782, 199)},
	],
	"fight": [
		# Left: below where the swag of chain meets it.
		{"outline": [Vector2(111, 106), Vector2(126, 106), Vector2(126, 181), Vector2(130, 183),
			Vector2(130, 201), Vector2(108, 201), Vector2(108, 184), Vector2(111, 181)], "top": Vector2(118, 106)},
		# Right of the window, below its swag.
		{"outline": [Vector2(603, 62), Vector2(616, 62), Vector2(616, 233), Vector2(600, 233),
			Vector2(600, 213), Vector2(603, 213)], "top": Vector2(609, 62)},
		# Right: below the swag and the web strands crossing it.
		{"outline": [Vector2(899, 68), Vector2(916, 68), Vector2(916, 200), Vector2(918, 201),
			Vector2(918, 224), Vector2(893, 224), Vector2(893, 201), Vector2(899, 200)], "top": Vector2(907, 68)},
	],
}


func _init() -> void:
	for name: String in CHAINS:
		var out := cut(name)
		for path: String in out:
			var img: Image = out[path]
			if path.ends_with(".webp"):
				img.save_webp(path, false)
			else:
				img.save_png(path)
				var w := img.get_width() / 5
				var frames := {}
				for f in 5:
					frames["%s_%d" % [path.get_file().get_basename(), f]] = {
						"frame": {"x": f * w, "y": 0, "w": w, "h": img.get_height()}, "duration": 100}
				var file := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
				file.store_string(JSON.stringify({"frames": frames}, "", false))  # unsorted: frames stay in order
				file.close()
			print("wrote ", path)
	quit()


## The pixels an outline covers: integer vertices, so pixel x is inside when minx <= x < maxx.
static func box(outline: Array) -> Rect2i:
	var r := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		r = r.expand(p)
	return Rect2i(r)


## Output res:// path -> Image for one backdrop: its sway strips and the filled-in backdrop.
static func cut(name: String) -> Dictionary:
	var src := Image.new()
	src.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://art/reference/bg_%s_still.webp" % name))
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var cut_out := PackedByteArray()
	cut_out.resize(w * src.get_height())
	var out := {}
	for i in CHAINS[name].size():
		var chain: Dictionary = CHAINS[name][i]
		var outline := PackedVector2Array(chain.outline)
		var r := box(chain.outline)
		var fw := r.size.x + 2 * SWING
		var strip := Image.create_empty(fw * 5, r.size.y, false, Image.FORMAT_RGBA8)
		var fall := float(r.end.y - 1 - chain.top.y)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), outline):
					continue
				cut_out[y * w + x] = 1
				for f in 5:
					# Bottom row moves f - 2 pxl pixels; rows above it less, in whole pxl pixels.
					var shift := PX * roundi((f - 2) * maxf(0.0, y - chain.top.y) / fall)
					strip.set_pixel(f * fw + SWING + x - r.position.x + shift, y - r.position.y, src.get_pixel(x, y))
		out["res://assets/ui/life/chain_%s_%d.png" % [name, i]] = strip
	var bg := src.duplicate() as Image
	for y in src.get_height():
		for x in w:
			if cut_out[y * w + x]:
				bg.set_pixel(x, y, src.get_pixel(_nearest_wall(cut_out, w, x, y), y))
	out["res://assets/ui/bg_%s.webp" % name] = bg
	return out


## The x of the closest uncut pixel to (x, y) in its row; the left one on a tie.
static func _nearest_wall(cut_out: PackedByteArray, w: int, x: int, y: int) -> int:
	for d in range(1, w):
		if x - d >= 0 and not cut_out[y * w + x - d]:
			return x - d
		if x + d < w and not cut_out[y * w + x + d]:
			return x + d
	return x
