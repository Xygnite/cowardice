class_name UI
## Placeholder-art building blocks shared by every screen.

const DANGER := Color(1, 0.45, 0.4)
const GOLD := Color(1, 0.85, 0.4)
const QUIET := Color(0.6, 0.62, 0.7)
## Number colour of a face carrying each Combat.MARKS mark, on every die art.
const MARK_COLORS := {"sharp": Color(0.9, 0.22, 0.18), "ember": Color(1, 0.55, 0.1), "ward": Color(0.25, 0.55, 1), "shard": Color(0.72, 0.35, 0.95)}
## Body text is m6x11, the theme default (assets/ui_theme.tres); titles use this.
const HEADING_FONT := preload("res://assets/fonts/alagard.ttf")
const ART := "res://assets/ui/cut/%s.png"


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


## Covers a screen made by page() with the picture assets/ui/bg_<art>.webp, behind its content.
static func backdrop(screen: Control, art: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/ui/bg_%s.webp" % art)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(r)
	screen.move_child(r, 1)  # over the page's flat colour, under its content
	BackdropLife.attach(r, art)
	return r


static func label(parent: Node, font_size: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	# Pixel fonts only stay crisp at whole multiples of their 16 px design size.
	l.add_theme_font_size_override("font_size", maxi(1, roundi(font_size / 16.0)) * 16)
	if parent is TextureRect:
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


## A piece of UI art from assets/ui/cut/ (made by tools/make_ui.gd), stretched to `min_size` if given.
## A label added to it is centred.
static func image(parent: Node, art: String, min_size := Vector2.ZERO) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(ART % art)
	if min_size != Vector2.ZERO:
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.custom_minimum_size = min_size
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(r)
	return r


## A framed health bar (styled by the theme).
static func hp_bar(parent: Node, width: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b


static func button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space/Enter for the game, not button focus
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## A framed panel (assets/ui/cut/panel.png via the theme); returns the column inside it.
static func panel(parent: Node, separation := 8) -> VBoxContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", separation)
	p.add_child(col)
	return col


static func spacer(parent: Node) -> void:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)


static func row(parent: Node, separation := 16) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", separation)
	parent.add_child(r)
	return r
