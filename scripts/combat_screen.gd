class_name CombatScreen
extends Control
## One fight on screen, built in code. The hero and enemies with a sprite are rigs from scenes/
## (made by tools/rig_sprites.gd); enemies without one are placeholder boxes.
## Rules are taught only in the tutorial fight; a floor's boss is hinted at only by murmurs in the fights before him.
## Keys: R reroll, Enter end turn, Space block/parry during the enemy wind-up, Esc the fight menu. Click an enemy to target it,
## a die for its actions (lock, place).

signal finished(won: bool)
signal abandoned  # quit from the fight menu

const SLOT_NAMES := ["-", "Attack", "Guard", "Skill"]
const SLOT_ICONS := ["", "attack", "guard", "cleave"]  # assets/ui/cut/slot_*.png, by Combat.Slot
const SPRITE_SCALE := 3  # whole-number scaling keeps every game pixel square
## How far down each fight picture (as a fraction) its floor's top edge is, by backdrop.
const LEDGES := {"fight": 0.683, "mine": 0.671}
const FEET_SINK := 10  # screen pixels the fighters' feet stand below that edge, on the floor's surface
const SPRITE_PAD := 2  # empty rows under every sprite (tools/make_sprites.gd "pad")
const TRAY_HEIGHT := 230  # screen pixels; leaves the fight row room for the tallest fight (the boss)
const EFFECT_FRAME := 0.06  # seconds per frame of a hit effect
const FLOAT_TIME := 0.8  # seconds a damage number takes to rise and fade
static var TARGET_ARROW := _arrow(UI.GOLD)  # over the enemy you aim at
static var ACTING_ARROW := _arrow(UI.DANGER)  # over the enemy taking its turn
const TRAY_INSET := 6  # screen pixels from the box's edge to the felt, which tucks under the frame's 8 px border
const LOG_LINES := 4
const STRIKE_DELAY := 0.2  # seconds into an enemy's attack animation when the blow lands
const MENU_LOCK := 100  # die menu id for lock/unlock; the other ids are Combat.Slot values
const HOLD_LOCK := 0.8  # seconds a die is held down, with quick dice control, to lock or unlock it
const HIT_SFX := preload("res://assets/audio/hit.wav")
const BLOCK_SFX := preload("res://assets/audio/block.wav")
const MARK_SFX := preload("res://assets/audio/confirm.wav")  # an Ember or Shard face paying out

## One lesson per tutorial turn, indexed by Combat.turn; the turn's QUICK_LESSONS entry replaces it under
## Quick dice control (Meta.quick_dice). Turn 2's roll is rigged to hold a pair, so its dice glow.
const LESSONS := [
	"Above the dummy is what it will do this turn. Hold R or the Roll button, then let go, to throw. Click a die to lock it or place it. Lock the dice you like, reroll the rest, then put a die in Attack and end the turn.",
	"Put a die in Guard. When the dummy swings, press SPACE as the marker reaches the blue zone. The later you press, the better the block.",
	"Two dice match, so they glow gold: a skill is ready. Put both in Skill to Cleave. A pair strikes harder and slips past any guard.",
	"Leave one die unplaced. It becomes Grit: one extra reroll next turn.",
	"Red means no shield will hold. Put a die in Guard and press SPACE inside the red zone to parry. A higher die gives you more time.",
]
const QUICK_LESSONS := {
	0: "Above the dummy is what it will do this turn. Hold R or the Roll button, then let go, to throw. Click a die to move it to the next slot, right-click to go back, hold it down to lock it. Lock the dice you like, reroll the rest, then put a die in Attack and end the turn.",
	1: "Click a die twice to put it in Guard. When the dummy swings, press SPACE as the marker reaches the blue zone. The later you press, the better the block.",
	2: "Two dice match, so they glow gold: a skill is ready. Right-click each one to put it straight in Skill and Cleave. A pair strikes harder and slips past any guard.",
}

const MURMUR_COLOR := Color(0.62, 0.72, 0.9)  # cold, like the window light
## Cryptic hints about the floor's boss (Bone Warden, Pit King), one per turn across the fights before him, by backdrop.
const MURMURS := {"fight": [
	"...he keeps the tallest bone for himself...",
	"...two of a kind walk where one cannot...",
	"...when he cracks in half, he writes on your bones...",
	"...hold the stained bone to your shield, and it burns clean...",
	"...at the last, he swings what no shield can hold...",
], "mine": [
	"...the King keeps what the mountain takes...",
	"...when the roof speaks, one die goes under...",
	"...the rock gives back what it buries, in time...",
	"...he never takes the last one. He wants you digging...",
	"...wounded, he brings the roof down with every swing...",
]}

var combat: Combat  # set by game.gd before the screen enters the tree
var backdrop := "fight"  # the floor's fight picture, assets/ui/bg_<backdrop>.webp; set by game.gd
var meta: Meta  # for the fight menu's settings; set by game.gd
var busy := false  # true while the dice are in the air or the enemies act, and after the fight ends
var rolling: Array = []  # indices of the dice in the air; their values aren't known until they land
var acting := -1  # enemy currently acting, highlighted

var menu_button: Button
var hp_label: Label
var hp_bar: ProgressBar
var crypt: TextureRect  # the fight backdrop
var bottom_row: HBoxContainer  # the dice box and the action buttons
var dice_box: Control
## Height of the dice row. The same in every fight by default; a boss gimmick can set it (even
## mid-fight) to squeeze or widen the tray, and the fight row above gives or takes the difference.
var tray_height := TRAY_HEIGHT:
	set(v):
		tray_height = v
		if bottom_row:
			bottom_row.custom_minimum_size.y = v
var fight_label: Label
var enemy_ui: Array[Dictionary] = []
var murmur_label: RichTextLabel
var murmur_tween: Tween
var lesson_label: Label
var tray: DiceTray
var die_menu: PopupMenu
var menu_die := 0  # die the open action menu acts on
var held := -1  # quick dice control: the die under a left press not yet let go or locked
var hold_tween: Tween  # winds the held die's chains on over HOLD_LOCK, then locks it
var faces_button: Button
var skill_button: Button  # names the skills the Skill dice fire; hover or press for what every unlocked one needs
var faces_popup: PopupPanel
var faces_label: Label
var summary_label: Label  # hover: each enemy's hits before and after Mult
var belt: VBoxContainer  # the relic belt, one icon per slot, beside the dice tray
var belt_values: Array[Label] = []  # a growing relic's current worth, over its icon
var reroll_button: Button
var end_button: Button
var timing_hint: Label
var timing: TimingBar
var charge: ChargeBar
var log_label: Label
var log_lines: Array[String] = []
var hero: Node2D
var sfx := AudioStreamPlayer.new()


func _ready() -> void:
	_build()
	sfx.max_polyphony = 4  # a cleave hits several enemies at once
	sfx.bus = "SFX"
	add_child(sfx)  # after _build: it expects page()'s background as child 0
	_log(", ".join(combat.enemies.map(func(e): return e.name)) + ".")
	if combat.is_boss_fight():
		_log("Something large stirs below.")
	_refresh()
	_roll_anim(range(combat.dice.size()), combat.rigged_turn(), true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and not event.echo):
		return
	if event.keycode == KEY_R or event.keycode == KEY_SPACE:
		_on_roll_key(event.pressed)
	elif not event.pressed:
		return
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_end_turn()
	elif event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_open_menu()


## Only on the player's turn, with the dice at rest, so no roll, bar or blow resolves behind it.
## The screen stays busy while it is open, which shuts out every key and click; Esc closes it (Overlay).
func _open_menu() -> void:
	if busy:
		return
	busy = true
	var m := FightMenu.new()
	m.meta = meta
	m.quit.connect(abandoned.emit)
	m.tree_exited.connect(func() -> void:
		busy = false
		_refresh())
	add_child(m)
	_refresh()


## The Roll button and its keys: held to wind up a throw that is waiting, or, with the dice at rest,
## to start a reroll and wind it up in the same press.
func _on_roll_key(down: bool) -> void:
	if down and not charge.waiting:
		_on_reroll()
	charge.press(down)


func _on_reroll() -> void:
	if busy:
		return
	if not combat.reroll():
		return
	_roll_anim(range(combat.dice.size()).filter(func(i): return not combat.dice[i].locked and combat.dice[i].buried == 0))


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
	var hp_was := combat.player_hp
	var shards_was := combat.shards
	var lit := combat.firing()  # before resolving: growing relics count the turn up as it resolves
	var dealt := combat.resolve_player()
	_log("You deal %d." % dealt)
	_mark_payout(combat.player_hp - hp_was, combat.shards - shards_was)
	if dealt > 0:
		await _play(hero, "attack")
	if dealt > 0:
		for k in lit:
			_flash(belt.get_child(k))
	for i in combat.enemies.size():
		var swapped: bool = combat.enemies[i].has("from")  # a Hulk died and Rubble stands in its slot
		if swapped or combat.enemies[i].hp < enemy_hp_before[i]:
			_play(enemy_ui[i].rig, "hurt")
			_slash(enemy_ui[i].body)
			_float(enemy_ui[i].body, "-%d" % (enemy_hp_before[i] - (0 if swapped else combat.enemies[i].hp)), UI.DANGER)
		if swapped:
			_log("The %s collapses into %s." % [combat.enemies[i].from, combat.enemies[i].name])
			_swap_body(i)
			combat.enemies[i].erase("from")  # handled; later turns must not replay the swap
	if unplaced > 0:
		_log("+%d Grit." % unplaced)
	_refresh()
	if combat.fight_won():
		_end(true)
		return
	for i in combat.enemies.size():
		if not combat.alive(i) or combat.enemies[i].intent.is_empty():  # a fresh Rubble waits a turn
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
		_refresh()  # a cave-in shows its rubble at once
		var at: Control = hero.get_parent()
		if combat.player_hp < hp_before:
			_play(hero, "hurt")
			_slash(at, true)
			_float(at, "-%d" % (hp_before - combat.player_hp), UI.DANGER)
		elif combat.cowered and kind in ["attack", "unblockable", "curse", "cave_in"]:
			_float(at, "Cowered!", UI.GOLD)
		elif grade != Combat.Grade.MISS:
			_play(hero, "block")
			_sfx(BLOCK_SFX)
			_float(at, "Parried!" if kind in ["unblockable", "curse"] else "Blocked", UI.GOLD)
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
		_roll_anim(range(combat.dice.size()).filter(func(i): return combat.dice[i].buried == 0), combat.rigged_turn(), true)


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
	hp_label.text = "%d/%d   Shards %d" % [combat.player_hp, combat.max_hp, combat.shards]
	hp_bar.max_value = combat.max_hp
	hp_bar.value = combat.player_hp
	fight_label.text = "Tutorial" if combat.is_tutorial() else ("Boss" if combat.is_boss_fight() else ("Mine" if backdrop == "mine" else "Dungeon"))
	for i in enemy_ui.size():
		var e: Dictionary = combat.enemies[i]
		var ui: Dictionary = enemy_ui[i]
		var up := combat.alive(i)
		var kind: String = e.intent.get("kind", "") if up else ""
		ui.icon.texture = load(UI.ART % ("intent_" + ("unblockable" if kind == "cave_in" else kind))) if kind else null  # no rocks icon: the label says it
		var cave: bool = kind == "cave_in" or e.intent.get("cave_in", false)
		ui.intent.text = ("die %d" % (e.intent.target + 1)) if kind == "curse" else ("CAVE-IN" if kind == "cave_in" else str(e.intent.get("value", "")) + (" + cave-in" if cave else ""))
		ui.intent.add_theme_color_override("font_color", UI.DANGER if kind in ["unblockable", "curse"] or cave else Color.WHITE)
		ui.rune.visible = up and e.intent.get("rung", false)
		ui.arcs.visible = kind == "ring"
		if ui.rig == null:
			ui.body.text = e.name
		ui.body.disabled = not up
		ui.body.modulate = Color(1, 1, 1, 1 if up else 0.3)
		ui.hp.text = "%s  %d/%d" % [e.name, e.hp, e.max] if up else e.name + "  down"
		ui.bar.value = e.hp
		ui.mark.texture = ACTING_ARROW if i == acting else TARGET_ARROW
		ui.mark.modulate.a = 1.0 if i == acting or (i == combat.target and up) else 0.0
	lesson_label.visible = combat.is_tutorial() and combat.turn < LESSONS.size()
	if lesson_label.visible:
		lesson_label.text = QUICK_LESSONS.get(combat.turn, LESSONS[combat.turn]) if meta and meta.quick_dice else LESSONS[combat.turn]
	# Blank rather than hidden: the murmur label is the gap that pushes the enemies to the right.
	var murmurs := not combat.is_tutorial() and not combat.is_boss_fight()
	var lines: Array = MURMURS[backdrop]
	var murmur: String = lines[mini(combat.dungeon_turns, lines.size() - 1)] if murmurs else ""
	if murmur != murmur_label.get_parsed_text():
		murmur_label.text = "[wave amp=12 freq=1.5]%s[/wave]" % murmur if murmur else ""
		_whisper()
	var fired := combat.fired()
	var ready := combat.skill_dice()  # an aura hints at a skill the dice can make
	for i in combat.dice.size():
		var d: Dictionary = combat.dice[i]
		var art := "cursed" if d.value == Combat.CURSE and i not in rolling else ("locked" if d.locked else ("placed" if d.slot != Combat.Slot.NONE else "bone"))
		tray.show_die(i, d.faces, d.value, art, SLOT_ICONS[d.slot], d.locked, d.buried > 0, d.marks)
		tray.glow(i, i in ready and i not in rolling)
	var fire := " + ".join(fired.map(func(id): return Combat.SKILLS[id].name))
	var hint := ("   %s ready" % fire) if fire else ("   Skill in reach" if combat.skill_in_roll() else "")
	skill_button.text = fire if fire else "Skills"
	var m := combat.mult()
	var times := not is_equal_approx(m, 1.0)
	var damage := "Damage %d" % combat.preview_damage() + (" (×%.1f)" % m if times else "")
	summary_label.text = "Rolling..." if rolling else "%s   Guard %d   Grit +%d%s" % [damage, combat.guard_total(), combat.unplaced_count(), hint]
	summary_label.tooltip_text = _mult_text(m) if times and not rolling else ""
	for k in belt_values.size():
		belt_values[k].text = _relic_value(k)
	summary_label.add_theme_color_override("font_color", UI.GOLD if combat.skill_in_roll() and not combat.skill_ready() and not rolling else Color.WHITE)
	reroll_button.text = "Hold to roll  [R]" if charge.waiting else "Reroll (%d)  [R]" % combat.rerolls
	reroll_button.disabled = not charge.waiting and (busy or combat.rerolls == 0)
	end_button.disabled = busy
	menu_button.disabled = busy
	log_label.text = "\n".join(log_lines)


## Each enemy's base hits times Mult, then the Mult, for the summary's hover.
func _mult_text(m: float) -> String:
	var lines := []
	for i in combat.enemies.size():
		var hits := combat.hits_to(i)
		if not hits.is_empty():
			lines.append("%s: %s  × %.1f = %d" % [combat.enemies[i].name, ("(" + " + ".join(hits.map(str)) + ")") if hits.size() > 1 else str(hits[0]), m, combat.damage_to(i)])
	lines.append("Mult ×%.1f" % m)
	return "
".join(lines)


## What a growing relic in belt slot k is worth now, from the slot's own counters; blank at 0 or for the rest.
func _relic_value(k: int) -> String:
	var r: Dictionary = combat.relics[k]
	match combat.relic_id(k):
		"gravedigger":
			return "+%.1f" % (0.1 * r.n) if r.n > 0 else ""
		"spare_fuse":
			return "+%.1f" % r.f if r.f > 0 else ""
		"hungry_bell":
			return "+%d" % (r.f + 1) if r.f > 0 else ""  # the streak's next firing turn adds one more
		"ward_icon":
			return "+%d" % r.f if r.f > 0 else ""
		"miners_ledger":
			return "+%d" % floori(r.n / 4) if r.n >= 4 else ""
	return ""


## A belt icon glows gold and fades back: its relic counted in the blow that just landed.
func _flash(icon: Control) -> void:
	icon.modulate = Color(2.2, 1.8, 0.7)
	icon.create_tween().tween_property(icon, "modulate", Color.WHITE, 0.6)


## A new murmur rises out of the dark, lingers a few seconds, then sinks back.
func _whisper() -> void:
	if murmur_tween:
		murmur_tween.kill()
	murmur_label.modulate.a = 0.0
	murmur_tween = create_tween()
	murmur_tween.tween_property(murmur_label, "modulate:a", 0.85, 1.5)
	murmur_tween.tween_interval(3.0)
	murmur_tween.tween_property(murmur_label, "modulate:a", 0.0, 2.5)


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > LOG_LINES:
		log_lines.pop_front()


# --- UI construction -------------------------------------------------------

func _build() -> void:
	var root := UI.page(self)
	# Placed by _ground_backdrop once the fighters are laid out; the rest sinks behind the dice tray.
	crypt = UI.backdrop(self, backdrop)
	# The strip it uncovers at the bottom takes the colour of the picture's bottom edge, so no seam shows.
	var art := crypt.texture.get_image()
	(get_child(0) as ColorRect).color = art.get_pixel(art.get_width() / 2, art.get_height() - 1)

	var top := UI.row(root, 8)
	UI.image(top, "hp_heart")
	hp_bar = UI.hp_bar(top, 240)
	hp_label = UI.label(top, 22)
	UI.spacer(top)
	fight_label = UI.heading(top, 32)
	menu_button = UI.button(top, "Menu  [Esc]", _open_menu)

	var field := UI.row(root)
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var player := Control.new()  # holds the hero's space in the row; the rig itself is a Node2D
	player.size_flags_vertical = Control.SIZE_SHRINK_END
	field.add_child(player)
	hero = _add_rig(player, "deserter")
	murmur_label = RichTextLabel.new()  # rich only for the [wave]
	murmur_label.bbcode_enabled = true
	murmur_label.scroll_active = false
	murmur_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	murmur_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	murmur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	murmur_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	murmur_label.add_theme_font_size_override("normal_font_size", 16)
	murmur_label.add_theme_color_override("default_color", MURMUR_COLOR)
	murmur_label.modulate.a = 0.0
	field.add_child(murmur_label)
	var enemy_row := UI.row(field)
	for i in combat.enemies.size():
		enemy_ui.append(_build_enemy(enemy_row, i))

	summary_label = UI.label(root, 18)
	summary_label.mouse_filter = Control.MOUSE_FILTER_PASS  # for its Mult hover

	# The dice row has a set height (tray_height) and the fight row above takes what is left, so the
	# dice box, which the throw's walls are sized to, is the same in every fight.
	bottom_row = UI.row(root, 24)
	bottom_row.custom_minimum_size.y = tray_height
	_build_dice(bottom_row)
	belt = VBoxContainer.new()
	belt.alignment = BoxContainer.ALIGNMENT_CENTER
	belt.visible = not combat.relics.is_empty()
	bottom_row.add_child(belt)
	for k in combat.relics.size():
		var value := UI.label(RelicPickScreen.belt_icon(belt, combat, k), 16)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		value.offset_bottom = 8  # hangs a little under the icon, clear of its glyph
		value.offset_right = 6
		value.add_theme_color_override("font_color", UI.GOLD)
		value.add_theme_constant_override("outline_size", 6)
		value.add_theme_color_override("font_outline_color", Color("070e10"))
		belt_values.append(value)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 280
	bottom_row.add_child(actions)
	reroll_button = UI.button(actions, "", func() -> void: pass)  # held, not clicked: see _on_roll_key
	reroll_button.custom_minimum_size.y = 56
	reroll_button.button_down.connect(_on_roll_key.bind(true))
	reroll_button.button_up.connect(_on_roll_key.bind(false))
	charge = ChargeBar.new()
	reroll_button.add_child(charge)
	end_button = UI.button(actions, "End turn  [Enter]", _on_end_turn)
	end_button.custom_minimum_size.y = 80  # the main action: biggest, in gold
	end_button.add_theme_font_size_override("font_size", 32)
	end_button.add_theme_color_override("font_color", UI.GOLD)

	log_label = UI.label(actions, 16)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Floating over the layout, not in it, so showing them never moves anything.
	lesson_label = UI.label(self, 20)  # tutorial lessons, over the top of the scene
	lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_label.add_theme_color_override("font_color", UI.GOLD)
	lesson_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lesson_label.offset_left = 24
	lesson_label.offset_right = -24
	lesson_label.offset_top = 72
	timing_hint = UI.label(dice_box, 20)  # the block/parry bar, over the top of the dice tray: no dice are
	timing_hint.position = Vector2(132, 20)  # used while the enemies act; right of the Faces button
	timing_hint.hide()
	timing = TimingBar.new()
	timing.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	timing.offset_left = 24
	timing.offset_right = -24
	timing.offset_top = 48
	timing.offset_bottom = 48 + 32
	timing.hide()
	dice_box.add_child(timing)


## One column per enemy: intent, clickable body (sets the target), name and HP, and a TARGET/ACTING mark.
## The body is the enemy's sprite when it has one, else a placeholder box.
func _build_enemy(parent: Node, i: int) -> Dictionary:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(col)
	var row := UI.row(col, 4)
	# Kept in the row even when unused (faded out), so the intent beside it doesn't shift.
	var mark := TextureRect.new()
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var icon := TextureRect.new()
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var intent := UI.label(row, 20)
	var rune := UI.image(row, "ring_rune", Vector2(21, 21))  # at the art's own size, small beside the number
	# Name and HP go above the sprite, so every fighter's feet end on the same line as the hero's,
	# written on the bar itself to keep the header short.
	var bar := UI.hp_bar(col, 0)
	bar.max_value = combat.enemies[i].max
	bar.custom_minimum_size.x = 150
	var hp := UI.label(bar, 16)
	hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var sprite: String = combat.enemies[i].type.get("sprite", "")
	var body := UI.button(col, "", _on_target.bind(i))
	var rig: Node2D = null
	if sprite:
		body.flat = true
		rig = _add_rig(body, sprite)
	else:
		body.custom_minimum_size = Vector2(120, 96)
	var arcs := UI.image(body, "ring_arcs")  # the bell's toll, beside it while its intent is to ring
	arcs.flip_h = true  # the sound travels left, toward the hero
	arcs.position = Vector2(-arcs.texture.get_width(), body.custom_minimum_size.y * 0.25)
	return {"intent": intent, "icon": icon, "rune": rune, "arcs": arcs, "body": body, "rig": rig, "hp": hp, "bar": bar, "mark": mark}


## The slot's Rubble replaces its Hulk: new HP bar max, and a new rig if the new type has a sprite.
func _swap_body(i: int) -> void:
	var ui: Dictionary = enemy_ui[i]
	ui.bar.max_value = combat.enemies[i].max
	if ui.rig:
		ui.rig.queue_free()
		ui.rig = null
	var sprite: String = combat.enemies[i].type.get("sprite", "")
	if sprite:
		ui.body.flat = true
		ui.rig = _add_rig(ui.body, sprite)


## Puts the rigged scene scenes/<sprite>.tscn inside `holder`, sized to the sprite at game scale.
## A frame-by-frame version (scenes/<sprite>_frames.tscn, tools/frames_scene.gd) wins when there is one.
func _add_rig(holder: Control, sprite: String) -> Node2D:
	holder.custom_minimum_size = load("res://assets/sprites/%s.png" % sprite).get_size() * SPRITE_SCALE
	var frames := "res://scenes/%s_frames.tscn" % sprite
	var rig: Node2D = load(frames if ResourceLoader.exists(frames) else "res://scenes/%s.tscn" % sprite).instantiate()
	rig.scale = Vector2.ONE * SPRITE_SCALE
	holder.add_child(rig)
	return rig


## The dice tray: the 3D dice on felt that fills the whole box out to its frame, the frame drawn over
## the felt's edge, and a Faces button floating in its top-left corner. Clicking a die opens its menu.
func _build_dice(parent: Node) -> void:
	var box := Control.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	dice_box = box
	tray = DiceTray.new()
	tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, TRAY_INSET)
	tray.die_clicked.connect(_on_die_clicked)
	tray.die_right_clicked.connect(_on_die_right_clicked)
	tray.left_released.connect(_on_left_released)
	box.add_child(tray)
	var frame := Panel.new()  # the panel art with its fill cleared (tools/make_ui.gd), over the felt's edge
	var outline: StyleBoxTexture = frame.get_theme_stylebox("panel").duplicate()
	outline.texture = load(UI.ART % "panel_frame")
	frame.add_theme_stylebox_override("panel", outline)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(frame)
	faces_button = UI.button(box, "Faces", _show_faces)
	faces_button.position = Vector2(28, 16)  # clear of the frame's corner ornament
	skill_button = UI.button(box, "Skills", _show_skill)
	skill_button.tooltip_text = _skill_text()
	skill_button.position = Vector2(28 + faces_button.get_combined_minimum_size().x + 8, 16)
	faces_popup = PopupPanel.new()
	faces_label = UI.label(faces_popup, 16)
	add_child(faces_popup)
	die_menu = PopupMenu.new()
	die_menu.id_pressed.connect(_on_die_menu)
	add_child(die_menu)
	for i in combat.dice.size():
		tray.add_die()


func _on_die_clicked(i: int) -> void:
	if busy or combat.dice[i].buried > 0:
		return
	if meta and meta.quick_dice:  # a quick click cycles on release; held long enough, it locks instead
		held = i
		hold_tween = create_tween()
		hold_tween.tween_method(func(t: float) -> void: tray.hold(i, t), 0.0, 1.0, HOLD_LOCK)
		hold_tween.tween_callback(_on_held.bind(i))
		return
	var d: Dictionary = combat.dice[i]
	menu_die = i
	die_menu.clear()
	die_menu.add_item("Unlock" if d.locked else "Lock", MENU_LOCK)
	die_menu.add_separator()
	for slot in [Combat.Slot.ATTACK, Combat.Slot.GUARD, Combat.Slot.SKILL]:
		die_menu.add_radio_check_item(SLOT_NAMES[slot], slot)
		die_menu.set_item_checked(die_menu.item_count - 1, d.slot == slot)
		if slot == Combat.Slot.SKILL:
			die_menu.set_item_tooltip(die_menu.item_count - 1, _skill_text())
	die_menu.add_item("Unplace", Combat.Slot.NONE)
	die_menu.set_item_disabled(die_menu.item_count - 1, d.slot == Combat.Slot.NONE)
	var r := tray.die_rect(i)
	die_menu.reset_size()
	die_menu.popup(Rect2i(Vector2i(r.end.x + 4, r.position.y), die_menu.size))


func _on_left_released() -> void:
	if held >= 0:
		hold_tween.kill()
		tray.hold(held, 0.0)
		_cycle(held, 1)
		held = -1


func _on_held(i: int) -> void:
	held = -1
	tray.hold(i, 0.0)
	_on_lock(i)


func _on_die_right_clicked(i: int) -> void:
	if meta and meta.quick_dice and not busy and combat.dice[i].buried == 0:
		_cycle(i, -1)


## Quick dice control: die i steps to the next (or, with `step` -1, the previous) of Attack, Guard, Skill, unplaced.
func _cycle(i: int, step: int) -> void:
	_on_assign(i, posmod(combat.dice[i].slot + step, SLOT_NAMES.size()))


func _on_die_menu(id: int) -> void:
	if id == MENU_LOCK:
		_on_lock(menu_die)
	else:
		_on_assign(menu_die, id)


## Every unlocked skill's need and effect, for the Skill button's and die menu item's hover.
func _skill_text() -> String:
	var lines: Array = combat.skills.map(func(id): return "%s: %s. %s" % [Combat.SKILLS[id].name, Combat.SKILLS[id].need, Combat.SKILLS[id].text])
	return "\n".join(lines) + "\nEvery skill the Skill dice fit fires at once.\nSkills ignore enemy Guard and Bone Wall."


func _show_skill() -> void:
	faces_label.text = _skill_text()
	faces_popup.reset_size()
	faces_popup.popup(Rect2i(Vector2i(skill_button.get_global_rect().end), faces_popup.size))


func _show_faces() -> void:
	var lines := []
	for i in combat.dice.size():
		var d: Dictionary = combat.dice[i]
		lines.append("Die %d:  %s" % [i + 1, "  ".join(range(d.faces.size()).map(func(k): return _face_text(d.faces[k]) + (" " + Combat.MARKS[d.marks[k]].name if d.marks[k] else "")))])
	faces_label.text = "\n".join(lines)
	faces_popup.reset_size()
	faces_popup.popup(Rect2i(Vector2i(faces_button.get_global_rect().end), faces_popup.size))


## Throws the dice at `which` (indices); the faces they land on become their values. Until then the
## screen is busy, so nothing acts on Combat's provisional roll. `steer` lands them on that roll instead.
## `stow` (a turn's opening throw) keeps them in the hand, off the felt, until the throw.
func _roll_anim(which: Array, steer := false, stow := false) -> void:
	busy = true
	if stow:
		rolling = which  # so the refresh shows "Rolling..." rather than the provisional roll's damage
		tray.stow(which)
		_refresh()
	# No refresh while winding up: it would square the resting dice onto the provisional roll.
	end_button.disabled = true
	menu_button.disabled = true
	reroll_button.text = "Hold to roll  [R]"
	reroll_button.disabled = false
	var power: float = await charge.wind_up()
	rolling = which
	tray.throw(which, steer, power)  # first, so the refresh doesn't square resting dice onto the provisional roll
	_refresh()
	await tray.landed
	for i in which:
		combat.dice[i].value = tray.dice[i].value
		combat.dice[i].side = tray.top_face(i)  # which of equal faces landed decides its mark
	rolling = []
	busy = false
	_refresh()


## Floats and logs what Ember and Shard faces, an even Oath or a killing Gambit just paid, over the hero.
func _mark_payout(healed: int, shards: int) -> void:
	if healed <= 0 and shards <= 0:
		return
	var parts := []
	if healed > 0:
		parts.append("+%d HP" % healed)
	if shards > 0:
		parts.append("+%d Shard%s" % [shards, "" if shards == 1 else "s"])
	var text := "  ".join(parts)
	_sfx(MARK_SFX)
	_float(hero.get_parent(), text, UI.MARK_COLORS.ember if healed > 0 else UI.MARK_COLORS.shard)
	_log(text + ".")


func _sfx(stream: AudioStream) -> void:
	sfx.stream = stream
	sfx.play()


func _face_text(f: int) -> String:
	return "X" if f == Combat.CURSE else str(f)


## Plays the slash (assets/ui/cut/slash_*.png) over `at`, at the sprites' pixel size; `mirror` swings it the other way.
func _slash(at: Control, mirror := false) -> void:
	_sfx(HIT_SFX)
	var fx := TextureRect.new()
	fx.texture = load(UI.ART % "slash_0")
	fx.flip_h = mirror
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.size = fx.texture.get_size() * SPRITE_SCALE / 2  # the cut art is at 2x; sprites are at SPRITE_SCALE
	fx.position = (at.size - fx.size) / 2
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	at.add_child(fx)
	for f in range(1, 4):
		await get_tree().create_timer(EFFECT_FRAME).timeout
		if not is_instance_valid(fx):
			return
		fx.texture = load(UI.ART % ("slash_%d" % f))
	await get_tree().create_timer(EFFECT_FRAME).timeout
	if is_instance_valid(fx):
		fx.queue_free()


## A word or number that rises from the top of `at` and fades out.
func _float(at: Control, text: String, color: Color) -> void:
	var l := UI.label(at, 32, text)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2((at.size.x - l.get_minimum_size().x) / 2, at.size.y * 0.2)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 48, FLOAT_TIME).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, FLOAT_TIME).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(l.queue_free)


## A chunky down-pointing arrowhead in `color` with a dark outline and a lit upper-left edge, at the sprites' scale.
static func _arrow(color: Color) -> Texture2D:
	const W := 11
	const H := 7
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in range(y, W - y):
			var edge := y == 0 or x == y or x == W - 1 - y or y == H - 1
			img.set_pixel(x, y, Color("070e10") if edge else (color.lightened(0.4) if x == y + 1 or y == 1 else color))
	img.resize(W * SPRITE_SCALE, H * SPRITE_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Slides the crypt picture up or down so its floor runs under the fighters' feet, wherever the
## layout put them (taller enemies push everyone lower). Every frame: the layout settles over several,
## and moving a container emits no signal its children hear.
func _process(_delta: float) -> void:
	var holder: Control = hero.get_parent()
	var feet := holder.get_global_rect().end.y - SPRITE_PAD * SPRITE_SCALE - global_position.y
	var shift: float = feet - FEET_SINK - LEDGES[backdrop] * size.y
	crypt.offset_top = shift
	crypt.offset_bottom = shift
