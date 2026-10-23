class_name BackdropLife
extends Control
## Moving overlays (flames, fog, chains) laid over a backdrop image. They are placed in the image's own
## 1024x572 pixels, and `cover()` maps those onto the TextureRect the way STRETCH_KEEP_ASPECT_COVERED does.

const IMAGE := Vector2(1024, 572)
## Per backdrop art: `px` is how many image px one pxl pixel covers; `parts` are dictionaries
## {"kind": "flame" | "fog" | "chain", "art": sheet name, "at": Vector2 (image px, top-left), ...}.
const LIFE := {
	"menu": {"px": 2, "parts": []},
	"camp": {"px": 4, "parts": []},
	"fight": {"px": 2, "parts": []},
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
	life.stage = Node2D.new()
	life.stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	life.add_child(life.stage)
	life.resized.connect(func(): life.stage.transform = cover(life.size))
	backdrop.add_child(life)
	return life


## A looping "default" animation from res://assets/ui/life/<sheet>.png and .json (pxl frame sheet,
## frames in order along one row).
static func frames(sheet: String, fps: float) -> SpriteFrames:
	var base := "res://assets/ui/life/" + sheet
	var tex: Texture2D = load(base + ".png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	for i in data.frames.size():
		var r: Dictionary = data.frames[sheet + "_" + str(i)].frame
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(r.x, r.y, r.w, r.h)
		sf.add_frame("default", at)
	return sf
