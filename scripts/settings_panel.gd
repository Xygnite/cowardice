class_name SettingsPanel
extends Control
## Settings, opened over whatever screen is up: a dimmed backdrop and a framed panel with the sound controls.
## Close or Esc removes it and leaves the screen behind as it was.

var meta: Meta


## Opens the panel over `screen`, which keeps running underneath.
static func open(screen: Control, m: Meta) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.meta = m
	screen.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()  # also swallows clicks meant for the screen behind
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UI.panel(center, SoundControls.GAP)
	col.custom_minimum_size.x = 360
	UI.heading(col, 32, "Settings").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sound := SoundControls.new()
	sound.meta = meta
	col.add_child(sound)
	UI.button(col, "Close  [Esc]", queue_free).custom_minimum_size.y = SoundControls.ROW_HEIGHT


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()
