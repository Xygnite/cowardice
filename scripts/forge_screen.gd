class_name ForgeScreen
extends Control
## Raise die faces for the rest of the run: paid in Shards at the Forge, one free upgrade at the Campfire.
## In carve mode (an event's reward) one face becomes a 9 and another is cursed.

signal done

const BONE_INK := Color(0.16, 0.13, 0.1)  # numbers on a bone die face, as in the dice tray

var combat: Combat
var no_cost := false
var carve := false
var info: Label
var face_buttons: Array = []  # per die, its 6 face buttons
var normal: StyleBoxTexture  # a face's look at rest, and a cursed face's
var cursed: StyleBoxTexture


func _ready() -> void:
	var root := UI.page(self)
	UI.backdrop(self, "campfire" if no_cost and not carve else "forge")
	root.alignment = BoxContainer.ALIGNMENT_CENTER  # over the forge's workbench
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)
	UI.heading(column, 32, "Carve a 9" if carve else ("Campfire: tend the dice" if no_cost else "Forge"))
	info = UI.label(column, 20)
	var face := {}  # one die face per button state, in the dice's flat art
	for state in [["normal", "bone"], ["hover", "locked"], ["pressed", "placed"], ["hover_pressed", "placed"], ["disabled", "empty"], ["cursed", "cursed"]]:
		var s := StyleBoxTexture.new()
		s.texture = load(UI.ART % ("die_" + state[1]))
		s.set_texture_margin_all(6)  # the die art's 3-pixel border, at 2x
		face[state[0]] = s
	normal = face.normal
	cursed = face.cursed
	face.erase("cursed")
	for i in combat.dice.size():
		var r := UI.row(column, 8)
		UI.label(r, 18, "Die %d   " % (i + 1)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var buttons := []
		for f in 6:
			var b := UI.button(r, "", _on_face.bind(i, f))
			b.custom_minimum_size = Vector2(64, 64)
			for state in face:
				b.add_theme_stylebox_override(state, face[state])
			b.add_theme_font_size_override("font_size", 32)
			b.add_theme_color_override("font_color", BONE_INK)  # dark on the bone face, light on the dark ones
			for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(state, Color.WHITE)
			buttons.append(b)
		face_buttons.append(buttons)
	UI.button(column, "Leave", done.emit)
	_refresh()


func _on_face(i: int, f: int) -> void:
	if carve:
		combat.carve(i, f)
		done.emit()
		return
	if not combat.forge(i, f, no_cost):
		return
	if no_cost:
		done.emit()  # the campfire gives exactly one
	else:
		_refresh()


func _refresh() -> void:
	if carve:
		info.text = "Pick a face to become a 9. Another face on that die is cursed."
	elif no_cost:
		info.text = "One free upgrade: +%d to a face" % Combat.FORGE_STEP
	else:
		info.text = "Shards %d   +%d to a face for %d Shards" % [combat.shards, Combat.FORGE_STEP, Combat.FORGE_COST]
	for i in face_buttons.size():
		for f in 6:
			var b: Button = face_buttons[i][f]
			var face: int = combat.dice[i].base[f]
			b.text = str(face)
			b.add_theme_stylebox_override("normal", cursed if face == Combat.CURSE else normal)
			b.add_theme_color_override("font_color", Color.WHITE if face == Combat.CURSE else BONE_INK)
			b.disabled = not (no_cost or carve) and combat.shards < Combat.FORGE_COST
