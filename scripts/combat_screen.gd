class_name CombatScreen
extends Control
## One fight on screen, built in code. The hero and enemies with a sprite are rigs from scenes/
## (made by tools/rig_sprites.gd); enemies without one are placeholder boxes.
## Rules are taught only in the tutorial fight; the boss is hinted at only by murmurs in the dungeon fights.
## Keys: R reroll, Enter end turn, Space block/parry during the enemy wind-up. Click an enemy to target it.

signal finished(won: bool)

const SLOT_NAMES := ["-", "Attack", "Guard", "Cleave"]
const SPRITE_SCALE := 3  # whole-number scaling keeps every game pixel square
const LOG_LINES := 4
const STRIKE_DELAY := 0.2  # seconds into an enemy's attack animation when the blow lands

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

var combat: Combat  # set by game.gd before the screen enters the tree
var busy := false  # true while the enemies act, and after the fight ends
var acting := -1  # enemy currently acting, highlighted

var hp_label: Label
var fight_label: Label
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
var hero: Node2D


func _ready() -> void:
	_build()
	_log(", ".join(combat.enemies.map(func(e): return e.name)) + ".")
	if combat.is_boss_fight():
		_log("Something large stirs below.")
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_R:
		_on_reroll()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_end_turn()


func _on_reroll() -> void:
	if busy:
		return
	combat.reroll()
	_refresh()


func _on_lock(i: int) -> void:
	if busy:
		return
	combat.toggle_lock(i)
	_refresh()


func _on_assign(i: int, slot: int) -> void:
	if busy:
		return
	combat.assign(i, slot)
	_refresh()


func _on_target(i: int) -> void:
	if busy:
		return
	combat.set_target(i)
	_refresh()


func _on_end_turn() -> void:
	if busy:
		return
	busy = true
	var unplaced := combat.unplaced_count()
	var enemy_hp_before: Array = combat.enemies.map(func(e): return e.hp)
	var dealt := combat.resolve_player()
	_log("You deal %d." % dealt)
	if dealt > 0:
		await _play(hero, "attack")
	for i in combat.enemies.size():
		if combat.enemies[i].hp < enemy_hp_before[i]:
			_play(enemy_ui[i].rig, "hurt")
	if unplaced > 0:
		_log("+%d Grit." % unplaced)
	_refresh()
	if combat.fight_won():
		_end(true)
		return
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
		var kind: String = combat.enemies[i].intent.get("kind", "")
		if kind in ["attack", "unblockable"]:
			_play(enemy_ui[i].rig, "attack")
			await get_tree().create_timer(STRIKE_DELAY).timeout
		elif kind == "guard":
			_play(enemy_ui[i].rig, "block")
		var hp_before := combat.player_hp
		_log(combat.resolve_enemy(i, grade))
		if combat.player_hp < hp_before:
			_play(hero, "hurt")
		elif grade != Combat.Grade.MISS:
			_play(hero, "block")
		if combat.player_hp == 0:
			break
	acting = -1
	combat.end_enemy_phase()
	if combat.player_hp == 0:
		_end(false)
	elif combat.tutorial_done():
		_end(true)
	else:
		combat.start_turn()
		busy = false
		_refresh()


## Plays one move of a rig from scenes/, then falls back to idle; await it to wait for the move to land.
## Does nothing for an enemy without a rig, or a rig without that move.
func _play(rig: Node2D, anim: StringName) -> void:
	if rig == null or not rig.get_node("AnimationPlayer").has_animation(anim):
		return
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	player.play(anim)
	await player.animation_finished
	if not player.is_playing():  # a newer move may have taken over meanwhile
		player.play("idle")


## Shows the last state for a moment so the final blow registers, then hands back to game.gd.
func _end(won: bool) -> void:
	_log("The room falls quiet." if won else "You fall.")
	_refresh()
	await get_tree().create_timer(1.2).timeout
	finished.emit(won)


func _refresh() -> void:
	hp_label.text = "HP %d/%d   Shards %d" % [combat.player_hp, combat.max_hp, combat.shards]
	fight_label.text = "Tutorial" if combat.is_tutorial() else ("Boss" if combat.is_boss_fight() else "Dungeon")
	for i in enemy_ui.size():
		var e: Dictionary = combat.enemies[i]
		var ui: Dictionary = enemy_ui[i]
		var up := combat.alive(i)
		ui.intent.text = combat.intent_text(i) if up else ""
		ui.intent.add_theme_color_override("font_color", UI.DANGER if e.intent.get("kind") in ["unblockable", "curse"] else Color.WHITE)
		if ui.rig == null:
			ui.body.text = e.name
		ui.body.disabled = not up
		ui.body.modulate = Color(1, 1, 1, 1 if up else 0.3)
		ui.hp.text = "%s   HP %d/%d" % [e.name, e.hp, e.type.hp] if up else e.name + "   down"
		ui.mark.text = "ACTING" if i == acting else ("TARGET" if i == combat.target and up else "")
		ui.mark.add_theme_color_override("font_color", UI.DANGER if i == acting else UI.GOLD)
	lesson_label.visible = combat.is_tutorial() and combat.turn < LESSONS.size()
	if lesson_label.visible:
		lesson_label.text = LESSONS[combat.turn]
	# Blank rather than hidden: the murmur label is the gap that pushes the enemies to the right.
	var murmurs := not combat.is_tutorial() and not combat.is_boss_fight()
	murmur_label.text = MURMURS[mini(combat.dungeon_turns, MURMURS.size() - 1)] if murmurs else ""
	for i in dice_ui.size():
		var d: Dictionary = combat.dice[i]
		var ui: Dictionary = dice_ui[i]
		ui.value.text = "X" if d.value == Combat.CURSE else str(d.value)
		ui.value.add_theme_color_override("font_color", UI.DANGER if d.value == Combat.CURSE else Color.WHITE)
		ui.faces.text = "faces: " + " ".join(d.faces.map(func(f): return "X" if f == Combat.CURSE else str(f)))
		ui.slot.text = SLOT_NAMES[d.slot]
		ui.lock.text = "Locked" if d.locked else "Lock"
	var pair := "   Pair of %ds" % combat.rolled_pair() if combat.rolled_pair() else ""
	summary_label.text = "Damage %d   Guard %d   Grit +%d%s" % [combat.preview_damage(), combat.guard_total(), combat.unplaced_count(), pair]
	summary_label.add_theme_color_override("font_color", UI.GOLD if combat.rolled_pair() and not combat.cleave_ready() else Color.WHITE)
	reroll_button.text = "Reroll (%d)  [R]" % combat.rerolls
	reroll_button.disabled = busy or combat.rerolls == 0
	end_button.disabled = busy
	log_label.text = "\n".join(log_lines)


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > LOG_LINES:
		log_lines.pop_front()


# --- UI construction -------------------------------------------------------

func _build() -> void:
	var root := UI.page(self)

	var top := UI.row(root)
	hp_label = UI.label(top, 22)
	UI.spacer(top)
	fight_label = UI.label(top, 22)

	var field := UI.row(root)
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var player := Control.new()  # holds the hero's space in the row; the rig itself is a Node2D
	player.size_flags_vertical = Control.SIZE_SHRINK_END
	field.add_child(player)
	hero = _add_rig(player, "deserter")
	murmur_label = UI.label(field, 18)
	murmur_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	murmur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	murmur_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	murmur_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	murmur_label.add_theme_color_override("font_color", UI.QUIET)
	var enemy_row := UI.row(field)
	for i in combat.enemies.size():
		enemy_ui.append(_build_enemy(enemy_row, i))

	lesson_label = UI.label(root, 20)
	lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_label.add_theme_color_override("font_color", UI.GOLD)

	timing_hint = UI.label(root, 20)
	timing_hint.hide()
	timing = TimingBar.new()
	timing.custom_minimum_size = Vector2(0, 32)
	timing.hide()
	root.add_child(timing)

	summary_label = UI.label(root, 18)

	var bottom := UI.row(root, 24)
	for i in combat.dice.size():
		dice_ui.append(_build_die(bottom, i))
	UI.spacer(bottom)
	var actions := VBoxContainer.new()
	bottom.add_child(actions)
	reroll_button = UI.button(actions, "", _on_reroll)
	end_button = UI.button(actions, "End turn  [Enter]", _on_end_turn)

	log_label = UI.label(root, 16)
	log_label.custom_minimum_size = Vector2(0, 22 * LOG_LINES)


## One column per enemy: intent, clickable body (sets the target), name and HP, and a TARGET/ACTING mark.
## The body is the enemy's sprite when it has one, else a placeholder box.
func _build_enemy(parent: Node, i: int) -> Dictionary:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(col)
	var intent := UI.label(col, 20)
	var sprite: String = combat.enemies[i].type.get("sprite", "")
	var body := UI.button(col, "", _on_target.bind(i))
	var rig: Node2D = null
	if sprite:
		body.flat = true
		rig = _add_rig(body, sprite)
	else:
		body.custom_minimum_size = Vector2(120, 96)
	var hp := UI.label(col, 16)
	var mark := UI.label(col, 16)
	return {"intent": intent, "body": body, "rig": rig, "hp": hp, "mark": mark}


## Puts the rigged scene scenes/<sprite>.tscn inside `holder`, sized to the sprite at game scale.
func _add_rig(holder: Control, sprite: String) -> Node2D:
	holder.custom_minimum_size = load("res://assets/sprites/%s.png" % sprite).get_size() * SPRITE_SCALE
	var rig: Node2D = load("res://scenes/%s.tscn" % sprite).instantiate()
	rig.scale = Vector2.ONE * SPRITE_SCALE
	holder.add_child(rig)
	return rig


func _build_die(parent: Node, i: int) -> Dictionary:
	var col := VBoxContainer.new()
	parent.add_child(col)
	var face := UI.box(col, Color(0.2, 0.22, 0.3), Vector2(96, 96))
	var value := UI.label(face, 44)
	var slot := UI.label(col, 16)
	var faces := UI.label(col, 12)
	var buttons := UI.row(col, 4)
	var lock := UI.button(buttons, "Lock", _on_lock.bind(i))
	UI.button(buttons, "Atk", _on_assign.bind(i, Combat.Slot.ATTACK))
	UI.button(buttons, "Grd", _on_assign.bind(i, Combat.Slot.GUARD))
	UI.button(buttons, "Clv", _on_assign.bind(i, Combat.Slot.CLEAVE))
	UI.button(buttons, "-", _on_assign.bind(i, Combat.Slot.NONE))
	return {"value": value, "slot": slot, "faces": faces, "lock": lock}
