class_name TimingBar
extends Control
## Enemy wind-up for the timed block and parry: the marker runs right, impact is the right edge.
## One SPACE press per attack; pressing early or not at all is a miss.

signal finished(grade: int)

const WINDUP_MS := 1400.0
const LATE_GRACE_MS := 200.0  # how long the bar waits past impact before calling it a miss

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
	draw_rect(Rect2(0, 0, w, h), Color(0.18, 0.19, 0.22))
	var px_per_ms := w / WINDUP_MS
	if combat.enemies[enemy].intent.kind == "attack":
		draw_rect(Rect2(w - Combat.GOOD_MS * px_per_ms, 0, Combat.GOOD_MS * px_per_ms, h), Color(0.25, 0.45, 0.8, 0.5))
		var perfect := combat.perfect_window_ms() * px_per_ms
		draw_rect(Rect2(w - perfect, 0, perfect, h), Color(0.4, 0.65, 1.0))
	else:
		var parry := combat.parry_window_ms() * px_per_ms
		draw_rect(Rect2(w - parry, 0, parry, h), Color(0.85, 0.25, 0.25))
	var x := minf(elapsed * px_per_ms, w)
	draw_rect(Rect2(x - 2, -6, 4, h + 12), Color(1, 0.85, 0.4))
