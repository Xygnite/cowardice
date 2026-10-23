class_name NoticeScreen
extends Control
## A title, a few lines and a row of choices. Used for the campfire and the end-of-run tally.

var title := ""
var lines: Array = []
var highlight := -1  # index of the line to show in gold
var choices: Array = []  # [button text, Callable]
var backdrop := ""  # picture behind it, assets/ui/bg_<backdrop>.webp; none if empty


func _ready() -> void:
	var root := UI.page(self)
	if backdrop:
		UI.backdrop(self, backdrop)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	_centered(UI.heading(root, 48, title))
	for i in lines.size():
		var l := _centered(UI.label(root, 20, lines[i]))
		if i == highlight:
			l.add_theme_color_override("font_color", UI.GOLD)
	var r := UI.row(root, 24)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in choices:
		UI.button(r, c[0], c[1]).custom_minimum_size = Vector2(240, 48)


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
