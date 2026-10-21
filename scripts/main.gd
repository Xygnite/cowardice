extends Control
## Combat prototype screen. Placeholder art: coloured boxes and labels, built in code.
## Rules are taught only in the tutorial fight; the boss is hinted at only by murmurs in the dungeon fights.
## Keys: R reroll, Enter end turn, Space block/parry during the enemy wind-up. Click an enemy to target it.

const SLOT_NAMES := ["-", "Attack", "Guard", "Cleave"]
const DANGER := Color(1, 0.45, 0.4)
const GOLD := Color(1, 0.85, 0.4)

## One lesson per tutorial turn, indexed by Combat.turn.
const LESSONS := [
	"Above the dummy is what it will do this turn. Lock the dice you like, reroll the rest, then put a die in Attack and end the turn.",
	"Put a die in Guard. When the dummy swings, press SPACE as the marker reaches the blue zone. The later you press, the better the block.",
	"Two of your dice match. Put both in Cleave: a pair strikes harder and slips past any guard.",
	"Leave one die unplaced. It becomes Grit: one extra reroll next turn.",
	"Red means no shield will hold. Put a die in Guard and press SPACE inside the red zone to parry. A higher die gives you more time.",
]

## Cryptic hints about the Bone Warden, one per turn across the dungeon fights before him.
const MURMURS := [
	"The walls murmur: \"...he keeps the tallest bone for himself...\"",
	"The walls murmur: \"...two of a kind walk where one cannot...\"",
	"The walls murmur: \"...when he cracks in half, he writes on your bones...\"",
	"The walls murmur: \"...hold the stained bone to your shield, and it burns clean...\"",
	"The walls murmur: \"...at the last, he swings what no shield can hold...\"",
]

var combat := Combat.new()
var busy := false  # true while the enemies act
var over := false
var acting := -1  # enemy currently acting, highlighted
var dungeon_turns := 0  # drives the murmurs

var hp_label: Label
var fight_label: Label
var enemy_row: HBoxContainer
var enemy_ui: Array[Dictionary] = []
var murmur_label: Label
var lesson_label: Label
var dice_ui: Array[Dictionary] = []
var summary_label: Label
var reroll_button: Button
var end_button: Button
var timing_hint: Label
var timing: TimingBar
var log_label: Label
var log_lines: Array[String] = []


func _ready() -> void:
	_build()
	_log("Tutorial: %s." % combat.enemies[0].name)
	_build_enemies()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if over and event.keycode == KEY_R:
		_restart()
	elif event.keycode == KEY_R:
		_on_reroll()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_end_turn()


func _on_reroll() -> void:
	if busy or over:
		return
	combat.reroll()
	_refresh()


func _on_lock(i: int) -> void:
	if busy or over:
		return
	combat.toggle_lock(i)
	_refresh()


func _on_assign(i: int, slot: int) -> void:
	if busy or over:
		return
	combat.assign(i, slot)
	_refresh()


func _on_target(i: int) -> void:
	if busy or over:
		return
	combat.set_target(i)
	_refresh()


func _on_end_turn() -> void:
	if busy or over:
		return
	busy = true
	var unplaced := combat.unplaced_count()
	_log("You deal %d." % combat.resolve_player())
	if unplaced > 0:
		_log("+%d Grit." % unplaced)
	if combat.fight_won():
		_fight_won()
		busy = false
		_refresh()
		return
	_refresh()
	for i in combat.enemies.size():
		if not combat.alive(i):
			continue
		acting = i
		_refresh()
		var grade: int = Combat.Grade.MISS
		if combat.needs_timing(i):
			timing_hint.text = ("BLOCK!  " if combat.enemies[i].intent.kind == "attack" else "PARRY!  ") + combat.enemies[i].name
			timing_hint.show()
			timing.start(combat, i)
			grade = await timing.finished
			timing_hint.hide()
		_log(combat.resolve_enemy(i, grade))
		if combat.player_hp == 0:
			break
	acting = -1
	combat.end_enemy_phase()
	if not combat.is_tutorial() and not combat.is_boss_fight():
		dungeon_turns += 1
	if combat.player_hp == 0:
		over = true
		_log("You fled. Press R to walk back in.")
	elif combat.tutorial_done():
		_fight_won()
	else:
		combat.start_turn()
	busy = false
	_refresh()


func _fight_won() -> void:
	if combat.is_tutorial():
		combat.player_hp = Combat.PLAYER_MAX_HP
		_log("The dummy collapses. The dungeon waits.")
	elif combat.fight + 1 < Combat.FIGHTS.size():
		combat.player_hp = mini(Combat.PLAYER_MAX_HP, combat.player_hp + Combat.HEAL_BETWEEN_FIGHTS)
		_log("The room falls quiet. You rest (+%d HP)." % Combat.HEAL_BETWEEN_FIGHTS)
	else:
		over = true
		_log("The Bone Warden falls. Victory! Press R to play again.")
		return
	combat.start_fight(combat.fight + 1)
	if combat.is_boss_fight():
		_log("Something large stirs below.")
	_build_enemies()


func _restart() -> void:
	combat = Combat.new()
	combat.start_fight(1)  # the tutorial is played once per launch
	over = false
	dungeon_turns = 0
	log_lines.clear()
	_log("You walk back in.")
	_build_enemies()
	_refresh()


func _refresh() -> void:
	hp_label.text = "HP %d/%d" % [combat.player_hp, Combat.PLAYER_MAX_HP]
	fight_label.text = "Tutorial" if combat.is_tutorial() else "Fight %d/%d" % [combat.fight, Combat.FIGHTS.size() - 1]
	for i in enemy_ui.size():
		var e: Dictionary = combat.enemies[i]
		var ui: Dictionary = enemy_ui[i]
		var up := combat.alive(i)
		ui.intent.text = combat.intent_text(i) if up else ""
		ui.intent.add_theme_color_override("font_color", DANGER if e.intent.get("kind") in ["unblockable", "curse"] else Color.WHITE)
		ui.body.text = e.name
		ui.body.disabled = not up
		ui.body.modulate = Color(1, 1, 1, 1 if up else 0.3)
		ui.hp.text = "HP %d/%d" % [e.hp, e.type.hp] if up else "down"
		ui.mark.text = "ACTING" if i == acting else ("TARGET" if i == combat.target and up else "")
		ui.mark.add_theme_color_override("font_color", DANGER if i == acting else GOLD)
	lesson_label.visible = combat.is_tutorial() and combat.turn < LESSONS.size()
	if lesson_label.visible:
		lesson_label.text = LESSONS[combat.turn]
	# Blank rather than hidden: the murmur label is the gap that pushes the enemies to the right.
	var murmurs := not combat.is_tutorial() and not combat.is_boss_fight()
	murmur_label.text = MURMURS[mini(dungeon_turns, MURMURS.size() - 1)] if murmurs else ""
	for i in dice_ui.size():
		var d: Dictionary = combat.dice[i]
		var ui: Dictionary = dice_ui[i]
		ui.value.text = "X" if d.value == Combat.CURSE else str(d.value)
		ui.value.add_theme_color_override("font_color", DANGER if d.value == Combat.CURSE else Color.WHITE)
		ui.faces.text = "faces: " + " ".join(d.faces.map(func(f): return "X" if f == Combat.CURSE else str(f)))
		ui.slot.text = SLOT_NAMES[d.slot]
		ui.lock.text = "Locked" if d.locked else "Lock"
	var pair := "   Pair of %ds" % combat.rolled_pair() if combat.rolled_pair() else ""
	summary_label.text = "Damage %d   Guard %d   Grit +%d%s" % [combat.preview_damage(), combat.guard_total(), combat.unplaced_count(), pair]
	summary_label.add_theme_color_override("font_color", GOLD if combat.rolled_pair() and not combat.cleave_ready() else Color.WHITE)
	reroll_button.text = "Reroll (%d)  [R]" % combat.rerolls
	reroll_button.disabled = busy or over or combat.rerolls == 0
	end_button.disabled = busy or over
	log_label.text = "\n".join(log_lines)


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 6:
		log_lines.pop_front()


# --- UI construction -------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	hp_label = _label(top, 22)
	_spacer(top)
	fight_label = _label(top, 22)

	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 16)
	root.add_child(field)
	var player := _box(field, Color(0.3, 0.4, 0.35), Vector2(120, 160))
	player.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(player, 18).text = "YOU"
	murmur_label = _label(field, 18)
	murmur_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	murmur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	murmur_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	murmur_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	murmur_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	enemy_row = HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 16)
	field.add_child(enemy_row)

	lesson_label = _label(root, 20)
	lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_label.add_theme_color_override("font_color", GOLD)

	timing_hint = _label(root, 20)
	timing_hint.hide()
	timing = TimingBar.new()
	timing.custom_minimum_size = Vector2(0, 32)
	timing.hide()
	root.add_child(timing)

	summary_label = _label(root, 18)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	root.add_child(bottom)
	for i in combat.dice.size():
		dice_ui.append(_build_die(bottom, i))
	_spacer(bottom)
	var actions := VBoxContainer.new()
	bottom.add_child(actions)
	reroll_button = _button(actions, "", _on_reroll)
	end_button = _button(actions, "End turn  [Enter]", _on_end_turn)

	log_label = _label(root, 16)
	log_label.custom_minimum_size = Vector2(0, 110)


## One column per enemy: intent, clickable body (sets the target), HP, and a TARGET/ACTING mark.
func _build_enemies() -> void:
	for c in enemy_row.get_children():
		c.queue_free()
	enemy_ui.clear()
	for i in combat.enemies.size():
		var col := VBoxContainer.new()
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		enemy_row.add_child(col)
		var intent := _label(col, 20)
		var body := _button(col, "", _on_target.bind(i))
		var big: bool = combat.enemies[i].type.get("boss", false)
		body.custom_minimum_size = Vector2(200, 160) if big else Vector2(150, 120)
		var hp := _label(col, 16)
		var mark := _label(col, 16)
		enemy_ui.append({"intent": intent, "body": body, "hp": hp, "mark": mark})


func _build_die(parent: Node, i: int) -> Dictionary:
	var col := VBoxContainer.new()
	parent.add_child(col)
	var face := _box(col, Color(0.2, 0.22, 0.3), Vector2(96, 96))
	var value := _label(face, 44)
	var slot := _label(col, 16)
	var faces := _label(col, 12)
	var row := HBoxContainer.new()
	col.add_child(row)
	var lock := _button(row, "Lock", _on_lock.bind(i))
	_button(row, "Atk", _on_assign.bind(i, Combat.Slot.ATTACK))
	_button(row, "Grd", _on_assign.bind(i, Combat.Slot.GUARD))
	_button(row, "Clv", _on_assign.bind(i, Combat.Slot.CLEAVE))
	_button(row, "-", _on_assign.bind(i, Combat.Slot.NONE))
	return {"value": value, "slot": slot, "faces": faces, "lock": lock}


func _label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	if parent is ColorRect:
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _box(parent: Node, color: Color, min_size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = min_size
	parent.add_child(r)
	return r


func _button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space/Enter for the game, not button focus
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _spacer(parent: Node) -> void:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)
