class_name Overlay
extends Control
## A window opened over whatever screen is up: a dimmed backdrop and a framed, centred panel. Esc or close()
## removes it and leaves the screen behind as it was. Subclasses fill `body` in _build().

var body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()  # also swallows clicks meant for the screen behind
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	body = UI.panel(center, SoundControls.GAP)
	body.custom_minimum_size.x = 360
	_build()


func _build() -> void:
	pass


## The window's title, centred at the top.
func heading(text: String) -> void:
	UI.heading(body, 32, text).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## A full-width button at the panel's row height.
func button(text: String, on_press: Callable) -> Button:
	var b := UI.button(body, text, on_press)
	b.custom_minimum_size.y = SoundControls.ROW_HEIGHT
	return b


func close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
