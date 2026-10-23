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
	var parchment := UI.image(self, "map", Vector2.ONE)
	parchment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 8)
	parchment.offset_top = 72  # below the HP and title row
	move_child(parchment, 1)  # over the page background, under the rooms
	var top := UI.row(root)
	UI.label(top, 22, "HP %d/%d   Shards %d" % [combat.player_hp, combat.max_hp, combat.shards])
	UI.spacer(top)
	UI.heading(top, 32, "The Sunken Chapel")
	for li in range(rooms.size() - 1, -1, -1):
		var r := UI.row(root, 24)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for ri in rooms[li].size():
			var b := UI.button(r, rooms[li][ri].label, picked.emit.bind(ri))
			b.custom_minimum_size = Vector2(320, 64)
			var taken: bool = li < layer and li < path.size() and path[li] == ri
			b.icon = load(UI.ART % ("room_" + ("cleared" if taken else _icon(rooms[li][ri]))))
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = li != layer
			if li < layer:
				# The room you took stays lit; the --fight dev shortcut skips layers, leaving no room to light.
				b.modulate.a = 1.0 if taken else 0.25
			elif li > layer:
				b.modulate.a = 0.6


## Room art in assets/ui/cut/room_*.png: fight, boss, forge or campfire.
func _icon(room: Dictionary) -> String:
	if room.kind == "fight":
		return "boss" if room.label.begins_with("Boss") else "fight"
	return room.kind
