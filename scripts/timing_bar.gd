class_name TimingBar
extends Control
## Enemy wind-up for the timed block and parry: the marker runs right, impact is the right edge.
## One SPACE press per attack; pressing early or not at all is a miss.

signal finished(grade: int)

const WINDUP_MS := 1400.0
const LATE_GRACE_MS := 200.0  # how long the bar waits past impact before calling it a miss
const INSET := 8.0  # frame border width in screen pixels
static var FRAME := _frame()


static func _frame() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = preload("res://assets/ui/cut/bar_frame.png")
	s.set_texture_margin_all(INSET)
	return s

var combat: Combat
var enemy := 0
var elapsed := 0.0
var running := false


func start(c: Combat, enemy_index: int) -> void:
	combat = c
	enemy = enemy_index
	elapsed = 0.0
	running = true
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta * 1000.0
	if elapsed > WINDUP_MS + LATE_GRACE_MS:
		_finish(Combat.Grade.MISS)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_finish(combat.grade_for(WINDUP_MS - elapsed, enemy))


func _finish(grade: int) -> void:
	running = false
	hide()
	finished.emit(grade)


func _draw() -> void:
	if combat == null:
		return
	var w := size.x
	var h := size.y
	draw_style_box(FRAME, Rect2(0, 0, w, h))
	var px_per_ms := w / WINDUP_MS
	if combat.enemies[enemy].intent.kind == "attack":
		_window(Combat.GOOD_MS * px_per_ms, Color(0.25, 0.45, 0.8, 0.5))
		_window(combat.perfect_window_ms() * px_per_ms, Color(0.4, 0.65, 1.0))
	else:
		_window(combat.parry_window_ms() * px_per_ms, Color(0.85, 0.25, 0.25))
	var x := minf(elapsed * px_per_ms, w)
	draw_rect(Rect2(x - 2, -6, 4, h + 12), Color(1, 0.85, 0.4))


## A timing window ending at impact (the right edge), kept inside the frame.
func _window(width: float, color: Color) -> void:
	draw_rect(Rect2(size.x - INSET - width, INSET, width, size.y - INSET * 2), color)
