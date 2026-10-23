class_name DiceTray
extends Control
## The dice as 3D cubes in a walled tray, seen from above, rendered at low resolution and scaled up so
## they stay pixel art. A roll throws them in from the left as rigid bodies: they bounce off the walls
## and knock into each other (and into locked dice, which stay put). Once a die slows down, a hidden
## torque tips it onto the face the game rolled and squares it to the screen, then it is pinned there.
## Each side shows one of the die's faces, on the die art from assets/ui/cut/die_<art>.png.

signal die_clicked(i: int)
signal landed  # once per throw, when its last die is pinned

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
const FELT := preload("res://assets/ui/cut/tray_felt.png")  # the tray floor's repeating tile, made by tools/make_ui.gd

const GRAVITY_SCALE := 3.0  # a cube width is a metre to the physics; small dice fall faster than that
const THROW_SPEED := Vector2(8, 11)  # cube widths per second, rightward
const THROW_SPIN := 15.0  # radians per second, about a random axis
const BOUNCE := 0.3
const FRICTION := 0.7
## Below this speed the die is steered onto its rolled face: torque = error * STEER - spin * DAMP.
## STEER must beat gravity (about 15 at the tipping point) so a die can be rolled over an edge.
const STEER_BELOW := 3.0
const STEER := 22.0
const DAMP := 3.0
const SETTLED_ANGLE := 0.05  # radians from the rest pose
const NEARLY_SQUARE := 0.26  # radians; a stopped die this close is nudged the rest of the way
const NUDGE_TIME := 0.1
const SETTLED_SPEED := 0.4
const GIVE_UP := 3.0  # seconds; a die still not settled (wedged on a wall, say) is eased into place
const EASE_TIME := 0.25

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
## faces, value, rolling, and t (seconds since thrown).
var dice: Array[Dictionary] = []
var in_flight := false  # a throw has dice still rolling; landed fires when none are


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
	var slot := TextureRect.new()  # the badge disc; its icon sits in the middle
	slot.texture = _disc()
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	slot.add_child(icon)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	dice.append({"body": body, "cube": cube, "labels": labels, "chain": chain, "slot": slot, "icon": icon,
		"faces": [], "value": 0, "rolling": false, "t": 0.0})
	for i in dice.size():  # the row stays centred as it grows
		dice[i].body.position = _spot(i)


## Shows die i's faces in `art` (bone, locked, placed, cursed) with `value` up, and the icon
## assets/ui/cut/slot_<slot_icon>.png in its top-right corner, or none if `slot_icon` is empty;
## a locked die is wrapped in chains.
## Mid-throw it only repaints; the throw lands on its own value.
func show_die(i: int, faces: Array, value: int, art: String, slot_icon: String, locked: bool) -> void:
	var d := dice[i]
	d.faces = faces
	d.value = value
	(d.cube.material_override as StandardMaterial3D).albedo_texture = _atlas(art)
	for k in d.labels.size():
		d.labels[k].text = "X" if faces[k] == Combat.CURSE else str(faces[k])
		d.labels[k].modulate = Color(0.16, 0.13, 0.1) if art == "bone" else Color.WHITE
	d.icon.texture = load(UI.ART % ("slot_" + slot_icon)) if slot_icon else null
	d.chain.visible = locked
	if not d.rolling:
		d.body.quaternion = _rest(d)


## Throws the dice at `which` (indices) in from the left; each lands on its current value.
func throw(which: Array) -> void:
	if size.x == 0:
		# The walls need the tray's size, and a new screen resizes it more than once while it lays out:
		# throwing after the first would spawn dice where the walls then close in and shove them out.
		await resized
		await get_tree().process_frame
	var depth := _half_depth() - 0.7
	for n in which.size():
		var d := dice[which[n]]
		var body: RigidBody3D = d.body
		d.rolling = true
		d.t = 0.0
		# Out of the hand in a loose line, so no two start inside each other.
		var lane := 0.0 if which.size() == 1 else lerpf(-depth, depth, float(n) / (which.size() - 1))
		body.position = Vector3(-_half_width() + 0.7 + n * 1.1, 1.5, lane)
		body.quaternion = Quaternion.from_euler(Vector3(randf(), randf(), randf()) * TAU)
		body.freeze = false
		body.linear_velocity = Vector3(randf_range(THROW_SPEED.x, THROW_SPEED.y), randf_range(0, 2), randf_range(-2, 2))
		body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * THROW_SPIN
		body.sleeping = false
	in_flight = true


func _physics_process(delta: float) -> void:
	for d in dice:
		if not d.rolling or d.body.freeze:
			continue
		var body: RigidBody3D = d.body
		d.t += delta
		var rest := _rest(d, body.quaternion)
		var off := _turn_between(body.quaternion, rest)
		var angle := off.get_angle()
		if angle < NEARLY_SQUARE and body.linear_velocity.length() < SETTLED_SPEED and body.angular_velocity.length() < SETTLED_SPEED:
			# Friction can hold a die a few degrees off, where the steering is too weak to finish; nudge it.
			_pin(d, 0.0 if angle < SETTLED_ANGLE else NUDGE_TIME)
		elif d.t > GIVE_UP:
			_pin(d, EASE_TIME)
		elif body.linear_velocity.length() < STEER_BELOW and angle > 0.001:
			# Torque toward the rest pose, damped so it does not wobble.
			body.apply_torque(off.get_axis() * angle * STEER - body.angular_velocity * DAMP)


## Stops a die and sets it exactly in its rest pose where it lies, easing there over `time` seconds.
func _pin(d: Dictionary, time: float) -> void:
	var body: RigidBody3D = d.body
	body.freeze = true
	var to := Vector3(body.position.x, 0.5, body.position.z)
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
	for d in dice:
		var top: Vector3 = d.body.position
		d.chain.position = top + Vector3(0, 0.53, CHAIN_DROP)  # above the number (at 0.51), so it covers it
		# A badge in the top-right corner of the top face, put away while the die tumbles.
		d.slot.position = _screen(top + BADGE) - d.slot.size / 2
		d.slot.visible = d.icon.texture != null and not d.rolling
	if in_flight and not dice.any(func(d): return d.rolling):
		in_flight = false
		landed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in dice.size():
			if event.position.distance_to(_screen(dice[i].body.position + Vector3.UP / 2)) < CLICK_RADIUS:
				die_clicked.emit(i)
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


## Keeps a cube UNIT pixels wide on the floor whatever the tray's size, and the walls on its edges.
func _fit() -> void:
	camera.size = size.y / UNIT
	var hw := _half_width()
	var hd := _half_depth()
	var spans := [Vector3(1, 10, hd * 2 + 2), Vector3(1, 10, hd * 2 + 2), Vector3(hw * 2 + 2, 10, 1), Vector3(hw * 2 + 2, 10, 1)]
	var centres := [Vector3(-hw - 0.5, 5, 0), Vector3(hw + 0.5, 5, 0), Vector3(0, 5, -hd - 0.5), Vector3(0, 5, hd + 0.5)]
	for i in 4:
		walls[i].shape.size = spans[i]
		walls[i].position = centres[i]
	for d in dice:  # a die the walls just closed in on goes back inside, not out through them
		var p: Vector3 = d.body.position
		d.body.position = Vector3(clampf(p.x, -hw + 0.5, hw - 0.5), p.y, clampf(p.z, -hd + 0.5, hd - 0.5))


## The turn that puts a side showing the die's value face up and square to the screen; of the sides
## showing it (forged dice can repeat a value), the one nearest `near`.
func _rest(d: Dictionary, near := Quaternion.IDENTITY) -> Quaternion:
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
