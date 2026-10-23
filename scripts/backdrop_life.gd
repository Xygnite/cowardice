class_name BackdropLife
extends Control
## Moving overlays (flames, fog, chains) laid over a backdrop image. They are placed in the image's own
## 1024x572 pixels, and `cover()` maps those onto the TextureRect the way STRETCH_KEEP_ASPECT_COVERED does.

const IMAGE := Vector2(1024, 572)
## Per backdrop art: `px` is how many image px one pxl pixel covers; `parts` are dictionaries
## {"kind": "flame" | "fog" | "chain", "art": sheet name, "at": Vector2 (image px, top-left), ...}.
## A flame also has "fps". Its sheet covers the painted flame under it on every frame.
const LIFE := {
	"menu": {"px": 2, "parts": [
		{"kind": "flame", "art": "torch", "at": Vector2(290, 314), "fps": 10.0},
		{"kind": "flame", "art": "torch_r", "at": Vector2(698, 314), "fps": 10.0},
	]},
	"camp": {"px": 4, "parts": [
		{"kind": "flame", "art": "campfire", "at": Vector2(173, 396), "fps": 8.0},
	]},
	"fight": {"px": 2, "parts": [
		{"kind": "flame", "art": "candle", "at": Vector2(157, 265), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(262, 266), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(277, 248), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(290, 274), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(737, 266), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(755, 253), "fps": 8.0},
		{"kind": "flame", "art": "candle", "at": Vector2(865, 274), "fps": 8.0},
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
		var node := _part(part)
		node.position = part.at
		node.scale = Vector2.ONE * LIFE[art].px
		life.stage.add_child(node)
	backdrop.add_child(life)
	return life


## The node for one LIFE part, by its kind.
static func _part(part: Dictionary) -> Node2D:
	match part.kind:
		"flame":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = frames(part.art, part.fps)
			s.centered = false
			s.play()
			s.frame = randi() % s.sprite_frames.get_frame_count("default")  # neighbours don't flicker in step
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
