class_name ForgeScreen
extends Control
## Raise die faces for the rest of the run. Every upgrade is thrown: Roll throws a die, Combat.FORGE_ROLL turns the face it
## lands on into an upgrade (+1, +4 or one of Combat.MARKS), and the next face clicked takes it. Rolls cost FORGE_COST
## Shards at the Forge; at a campfire or as an event's reward (no_cost) it's one free roll.
## In carve mode (an event's reward) one face becomes a 9 and another is cursed.

signal done

const BONE_INK := Color(0.16, 0.13, 0.1)  # numbers on a bone die face, as in the dice tray
const TRAY_SIZE := Vector2(360, 216)  # the roll's tray, beside the dice and as tall as their three rows
const TRAY_INSET := 6  # as combat_screen.gd: the felt tucks under the frame's border
const ROLL_FACES := [1, 2, 3, 4, 5, 6]
const ROLL_MARKS := ["", "sharp", "ember", "ward", "shard", ""]  # the roll die shows what each face grants:
const ROLL_TEXTS := ["+1", "", "", "", "", "+4"]  # a mark's glyph alone, or the raise

var combat: Combat
var no_cost := false
var carve := false
var info: Label
var face_buttons: Array = []  # per die, its 6 face buttons
var mark := ""  # the rolled upgrade a face click applies: "" for +`step`, else a Combat.MARKS key
var step := 0
var owed := false  # a paid roll's upgrade waits for a face; nothing else can be done until it lands somewhere
var busy := false  # the roll die is in the air
var tray: DiceTray
var roll_button: Button
var leave: Button
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
	var middle := UI.row(column, 24)  # the dice, and at the Forge the roll's tray beside them
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 12)
	middle.add_child(grid)
	for i in combat.dice.size():
		var r := UI.row(grid, 8)
		UI.label(r, 18, "Die %d   " % (i + 1)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var buttons := []
		for f in 6:
			var b := UI.button(r, "", _on_face.bind(i, f))
			b.custom_minimum_size = Vector2(64, 64)
			var glyph := TextureRect.new()  # the face's mark in its lower-left corner, as on the dice, so the number stays centred
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glyph.position = Vector2(7, 64 - 7 - 14)  # inside the die art's border; the glyph art is 16x14
			b.add_child(glyph)
			for state in face:
				b.add_theme_stylebox_override(state, face[state])
			b.add_theme_font_size_override("font_size", 32)
			b.add_theme_color_override("font_color", BONE_INK)  # dark on the bone face, light on the dark ones
			for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(state, Color.WHITE)
			buttons.append(b)
		face_buttons.append(buttons)
	var bottom := UI.row(column, 12)
	if not carve:
		_build_tray(middle)
		roll_button = UI.button(bottom, "Roll  (free)" if no_cost else "Roll  (%d Shards)" % Combat.FORGE_COST, _ask_roll)
		roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave = UI.button(bottom, "Leave", _on_leave)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh()


## The roll die's tray, framed like the event screen's, with what each of its faces grants under it.
func _build_tray(parent: Node) -> void:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	parent.add_child(side)
	var box := Control.new()
	box.custom_minimum_size = TRAY_SIZE
	side.add_child(box)
	tray = DiceTray.new()
	tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, TRAY_INSET)
	box.add_child(tray)
	var frame := Panel.new()
	var outline: StyleBoxTexture = frame.get_theme_stylebox("panel").duplicate()
	outline.texture = load(UI.ART % "panel_frame")
	frame.add_theme_stylebox_override("panel", outline)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(frame)
	tray.add_die()
	tray.show_die(0, ROLL_FACES, 6, "bone", "", false, false, ROLL_MARKS, ROLL_TEXTS)
	var odds := UI.label(side, 16, "The die:  " + ",  ".join(Combat.FORGE_ROLL.map(_upgrade_name)))
	odds.add_theme_color_override("font_color", UI.QUIET)
	odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _upgrade_name(u: Dictionary) -> String:
	return Combat.MARKS[u.mark].name if u.has("mark") else "+%d" % u.step


## Pays for a roll, throws the die, and readies what it lands on for the next face clicked.
## A paid throw asks first; a free one just goes.
func _ask_roll() -> void:
	if no_cost:
		_on_roll()
	elif not (busy or owed) and _can_pay():
		ConfirmPanel.ask(self, "Throw for %d Shards?" % Combat.FORGE_COST, "You have %d. Whatever the die lands on goes on a face you pick." % combat.shards, "Throw", _on_roll)


## A free upgrade left unthrown asks before it's walked away from.
func _on_leave() -> void:
	if no_cost and not carve and not owed and not busy:
		ConfirmPanel.ask(self, "Leave without throwing?", "Your free roll is lost.", "Leave", done.emit)
	else:
		done.emit()


func _on_roll() -> void:
	if busy or owed or not _can_pay():
		return
	if not no_cost:
		combat.pay_forge()
	busy = true
	_refresh()
	tray.throw([0])  # lands on whatever comes up
	await tray.landed
	busy = false
	var u: Dictionary = Combat.FORGE_ROLL[tray.dice[0].value - 1]  # the face that came up is the roll
	if u.has("mark") and not combat.can_mark(u.mark):
		if not no_cost:
			combat.refund_forge()  # every face already carries it: nowhere for it to go
		info.text = "Rolled %s, but no face can take it. %s" % [_upgrade_name(u), "Roll again." if no_cost else "Shards returned."]
		_refresh(false)
		return
	owed = true
	mark = u.get("mark", "")
	step = u.get("step", 0)
	_refresh()


func _can_pay() -> bool:
	return no_cost or combat.shards >= Combat.FORGE_COST


## Asks before a face changes for good: what it becomes, and what that costs.
func _on_face(i: int, f: int) -> void:
	var d: Dictionary = combat.dice[i]
	var was := "cursed face" if d.base[f] == Combat.CURSE else str(d.base[f])
	if carve:
		ConfirmPanel.ask(self, "Carve a 9?", "Die %d's %s becomes a 9, and another face on that die is cursed." % [i + 1, was], "Carve", _carve.bind(i, f))
		return
	if not owed:
		return
	var what: String = Combat.MARKS[mark].name if mark else "+%d" % step
	var note := ""
	if d.base[f] == Combat.CURSE:
		note = " The curse is lifted." if mark else " The curse is lifted instead."
	elif mark and d.marks[f]:
		note = " It replaces %s." % Combat.MARKS[d.marks[f]].name
	ConfirmPanel.ask(self, "%s on die %d's %s?" % [what, i + 1, was], "This lasts the rest of the run.%s" % note, "Forge it", _apply.bind(i, f))


func _carve(i: int, f: int) -> void:
	combat.carve(i, f)
	done.emit()


func _apply(i: int, f: int) -> void:
	if not owed or not combat.forge(i, f, true, mark, step):  # paid for when it was rolled
		return
	owed = false
	mark = ""
	if no_cost:
		done.emit()  # the campfire gives exactly one
	else:
		_refresh()


## Redraws the faces and buttons; `say` false keeps the info line's last message.
func _refresh(say := true) -> void:
	if roll_button:
		roll_button.disabled = busy or owed or not _can_pay()
	if leave:
		leave.disabled = busy or owed  # a paid roll can't be walked away from
	if carve:
		info.text = "Pick a face to become a 9. Another face on that die is cursed."
	elif not say:
		pass
	elif busy:
		info.text = "Shards %d   Rolling..." % combat.shards
	elif owed:
		var u := {"mark": mark} if mark else {"step": step}
		info.text = "Rolled %s. Pick a face for it.\n%s" % [_upgrade_name(u), Combat.MARKS[mark].text if mark else "+%d to a face" % step]
	elif no_cost:
		info.text = "One free roll: throw the die, then pick a face for what it lands on."
	else:
		info.text = "Shards %d   Throw the die, then pick a face for what it lands on.\n%d Shards a throw." % [combat.shards, Combat.FORGE_COST]
	for i in face_buttons.size():
		for f in 6:
			var b: Button = face_buttons[i][f]
			var face: int = combat.dice[i].base[f]
			var has: String = combat.dice[i].marks[f]
			b.text = str(face)
			b.tooltip_text = "%s: %s" % [Combat.MARKS[has].name, Combat.MARKS[has].text] if has else ""
			b.add_theme_stylebox_override("normal", cursed if face == Combat.CURSE else normal)
			b.add_theme_color_override("font_color", Color.WHITE if face == Combat.CURSE else (UI.MARK_COLORS[has] if has else BONE_INK))
			b.disabled = not carve and (not owed or (mark != "" and has == mark))  # faces wait for a throw
			var glyph: TextureRect = b.get_child(0)
			glyph.texture = load(UI.ART % ("mark_" + has)) if has else null
			glyph.modulate = UI.MARK_COLORS[has] if has else Color.WHITE
			glyph.modulate.a = 0.5 if b.disabled else 1.0  # dimmed with its disabled face
