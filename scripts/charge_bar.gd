class_name ChargeBar
extends Control
## The wind-up before a throw, drawn inside the Roll button: while the button (or its key) is held the
## fill swings up and back down; letting go throws with that much power. The screen feeds it press().

signal thrown(power: float)

const SWING_MS := 900.0  # how long the fill takes to rise from empty to full
const FLASH_MS := 800.0  # one pulse of the waiting glow
const INSET := 4.0  # two art pixels: keeps the gold off the frame's rounded outer corners
static var auto := false  # tests: throw at full power straight away, nobody holds anything

var waiting := false  # a throw is waiting on the press and release
var held := -1.0  # ms held so far; below zero until the press
var frames := {}  # the button's iron border per look, fill cleared (tools/make_ui.gd)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the button under it takes the clicks
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Waits for a press and release; returns the power, 0 to 1.
func wind_up() -> float:
	if auto:
		return 1.0
	waiting = true
	held = -1.0
	queue_redraw()
	return await thrown


func power() -> float:
	return pingpong(maxf(held, 0.0) / SWING_MS, 1.0)


func press(down: bool) -> void:
	if not waiting:
		return
	if down and held < 0.0:
		held = 0.0
	elif not down and held >= 0.0:
		waiting = false
		var p := power()
		held = -1.0
		queue_redraw()
		thrown.emit(p)


func _process(delta: float) -> void:
	if held >= 0.0:
		held += delta * 1000.0
	if waiting:
		queue_redraw()


## Gold over the button's face, then the button's iron border (its art with the fill cleared,
## tools/make_ui.gd) laid back over the gold, so the fill sits inside the frame.
func _draw() -> void:
	var inner := Rect2(Vector2.ZERO, size).grow(-INSET)
	if waiting and held < 0.0:  # pulses until pressed, so the player sees it is time to throw
		var glow := 0.5 - 0.5 * cos(Time.get_ticks_msec() / FLASH_MS * TAU)
		draw_rect(inner, Color(UI.GOLD, 0.35 * glow))
	elif held >= 0.0:
		draw_rect(Rect2(inner.position, inner.size * Vector2(power(), 1)), Color(UI.GOLD, 0.45))
	else:
		return
	var state := (get_parent() as Button).get_draw_mode()
	var look := "pressed" if state in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else ("hover" if state == BaseButton.DRAW_HOVER else "normal")
	draw_style_box(frames[look], Rect2(Vector2.ZERO, size))


## Kept for the bar's life: a texture freed when _draw returns renders white.
func _ready() -> void:
	for look in ["normal", "hover", "pressed"]:
		var frame: StyleBoxTexture = get_parent().get_theme_stylebox(look).duplicate()
		frame.texture = load(UI.ART % ("button_frame" if look == "normal" else "button_frame_" + look))
		frames[look] = frame
