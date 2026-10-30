class_name RelicIcon
extends Control
## One belt relic: its 4-frame strip playing, bobbing in its slot's own phase, with its tooltip, a growing-value label
## and a fire() flourish. Drags and drops go through the BeltRow it sits in.

const FPS := 6.0
const FRAMES := 4
const BOB := 1.5  # pixels up and down
const FIRE_TIME := 0.25
const SLIDE_SPEED := 300.0  # pixels per second
const DRAGGED_ALPHA := 0.3

var k := 0
var value_label: Label  # a growing relic's current worth, gold, hanging off the bottom-right corner
var relic := ""
var big := false  # the 64x64 still of a shop card, rather than the 32x32 animated strip
var slide_x := 0.0  # how far the art has slid sideways, to open a gap in a drag-over
var _slide_to := 0.0
var _art: TextureRect  # what moves; the Control itself stays where its container put it
var _frame: AtlasTexture
var _time := 0.0
var _fire := 1.0  # 0..1 through a fire(), 1 at rest
var _tween: Tween


## Relic `id`'s icon off the belt (a shop card), not yet in a parent; its tooltip names the relic and its text.
## `big` is the large still.
static func of(id: String, big := false) -> RelicIcon:
	var icon := RelicIcon.new()
	icon.relic = id
	icon.big = big
	icon.tooltip_text = "%s\n%s" % [Combat.RELICS[id].name, Combat.RELICS[id].text]
	icon._build()  # here, not in _ready, so value_label exists before the icon is in the tree
	return icon


## Belt slot k's icon, not yet in a parent; a Mirror Shard's tooltip also says what it copies.
static func make(combat: Combat, k: int) -> RelicIcon:
	var icon := of(combat.relics[k].id)
	icon.k = k
	if icon.relic == "mirror_shard":
		var copy := combat.relic_id(k)
		icon.tooltip_text += "\nCopying: " + (Combat.RELICS[copy].name if copy else "nothing")
	return icon


func _build() -> void:
	var still: Texture2D = load(UI.ART % ("relic_" + relic + ("_big" if big else "")))
	custom_minimum_size = still.get_size()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_art = TextureRect.new()
	if big:
		_art.texture = still
	else:
		_frame = AtlasTexture.new()
		_frame.atlas = load(UI.ART % ("relic_%s_anim" % relic))
		_frame.region = Rect2(Vector2.ZERO, still.get_size())
		_art.texture = _frame
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.pivot_offset = still.get_size() / 2
	add_child(_art)
	value_label = UI.label(self, 16)
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	value_label.offset_bottom = 8  # hangs a little under the icon, clear of its glyph
	value_label.offset_right = 6
	value_label.add_theme_color_override("font_color", UI.GOLD)
	value_label.add_theme_constant_override("outline_size", 6)
	value_label.add_theme_color_override("font_outline_color", Color("070e10"))


func _process(delta: float) -> void:
	_time += delta
	slide_x = move_toward(slide_x, _slide_to, SLIDE_SPEED * delta)
	if _frame:
		_frame.region.position.x = (int(_time * FPS) % FRAMES) * _frame.region.size.x
	var bob := roundf(sin(_time * 2.5 + k * 0.7) * BOB)
	_art.position = Vector2(slide_x + sin(_fire * TAU * 3) * 3 * (1 - _fire), bob - sin(_fire * PI) * 8)
	_art.rotation = sin(_fire * TAU * 3) * 0.12 * (1 - _fire)


## A bounce up and a quick shake, for when this relic adds to the turn.
func fire() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void: _fire = t, 0.0, 1.0, FIRE_TIME)


## Slides the art to x (0 to come back), e.g. out of the way of a relic being dragged over.
func slide(x: float) -> void:
	_slide_to = x


## Back to normal after a drag: in place and fully shown.
func rest() -> void:
	_slide_to = 0.0
	modulate.a = 1.0


## The belt row this icon sits in, or null (a lone icon neither drags nor takes drops).
func _row() -> BeltRow:
	var p := get_parent()
	while p and not p is BeltRow:
		p = p.get_parent()
	return p


func _get_drag_data(_at: Vector2) -> Variant:
	var row := _row()
	if row == null or not row.can_drag.call():
		return null
	modulate.a = DRAGGED_ALPHA  # the relic lifts: this slot stays, dimmed, until the drag ends
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # a real drag; the tests call this with no mouse down
		var lift := Control.new()  # the preview's origin is the cursor
		var art := TextureRect.new()
		art.texture = load(UI.ART % ("relic_" + relic))
		art.scale = Vector2(1.25, 1.25)
		art.rotation = 0.15
		art.position = -art.texture.get_size() * 0.625
		art.pivot_offset = art.texture.get_size() / 2
		lift.add_child(art)
		set_drag_preview(lift)
	return {"belt_k": k}


# An icon is in the way of its row, so it passes drops on, with the position in the row's terms.
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var row := _row()
	return row != null and row._can_drop_data(_in_row(row, at), data)


func _drop_data(at: Vector2, data: Variant) -> void:
	var row := _row()
	row._drop_data(_in_row(row, at), data)


func _in_row(row: BeltRow, at: Vector2) -> Vector2:
	return row.get_global_transform().affine_inverse() * (get_global_transform() * at)
