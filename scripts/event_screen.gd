class_name EventScreen
extends Control
## A "?" room: an event from Events with its choices, and a dice tray for the choices that throw dice.
## Emits `finished` with the resolved result (see Events.resolve) once the player goes on.

signal finished(result: Dictionary)

const TRAY_SIZE := Vector2(640, 200)
const TRAY_INSET := 6  # as combat_screen.gd: the felt tucks under the frame's border
const SKULL_FACES := [1, 2, 3, 4, 5, 6]

var combat: Combat
var id: String
var text: Label
var choice_row: HBoxContainer
var tray: DiceTray
var busy := false  # dice are in the air
var picking := -1  # the one-die choice waiting for a die to be clicked
var tries := 0


func _ready() -> void:
	var root := UI.page(self)
	var art := "event_" + id  # each event's own still; the campfire if one is missing
	UI.backdrop(self, art if ResourceLoader.exists("res://assets/ui/bg_%s.webp" % art) else "campfire")
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var event: Dictionary = Events.EVENTS[id]
	_centered(UI.heading(root, 48, event.title))
	text = _centered(UI.label(root, 20, event.text))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_row = UI.row(root, 24)
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if event.choices.any(func(c): return c.dice > 0):
		_build_tray(root)
	_show_choices()


func _build_tray(parent: Node) -> void:
	var box := Control.new()
	var count := combat.dice.size() + (3 if id == "gambler" else 0)
	# Wide enough for the dice's starting row, the skull's included.
	box.custom_minimum_size = Vector2(maxf(TRAY_SIZE.x, count * DiceTray.SPACING * DiceTray.UNIT + TRAY_INSET * 2), TRAY_SIZE.y)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(box)
	tray = DiceTray.new()
	tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, TRAY_INSET)
	tray.die_clicked.connect(_on_die_clicked)
	box.add_child(tray)
	var frame := Panel.new()  # the frame over the felt's edge, as in the combat tray
	var outline: StyleBoxTexture = frame.get_theme_stylebox("panel").duplicate()
	outline.texture = load(UI.ART % "panel_frame")
	frame.add_theme_stylebox_override("panel", outline)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(frame)
	for i in combat.dice.size():
		tray.add_die()
		_show_die(i)
	if id == "gambler":
		for k in 3:  # the skull's own dice, in the locked art so they read as not yours
			tray.add_die()
			tray.show_die(combat.dice.size() + k, SKULL_FACES, 1, "locked", "", false)


## What a choice button or a die click calls. `die` is the die thrown for a one-die choice.
func choose(choice: int, die := 0) -> void:
	picking = -1
	_clear_choices()
	var which: Array = []
	match int(Events.EVENTS[id].choices[choice].dice):
		1:
			which = [die]
		3:
			which = range(combat.dice.size())
	var rolled: Array = combat.roll_dice(which)
	if which:
		for i in which:
			_show_die(i)
		var thrown := which.duplicate()
		if id == "gambler":
			for k in 3:
				var v := combat.rng.randi_range(1, 6)
				rolled.append(v)
				tray.show_die(combat.dice.size() + k, SKULL_FACES, v, "locked", "", false)
				thrown.append(combat.dice.size() + k)
		busy = true
		tray.throw(thrown)
		await tray.landed
		busy = false
	tries += 1
	var result: Dictionary = Events.resolve(id, choice, combat, rolled, tries)
	text.text = result.text
	if result.get("retry", false):
		_show_choices()
	else:
		UI.button(choice_row, "Go on", finished.emit.bind(result)).custom_minimum_size = Vector2(240, 48)


func _show_choices() -> void:
	var choices: Array = Events.EVENTS[id].choices
	for c in choices.size():
		var b := UI.button(choice_row, choices[c].label, _on_choice.bind(c))
		b.custom_minimum_size = Vector2(240, 48)
		b.disabled = not Events.can_choose(id, c, combat)


func _on_choice(c: int) -> void:
	if Events.EVENTS[id].choices[c].dice == 1:
		_clear_choices()
		text.text = "Pick a die to throw."
		picking = c
	else:
		choose(c)


func _on_die_clicked(i: int) -> void:
	if picking >= 0 and i < combat.dice.size():
		choose(picking, i)


func _clear_choices() -> void:
	for b in choice_row.get_children():
		choice_row.remove_child(b)
		b.queue_free()


func _show_die(i: int) -> void:
	var d: Dictionary = combat.dice[i]
	tray.show_die(i, d.faces, d.value, "cursed" if d.value == Combat.CURSE else "bone", "", false)


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
