class_name SettingsPanel
extends Overlay
## Settings, opened over whatever screen is up: the sound controls.

var meta: Meta


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
	button("Close  [Esc]", close)
