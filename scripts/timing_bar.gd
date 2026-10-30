class_name TimingBar
extends Control
## Enemy wind-up for the timed block and parry: the marker runs right, and impact lands at a random
## point along the bar each attack, where the windows end. One SPACE press or left click on the tray per attack; pressing early,
## late or not at all is a miss.

signal finished(grade: int)

const WINDUP_MS := 900.0  # how long the marker takes to cross the whole bar
const EARLIEST_IMPACT := 0.45  # share of the bar before which impact never lands, so even a Good window fits
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
var impact_ms := WINDUP_MS  # when this attack lands, measured like elapsed
var running := false


func start(c: Combat, enemy_index: int) -> void:
	combat = c
	enemy = enemy_index
	elapsed = 0.0
	impact_ms = c.rng.randf_range(WINDUP_MS * EARLIEST_IMPACT, WINDUP_MS)
	running = true
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta * 1000.0
	if elapsed > impact_ms + LATE_GRACE_MS:
		_finish(Combat.Grade.MISS)
	queue_redraw()


## _input, not _unhandled_input: the dice tray under the bar would eat the click otherwise.
## A click counts only on the tray (the bar's parent), so a stray click elsewhere isn't a miss.
func _input(event: InputEvent) -> void:
	if not running or not event.is_pressed() or event.is_echo():
		return
	var key: bool = event is InputEventKey and event.keycode == KEY_SPACE
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and get_parent_control().get_global_rect().has_point(event.position)
	if key or click:
		get_viewport().set_input_as_handled()
		_finish(combat.grade_for(impact_ms - elapsed, enemy))


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
	var px_per_ms := (w - INSET * 2) / WINDUP_MS
	var impact := INSET + impact_ms * px_per_ms
	if combat.enemies[enemy].intent.kind == "attack":
		_window(impact, Combat.GOOD_MS * px_per_ms, Color(0.25, 0.45, 0.8, 0.5))
		_window(impact, combat.perfect_window_ms() * px_per_ms, Color(0.4, 0.65, 1.0))
	else:
		_window(impact, combat.parry_window_ms() * px_per_ms, Color(0.85, 0.25, 0.25))
	var x := minf(INSET + elapsed * px_per_ms, w - INSET)
	draw_rect(Rect2(x - 2, -6, 4, h + 12), Color(1, 0.85, 0.4))


## A timing window ending at impact, kept inside the frame.
func _window(impact: float, width: float, color: Color) -> void:
	var left := maxf(INSET, impact - width)
	draw_rect(Rect2(left, INSET, impact - left, size.y - INSET * 2), color)
