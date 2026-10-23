class_name SoundControls
extends VBoxContainer
## Music and sound sliders and a mute button, kept in Meta's save. The M key (game.gd) mutes from anywhere.

var meta: Meta
var sliders := {}  # Meta field ("music" or "sounds") -> its HSlider
var mute_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for s in [["music", "Music"], ["sounds", "Sounds"]]:
		var r := UI.row(self, 12)
		UI.label(r, 16, s[1]).custom_minimum_size.x = 80
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.x = 160
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE  # keep the keys for the game, as buttons do
		slider.value_changed.connect(_on_slider.bind(s[0]))
		r.add_child(slider)
		sliders[s[0]] = slider
	mute_button = UI.button(self, "", _on_mute)
	meta.sound_changed.connect(_refresh)
	_refresh()


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
