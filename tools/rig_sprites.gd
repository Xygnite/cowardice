extends SceneTree
## Cuts character sprites into cut-out parts and writes a rigged scene for each:
## assets/sprites/<name>/<part>.png and scenes/<name>.tscn with idle, attack, hurt (and block, given a shield).
## Every part keeps the full sprite canvas, so the scene only needs pivots, not per-part offsets.
## Re-run after tools/make_sprites.gd changes a sprite; it overwrites the parts and the scene.
## Hand edits to a generated scene are lost on the next run, so change RIGS instead.
## Run: godot --headless --path . -s tools/rig_sprites.gd [-- --only=<name>] [--preview=<png path>]
## then once more with --import so Godot picks up new part textures.

const SPRITES := "res://assets/sprites/"
const SCENES := "res://scenes/"
const ROLES := ["weapon", "shield", "head"]  # drawn in this order, in front of the body
const BODY_OVERLAP := 2  # the body reaches this far into the legs, so bobbing up never opens a gap at the waist
const SWAY_STEPS := 5  # lantern frames: its bottom shifted -2..+2 px; frame 2 hangs straight
const GLOW_DIM := Color(0.7, 0.6, 0.55)
const GLOW_FLARE := Color(1.5, 1.3, 1.1)

## One entry per sprite in assets/sprites/. Points are in sprite pixels.
## facing: 1 looks right (the hero), -1 looks left (the enemies); lunges and flinches follow it.
## body: hip pivot. legs_top: rows from here down stay still (use the sprite height for no legs).
## weapon / shield / head (all optional): "outline" claims the pixels inside it, checked in that order,
## "pivot" is the joint it turns or moves around. weapon "swing" is [wind-up, strike] rotation in radians.
## weapon "flourish": weapon rotations at 0.08, 0.2, 0.26, 0.34, 0.46 and 0.62 s for a livelier, longer attack
## (anticipation, wind-up, strike, hit-stop, settle); the body crouches, lunges and holds on the hit with it.
## weapon "patch": [colour, last row]: the hole it leaves in the body down to that row is filled with the
## colour instead of smeared from the neighbouring pixels (use it for a big part, like a whole arm;
## the rows below, under the blade, smear fine).
## Hero only: enemy blows must land STRIKE_DELAY (0.2 s) into the attack, which this timing doesn't keep.
## chest (optional): {outline, pivot} part of the body that rises 1 px to breathe; the roles above ride on it.
## lantern (optional): {outline, pivot, glow} a hanging prop. It sways by swapping SWAY_STEPS frames that
## shear it about the pivot row (never rotated); the pixels inside "glow" flicker on their own layer.
## skirt (optional): outlines of cloth strips that trail every move by 1 px, one strip a frame behind the last.
const RIGS := {
	"deserter": {"facing": 1, "body": Vector2(32, 64), "legs_top": 64,
		# The whole sword arm, shoulder to blade, swings from the shoulder.
		"weapon": {"pivot": Vector2(21, 22), "swing": [-2.2, 0.5], "patch": [Color("1c202c"), 46],
			# Pull back, raise it behind him, chop over the top to forward-down, then fall back to rest (TAU = 0).
			"flourish": [0.4, 2.4, 5.5, 5.6, 6.0, TAU],
			"outline": [Vector2(16, 19), Vector2(26, 19), Vector2(27, 30), Vector2(26, 43), Vector2(30, 49), Vector2(43, 63), Vector2(42, 67), Vector2(38, 67), Vector2(26, 56), Vector2(19, 52), Vector2(13, 46), Vector2(13, 42), Vector2(16, 38), Vector2(15, 26)]},
		"shield": {"pivot": Vector2(48, 42),
			"outline": [Vector2(46, 30), Vector2(52, 30), Vector2(57, 38), Vector2(57, 50), Vector2(53, 56), Vector2(46, 56)]},
		"head": {"pivot": Vector2(37, 15),
			"outline": [Vector2(29, 1), Vector2(46, 1), Vector2(46, 15), Vector2(30, 15), Vector2(29, 8)]}},
	"skeleton": {"facing": -1, "body": Vector2(22, 34), "legs_top": 34,
		"weapon": {"pivot": Vector2(31, 32), "swing": [1.9, -0.5],
			"outline": [Vector2(36, 26), Vector2(42, 26), Vector2(42, 31), Vector2(33, 36), Vector2(27, 42), Vector2(18, 44), Vector2(17, 40), Vector2(26, 34), Vector2(30, 30)]},
		"shield": {"pivot": Vector2(8, 25),
			"outline": [Vector2(1, 16), Vector2(15, 16), Vector2(15, 34), Vector2(1, 34)]},
		"head": {"pivot": Vector2(19, 10),
			"outline": [Vector2(13, 1), Vector2(25, 1), Vector2(25, 10), Vector2(14, 10)]}},
	"bone_warden": {"facing": -1, "body": Vector2(47, 76), "legs_top": 76,
		"weapon": {"pivot": Vector2(66, 53), "swing": [-1.6, 0.4],
			"outline": [Vector2(94, 60), Vector2(80, 60), Vector2(70, 50), Vector2(63, 48), Vector2(63, 57), Vector2(74, 66), Vector2(74, 85), Vector2(94, 85)]},
		"shield": {"pivot": Vector2(26, 45),
			"outline": [Vector2(36, 14), Vector2(15, 13), Vector2(2, 28), Vector2(2, 78), Vector2(14, 82), Vector2(34, 80), Vector2(36, 40)]},
		"head": {"pivot": Vector2(47, 19),
			"outline": [Vector2(54, 2), Vector2(40, 2), Vector2(40, 19), Vector2(54, 19)]}},
	"rotwood_treant": {"facing": -1, "body": Vector2(25, 45), "legs_top": 45,
		"weapon": {"pivot": Vector2(9, 30), "swing": [0.8, -0.3],
			"outline": [Vector2(0, 28), Vector2(11, 28), Vector2(11, 48), Vector2(0, 48)]},
		"head": {"pivot": Vector2(19, 17),
			"outline": [Vector2(11, 2), Vector2(27, 2), Vector2(27, 17), Vector2(11, 17)]}},
	"mother_moss": {"facing": -1, "body": Vector2(42, 70), "legs_top": 70,
		"weapon": {"pivot": Vector2(21, 36), "swing": [0.6, -0.3],
			"outline": [Vector2(23, 34), Vector2(2, 34), Vector2(2, 58), Vector2(23, 58)]},
		"head": {"pivot": Vector2(30, 28),
			"outline": [Vector2(39, 8), Vector2(21, 8), Vector2(21, 28), Vector2(39, 28)]}},
	"foreman_grieve": {"facing": -1, "body": Vector2(38, 64), "legs_top": 64,
		"weapon": {"pivot": Vector2(17, 56), "swing": [-0.8, 0.4],
			"outline": [Vector2(2, 52), Vector2(33, 52), Vector2(33, 42), Vector2(41, 42), Vector2(41, 71), Vector2(33, 71), Vector2(33, 59), Vector2(2, 59)]},
		"shield": {"pivot": Vector2(68, 30),
			"outline": [Vector2(61, 26), Vector2(75, 26), Vector2(75, 62), Vector2(61, 62)]},
		"head": {"pivot": Vector2(38, 31),
			"outline": [Vector2(29, 7), Vector2(48, 7), Vector2(48, 30), Vector2(29, 30)]}},
	"archivist": {"facing": -1, "body": Vector2(37, 88), "legs_top": 89,
		"weapon": {"pivot": Vector2(53, 31), "swing": [-0.4, 0.2],
			"outline": [Vector2(51, 18), Vector2(67, 18), Vector2(67, 33), Vector2(51, 33)]},
		"shield": {"pivot": Vector2(10, 30),
			"outline": [Vector2(1, 5), Vector2(18, 5), Vector2(18, 54), Vector2(1, 54)]},
		"head": {"pivot": Vector2(37, 16),
			"outline": [Vector2(32, 1), Vector2(43, 1), Vector2(43, 16), Vector2(32, 16)]}},
	"plague_doctor": {"facing": -1, "body": Vector2(30, 60), "legs_top": 60,
		"weapon": {"pivot": Vector2(46, 38), "swing": [1.6, -0.4],
			"outline": [Vector2(40, 33), Vector2(53, 33), Vector2(53, 48), Vector2(42, 49), Vector2(32, 57), Vector2(22, 57), Vector2(22, 50), Vector2(32, 47), Vector2(40, 46)]},
		"head": {"pivot": Vector2(29, 18),
			"outline": [Vector2(14, 11), Vector2(23, 1), Vector2(37, 1), Vector2(37, 16), Vector2(33, 19), Vector2(14, 19)]},
		"chest": {"pivot": Vector2(30, 35),
			"outline": [Vector2(10, 13), Vector2(51, 13), Vector2(53, 35), Vector2(10, 35)]},
		"lantern": {"pivot": Vector2(7, 22),
			"outline": [Vector2(1, 21), Vector2(11, 21), Vector2(11, 33), Vector2(12, 33), Vector2(12, 48), Vector2(1, 48)],
			"glow": [Vector2(4, 36), Vector2(10, 36), Vector2(10, 42), Vector2(4, 42)]},
		"skirt": [
			[Vector2(33, 57), Vector2(38, 57), Vector2(38, 67), Vector2(33, 67)],
			[Vector2(38, 56), Vector2(44, 56), Vector2(44, 64), Vector2(38, 64)],
			[Vector2(44, 52), Vector2(50, 52), Vector2(50, 61), Vector2(44, 61)]]},
}


func _init() -> void:
	var only := ""
	var preview := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--preview="):
			preview = arg.trim_prefix("--preview=")
	if only and only not in RIGS:
		push_error("No rig named %s; known: %s" % [only, ", ".join(RIGS.keys())])
		quit(1)
		return
	var sheets: Array[Image] = []
	for name in RIGS:
		if only and name != only:
			continue
		var parts := _cut(name, RIGS[name])
		_write_scene(name, RIGS[name], parts.keys())
		sheets.append(_preview(parts))
		print("%s: %s" % [name, ", ".join(parts.keys())])
	if preview:
		_stack(sheets).save_png(preview)
	quit()


## Splits the sprite into legs, body and its optional parts; returns {part name: Image}.
func _cut(name: String, rig: Dictionary) -> Dictionary:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SPRITES + name + ".png"))
	src.convert(Image.FORMAT_RGBA8)
	var names := ["legs", "body"] + ROLES.filter(func(r): return rig.has(r))
	if rig.has("lantern"):
		names += ["lantern", "glow"]
	for i in rig.get("skirt", []).size():
		names.append("skirt_%d" % i)
	if rig.has("chest"):
		names.append("chest")
	var parts := {}
	for part in names:
		parts[part] = Image.create_empty(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var part := _part_at(rig, x, y)
			parts[part].set_pixel(x, y, c)
			# The body keeps a copy under the chest, so breathing in stretches the waist instead of opening it.
			if part == "chest" or (part == "legs" and y < rig.legs_top + BODY_OVERLAP):
				parts.body.set_pixel(x, y, c)
	_fill_holes(parts.body, [parts.get("weapon"), parts.get("shield")], rig.legs_top)
	if rig.has("weapon") and rig.weapon.has("patch"):  # a flat shade reads as the far side of the body
		for y in rig.weapon.patch[1] + 1:
			for x in src.get_width():
				if parts.weapon.get_pixel(x, y).a > 0.0 and parts.body.get_pixel(x, y).a > 0.0:
					parts.body.set_pixel(x, y, rig.weapon.patch[0])
	var dir := SPRITES + name + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for part in parts:
		var img: Image = _sway_sheet(parts[part], rig.lantern) if part in ["lantern", "glow"] else parts[part]
		img.save_png(dir + part + ".png")
	return parts


func _part_at(rig: Dictionary, x: int, y: int) -> String:
	var p := Vector2(x + 0.5, y + 0.5)
	for role in ROLES:
		if rig.has(role) and _inside(p, rig[role].outline):
			return role
	if rig.has("lantern"):
		if _inside(p, rig.lantern.glow):
			return "glow"
		if _inside(p, rig.lantern.outline):
			return "lantern"
	var skirt: Array = rig.get("skirt", [])
	for i in skirt.size():
		if _inside(p, skirt[i]):
			return "skirt_%d" % i
	if rig.has("chest") and _inside(p, rig.chest.outline):
		return "chest"
	return "legs" if y >= rig.legs_top else "body"


func _inside(p: Vector2, outline: Array) -> bool:
	return Geometry2D.is_point_in_polygon(p, PackedVector2Array(outline))


## SWAY_STEPS copies of a hanging part side by side. Each row shifts by whole pixels in proportion to how
## far it hangs below the pivot, so the top stays in the hand and the bottom swings -2..+2 px.
func _sway_sheet(img: Image, lantern: Dictionary) -> Image:
	var w := img.get_width()
	var top: float = lantern.pivot.y
	var bottom: float = lantern.outline.map(func(v): return v.y).max()
	var sheet := Image.create_empty(w * SWAY_STEPS, img.get_height(), false, Image.FORMAT_RGBA8)
	for f in SWAY_STEPS:
		for y in img.get_height():
			var shift := roundi((f - SWAY_STEPS / 2) * clampf((y - top) / (bottom - top), 0.0, 1.0))
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and x + shift >= 0 and x + shift < w:
					sheet.set_pixel(f * w + x + shift, y, c)
	return sheet


## Where a weapon or shield is cut out of the middle of the body, patch the hole with the nearest
## body colour on the same row, so swinging it shows the body instead of background.
## The head's hole is left open: it only tilts, and a patch there smears across the top of the body.
func _fill_holes(body: Image, cut_out: Array, legs_top: int) -> void:
	cut_out = cut_out.filter(func(img): return img != null)
	var filled: Image = body.duplicate()
	for y in mini(legs_top, body.get_height()):
		var row: Array[int] = []
		for x in body.get_width():
			if body.get_pixel(x, y).a > 0.0:
				row.append(x)
		if row.is_empty():
			continue
		for x in range(row.front(), row.back()):
			if body.get_pixel(x, y).a > 0.0 or not cut_out.any(func(img): return img.get_pixel(x, y).a > 0.0):
				continue
			var left := x
			while body.get_pixel(left, y).a == 0.0:
				left -= 1
			var right := x
			while body.get_pixel(right, y).a == 0.0:
				right += 1
			var from := Vector2i(left if x - left <= right - x else right, y)
			# A wide, flat hole (a blade held across the body) patches better from above or below.
			for dy in [-1, 1]:
				var v: int = y + dy
				while v >= 0 and v < body.get_height() and body.get_pixel(x, v).a == 0.0:
					v += dy
				if v >= 0 and v < body.get_height() and absi(v - y) < absi(from.x - x):
					from = Vector2i(x, v)
			filled.set_pixel(x, y, body.get_pixelv(from))
	body.copy_from(filled)


# --- Scene ---------------------------------------------------------------------

## Writes scenes/<name>.tscn: Rig > Legs, Body > (skirt strips, Chest >) weapon, shield, head, lantern,
## plus an AnimationPlayer.
## Written as text because the part textures are not imported yet while this runs.
func _write_scene(name: String, rig: Dictionary, part_names: Array) -> void:
	var f: int = rig.facing
	var body: Vector2 = rig.body
	var has := func(role: String) -> bool: return rig.has(role)
	var upper := "Rig/Body/Chest" if has.call("chest") else "Rig/Body"  # what the roles and the lantern hang on
	var node := func(role: String) -> String: return upper + "/" + role.capitalize()
	var rest := func(role: String) -> Vector2: return rig[role].pivot - (rig.chest.pivot if has.call("chest") else body)
	var chest: Vector2 = rig.chest.pivot - body if has.call("chest") else Vector2.ZERO
	var lantern := upper + "/Lantern"
	var skirts: Array = range(rig.get("skirt", []).size()).map(func(i): return "Rig/Body/Skirt%d" % i)
	# Lantern swing in whole pixels at its bottom (-2..2); the glow layer swaps the same frames.
	var sway := func(times: Array, shifts: Array) -> Array:
		if not has.call("lantern"):
			return []
		var frames: Array = shifts.map(func(s): return SWAY_STEPS / 2 + s)
		return [_track(lantern + ":frame", times, frames, true), _track(lantern + "/Glow:frame", times, frames, true)]
	var flicker := func(times: Array, colors: Array) -> Array:
		return [_track(lantern + "/Glow:modulate", times, colors, true)] if has.call("lantern") else []
	# Skirt strips step dx px aside at `start` and back at `back`, each a frame after the one before.
	var trail := func(start: float, back: float, dx: int) -> Array:
		return range(skirts.size()).map(func(i): return _track(skirts[i] + ":position",
			[0, start + 0.08 * i, back + 0.08 * i], [Vector2.ZERO, Vector2(dx, 0), Vector2.ZERO], true))

	var anims := {}
	var reset: Array = [
		_track("Rig:position", [0], [Vector2.ZERO], true),
		_track("Rig:modulate", [0], [Color.WHITE], false),
		_track("Rig/Body:position", [0], [body], true),
	]
	if has.call("weapon"):
		reset.append(_track(node.call("weapon") + ":rotation", [0], [0.0], false))
	if has.call("shield"):
		reset.append(_track(node.call("shield") + ":position", [0], [rest.call("shield")], true))
	if has.call("head"):
		reset.append(_track(node.call("head") + ":rotation", [0], [0.0], false))
	if has.call("chest"):
		reset.append(_track("Rig/Body/Chest:position", [0], [chest], true))
	reset += sway.call([0], [0]) + flicker.call([0], [Color.WHITE])
	for s in skirts:
		reset.append(_track(s + ":position", [0], [Vector2.ZERO], true))
	anims["RESET"] = {"length": 0.001, "tracks": reset}

	var idle: Array = [_track("Rig/Body:position", [0, 0.8], [body, body + Vector2(0, 1)], true)]
	if has.call("shield"):
		var s: Vector2 = rest.call("shield")
		idle.append(_track(node.call("shield") + ":position", [0, 1.0], [s, s + Vector2(0, 1)], true))
	if has.call("chest"):  # breathe in while the body is up; head and lantern ride along
		idle.append(_track("Rig/Body/Chest:position", [0, 0.2, 0.8], [chest, chest + Vector2(0, -1), chest], true))
	idle += sway.call([0, 0.3, 0.7, 1.1, 1.5], [0, 1, 0, -1, 0])
	idle += flicker.call([0, 0.5, 0.58, 1.15, 1.25], [Color.WHITE, GLOW_DIM, Color.WHITE, GLOW_DIM, Color.WHITE])
	idle += trail.call(0.3, 1.0, 1)
	anims["idle"] = {"length": 1.6, "loop": true, "tracks": idle}

	var attack: Array = [
		_track("Rig:position", [0, 0.15, 0.22, 0.4, 0.5], [Vector2.ZERO, Vector2(3 * f, 0), Vector2(6 * f, 0), Vector2(3 * f, 0), Vector2.ZERO], true),
		_track("Rig/Body:position", [0, 0.15, 0.25, 0.5], [body, body + Vector2(-f, 0), body + Vector2(f, 1), body], true),
	]
	if has.call("weapon"):
		var swing: Array = rig.weapon.swing
		attack.append(_track(node.call("weapon") + ":rotation", [0, 0.15, 0.25, 0.5], [0.0, swing[0], swing[1], 0.0], false, [0.5, 1, 2, 1]))
	# The lantern and skirt lag behind the lunge, then overshoot as it pulls back.
	attack += sway.call([0, 0.15, 0.22, 0.3, 0.4, 0.5], [0, -f, -2 * f, 0, f, 0])
	attack += flicker.call([0, 0.15, 0.35], [Color.WHITE, GLOW_FLARE, Color.WHITE])
	attack += trail.call(0.2, 0.32, -f)
	anims["attack"] = {"length": 0.5, "tracks": attack}
	if has.call("weapon") and rig.weapon.has("flourish"):
		anims["attack"] = {"length": 0.62, "tracks": _flourish(rig, node, rest, body, f)}

	if has.call("shield"):
		var s: Vector2 = rest.call("shield")
		anims["block"] = {"length": 0.4, "tracks": [
			_track(node.call("shield") + ":position", [0, 0.06, 0.3, 0.4], [s, s + Vector2(2 * f, -3), s + Vector2(f, -2), s], true),
			_track("Rig:position", [0, 0.08, 0.3], [Vector2.ZERO, Vector2(-f, 0), Vector2.ZERO], true),
		]}

	var hurt: Array = [
		_track("Rig:position", [0, 0.05, 0.2, 0.4], [Vector2.ZERO, Vector2(-3 * f, 0), Vector2(-2 * f, 0), Vector2.ZERO], true),
		_track("Rig:modulate", [0, 0.3], [Color(1, 0.35, 0.35), Color.WHITE], false),
	]
	if has.call("head"):
		hurt.append(_track(node.call("head") + ":rotation", [0, 0.05, 0.3], [0.0, -0.25 * f, 0.0], false))
	hurt += sway.call([0, 0.1, 0.2, 0.3, 0.4], [0, 2 * f, f, -f, 0])
	hurt += flicker.call([0, 0.05, 0.3], [Color.WHITE, GLOW_FLARE, Color.WHITE])
	hurt += trail.call(0.1, 0.24, f)
	anims["hurt"] = {"length": 0.4, "tracks": hurt}

	var out: PackedStringArray = ["[gd_scene format=3]", ""]
	for part in part_names:
		out.append('[ext_resource type="Texture2D" path="%s%s/%s.png" id="%s"]' % [SPRITES, name, part, part])
	out.append("")
	for anim in anims:
		out.append('[sub_resource type="Animation" id="Animation_%s"]' % anim)
		out.append('resource_name = "%s"' % anim)
		out.append("length = %s" % anims[anim].length)
		if anims[anim].get("loop", false):
			out.append("loop_mode = 1")
		var tracks: Array = anims[anim].tracks
		for i in tracks.size():
			out.append(tracks[i].replace("tracks/#/", "tracks/%d/" % i))
		out.append("")
	out.append('[sub_resource type="AnimationLibrary" id="AnimationLibrary_rig"]')
	out.append("_data = {\n%s\n}" % ",\n".join(anims.keys().map(func(a): return '&"%s": SubResource("Animation_%s")' % [a, a])))
	out.append("")
	out.append('[node name="%s" type="Node2D"]' % name.to_pascal_case())
	out.append("")
	out.append('[node name="Rig" type="Node2D" parent="."]')
	out.append("")
	out.append(_sprite("Legs", "Rig", "legs", Vector2.ZERO, Vector2.ZERO))
	out.append(_sprite("Body", "Rig", "body", body, body))
	for i in skirts.size():
		out.append(_sprite("Skirt%d" % i, "Rig/Body", "skirt_%d" % i, Vector2.ZERO, body))
	if has.call("chest"):
		out.append(_sprite("Chest", "Rig/Body", "chest", chest, rig.chest.pivot))
	for role in ROLES:
		if has.call(role):
			out.append(_sprite(role.capitalize(), upper, role, rest.call(role), rig[role].pivot))
	if has.call("lantern"):
		out.append(_sprite("Lantern", upper, "lantern", rest.call("lantern"), rig.lantern.pivot, SWAY_STEPS))
		out.append(_sprite("Glow", lantern, "glow", Vector2.ZERO, rig.lantern.pivot, SWAY_STEPS))
	out.append('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]')
	out.append('libraries = {\n&"": SubResource("AnimationLibrary_rig")\n}')
	out.append('autoplay = &"idle"')
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENES))
	var file := FileAccess.open(SCENES + name + ".tscn", FileAccess.WRITE)
	file.store_string("\n".join(out) + "\n")


## A part sprite placed at its pivot; the offset puts its full-canvas texture back where it was cut from.
## Crouch and draw back, lunge into the hit, hold on it, then settle.
func _flourish(rig: Dictionary, node: Callable, rest: Callable, body: Vector2, f: int) -> Array:
	var t := [0, 0.08, 0.2, 0.26, 0.34, 0.46, 0.62]
	var tracks: Array = [
		_track("Rig:position", t, [Vector2.ZERO, Vector2(-f, 0), Vector2(-2 * f, 0), Vector2(5 * f, 0),
			Vector2(7 * f, 0), Vector2(4 * f, 0), Vector2.ZERO], true),
		_track("Rig/Body:position", t, [body, body + Vector2(0, 1), body + Vector2(-f, 0), body + Vector2(f, 1),
			body + Vector2(f, 1), body, body], true),
		# Eased out into the wind-up, eased in (accelerating) into the strike.
		_track(node.call("weapon") + ":rotation", t, [0.0] + rig.weapon.flourish, false, [0.5, 0.5, 2.5, 1, 0.6, 0.6, 1]),
	]
	if rig.has("head"):  # small tilts only: head holes aren't patched
		tracks.append(_track(node.call("head") + ":rotation", t, [0.0, 0.0, -0.06 * f, 0.08 * f, 0.08 * f, 0.03 * f, 0.0], false))
	if rig.has("shield"):
		var s: Vector2 = rest.call("shield")
		tracks.append(_track(node.call("shield") + ":position", t, [s, s, s + Vector2(-f, 1), s + Vector2(f, -1),
			s + Vector2(f, -1), s, s], true))
	return tracks


func _sprite(node_name: String, parent: String, texture_id: String, position: Vector2, pivot: Vector2, frames := 1) -> String:
	var lines: PackedStringArray = ['[node name="%s" type="Sprite2D" parent="%s"]' % [node_name, parent]]
	if position != Vector2.ZERO:
		lines.append("position = " + var_to_str(position))
	lines.append('texture = ExtResource("%s")' % texture_id)
	lines.append("centered = false")
	if frames > 1:
		lines.append("hframes = %d" % frames)
		lines.append("frame = %d" % (frames / 2))
	if pivot != Vector2.ZERO:
		lines.append("offset = " + var_to_str(-pivot))
	return "\n".join(lines) + "\n"


## One value track; `discrete` snaps between keys so moves land on whole sprite pixels.
func _track(path: String, times: Array, values: Array, discrete: bool, transitions := []) -> String:
	if transitions.is_empty():
		transitions = times.map(func(_t): return 1)
	return "\n".join([
		'tracks/#/type = "value"',
		"tracks/#/imported = false",
		"tracks/#/enabled = true",
		'tracks/#/path = NodePath("%s")' % path,
		"tracks/#/interp = 1",
		"tracks/#/loop_wrap = true",
		"tracks/#/keys = {",
		'"times": ' + var_to_str(PackedFloat32Array(times)) + ",",
		'"transitions": ' + var_to_str(PackedFloat32Array(transitions)) + ",",
		'"update": %d,' % (1 if discrete else 0),
		'"values": ' + var_to_str(values),
		"}",
	])


# --- Preview -------------------------------------------------------------------

## One row per sprite: each part on its own at 4x, so the cuts are easy to check.
func _preview(parts: Dictionary) -> Image:
	const S := 4
	var w: int = parts.body.get_width() * S
	var h: int = parts.body.get_height() * S
	var sheet := Image.create_empty((w + 8) * parts.size() + 8, h + 16, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.22, 0.25, 0.33))
	var x := 8
	for part in parts:
		var big: Image = parts[part].duplicate()
		big.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, 8))
		x += w + 8
	return sheet


func _stack(sheets: Array[Image]) -> Image:
	var w := 0
	var h := 0
	for s in sheets:
		w = maxi(w, s.get_width())
		h += s.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.22, 0.25, 0.33))
	var y := 0
	for s in sheets:
		out.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(0, y))
		y += s.get_height()
	return out
