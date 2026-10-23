class_name CampScreen
extends Control
## The perk board: unlock perks with Embers, equip up to Meta.SLOTS of them, start a run.

signal start_run
signal main_menu

var meta: Meta
var embers_label: Label
var loadout_label: Label
var cards := {}  # perk id -> {state: Label, button: Button}


func _ready() -> void:
	var root := UI.page(self)
	UI.backdrop(self, "camp")
	var top := UI.row(root)
	UI.image(top, "logo")
	UI.spacer(top)
	# In the logo's row rather than its own, so ten perk cards still leave the bottom buttons their margin.
	UI.heading(top, 32, "Camp: perk board").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.spacer(top)
	var side := UI.panel(top)  # the Embers purse, framed like the perk cards
	side.get_parent().size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var purse := UI.row(side, 8)
	UI.image(purse, "icon_ember")
	embers_label = UI.heading(purse, 32)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	for id in Meta.PERKS:
		var p: Dictionary = Meta.PERKS[id]
		var col := UI.panel(grid)
		col.custom_minimum_size = Vector2(180, 0)  # five columns plus the panel frames fit 1280
		col.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.get_parent().size_flags_vertical = Control.SIZE_FILL
		var title := UI.row(col, 10)
		UI.image(title, "perk_" + id)  # assets/ui/cut/perk_<id>.png, from tools/make_ui.gd or tools/make_perk_badges.gd
		UI.label(title, 22, p.name).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var text := UI.label(col, 16, p.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.y = text.get_line_height() * 2 + text.get_theme_constant("line_spacing")  # room for two lines on every card, so costs and buttons line up
		text.add_theme_color_override("font_color", UI.QUIET)
		var state := UI.label(col, 16)
		var b := UI.button(col, "", _on_card.bind(id))
		cards[id] = {"state": state, "button": b}
	loadout_label = UI.label(root, 20)
	var bottom := UI.row(root)
	UI.button(bottom, "Main menu", main_menu.emit).custom_minimum_size = Vector2(200, 48)
	UI.button(bottom, "Settings", SettingsPanel.open.bind(self, meta)).custom_minimum_size = Vector2(200, 48)
	var start := UI.button(bottom, "Start run", start_run.emit)
	start.custom_minimum_size = Vector2(240, 48)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh()


func _on_card(id: String) -> void:
	if id in meta.owned:
		meta.toggle_equip(id)
	else:
		meta.unlock(id)
	meta.save()
	_refresh()


func _refresh() -> void:
	embers_label.text = "Embers %d" % meta.embers
	for id in cards:
		var c: Dictionary = cards[id]
		if id in meta.equipped:
			c.state.text = "Equipped"
			c.button.text = "Unequip"
			c.button.disabled = false
		elif id in meta.owned:
			c.state.text = "Owned"
			c.button.text = "Equip"
			c.button.disabled = meta.equipped.size() >= Meta.SLOTS
		else:
			c.state.text = "%d Embers" % Meta.PERKS[id].cost
			c.button.text = "Unlock"
			c.button.disabled = meta.embers < Meta.PERKS[id].cost
	var names := meta.equipped.map(func(id): return Meta.PERKS[id].name)
	loadout_label.text = "Loadout %d/%d: %s" % [meta.equipped.size(), Meta.SLOTS, ", ".join(names) if names else "empty"]
