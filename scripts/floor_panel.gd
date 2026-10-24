class_name FloorPanel
extends Overlay
## Start run, once the Hollow Mine is unlocked: choose the floor to start on.

signal chosen(floor_id: String)


func _build() -> void:
	heading("Start run")
	for id in Floor.FLOORS:
		button(Floor.FLOORS[id].title, _pick.bind(id))
	button("Back  [Esc]", close)


func _pick(id: String) -> void:
	chosen.emit(id)
	close()
