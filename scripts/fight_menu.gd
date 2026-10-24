class_name FightMenu
extends Overlay
## The fight's menu (its Menu button or Esc): resume, settings, or give up the run for the main menu.

signal quit

var meta: Meta


func _build() -> void:
	heading("Paused")
	button("Resume  [Esc]", close)
	button("Settings", func() -> void: SettingsPanel.open(get_parent(), meta))
	button("Quit to main menu", _ask_quit)


func _ask_quit() -> void:
	var c := ConfirmPanel.new()
	c.title = "Quit this run?"
	c.text = "The run ends here: no Embers, and any saved run is lost."
	c.yes = "Quit to main menu"
	c.confirmed.connect(quit.emit)
	get_parent().add_child(c)
