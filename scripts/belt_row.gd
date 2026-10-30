class_name BeltRow
extends HBoxContainer
## The belt as a row of BELT_SIZE slots: a RelicIcon per relic, then dashed empty ones. Icons drag to reorder the
## belt (while can_drag says so); show_destroy puts a Destroy button under each relic.

signal moved  # a drop reordered the belt
signal destroy_pressed(k: int)

var combat: Combat
var can_drag := func() -> bool: return true
var show_destroy := false


## Redraws the slots from combat.relics.
func rebuild() -> void:
	for c in get_children():
		remove_child(c)  # now, so a lookup straight after sees only the new slots
		c.queue_free()
	for k in Combat.BELT_SIZE:
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(slot)
		if k < combat.relics.size():
			slot.add_child(RelicIcon.make(combat, k))
			if show_destroy:
				UI.button(slot, "Destroy", func() -> void: destroy_pressed.emit(k))
		else:
			var empty := Control.new()
			empty.custom_minimum_size = Vector2(32, 32)
			empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty.draw.connect(_draw_empty.bind(empty))
			slot.add_child(empty)


## Belt slot k's icon.
func icon(k: int) -> RelicIcon:
	return get_child(k).get_child(0)


func _draw_empty(empty: Control) -> void:
	var r := Rect2(Vector2.ZERO, empty.size).grow(-1)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		empty.draw_dashed_line(corners[i], corners[i + 1], UI.QUIET, 2, 4)


## The relic index a drop at x lands on: the slot under it, but never past the last relic.
func _slot_at(x: float) -> int:
	var k := 0
	while k < get_child_count() - 1 and x >= get_child(k + 1).position.x:
		k += 1
	return mini(k, combat.relics.size() - 1)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("belt_k") and can_drag.call()


func _drop_data(at: Vector2, data: Variant) -> void:
	var to := _slot_at(at.x)
	if to == data.belt_k:
		return
	combat.move_relic(data.belt_k, to)
	rebuild()
	moved.emit()
