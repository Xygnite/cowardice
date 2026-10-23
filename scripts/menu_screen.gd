class_name MenuScreen
extends Control
## The title screen: the logo over a column of choices.

signal play
signal tutorial

var tutorial_done := false
var meta: Meta  # for the sound controls


func _ready() -> void:
	var root := UI.page(self)
	UI.backdrop(self, "menu")
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var logo := UI.image(root, "logo")
	logo.custom_minimum_size = logo.texture.get_size() * 2  # a whole multiple keeps its pixels square
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choices.add_theme_constant_override("separation", 12)
	root.add_child(choices)
	UI.button(choices, "Play", play.emit).custom_minimum_size = Vector2(280, 48)
	if tutorial_done:  # the first Play is the tutorial anyway
		UI.button(choices, "Tutorial", tutorial.emit).custom_minimum_size = Vector2(280, 48)
	UI.button(choices, "Settings", SettingsPanel.open.bind(self, meta)).custom_minimum_size = Vector2(280, 48)
	UI.button(choices, "Quit", get_tree().quit).custom_minimum_size = Vector2(280, 48)
