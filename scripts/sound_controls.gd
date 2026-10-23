class_name SoundControls
extends VBoxContainer
## Music and sound sliders and a mute button, kept in Meta's save. The M key (game.gd) mutes from anywhere.

const GAP := 12  # between every row here; SettingsPanel uses the same, so the panel spaces evenly
const ROW_HEIGHT := 48  # slider rows and buttons alike

var meta: Meta
var sliders := {}  # Meta field ("music" or "sounds") -> its HSlider
var mute_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	for s in [["music", "Music"], ["sounds", "Sounds"]]:
		var r := UI.row(self, GAP)
		r.custom_minimum_size.y = ROW_HEIGHT
		UI.label(r, 16, s[1]).custom_minimum_size.x = 80
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.x = 160
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # out to the buttons' right edge
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE  # keep the keys for the game, as buttons do
		_style(slider)
		slider.value_changed.connect(_on_slider.bind(s[0]))
		r.add_child(slider)
		sliders[s[0]] = slider
	mute_button = UI.button(self, "", _on_mute)
	mute_button.custom_minimum_size.y = ROW_HEIGHT
	meta.sound_changed.connect(_refresh)
	_refresh()


## A dark groove that fills gold up to a square gold handle, in place of Godot's default slider.
static func _style(slider: HSlider) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("0c0f15")
	groove.border_color = Color("3a4250")
	groove.set_border_width_all(2)
	groove.content_margin_top = 4
	groove.content_margin_bottom = 4
	var filled := StyleBoxFlat.new()
	filled.bg_color = UI.GOLD.darkened(0.35)
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var handle := Image.create_empty(8, 16, false, Image.FORMAT_RGBA8)
	handle.fill(Color("070e10"))
	handle.fill_rect(Rect2i(2, 2, 4, 12), UI.GOLD)
	var tex := ImageTexture.create_from_image(handle)
	slider.add_theme_icon_override("grabber", tex)
	slider.add_theme_icon_override("grabber_highlight", tex)


func _on_slider(value: float, field: String) -> void:
	meta.set(field, value)
	meta.apply_sound()
	meta.save()


func _on_mute() -> void:
	meta.muted = not meta.muted
	meta.apply_sound()
	meta.save()


func _refresh() -> void:
	for field in sliders:
		sliders[field].set_value_no_signal(meta.get(field))
	mute_button.text = ("Unmute" if meta.muted else "Mute") + "  [M]"
