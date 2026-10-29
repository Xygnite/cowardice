class_name BackdropLife
extends Control
## Moving overlays (flames, fog, chains) laid over a backdrop image. They are placed in the image's own
## 1024x572 pixels, and `cover()` maps those onto the TextureRect the way STRETCH_KEEP_ASPECT_COVERED does.

const IMAGE := Vector2(1024, 572)
## Per backdrop art: `px` is how many image px one pxl pixel covers; `parts` are dictionaries
## {"kind": "flame" | "fog" | "chain", "art": sheet name, "at": Vector2 (image px, top-left), ...}.
## A flame also has "fps". Its sheet covers the painted flame under it on every frame.
## A fog band also has "width" (image px it covers), "period" (pxl px after which the band repeats),
## "step_s" (seconds per one-pxl-pixel drift step) and "alpha".
## A chain (a strip in image px, drawn so in pxl) also has "period": seconds for one
## swing there and back across its 5 sway frames.
const LIFE := {
	# Drawn as one with its parts in art/pxl/bg_screens.px.js: flames on its braziers (M.brazier), chains under its
	# MENU_CHAINS, fog over the moat.
	"menu": {"px": 2, "parts": [
		{"kind": "flame", "art": "torch", "at": Vector2(272, 322), "fps": 10.0},
		{"kind": "flame", "art": "torch", "at": Vector2(728, 322), "fps": 10.0},
		{"kind": "fog", "art": "moat", "at": Vector2(0, 516), "width": 1024.0, "period": 96, "step_s": 0.4, "alpha": 0.9},
		{"kind": "chain", "art": "chain_menu_0", "at": Vector2(74, 0), "period": 3.4},
		{"kind": "chain", "art": "chain_menu_1", "at": Vector2(132, 0), "period": 3.8},
		{"kind": "chain", "art": "chain_menu_2", "at": Vector2(876, 0), "period": 3.6},
		{"kind": "chain", "art": "chain_menu_3", "at": Vector2(930, 0), "period": 3.3},
	]},
	# Also from bg_screens.px.js: the flame on its fire (CAMP.fire), fog in the strip between the perk board and the
	# buttons, the one stretch of ground left in view, starting past the fire and the log, thin over the tent.
	"camp": {"px": 2, "parts": [
		{"kind": "flame", "art": "campfire", "at": Vector2(196, 450), "fps": 8.0},
		{"kind": "fog", "art": "ground", "at": Vector2(380, 472), "width": 644.0, "period": 128, "step_s": 0.5, "alpha": 0.55},
	]},
	# Drawn as one with its parts in art/pxl/bg_fights.px.js (its build prints these spots): flames on the candles in
	# the nave's two nearer bays a side, chains under the eyes on the near arch.
	"fight": {"px": 2, "parts": [
		{"kind": "flame", "art": "candle", "at": Vector2(158, 266), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(186, 268), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(202, 264), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(248, 260), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(262, 262), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(758, 262), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(772, 260), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(818, 264), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(834, 268), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(862, 266), "fps": 8.0},
		# Ends at y 390, along the foot of the step behind the fighters (CombatScreen.LEDGES), so they stand in front of it.
		{"kind": "fog", "art": "floor", "at": Vector2(0, 342), "width": 1024.0, "period": 96, "step_s": 0.55, "alpha": 0.8},
		{"kind": "chain", "art": "chain_fight_0", "at": Vector2(96, 112), "period": 3.2},
		{"kind": "chain", "art": "chain_fight_1", "at": Vector2(598, 62), "period": 3.8},
		{"kind": "chain", "art": "chain_fight_2", "at": Vector2(956, 132), "period": 3.5},
	]},
	# Also from bg_fights.px.js: flames on the glass of its LANTERNS, chains under the eye bolts on its sets' caps.
	"mine": {"px": 2, "parts": [
		{"kind": "flame", "art": "lantern", "at": Vector2(444, 226), "fps": 6.0},
		{"kind": "flame", "art": "lantern", "at": Vector2(576, 226), "fps": 6.0},
		{"kind": "flame", "art": "lantern", "at": Vector2(268, 216), "fps": 6.0},
		{"kind": "flame", "art": "lantern", "at": Vector2(752, 216), "fps": 6.0},
		# Ends at y 380, above the ground sill (CombatScreen.LEDGES), so the fighters stand in front of it.
		{"kind": "fog", "art": "dust", "at": Vector2(0, 300), "width": 1024.0, "period": 128, "step_s": 0.6, "alpha": 1.0},
		{"kind": "chain", "art": "chain_mine_0", "at": Vector2(228, 122), "period": 3.4},
		{"kind": "chain", "art": "chain_mine_1", "at": Vector2(798, 122), "period": 3.9},
		{"kind": "chain", "art": "chain_mine_2", "at": Vector2(592, 170), "period": 3.1},
	]},
}

var stage: Node2D


## Image px to rect px for a covered image: uniform scale, centred, overflow cropped.
static func cover(rect: Vector2, image := IMAGE) -> Transform2D:
	var s := maxf(rect.x / image.x, rect.y / image.y)
	return Transform2D(0.0, Vector2(s, s), 0.0, (rect - image * s) / 2.0)


## Lays a stage over `backdrop` and builds the parts for `art`; null when that art has none.
static func attach(backdrop: TextureRect, art: String) -> BackdropLife:
	if not LIFE.has(art):
		return null
	var life := BackdropLife.new()
	life.mouse_filter = Control.MOUSE_FILTER_IGNORE
	life.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	life.clip_contents = true  # parts near the image edge stay inside the cropped painting
	life.stage = Node2D.new()
	life.stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	life.add_child(life.stage)
	life.resized.connect(func(): life.stage.transform = cover(life.size))
	for part: Dictionary in LIFE[art].parts:
		var node := _part(part, LIFE[art].px)
		node.position = part.at
		node.scale = Vector2.ONE * (1 if part.kind == "chain" else LIFE[art].px)  # chain strips are in image px
		life.stage.add_child(node)
	backdrop.add_child(life)
	return life


## The node for one LIFE part, by its kind; `px` is its screen's image px per pxl pixel.
static func _part(part: Dictionary, px: int) -> Node2D:
	match part.kind:
		"flame":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = frames(part.art, part.fps)
			s.centered = false
			s.play()
			s.frame = randi() % s.sprite_frames.get_frame_count("default")  # neighbours don't flicker in step
			return s
		"fog":
			var s := Sprite2D.new()
			s.texture = load("res://assets/ui/life/%s.png" % part.art)
			s.centered = false
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, part.width / px, s.texture.get_height())
			s.modulate.a = part.alpha
			# Whole pxl pixels only: a smooth scroll would smear the hard pixel edges.
			var tick := Timer.new()
			tick.wait_time = part.step_s
			tick.autostart = true
			tick.timeout.connect(func(): s.region_rect.position.x = fmod(s.region_rect.position.x + 1, part.period))
			s.add_child(tick)
			return s
		"chain":
			var s := AnimatedSprite2D.new()
			var sf := frames(part.art, 8.0 / part.period)
			for f in [3, 2, 1]:  # ping-pong: 0..4 and back
				sf.add_frame("default", sf.get_frame_texture("default", f))
			s.sprite_frames = sf
			s.centered = false
			s.play()
			s.frame = randi() % 8  # neighbours don't swing in step
			return s
	push_error("BackdropLife: unknown part kind %s" % part.kind)
	return Node2D.new()


## A looping "default" animation from `<dir><sheet>.png` and `.json` (pxl frame sheet: frames taken in
## order, whatever they are named). `dir` is overridable for tests.
static func frames(sheet: String, fps: float, dir := "res://assets/ui/life/") -> SpriteFrames:
	var base := dir + sheet
	var tex: Texture2D
	if ResourceLoader.exists(base + ".png"):
		tex = load(base + ".png")
	else:  # a loose file (not imported), as the tests write
		tex = ImageTexture.create_from_image(Image.load_from_file(base + ".png"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	var list: Array = data.frames.values() if data.frames is Dictionary else data.frames
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	for f: Dictionary in list:
		var r: Dictionary = f.frame
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(r.x, r.y, r.w, r.h)
		sf.add_frame("default", at)
	return sf
