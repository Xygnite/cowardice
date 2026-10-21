class_name CampScreen
extends Control
## The perk board: unlock perks with Embers, equip up to Meta.SLOTS of them, start a run.

signal start_run

var meta: Meta
var embers_label: Label
var loadout_label: Label
var cards := {}  # perk id -> {state: Label, button: Button}


func _ready() -> void:
	var root := UI.page(self)
	var top := UI.row(root)
	UI.label(top, 28, "Camp: perk board")
	UI.spacer(top)
	embers_label = UI.label(top, 22)
	var grid := UI.row(root, 24)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for id in Meta.PERKS:
		var p: Dictionary = Meta.PERKS[id]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(300, 0)
		col.add_theme_constant_override("separation", 8)
		grid.add_child(col)
		UI.label(col, 22, p.name)
		var text := UI.label(col, 16, p.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_color_override("font_color", UI.QUIET)
		var state := UI.label(col, 16)
		var b := UI.button(col, "", _on_card.bind(id))
		cards[id] = {"state": state, "button": b}
	loadout_label = UI.label(root, 20)
	UI.button(root, "Start run", start_run.emit).custom_minimum_size = Vector2(240, 48)
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
