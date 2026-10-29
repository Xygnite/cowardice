class_name SettingsPanel
extends Overlay
## Settings, opened over whatever screen is up: the sound controls and dice control.

var meta: Meta
var dice_button: Button
var dice_hint: Label


## Opens the panel over `screen`, which keeps running underneath.
static func open(screen: Control, m: Meta) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.meta = m
	screen.add_child(p)
	return p


func _build() -> void:
	heading("Settings")
	var sound := SoundControls.new()
	sound.meta = meta
	body.add_child(sound)
	dice_button = button("", _on_dice)
	dice_hint = UI.label(body, 16)
	dice_hint.add_theme_color_override("font_color", UI.QUIET)
	_show_dice()
	button("Close  [Esc]", close)


func _on_dice() -> void:
	meta.quick_dice = not meta.quick_dice
	meta.save()
	_show_dice()


func _show_dice() -> void:
	dice_button.text = "Dice control: " + ("Quick" if meta.quick_dice else "Menu")
	dice_hint.text = "Click a die: next slot. Right-click: back.\nHold it: lock or unlock." if meta.quick_dice else "Click a die for its menu."
