class_name CampScreen
extends Control
## The camp board: skills and perks as tiles (TileBoard). Unlock them with Embers (skills for good: every unlocked one
## fires when the Skill dice fit), equip up to Meta.SLOTS perks for the next run, start a run (in the Mine too, once unlocked).

signal start_run(floor_id: String)
signal main_menu

var meta: Meta
var embers_label: Label
var loadout: HBoxContainer
var board: TileBoard


func _ready() -> void:
	var root := UI.page(self)
	UI.backdrop(self, "camp")
	var top := UI.row(root)
	UI.image(top, "logo")
	UI.spacer(top)
	loadout = UI.row(top, 12)  # the next run's perk slots, filled by _refresh()
	loadout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.spacer(top)
	var side := UI.panel(top)  # the Embers purse
	side.get_parent().size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var purse := UI.row(side, 8)
	UI.image(purse, "icon_ember")
	embers_label = UI.heading(purse, 32)
	board = TileBoard.new()
	board.look = _look
	board.press = _on_tile
	root.add_child(board)
	var skills := board.section("Skills: every unlocked one fires when its dice fit")
	for id in Combat.SKILLS:
		board.add(skills, id, Combat.SKILLS[id].name, TileBoard.dice(id))
	var perks := board.section("Perks: equip %d" % Meta.SLOTS)
	for id in Meta.PERKS:
		board.add(perks, id, Meta.PERKS[id].name, TileBoard.badge(id))
	board.shown = "cleave"
	var bottom := UI.row(root)
	UI.button(bottom, "Main menu", main_menu.emit).custom_minimum_size = Vector2(200, 48)
	UI.button(bottom, "Settings", SettingsPanel.open.bind(self, meta)).custom_minimum_size = Vector2(200, 48)
	var start := UI.button(bottom, "Start run", _on_start)
	start.custom_minimum_size = Vector2(240, 48)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh()


## Straight into the Chapel until the Mine is unlocked; after that, a window to choose the floor.
func _on_start() -> void:
	if not meta.mine_unlocked:
		start_run.emit("chapel")
		return
	var pick := FloorPanel.new()
	pick.chosen.connect(start_run.emit)
	add_child(pick)


## What the board shows for skill or perk `id`: its state says what a click on it does.
func _look(id: String) -> Dictionary:
	var skill := id in Combat.SKILLS
	var k: Dictionary = Combat.SKILLS[id] if skill else Meta.PERKS[id]
	var owned: bool = id in (meta.skills if skill else meta.owned)
	var on: bool = owned if skill else id in meta.equipped  # an unlocked skill is always in play
	var state := "Owned. Click to equip."
	if not owned:
		state = "Locked: %d Embers. Click to unlock." % k.cost
	elif skill:
		state = "Unlocked. Fires whenever its dice fit."
	elif on:
		state = "Equipped. Click to unequip."
	return {"locked": not owned, "on": on, "cost": k.cost, "state": state,
		"text": "Needs: %s\n%s" % [k.need, k.text] if skill else k.text}


## A click: unlock (after a confirm), or equip or unequip a perk.
func _on_tile(id: String) -> void:
	var skill := id in Combat.SKILLS
	var k: Dictionary = Combat.SKILLS[id] if skill else Meta.PERKS[id]
	if id not in (meta.skills if skill else meta.owned):
		if meta.embers < k.cost:
			board.warn("Not enough Embers: %d of %d." % [meta.embers, k.cost])
			return
		ConfirmPanel.ask(self, "Unlock %s?" % k.name, "Spend %d of your %d Embers." % [k.cost, meta.embers], "Unlock", func() -> void:
			if skill:
				meta.unlock_skill(id)
			else:
				meta.unlock(id)
			meta.save()
			_refresh())
		return
	if skill:
		return  # unlocked for good; nothing to equip
	if id not in meta.equipped and meta.equipped.size() >= Meta.SLOTS:
		board.warn("Both perk slots are full. Unequip one first.")
		return
	meta.toggle_equip(id)
	meta.save()
	_refresh()


func _refresh() -> void:
	embers_label.text = "Embers %d" % meta.embers
	for c in loadout.get_children():
		c.queue_free()
	UI.label(loadout, 16, "Perks").add_theme_color_override("font_color", UI.QUIET)
	for i in Meta.SLOTS:
		if i < meta.equipped.size():
			_slot(TileBoard.badge(meta.equipped[i]), Meta.PERKS[meta.equipped[i]].name)
		else:
			_slot(Callable(), "empty")
	board.refresh()


## One loadout slot: its picture (none for an empty slot) and name.
func _slot(art: Callable, text: String) -> void:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loadout.add_child(col)
	if art.is_valid():
		art.call(col, 1)
	var l := UI.label(col, 16, text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not art.is_valid():
		l.add_theme_color_override("font_color", UI.QUIET)
