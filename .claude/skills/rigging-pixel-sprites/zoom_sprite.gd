extends SceneTree
## Blows a sprite up 16x on a checkerboard with a yellow line every 5 pixels, so outline points
## and pivots can be read off in sprite pixels.
## Run: godot --headless --path . -s <this file> -- <sprite png> <out png>

const K := 16


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(src.get_width() * K, src.get_height() * K, false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var p := Vector2i(x / K, y / K)
			var c := src.get_pixelv(p)
			if c.a == 0.0:
				c = Color8(70, 80, 110) if (p.x + p.y) % 2 else Color8(80, 90, 120)
			if x % (K * 5) == 0 or y % (K * 5) == 0:
				c = Color.YELLOW
			out.set_pixel(x, y, c)
	out.save_png(args[1])
	quit()
