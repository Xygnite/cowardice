class_name MapScreen
extends Control
## The floor as rows of rooms, boss at the top. Only the current row can be picked.

signal picked(index: int)

var rooms: Array = []  # layers of room dictionaries, entrance first
var layer := 0
var path: Array = []
var combat: Combat


func _ready() -> void:
	var root := UI.page(self)
	var top := UI.row(root)
	UI.label(top, 22, "HP %d/%d   Shards %d" % [combat.player_hp, combat.max_hp, combat.shards])
	UI.spacer(top)
	UI.label(top, 22, "The Sunken Chapel")
	for li in range(rooms.size() - 1, -1, -1):
		var r := UI.row(root, 24)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for ri in rooms[li].size():
			var b := UI.button(r, rooms[li][ri].label, picked.emit.bind(ri))
			b.custom_minimum_size = Vector2(320, 64)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = li != layer
			if li < layer:
				# The room you took stays lit; the --fight dev shortcut skips layers, leaving no room to light.
				b.modulate.a = 1.0 if li < path.size() and path[li] == ri else 0.25
			elif li > layer:
				b.modulate.a = 0.6
