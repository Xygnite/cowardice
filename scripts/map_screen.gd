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
var seen_events: Array = []  # for the "?" rooms' odds
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
	if room.kind == "unknown" and not _taken(c, i):
		# room_unknown.png is a broken cut, so a pixel-font "?" stands in
		b.texture_normal = ImageTexture.create_from_image(Image.create_empty(52, 56, false, Image.FORMAT_RGBA8))
		var q := UI.heading(b, 64, "?")
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.add_theme_color_override("font_color", INK)
	else:
		b.texture_normal = load(UI.ART % ("room_" + ("cleared" if _taken(c, i) else _icon(room))))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.disabled = not can_pick
	b.visible = c >= layer or _taken(c, i)  # branches you passed by vanish
	if room.kind == "fight":
		b.tooltip_text = room.label
	elif room.kind == "unknown" and not _taken(c, i):
		b.tooltip_text = "\n".join(Events.odds(seen_events).map(func(o): return "%s  %.0f%%" % o))
	if can_pick:
		# Past 1.0 so the dark art actually brightens; the gold disc in _draw_links does the rest.
		var glow := Color(1.8, 1.4, 0.6)
		b.modulate = glow
		var t := b.create_tween().set_loops()
		t.tween_property(b, "modulate", glow * 0.67, 0.7)
		t.tween_property(b, "modulate", glow, 0.7)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.mouse_entered.connect(_grow.bind(b, 1.2))
		b.mouse_exited.connect(_grow.bind(b, 1.0))
		b.button_down.connect(_grow.bind(b, 0.9))
	elif c >= layer:
		b.modulate.a = 0.6
	b.pressed.connect(picked.emit.bind(i))
	return b


## Eases a pickable room to `to` times its size: up on hover, down while pressed.
func _grow(b: TextureButton, to: float) -> void:
	b.create_tween().tween_property(b, "scale", Vector2.ONE * to, 0.08)


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
			b.pivot_offset = b.get_combined_minimum_size() / 2  # hover and press scale from the centre
	var boss := _spot(rooms.size() - 1, rooms[-1][0].lane)
	var lair: Label = _field.get_node("Lair")
	lair.position = boss + Vector2(-lair.get_minimum_size().x / 2, 36)
	_field.queue_redraw()


func _draw_links() -> void:
	if layer < rooms.size():
		for i in pickable():
			var at := _spot(layer, rooms[layer][i].lane)
			_field.draw_circle(at, 36, Color(UI.GOLD, 0.3))
			_field.draw_arc(at, 36, 0, TAU, 32, Color(UI.GOLD, 0.8), 2)
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
