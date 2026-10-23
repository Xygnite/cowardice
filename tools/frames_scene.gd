extends SceneTree
## Turns a pxl frame sheet (art/pxl/<name>.px.js, built into assets/sprites/<name>_frames.png + .json)
## into scenes/<name>_frames.tscn: one Sprite2D stepping through the strip, and an AnimationPlayer with
## the same move names as a rig (idle, attack, block, hurt), so combat_screen.gd plays it the same way.
## Frames are named <name>_<move>_<i> by pxl and sit in one row in order.
## Run: godot --headless --path . -s tools/frames_scene.gd -- <name>   (then --import for a new PNG)

func _init() -> void:
	var name: String = OS.get_cmdline_user_args()[0]
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s_frames.json" % name))
	# art/pxl/lib.px.js pads the sprite by the same margin on every side, so its top-left sits at that margin.
	var sprite := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % name)).get_size()
	var first: Dictionary = sheet.frames.values()[0].sourceSize
	var origin := (Vector2(first.w, first.h) - Vector2(sprite)) / 2
	var moves := {}  # move name -> [[frame index, seconds]]
	var i := 0
	for key: String in sheet.frames:
		var move := key.trim_prefix(name + "_").rsplit("_", true, 1)[0]
		moves.get_or_add(move, []).append([i, sheet.frames[key].duration / 1000.0])
		i += 1
	var out: PackedStringArray = ["[gd_scene format=3]", "",
		'[ext_resource type="Texture2D" path="res://assets/sprites/%s_frames.png" id="frames"]' % name, ""]
	moves["RESET"] = [moves.idle[0]]
	for move in moves:
		var times: Array = []
		var frames: Array = []
		var t := 0.0
		for f in moves[move]:
			times.append(t)
			frames.append(f[0])
			t += f[1]
		out.append('[sub_resource type="Animation" id="Animation_%s"]' % move)
		out.append('resource_name = "%s"' % move)
		out.append("length = %s" % (0.001 if move == "RESET" else t))
		if move == "idle":
			out.append("loop_mode = 1")
		out.append("\n".join([
			'tracks/0/type = "value"', "tracks/0/imported = false", "tracks/0/enabled = true",
			'tracks/0/path = NodePath("Frames:frame")', "tracks/0/interp = 0", "tracks/0/loop_wrap = true",
			"tracks/0/keys = {",
			'"times": ' + var_to_str(PackedFloat32Array(times)) + ",",
			'"transitions": ' + var_to_str(PackedFloat32Array(times.map(func(_t): return 1))) + ",",
			'"update": 1,',
			'"values": ' + var_to_str(frames), "}"]))
		out.append("")
	out.append('[sub_resource type="AnimationLibrary" id="AnimationLibrary_frames"]')
	out.append("_data = {\n%s\n}" % ",\n".join(moves.keys().map(func(m): return '&"%s": SubResource("Animation_%s")' % [m, m])))
	out.append("")
	out.append('[node name="%sFrames" type="Node2D"]' % name.to_pascal_case())
	out.append("")
	out.append('[node name="Frames" type="Sprite2D" parent="."]')
	out.append('texture = ExtResource("frames")')
	out.append("centered = false")
	out.append("offset = " + var_to_str(-origin))
	out.append("hframes = %d" % i)
	out.append("")
	out.append('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]')
	out.append('libraries = {\n&"": SubResource("AnimationLibrary_frames")\n}')
	out.append('autoplay = &"idle"')
	FileAccess.open("res://scenes/%s_frames.tscn" % name, FileAccess.WRITE).store_string("\n".join(out) + "\n")
	print("%s: %s" % [name, ", ".join(moves.keys())])
	quit()
