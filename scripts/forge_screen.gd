class_name ForgeScreen
extends Control
## Raise die faces for the rest of the run: paid in Shards at the Forge, one free upgrade at the Campfire.

signal done

var combat: Combat
var no_cost := false
var info: Label
var face_buttons: Array = []  # per die, its 6 face buttons


func _ready() -> void:
	var root := UI.page(self)
	UI.heading(root, 32, "Campfire: tend the dice" if no_cost else "Forge")
	info = UI.label(root, 20)
	for i in combat.dice.size():
		var r := UI.row(root, 8)
		UI.label(r, 18, "Die %d   " % (i + 1))
		var buttons := []
		for f in 6:
			var b := UI.button(r, "", _on_face.bind(i, f))
			b.custom_minimum_size = Vector2(64, 64)
			buttons.append(b)
		face_buttons.append(buttons)
	UI.button(root, "Leave", done.emit)
	_refresh()


func _on_face(i: int, f: int) -> void:
	if not combat.forge(i, f, no_cost):
		return
	if no_cost:
		done.emit()  # the campfire gives exactly one
	else:
		_refresh()


func _refresh() -> void:
	if no_cost:
		info.text = "One free upgrade: +%d to a face" % Combat.FORGE_STEP
	else:
		info.text = "Shards %d   +%d to a face for %d Shards" % [combat.shards, Combat.FORGE_STEP, Combat.FORGE_COST]
	for i in face_buttons.size():
		for f in 6:
			var b: Button = face_buttons[i][f]
			b.text = str(combat.dice[i].base[f])
			b.disabled = not no_cost and combat.shards < Combat.FORGE_COST
