class_name PerkPickScreen
extends Control
## The Warden's gift: pick one of three perks to carry down into the Mine, for this run only.

signal picked(id: String)

var choices: Array = []  # three Meta.PERKS ids, from offer()


## Three different perks, owned or not, none of them in `exclude` (the ones already on).
static func offer(exclude: Array) -> Array:
	var pool: Array = Meta.PERKS.keys().filter(func(id): return id not in exclude)
	pool.shuffle()
	return pool.slice(0, 3)


func _ready() -> void:
	var root := UI.page(self)
	UI.backdrop(self, "campfire")
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.heading(root, 48, "The Bone Warden falls.").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.label(root, 20, "Something of his is yours for the way down. Take one, for this run only.").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := UI.row(root, 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in choices:  # the camp's perk card, with a Take button
		var p: Dictionary = Meta.PERKS[id]
		var col := UI.panel(row)
		col.custom_minimum_size = Vector2(260, 0)
		var title := UI.row(col, 10)
		UI.image(title, "perk_" + id)
		UI.label(title, 22, p.name).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var text := UI.label(col, 16, p.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.y = text.get_line_height() * 2 + text.get_theme_constant("line_spacing")
		text.add_theme_color_override("font_color", UI.QUIET)
		UI.button(col, "Take", picked.emit.bind(id)).custom_minimum_size.y = 48
