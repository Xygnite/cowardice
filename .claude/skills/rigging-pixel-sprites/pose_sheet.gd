extends SceneTree
## Renders rigged scenes frozen at key poses into one sheet: a row per rig, a column per pose
## (idle, wind-up, strike, block, hurt). A white cell means that rig has no such animation.
## Needs a real renderer, so run it WITHOUT --headless (a window flashes up briefly).
## Run: godot --path . -s <this file> -- <out png> [rig name ...]   (default: every rig in scenes/ with an AnimationPlayer)

const POSES := [["idle", 0.0], ["attack", 0.15], ["attack", 0.25], ["block", 0.1], ["hurt", 0.06]]
const MARGIN := 8
const SCALE := 3


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var names: Array = args.slice(1)
	if names.is_empty():
		for f in DirAccess.get_files_at("res://scenes/"):
			if not f.ends_with(".tscn"):
				continue
			var probe: Node = load("res://scenes/" + f).instantiate()
			if probe.has_node("AnimationPlayer") and probe.has_node("Rig/Legs"):
				names.append(f.get_basename())
			probe.free()
	var rigs: Array[Node2D] = []
	var cell := Vector2i.ZERO
	for n in names:
		var rig: Node2D = load("res://scenes/%s.tscn" % n).instantiate()
		rigs.append(rig)
		var legs: Sprite2D = rig.get_node("Rig/Legs")
		cell = cell.max(Vector2i(legs.texture.get_size()) + Vector2i(MARGIN * 2, MARGIN * 2))
	var vp := SubViewport.new()
	vp.size = cell
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.25, 0.33)
	bg.size = Vector2(cell)
	vp.add_child(bg)
	var sheet := Image.create_empty(cell.x * POSES.size(), cell.y * rigs.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for r in rigs.size():
		var rig := rigs[r]
		rig.position = Vector2(MARGIN, MARGIN)
		vp.add_child(rig)
		var player: AnimationPlayer = rig.get_node("AnimationPlayer")
		for p in POSES.size():
			if not player.has_animation(POSES[p][0]):
				continue
			player.play(POSES[p][0])
			player.seek(POSES[p][1], true)
			player.pause()
			await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(cell.x * p, cell.y * r))
		rig.free()
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	sheet.save_png(args[0])
	print("%s: %s" % [args[0], ", ".join(names)])
	quit()
