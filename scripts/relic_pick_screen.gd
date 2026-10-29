class_name RelicPickScreen
extends Control
## Spoils: take one of three relics onto the belt for this run, or skip them for Shards. The belt can be reordered here,
## and taking onto a full belt breaks the relic you choose. Every way out asks first, then emits done.

signal done

const SKIP_SHARDS := 3
const RARE_CHANCE := 1.0 / 6.0

var combat: Combat
var choices: Array = []  # up to three Combat.RELICS ids, from offer()
var rares := false  # a rare pick: the Warden's hoard or a Mine start
var title := "Spoils"
var breaking := ""  # the card being taken onto a full belt, waiting for which belt relic to break
var belt_row: HBoxContainer


## Up to three different relics not on `belt`. A rare pick deals only rares; otherwise each card is rare
## with RARE_CHANCE, from the other pool when one runs dry.
static func offer(belt: Array, rares: bool, rng: RandomNumberGenerator) -> Array:
	var owned: Array = belt.map(func(r): return r.id)
	var pools := [[], []]  # commons, rares
	for id: String in Combat.RELICS:
		if id not in owned:
			pools[int(Combat.RELICS[id].rare)].append(id)
	var out := []
	for i in 3:
		var k := 1 if rares or rng.randf() < RARE_CHANCE else 0
		if pools[k].is_empty() and not rares:
			k = 1 - k
		if pools[k].is_empty():
			break
		out.append(pools[k].pop_at(rng.randi_range(0, pools[k].size() - 1)))
	return out


func _ready() -> void:
	var root := UI.page(self)
	UI.backdrop(self, "campfire")
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.heading(root, 48, title).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.label(root, 20, "Take one for the belt, for this run only, or leave them for +%d Shards." % SKIP_SHARDS).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := UI.row(root, 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id: String in choices:  # the perk pick's card, with a relic icon
		var r: Dictionary = Combat.RELICS[id]
		var col := UI.panel(row)
		col.custom_minimum_size = Vector2(260, 0)
		var head := UI.row(col, 10)
		UI.image(head, "relic_" + id).tooltip_text = "%s\n%s" % [r.name, r.text]
		UI.label(head, 22, r.name).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if r.rare:
			UI.label(col, 16, "Rare").add_theme_color_override("font_color", UI.GOLD)
		var text := UI.label(col, 16, r.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.y = text.get_line_height() * 3 + text.get_theme_constant("line_spacing") * 2
		text.add_theme_color_override("font_color", UI.QUIET)
		UI.button(col, "Take", _take.bind(id)).custom_minimum_size.y = 48
	var skip := UI.button(root, "Skip", func(): ConfirmPanel.ask(self, "Skip the relics?", "+%d Shards instead. All of them are left behind." % SKIP_SHARDS, "Skip", _skip))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.label(root, 20, "Your belt").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	belt_row = UI.row(root, 12)
	belt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_show_belt()


## The belt, left to right: each relic with a move-left button, and a Break button while a card waits for room.
func _show_belt() -> void:
	for c in belt_row.get_children():
		belt_row.remove_child(c)  # now, so a lookup straight after sees only the new row
		c.queue_free()
	if combat.relics.is_empty():
		UI.label(belt_row, 16, "Empty").add_theme_color_override("font_color", UI.QUIET)
	for k in combat.relics.size():
		var col := UI.panel(belt_row, 4)
		belt_icon(col, combat, k)
		if k > 0:
			UI.button(col, "<", _move_left.bind(k))
		if breaking != "":
			UI.button(col, "Break", _ask_break.bind(k))


## Belt slot k's icon, its name and text on hover; a Mirror Shard also names what it copies.
static func belt_icon(parent: Node, combat: Combat, k: int) -> TextureRect:
	var id: String = combat.relics[k].id
	var r: Dictionary = Combat.RELICS[id]
	var icon := UI.image(parent, "relic_" + id)
	icon.tooltip_text = "%s\n%s" % [r.name, r.text]
	if id == "mirror_shard":
		var copy := combat.relic_id(k)
		icon.tooltip_text += "\nCopying: " + (Combat.RELICS[copy].name if copy else "nothing")
	return icon


func _take(id: String) -> void:
	if combat.relics.size() < Combat.BELT_SIZE:
		ConfirmPanel.ask(self, "Take %s?" % Combat.RELICS[id].name, "For this run only. The others are left behind.", "Take it", _taken.bind(id, -1))
	else:  # full: first choose which belt relic to break
		breaking = id
		_show_belt()


func _ask_break(k: int) -> void:
	var old: String = Combat.RELICS[combat.relics[k].id].name
	ConfirmPanel.ask(self, "Break %s?" % old, "Break %s for +%d Shards and take %s?" % [old, Combat.BREAK_SHARDS, Combat.RELICS[breaking].name], "Break it", _taken.bind(breaking, k))


func _move_left(k: int) -> void:
	combat.move_relic(k, k - 1)
	_show_belt()


func _taken(id: String, replace: int) -> void:
	combat.take_relic(id, replace)
	done.emit()


func _skip() -> void:
	combat.shards += SKIP_SHARDS
	done.emit()
