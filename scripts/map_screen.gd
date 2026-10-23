class_name MapScreen
extends Control
## The floor as a branching map, entrance on the left and boss on the right. You can only step along a link.

signal picked(index: int)

const INK := Color(0.23, 0.16, 0.1)
const WALKED := Color(0.48, 0.14, 0.09)
const COLUMNS := 10
const LANES := 5
const INSET := Vector4(0.07, 0.12, 0.07, 0.1)  # left, top, right, bottom share of the parchment, clear of its burnt edge

var rooms: Array = []  # columns of room dictionaries, entrance first
var layer := 0
var path: Array = []
var combat: Combat
var room_buttons: Array = []  # per column, its rooms' buttons
var _field: Control  # the parchment area the rooms sit on


## Room indices in column `layer` that the last room taken links to.
func pickable() -> Array:
	if layer == 0:
		return [0]
	if path.size() < layer:  # the --fight dev shortcut jumps in without a path
		return range(rooms[layer].size())
	return rooms[layer - 1][path[layer - 1]].next


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
	_field = Control.new()
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 8)
	_field.offset_top = 72
	_field.draw.connect(_draw_links)
	add_child(_field)
	var pick := pickable()
	for c in rooms.size():
		room_buttons.append([])
		for i in rooms[c].size():
			var b := _room_button(c, i, c == layer and i in pick)
			_field.add_child(b)
			room_buttons[c].append(b)
	var lair := UI.label(_field, 16, "The Warden's Lair")
	lair.name = "Lair"
	lair.add_theme_color_override("font_color", INK)
	_field.resized.connect(_place_rooms)  # only now: it needs the buttons
	_place_rooms()


func _taken(c: int, i: int) -> bool:
	# The --fight dev shortcut skips columns, leaving no room taken there.
	return c < layer and c < path.size() and path[c] == i


func _room_button(c: int, i: int, can_pick: bool) -> TextureButton:
	var room: Dictionary = rooms[c][i]
	var b := TextureButton.new()
	b.texture_normal = load(UI.ART % ("room_" + ("cleared" if _taken(c, i) else _icon(room))))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.disabled = not can_pick
	b.visible = c >= layer or _taken(c, i)  # branches you passed by vanish
	if room.kind == "fight":
		b.tooltip_text = room.label
	if can_pick:
		b.modulate = UI.GOLD
		var t := b.create_tween().set_loops()
		t.tween_property(b, "modulate", UI.GOLD * 1.2, 0.7)
		t.tween_property(b, "modulate", UI.GOLD * 0.8, 0.7)
	elif c >= layer:
		b.modulate.a = 0.6
	b.pressed.connect(picked.emit.bind(i))
	return b


## Centre of room (column, lane) in field coordinates.
func _spot(c: int, lane: int) -> Vector2:
	var s := _field.size
	var box := Rect2(s.x * INSET.x, s.y * INSET.y, s.x * (1 - INSET.x - INSET.z), s.y * (1 - INSET.y - INSET.w))
	return box.position + Vector2((c + 0.5) / COLUMNS * box.size.x, (lane + 0.5) / LANES * box.size.y)


func _place_rooms() -> void:
	for c in rooms.size():
		for i in rooms[c].size():
			var b: TextureButton = room_buttons[c][i]
			b.position = _spot(c, rooms[c][i].lane) - b.get_combined_minimum_size() / 2
	var boss := _spot(rooms.size() - 1, rooms[-1][0].lane)
	var lair: Label = _field.get_node("Lair")
	lair.position = boss + Vector2(-lair.get_minimum_size().x / 2, 36)
	_field.queue_redraw()


func _draw_links() -> void:
	for c in rooms.size() - 1:
		for i in rooms[c].size():
			for n in rooms[c][i].next:
				var from := _spot(c, rooms[c][i].lane)
				var to := _spot(c + 1, rooms[c + 1][n].lane)
				if _taken(c, i) and _taken(c + 1, n):
					_field.draw_line(from, to, WALKED, 3)
				elif c >= layer or (c == layer - 1 and _taken(c, i)):  # nothing leads off a branch you passed by
					_field.draw_dashed_line(from, to, Color(INK, 0.75), 2)


## Room art in assets/ui/cut/room_*.png: fight, boss, forge or campfire.
func _icon(room: Dictionary) -> String:
	if room.kind == "fight":
		return "boss" if room.label.begins_with("Boss") else "fight"
	return room.kind
