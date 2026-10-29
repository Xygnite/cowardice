class_name TileBoard
extends HBoxContainer
## Small tiles in one scrolling column, in titled sections, beside a fixed panel that describes the last tile
## hovered or clicked. The screen that owns it says what each tile is through `look`, acts on a click through
## `press`, and calls refresh() after anything changes.

const TILE := Vector2(112, 112)
const LOCKED := Color(0.45, 0.45, 0.45)
const HOVER := Color(1.4, 1.4, 1.4)  # the tile's frame under the mouse
const SELECTED := Color(1.9, 1.5, 0.9)  # the tile the panel describes

## id -> {locked, on, cost, state, text}
var look: Callable
var press: Callable  # id -> void, on a tile's click
var shown := ""  # the tile the panel describes
var tiles := {}  # id -> {button, body, cost, caption, art: Callable}
var column: VBoxContainer
var group := ButtonGroup.new()
var art_box: CenterContainer
var title: Label
var state: Label
var text: Label


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var info := UI.panel(self)
	info.custom_minimum_size.x = 280
	art_box = CenterContainer.new()
	art_box.custom_minimum_size.y = 112
	info.add_child(art_box)
	title = UI.heading(info, 32)
	state = UI.label(info, 16)
	text = UI.label(info, 16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("font_color", UI.QUIET)


## A titled run of tiles; returns the flow to add() them to.
func section(heading: String) -> HFlowContainer:
	UI.label(column, 16, heading).add_theme_color_override("font_color", UI.QUIET)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	column.add_child(flow)
	return flow


## A tile for `id`; `art` draws its picture into a parent at a scale (1 on the tile, 2 in the panel).
func add(flow: HFlowContainer, id: String, caption: String, art: Callable) -> void:
	var b := UI.button(flow, "", _click.bind(id))
	b.custom_minimum_size = TILE
	b.toggle_mode = true
	b.button_group = group
	# The hover and pressed button art has other corners, which squash on a square tile; tint the normal frame instead.
	var frame: StyleBoxTexture = b.get_theme_stylebox("normal")
	for state in ["hover", "pressed", "hover_pressed"]:
		var tinted: StyleBoxTexture = frame.duplicate()
		tinted.modulate_color = HOVER if state == "hover" else SELECTED
		b.add_theme_stylebox_override(state, tinted)
	b.mouse_entered.connect(_show.bind(id))
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(body)
	art.call(body, 1)
	var l := UI.label(body, 16, caption)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cost := UI.label(b, 16)
	cost.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	cost.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cost.add_theme_color_override("font_color", UI.GOLD)
	for c in b.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE  # hovers and clicks go to the tile
	tiles[id] = {"button": b, "body": body, "cost": cost, "caption": caption, "art": art}


func refresh() -> void:
	for id in tiles:
		var k: Dictionary = look.call(id)
		var t: Dictionary = tiles[id]
		t.cost.text = str(k.cost) if k.locked else ""
		t.body.modulate = LOCKED if k.locked else Color.WHITE
		t.button.self_modulate = UI.GOLD if k.on else Color.WHITE
	_show(shown)


func _show(id: String) -> void:
	if id not in tiles:
		return
	shown = id
	var t: Dictionary = tiles[id]
	var k: Dictionary = look.call(id)
	t.button.button_pressed = true  # through the group, so the last one shown lets go
	for c in art_box.get_children():
		c.queue_free()
	var holder := VBoxContainer.new()  # art() adds to a box, as on the tile
	art_box.add_child(holder)
	t.art.call(holder, 2)
	title.text = t.caption
	state.text = k.state
	state.add_theme_color_override("font_color", UI.GOLD if k.on else UI.QUIET if not k.locked else Color(1, 0.6, 0.3))
	text.text = k.text


func _click(id: String) -> void:
	_show(id)
	press.call(id)


## Puts `why` in red on the panel's state line, until the next tile is shown.
func warn(why: String) -> void:
	state.text = why
	state.add_theme_color_override("font_color", UI.DANGER)


## A perk's badge, for add()'s `art`.
static func badge(id: String) -> Callable:
	return func(parent: Node, s: int): UI.image(parent, "perk_" + id, Vector2(54, 54) * s)


## The dice a skill needs (Combat.SKILLS dice), as bone dice, for add()'s `art`.
static func dice(id: String) -> Callable:
	return func(parent: Node, s: int) -> void:
		var r := UI.row(parent, 4 * s)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		for face: String in Combat.SKILLS[id].dice:
			var l := UI.label(UI.image(r, "die_bone", Vector2(28, 28) * s), 16 * s, face)
			l.add_theme_color_override("font_color", Color(0.22, 0.17, 0.12))
