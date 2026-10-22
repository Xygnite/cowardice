class_name UI
## Placeholder-art building blocks shared by every screen.

const DANGER := Color(1, 0.45, 0.4)
const GOLD := Color(1, 0.85, 0.4)
const QUIET := Color(0.6, 0.62, 0.7)
## Body text is m6x11, the theme default (assets/ui_theme.tres); titles use this.
const HEADING_FONT := preload("res://assets/fonts/alagard.ttf")


## Fills `screen` with the dark background and a padded column; returns the column.
static func page(screen: Control) -> VBoxContainer:
	# Anchors AND offsets: a screen is added at size 0, so anchors alone would leave it shrunk to its content.
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	screen.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	return root


static func label(parent: Node, font_size: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	# Pixel fonts only stay crisp at whole multiples of their 16 px design size.
	l.add_theme_font_size_override("font_size", maxi(1, roundi(font_size / 16.0)) * 16)
	if parent is ColorRect:
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## A title in the gothic heading font.
static func heading(parent: Node, font_size: int, text := "") -> Label:
	var l := label(parent, font_size, text)
	l.add_theme_font_override("font", HEADING_FONT)
	return l


static func box(parent: Node, color: Color, min_size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = min_size
	parent.add_child(r)
	return r


static func button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space/Enter for the game, not button focus
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


static func spacer(parent: Node) -> void:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)


static func row(parent: Node, separation := 16) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", separation)
	parent.add_child(r)
	return r
