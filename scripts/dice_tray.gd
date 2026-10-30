class_name DiceTray
extends Control
## The dice as 3D cubes in a walled tray, seen from above, rendered at low resolution and scaled up so
## they stay pixel art. A roll throws them in from the left as rigid bodies: they bounce off the walls
## and knock into each other (and into locked dice, which stay put), clacking on every bump. Whatever
## face ends up on top is the roll: once a die stops, it is squared to the screen on that face and
## pinned there (a die left leaning on a wall settles onto the face pointing most upward).
## Each side shows one of the die's faces, on the die art from assets/ui/cut/die_<art>.png.

signal die_clicked(i: int)  # a left press on die i
signal die_right_clicked(i: int)
signal left_released  # wherever the button comes up, so a hold on a die can end
signal landed  # once per throw, when its last die is pinned; each die's value is then the face it shows

const PIXEL := 2  # screen pixels per rendered pixel
const UNIT := 80.0  # screen pixels per cube width, on the tray floor
const CAMERA_HEIGHT := 24.0  # cube widths; only needs to clear the highest bounce
const SPACING := 2.0  # cube widths between the dice's centres before the first throw
const CLICK_RADIUS := 48.0  # screen pixels
const LAMP_HEIGHT := 8.0  # cube widths above the floor
const BADGE := Vector3(0.5, 0.5, -0.5)  # where the slot badge is centred on a resting die: its top-right corner
const BADGE_SIZE := 16  # pixels across the badge disc, at the dice's pixel size
const CHAIN_WIDTH := 1.0  # cube widths: as wide as the die
const CHAIN_DROP := 0.2  # cube widths toward the camera's bottom, so the padlock just overlaps the number's foot
const RUBBLE_SIZE := 40  # pixels across the rubble sprite at the dice's pixel size: one cube width
const FELT := preload("res://assets/ui/cut/tray_felt.png")  # the tray floor's repeating tile, made by tools/make_ui.gd

const GRAVITY_SCALE := 3.0  # a cube width is a metre to the physics; small dice fall faster than that
const THROW_SPEED := Vector2(8, 11)  # cube widths per second, rightward
const THROW_SPIN := 15.0  # radians per second, about a random axis
const TRAY_LAYER := 1  # the floor and walls, on Godot's default layer
const DIE_LAYER := 2  # a thrown die once it has landed; until then, and while left out of a throw, it is on none
const LANDED_Y := 0.9  # a cube's centre is below this only when it touches the felt (corner down: 0.87)
const BOUNCE := 0.3
const FRICTION := 0.7
const SETTLED_ANGLE := 0.05  # radians from the rest pose
const NEARLY_SQUARE := 0.26  # radians; a stopped die this close is nudged the rest of the way
const NUDGE_TIME := 0.1
const SETTLED_SPEED := 0.4
const GIVE_UP := 3.0  # seconds; a die still not settled (wedged on a wall, say) is eased into place
const EASE_TIME := 0.25
const SLOW_TIME := 0.25  # seconds a die must stay stopped before a crooked one is settled onto its top face
const GLYPH_PIXEL := 0.0175  # a mark's glyph (art at 2x), a touch under the digits so it clears the border
const GLYPH_CORNER := Vector3(-0.25, -0.27, 0)  # where it sits beside a number, in the lower-left corner
const CLACK := preload("res://assets/audio/dice_clack.wav")  # cut from dice.wav
const CLACK_MIN := 1.5  # cube widths per second of speed lost or gained in one step; gentler touches are silent
const CLACK_LOUD := 12.0  # a jolt this hard plays at full volume
const CLACK_GAP := 0.08  # seconds; one die clacks no more often, so a die chattering on the floor doesn't buzz
const HALO := 8  # pixels the glow round a firing Skill die spreads past its edge, at the dice's pixel size
const HALO_PULSE := Vector2(0.45, 1.0)  # the glow's opacity swings between these
const HALO_SPEED := 5.0  # radians per second of the swing
const HALO_GROW := 0.08  # and it breathes out this share of its size and back
const HOLD_QUIET := 0.2  # share of a hold that shows nothing yet, so a quick click doesn't flash
const HOLD_SHAKE := 0.05  # cube widths a die about to lock or unlock trembles, at most
const SPARKS := 28  # gold sparks alive round a glowing die at once, drifting up the screen like flames

## Turns that bring each side to face +Z; faces[k] is drawn on side k.
const SIDES := [
	Vector3(0, 0, 0),  # +Z
	Vector3(0, -PI / 2, 0),  # +X
	Vector3(PI / 2, 0, 0),  # +Y
	Vector3(0, PI, 0),  # -Z
	Vector3(0, PI / 2, 0),  # -X
	Vector3(-PI / 2, 0, 0),  # -Y
]
## Tips +Z up toward the camera, which looks down with screen-up along -Z, so labels read upright.
const FACE_UP := Vector3(-PI / 2, 0, 0)

static var _atlases := {}  # art name -> the die art tiled 3x2, the layout BoxMesh maps onto its sides

var camera: Camera3D
var walls: Array[CollisionShape3D] = []  # left, right, top, bottom; moved to the tray's edges on resize
## Per die: body (the RigidBody3D), cube (its mesh), labels, chain, slot (2D badge) with its icon,
## clack (its AudioStreamPlayer), faces, value, rolling, t (seconds since thrown),
## slow (seconds it has been stopped), last_v (velocity a step ago) and quiet (seconds until it may clack).
var dice: Array[Dictionary] = []
var in_flight := false  # a throw has dice still rolling; landed fires when none are
## Screen pixels the top wall sits below the felt's top edge, so no die comes to rest under what floats there.
var top_inset := 0.0:
	set(v):
		top_inset = v
		if size.y > 0:  # unsized, the camera can't take a zero size; the first resize fits it
			_fit()


func _init() -> void:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.stretch_shrink = PIXEL
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	view.add_child(vp)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL  # straight down: a resting die shows only its top
	camera.position = Vector3(0, CAMERA_HEIGHT, 0)
	camera.rotation = Vector3(-PI / 2, 0, 0)
	vp.add_child(camera)
	var lamp := SpotLight3D.new()  # hangs over the middle of the tray, lighting a pool on the floor
	lamp.position = Vector3(0, LAMP_HEIGHT, 0)
	lamp.rotation = Vector3(-PI / 2, 0, 0)
	lamp.spot_range = LAMP_HEIGHT * 2
	lamp.spot_angle = 35
	lamp.spot_attenuation = 1.0
	lamp.light_color = Color(1, 0.9, 0.75)
	lamp.light_energy = 3
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.15  # less and the dice faces shade themselves in stripes
	vp.add_child(lamp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	vp.add_child(env)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(200, 200)
	var felt := StandardMaterial3D.new()
	felt.albedo_texture = FELT
	felt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# One felt pixel per rendered pixel, the dice's pixel size: the tile is FELT's width/2 game pixels.
	var tile := FELT.get_width() / 2.0 / (UNIT / PIXEL)
	felt.uv1_scale = Vector3(floor.mesh.size.x / tile, floor.mesh.size.y / tile, 1)
	floor.material_override = felt
	vp.add_child(floor)
	var box := StaticBody3D.new()  # the tray: an endless floor and four invisible walls
	box.physics_material_override = _surface()
	var ground := CollisionShape3D.new()
	ground.shape = WorldBoundaryShape3D.new()
	box.add_child(ground)
	for i in 4:
		var wall := CollisionShape3D.new()
		wall.shape = BoxShape3D.new()
		box.add_child(wall)
		walls.append(wall)
	vp.add_child(box)
	resized.connect(_fit)


func add_die() -> void:
	var body := RigidBody3D.new()
	body.gravity_scale = GRAVITY_SCALE
	body.physics_material_override = _surface()
	body.continuous_cd = true
	body.can_sleep = false  # a die only stops by being pinned (_pin), never by dozing off a little crooked
	body.freeze = true  # pinned until thrown
	var hitbox := CollisionShape3D.new()
	hitbox.shape = BoxShape3D.new()
	body.add_child(hitbox)
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cube.material_override = mat
	body.add_child(cube)
	camera.get_parent().add_child(body)
	var labels: Array[Label3D] = []
	for side in SIDES:
		var l := Label3D.new()
		l.font = preload("res://assets/fonts/m6x11.ttf")
		l.font_size = 64
		# 4 texture pixels per font pixel at size 64, 1/80 cube each: 2 rendered pixels per font pixel.
		l.pixel_size = 0.0125
		# The line box leaves room below the baseline, so digits sit high (and a hair left); nudge them back.
		l.offset = Vector2(2, -4)
		l.outline_size = 0
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Out of the side by a hair, turned so the text reads upright once that side faces up.
		var turn := Basis.from_euler(side).inverse()
		l.transform = Transform3D(turn, turn * Vector3(0, 0, 0.51))
		cube.add_child(l)
		var glyph := Sprite3D.new()  # a face's mark, small in its lower-left corner
		glyph.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		glyph.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.add_child(glyph)
		labels.append(l)
	var chain := Sprite3D.new()  # wraps a locked die; follows it, but never turns with it (_process)
	chain.texture = preload("res://assets/ui/cut/chains.png")
	chain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	chain.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	chain.shaded = true
	chain.pixel_size = CHAIN_WIDTH / chain.texture.get_width()
	chain.rotation = FACE_UP  # lies flat on the top face, reading upright from the camera
	chain.hide()
	camera.get_parent().add_child(chain)
	var rubble := Sprite3D.new()  # heaped on a buried die like the chain
	rubble.texture = _rubble()
	rubble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	rubble.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	rubble.shaded = true
	rubble.pixel_size = 1.0 / RUBBLE_SIZE
	rubble.rotation = FACE_UP
	rubble.hide()
	camera.get_parent().add_child(rubble)
	var halo := Sprite3D.new()  # gold on the felt round the die while glow() has it on
	halo.texture = _halo()
	halo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	halo.pixel_size = 1.0 / RUBBLE_SIZE
	halo.rotation = FACE_UP
	halo.hide()
	camera.get_parent().add_child(halo)
	var sparks := _sparks()
	camera.get_parent().add_child(sparks)
	var slot := TextureRect.new()  # the badge disc; its icon sits in the middle
	slot.texture = _disc()
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	slot.add_child(icon)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	var clack := AudioStreamPlayer.new()  # one per die, so each clack keeps its own volume and pitch
	clack.stream = CLACK
	clack.bus = "SFX"
	add_child(clack)
	dice.append({"body": body, "cube": cube, "labels": labels, "chain": chain, "rubble": rubble, "halo": halo, "sparks": sparks, "slot": slot, "icon": icon,
		"clack": clack, "hold": 0.0, "locked": false, "faces": [], "value": 0, "rolling": false, "t": 0.0, "slow": 0.0,
		"last_v": Vector3.ZERO, "quiet": 0.0})
	for i in dice.size():  # the row stays centred as it grows
		dice[i].body.position = _spot(i)


## Shows die i's faces in `art` (bone, locked, placed, cursed) with `value` up, and the icon
## assets/ui/cut/slot_<slot_icon>.png in its top-right corner, or none if `slot_icon` is empty;
## a locked die is wrapped in chains, a buried one heaped with rubble. A face with a mark in `marks` is in its UI.MARK_COLORS.
## `texts`, if given, is drawn on each side instead of its number; a marked side with "" there shows its glyph alone, large.
## Mid-throw it only repaints; the throw lands on whatever face comes up.
func show_die(i: int, faces: Array, value: int, art: String, slot_icon: String, locked: bool, buried := false, marks := [], texts := []) -> void:
	var d := dice[i]
	d.faces = faces
	d.value = value
	(d.cube.material_override as StandardMaterial3D).albedo_texture = _atlas(art)
	for k in d.labels.size():
		d.labels[k].text = texts[k] if k < texts.size() else ("X" if faces[k] == Combat.CURSE else str(faces[k]))
		d.labels[k].modulate = Color(0.16, 0.13, 0.1) if art == "bone" else Color.WHITE
		var mark: String = marks[k] if k < marks.size() and faces[k] != Combat.CURSE else ""
		if mark:
			d.labels[k].modulate = UI.MARK_COLORS[mark]
		var glyph: Sprite3D = d.labels[k].get_child(0)
		glyph.texture = load(UI.ART % ("mark_" + mark)) if mark else null
		glyph.modulate = d.labels[k].modulate
		var alone: bool = d.labels[k].text == ""  # the glyph is the whole face
		glyph.position = Vector3.ZERO if alone else GLYPH_CORNER
		glyph.pixel_size = GLYPH_PIXEL * (2 if alone else 1)
	d.icon.texture = load(UI.ART % ("slot_" + slot_icon)) if slot_icon else null
	d.locked = locked
	d.chain.visible = locked
	d.rubble.visible = buried
	if not d.rolling:
		d.body.quaternion = _rest(d, d.body.quaternion)


## Die i held down `t` of the way (0 to 1) to locking or unlocking: its chains close in (or slip off) and
## it trembles harder as `t` grows; 0 puts it back as it was.
func hold(i: int, t: float) -> void:
	var d := dice[i]
	d.hold = t
	if t == 0.0:
		d.chain.visible = d.locked
		d.chain.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		d.chain.modulate.a = 1.0
		d.chain.scale = Vector3.ONE
		d.cube.position = Vector3.ZERO


## Die i swells and settles back: the End turn count reaching it.
func pop(i: int) -> void:
	var cube: MeshInstance3D = dice[i].cube
	cube.scale = Vector3.ONE * 1.25
	create_tween().tween_property(cube, "scale", Vector3.ONE, 0.2)


## Die i glows gold on the felt while `on`: it can help make a skill. A die in the hand never glows.
func glow(i: int, on: bool) -> void:
	on = on and dice[i].body.visible
	dice[i].halo.visible = on
	dice[i].sparks.emitting = on


## Takes the dice at `which` off the felt into the hand until throw() brings them back: not rolled yet.
func stow(which: Array) -> void:
	for i in which:
		dice[i].body.hide()
		glow(i, false)


## Throws the dice at `which` (indices) in from the left. Each lands on whatever face comes up, its
## value once `landed` fires.
## `power` (0 to 1, from the charge bar) scales how hard they leave the hand.
func throw(which: Array, power := 1.0) -> void:
	var force := lerpf(0.4, 1.0, power)  # full power is the tuned throw
	if size.x == 0:
		# The walls need the tray's size, and a new screen resizes it more than once while it lays out:
		# throwing after the first would spawn dice where the walls then close in and shove them out.
		await resized
		await get_tree().process_frame
	var top := top_inset / UNIT
	var depth := _half_depth() - top / 2 - 0.7  # the lanes span the felt below the inset
	for d in dice:  # dice left out of the throw sit still on no layer, so the throw goes through them
		d.body.collision_layer = 0
	for n in which.size():
		var d := dice[which[n]]
		var body: RigidBody3D = d.body
		body.show()
		d.rolling = true
		d.t = 0.0
		d.slow = 0.0
		# Out of the hand in a loose line, so no two start inside each other.
		var lane := top / 2 + (0.0 if which.size() == 1 else lerpf(-depth, depth, float(n) / (which.size() - 1)))
		body.position = Vector3(-_half_width() + 0.7 + n * 1.1, 1.5, lane)
		body.quaternion = Quaternion.from_euler(Vector3(randf(), randf(), randf()) * TAU)
		body.collision_mask = TRAY_LAYER  # in the air only the tray stops it; _physics_process adds the dice on landing
		body.freeze = false
		body.linear_velocity = Vector3(randf_range(THROW_SPEED.x, THROW_SPEED.y) * force, randf_range(0, 2), randf_range(-2, 2))
		body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * THROW_SPIN * force
		body.sleeping = false
		d.last_v = body.linear_velocity  # the throw itself is no bump
	in_flight = true


func _physics_process(delta: float) -> void:
	for d in dice:
		if not d.rolling or d.body.freeze:
			continue
		var body: RigidBody3D = d.body
		d.t += delta
		if body.collision_layer == 0 and body.position.y < LANDED_Y:  # it has touched the felt
			body.collision_layer = DIE_LAYER
			body.collision_mask = TRAY_LAYER | DIE_LAYER
		_clack(d, delta)
		d.value = d.faces[_top(d)]  # the roll is whatever is up; _rest then squares the die on it
		var rest := _rest(d, body.quaternion)
		var off := _turn_between(body.quaternion, rest)
		var angle := off.get_angle()
		var stopped := body.linear_velocity.length() < SETTLED_SPEED and body.angular_velocity.length() < SETTLED_SPEED
		d.slow = d.slow + delta if stopped else 0.0
		if angle < NEARLY_SQUARE and stopped:
			# Friction can hold a die a few degrees off, where it would rest crooked; nudge it.
			_pin(d, 0.0 if angle < SETTLED_ANGLE else NUDGE_TIME)
		elif d.t > GIVE_UP or d.slow > SLOW_TIME:
			_pin(d, EASE_TIME)


## Plays a die's clack when its velocity jumps (it hit the floor, a wall or another die), louder the harder.
func _clack(d: Dictionary, delta: float) -> void:
	var v: Vector3 = d.body.linear_velocity
	var jolt: float = (v - d.last_v).length()
	d.last_v = v
	d.quiet -= delta
	if jolt < CLACK_MIN or d.quiet > 0:
		return
	d.quiet = CLACK_GAP
	d.clack.volume_db = linear_to_db(clampf(jolt / CLACK_LOUD, 0.1, 1.0))
	d.clack.pitch_scale = randf_range(0.9, 1.12)
	d.clack.play()


## The side of die i facing most upward, as an index into its faces.
func top_face(i: int) -> int:
	return _top(dice[i])


func _top(d: Dictionary) -> int:
	var best := 0
	var basis: Basis = d.body.basis  # the dice's parent is untransformed; local works off the tree too
	for k in SIDES.size():
		# Side k's outward normal, as the labels are placed: the turn that faces it to +Z, undone.
		if (basis * (Basis.from_euler(SIDES[k]).inverse() * Vector3.BACK)).y > (basis * (Basis.from_euler(SIDES[best]).inverse() * Vector3.BACK)).y:
			best = k
	return best


## Stops a die and sets it exactly in its rest pose where it lies, easing there over `time` seconds.
func _pin(d: Dictionary, time: float) -> void:
	var body: RigidBody3D = d.body
	body.freeze = true
	var to := Vector3(body.position.x, 0.5, body.position.z)
	# A die that came to rest on or against another goes down beside it, not into it.
	# ponytail: one pass, so a push can still end up in a third die or back in via the walls; loop if that shows up.
	for e in dice:
		var at: Vector3 = e.body.position
		# Squared dice are axis-aligned cubes: they overlap while both offsets are under a cube width.
		if is_same(e, d) or absf(to.x - at.x) >= 1.0 or absf(to.z - at.z) >= 1.0:
			continue
		if absf(to.x - at.x) >= absf(to.z - at.z):  # out along whichever axis is the shorter push
			to.x = at.x + (1.0 if to.x >= at.x else -1.0)
		else:
			to.z = at.z + (1.0 if to.z >= at.z else -1.0)
	to = Vector3(clampf(to.x, -_half_width() + 0.5, _half_width() - 0.5), 0.5, clampf(to.z, -_half_depth() + top_inset / UNIT + 0.5, _half_depth() - 0.5))
	var rest := _rest(d, body.quaternion)
	if time == 0.0:
		body.quaternion = rest
		body.position = to
		d.rolling = false
		return
	var t := create_tween().set_parallel()
	t.tween_property(body, "quaternion", rest, time)
	t.tween_property(body, "position", to, time)
	t.chain().tween_callback(func(): d.rolling = false)


func _process(_delta: float) -> void:
	var swing := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * HALO_SPEED)
	for d in dice:
		d.halo.position = Vector3(d.body.position.x, 0.01, d.body.position.z)  # flat on the felt, under the die
		d.halo.modulate.a = lerpf(HALO_PULSE.x, HALO_PULSE.y, swing)
		d.halo.scale = Vector3.ONE * (1 + HALO_GROW * swing)
		d.sparks.position = d.halo.position
		var top: Vector3 = d.body.position
		d.chain.position = top + Vector3(0, 0.53, CHAIN_DROP)  # above the number (at 0.51), so it covers it
		if d.hold > 0:
			var k := clampf((d.hold - HOLD_QUIET) / (1 - HOLD_QUIET), 0, 1)
			d.chain.visible = d.locked or k > 0
			d.chain.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED  # so it can fade
			d.chain.modulate.a = lerpf(1, 0.25, k) if d.locked else k
			d.chain.scale = Vector3.ONE * (lerpf(1, 1.3, k) if d.locked else lerpf(1.4, 1, k))
			d.cube.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * HOLD_SHAKE * k
			d.chain.position += d.cube.position
		# A badge in the top-right corner of the top face, put away while the die tumbles.
		d.rubble.position = top + Vector3(0, 0.54, 0)
		d.slot.position = _screen(top + BADGE) - d.slot.size / 2
		d.slot.visible = d.icon.texture != null and not d.rolling
	if in_flight and not dice.any(func(d): return d.rolling):
		in_flight = false
		landed.emit()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			left_released.emit()
		return
	for i in dice.size():
		if event.position.distance_to(_screen(dice[i].body.position + Vector3.UP / 2)) < CLICK_RADIUS:
			(die_clicked if event.button_index == MOUSE_BUTTON_LEFT else die_right_clicked).emit(i)
			return


## Die i's top face on screen, in global coordinates (for anchoring its menu).
func die_rect(i: int) -> Rect2:
	var c := _screen(dice[i].body.position + Vector3.UP / 2)
	return Rect2(global_position + c - Vector2.ONE * UNIT / 2, Vector2.ONE * UNIT)


## Where a world point lands in this control, in screen pixels.
func _screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p) * PIXEL


## Die i's spot before the first throw: a row across the middle of the tray.
func _spot(i: int) -> Vector3:
	return Vector3((i - (dice.size() - 1) / 2.0) * SPACING, 0.5, 0)


func _half_width() -> float:
	return size.x / UNIT / 2


func _half_depth() -> float:
	return size.y / UNIT / 2


## Keeps a cube UNIT pixels wide on the floor whatever the tray's size, and the walls on its edges (the top one top_inset in).
func _fit() -> void:
	camera.size = size.y / UNIT
	var hw := _half_width()
	var hd := _half_depth()
	var top := top_inset / UNIT
	var spans := [Vector3(1, 10, hd * 2 + 2), Vector3(1, 10, hd * 2 + 2), Vector3(hw * 2 + 2, 10, 1), Vector3(hw * 2 + 2, 10, 1)]
	var centres := [Vector3(-hw - 0.5, 5, 0), Vector3(hw + 0.5, 5, 0), Vector3(0, 5, -hd + top - 0.5), Vector3(0, 5, hd + 0.5)]
	for i in 4:
		walls[i].shape.size = spans[i]
		walls[i].position = centres[i]
	for d in dice:  # a die the walls just closed in on goes back inside, not out through them
		var p: Vector3 = d.body.position
		d.body.position = Vector3(clampf(p.x, -hw + 0.5, hw - 0.5), p.y, clampf(p.z, -hd + top + 0.5, hd - 0.5))


## The turn that puts a side showing the die's value face up and square to the screen; of the sides
## showing it (forged dice can repeat a value), the one already up, else the one nearest `near`.
func _rest(d: Dictionary, near := Quaternion.IDENTITY) -> Quaternion:
	var up := _top(d)
	if d.faces[up] == d.value:  # nearest by angle counts the spin about the vertical and could tip it onto a twin side
		return Quaternion.from_euler(FACE_UP) * Quaternion.from_euler(SIDES[up])
	var best := Quaternion.from_euler(FACE_UP) * Quaternion.from_euler(SIDES[maxi(0, d.faces.find(d.value))])
	for k in d.faces.size():
		if d.faces[k] == d.value:
			var q := Quaternion.from_euler(FACE_UP) * Quaternion.from_euler(SIDES[k])
			if _turn_between(near, q).get_angle() < _turn_between(near, best).get_angle():
				best = q
	return best


## The turn taking `from` to `to`, the short way round.
static func _turn_between(from: Quaternion, to: Quaternion) -> Quaternion:
	var q := (to * from.inverse()).normalized()
	return q if q.w >= 0 else -q


static func _surface() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = BOUNCE
	m.friction = FRICTION
	return m


static func _atlas(art: String) -> Texture2D:
	if not _atlases.has(art):
		var tile: Image = load(UI.ART % ("die_" + art)).get_image()
		tile.convert(Image.FORMAT_RGBA8)
		var w := tile.get_width()
		var h := tile.get_height()
		var img := Image.create_empty(w * 3, h * 2, false, Image.FORMAT_RGBA8)
		for y in 2:
			for x in 3:
				img.blit_rect(tile, Rect2i(0, 0, w, h), Vector2i(x * w, y * h))
		_atlases[art] = ImageTexture.create_from_image(img)
	return _atlases[art]


## Grey stones piled in the corners of the top face, the die's number left clear between them, in dice pixels, with dark rims and a lit upper-left edge. Fixed, so a heap never shifts.
static func _rubble() -> Texture2D:
	var img := Image.create_empty(RUBBLE_SIZE, RUBBLE_SIZE, false, Image.FORMAT_RGBA8)
	# Stones as x, y, radius, painted back to front.
	for s: Array in [[8, 32, 8], [32, 33, 7], [33, 8, 6], [7, 7, 5], [20, 36, 4]]:
		for y in RUBBLE_SIZE:
			for x in RUBBLE_SIZE:
				var d := Vector2(x + 0.5 - s[0], y + 0.5 - s[1]).length()
				if d <= s[2]:
					var lit: bool = x + y < s[0] + s[1] - s[2] * 0.4
					img.set_pixel(x, y, Color("070e10") if d > s[2] - 1.5 else (Color("8c8a82") if lit else (Color("6a6862") if d < s[2] - 4 else Color("4d4b47"))))
	return ImageTexture.create_from_image(img)


## The glow round a die: gold fading out from its edge in three hard steps, rounded at the corners, in dice pixels.
static func _halo() -> Texture2D:
	var n := RUBBLE_SIZE + HALO * 2
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var out := Vector2(maxf(absf(x + 0.5 - n / 2.0) - RUBBLE_SIZE / 2.0, 0), maxf(absf(y + 0.5 - n / 2.0) - RUBBLE_SIZE / 2.0, 0)).length()
			var step := ceilf((1 - out / HALO) * 3) / 3
			if step > 0:
				img.set_pixel(x, y, Color(UI.GOLD, step * 0.8))
	return ImageTexture.create_from_image(img)


## Gold specks, two dice pixels square, rising off the felt all round a die toward the top of the screen and fading out.
static func _sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = SPARKS
	p.lifetime = 1.1
	p.local_coords = false
	var speck := QuadMesh.new()
	speck.orientation = PlaneMesh.FACE_Y  # flat, facing the camera overhead
	speck.size = Vector2.ONE * 2.0 / RUBBLE_SIZE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	speck.material = mat
	p.mesh = speck
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING  # round the die's edge, not under it
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.62
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0
	p.direction = Vector3(0, 0, -1)  # up the screen
	p.spread = 20
	p.gravity = Vector3(0, 0, -0.6)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(UI.GOLD.lightened(0.4), 1))
	fade.set_color(1, Color(UI.GOLD, 0))
	p.color_ramp = fade
	return p


## The badge disc: a bone coin (like a bone die, so the dark iron icons stand out) with a near-black rim, in game pixels blown up to the dice's 2x.
static func _disc() -> Texture2D:
	var img := Image.create_empty(BADGE_SIZE, BADGE_SIZE, false, Image.FORMAT_RGBA8)
	var r := BADGE_SIZE / 2.0
	for y in BADGE_SIZE:
		for x in BADGE_SIZE:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if d <= r:
				img.set_pixel(x, y, Color("070e10") if d > r - 1 else (Color("8a7f6a") if d > r - 2 else Color("c1b59b")))
	img.resize(BADGE_SIZE * PIXEL, BADGE_SIZE * PIXEL, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
