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
const LIFE := {
	"menu": {"px": 2, "parts": [
		{"kind": "flame", "art": "torch", "at": Vector2(290, 314), "fps": 10.0},
		{"kind": "flame", "art": "torch_r", "at": Vector2(698, 314), "fps": 10.0},
		{"kind": "fog", "art": "moat", "at": Vector2(0, 516), "width": 1024.0, "period": 96, "step_s": 0.4, "alpha": 0.9},
	]},
	"camp": {"px": 4, "parts": [
		{"kind": "flame", "art": "campfire", "at": Vector2(173, 396), "fps": 8.0},
		# In the strip between the perk board and the buttons, the one stretch of ground left in view;
		# it starts right of the campfire, which greyed out under it.
		{"kind": "fog", "art": "ground", "at": Vector2(248, 464), "width": 776.0, "period": 64, "step_s": 0.5, "alpha": 0.9},
	]},
	"fight": {"px": 2, "parts": [
		{"kind": "flame", "art": "candle", "at": Vector2(157, 265), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(262, 266), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(277, 248), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(290, 274), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(737, 266), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(755, 253), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(865, 274), "fps": 8.0},
		# Ends at y 390, above the floor ledge (CombatScreen.FLOOR_LEDGE), so the fighters stand in front of it.
		{"kind": "fog", "art": "floor", "at": Vector2(0, 366), "width": 1024.0, "period": 96, "step_s": 0.55, "alpha": 0.8},
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
		node.scale = Vector2.ONE * LIFE[art].px
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
