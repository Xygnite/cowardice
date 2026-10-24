class_name CombatScreen
extends Control
## One fight on screen, built in code. The hero and enemies with a sprite are rigs from scenes/
## (made by tools/rig_sprites.gd); enemies without one are placeholder boxes.
## Rules are taught only in the tutorial fight; a floor's boss is hinted at only by murmurs in the fights before him.
## Keys: R reroll, Enter end turn, Space block/parry during the enemy wind-up. Click an enemy to target it,
## a die for its actions (lock, place).

signal finished(won: bool)

const SLOT_NAMES := ["-", "Attack", "Guard", "Cleave"]
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
const HIT_SFX := preload("res://assets/audio/hit.wav")
const BLOCK_SFX := preload("res://assets/audio/block.wav")

## One lesson per tutorial turn, indexed by Combat.turn.
const LESSONS := [
	"Above the dummy is what it will do this turn. Click a die to lock it or place it. Lock the dice you like, reroll the rest, then put a die in Attack and end the turn.",
	"Put a die in Guard. When the dummy swings, press SPACE as the marker reaches the blue zone. The later you press, the better the block.",
	"Two of your dice match. Put both in Cleave: a pair strikes harder and slips past any guard.",
	"Leave one die unplaced. It becomes Grit: one extra reroll next turn.",
	"Red means no shield will hold. Put a die in Guard and press SPACE inside the red zone to parry. A higher die gives you more time.",
]

## Cryptic hints about the floor's boss (Bone Warden, Pit King), one per turn across the fights before him, by backdrop.
const MURMURS := {"fight": [
	"The walls murmur: \"...he keeps the tallest bone for himself...\"",
	"The walls murmur: \"...two of a kind walk where one cannot...\"",
	"The walls murmur: \"...when he cracks in half, he writes on your bones...\"",
	"The walls murmur: \"...hold the stained bone to your shield, and it burns clean...\"",
	"The walls murmur: \"...at the last, he swings what no shield can hold...\"",
], "mine": [
	"The timbers creak: \"...the King keeps what the mountain takes...\"",
	"The timbers creak: \"...when the roof speaks, one die goes under...\"",
	"The timbers creak: \"...the rock gives back what it buries, in time...\"",
	"The timbers creak: \"...he never takes the last one. He wants you digging...\"",
	"The timbers creak: \"...wounded, he brings the roof down with every swing...\"",
]}

var combat: Combat  # set by game.gd before the screen enters the tree
var backdrop := "fight"  # the floor's fight picture, assets/ui/bg_<backdrop>.webp; set by game.gd
var busy := false  # true while the dice are in the air or the enemies act, and after the fight ends
var rolling: Array = []  # indices of the dice in the air; their values aren't known until they land
var acting := -1  # enemy currently acting, highlighted

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
var murmur_label: Label
var lesson_label: Label
var tray: DiceTray
var die_menu: PopupMenu
var menu_die := 0  # die the open action menu acts on
var faces_button: Button
var faces_popup: PopupPanel
var faces_label: Label
var summary_label: Label
var reroll_button: Button
var end_button: Button
var timing_hint: Label
var timing: TimingBar
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
	_roll_anim(range(combat.dice.size()), combat.rigged_turn())


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
	var dealt := combat.resolve_player()
	_log("You deal %d." % dealt)
	if dealt > 0:
		await _play(hero, "attack")
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
		_roll_anim(range(combat.dice.size()).filter(func(i): return combat.dice[i].buried == 0), combat.rigged_turn())


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
		ui.hp.text = "%s  %d/%d" % [e.name, e.hp, e.type.hp] if up else e.name + "  down"
		ui.bar.value = e.hp
		ui.mark.texture = ACTING_ARROW if i == acting else TARGET_ARROW
		ui.mark.modulate.a = 1.0 if i == acting or (i == combat.target and up) else 0.0
	lesson_label.visible = combat.is_tutorial() and combat.turn < LESSONS.size()
	if lesson_label.visible:
		lesson_label.text = LESSONS[combat.turn]
	# Blank rather than hidden: the murmur label is the gap that pushes the enemies to the right.
	var murmurs := not combat.is_tutorial() and not combat.is_boss_fight()
	var lines: Array = MURMURS[backdrop]
	murmur_label.text = lines[mini(combat.dungeon_turns, lines.size() - 1)] if murmurs else ""
	for i in combat.dice.size():
		var d: Dictionary = combat.dice[i]
		var art := "cursed" if d.value == Combat.CURSE and i not in rolling else ("locked" if d.locked else ("placed" if d.slot != Combat.Slot.NONE else "bone"))
		tray.show_die(i, d.faces, d.value, art, SLOT_ICONS[d.slot], d.locked, d.buried > 0)
	var pair := "   Pair of %ds" % combat.rolled_pair() if combat.rolled_pair() else ""
	summary_label.text = "Rolling..." if rolling else "Damage %d   Guard %d   Grit +%d%s" % [combat.preview_damage(), combat.guard_total(), combat.unplaced_count(), pair]
	summary_label.add_theme_color_override("font_color", UI.GOLD if combat.rolled_pair() and not combat.cleave_ready() and not rolling else Color.WHITE)
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

	summary_label = UI.label(root, 18)

	# The dice row has a set height (tray_height) and the fight row above takes what is left, so the
	# dice box, which the throw's walls are sized to, is the same in every fight.
	bottom_row = UI.row(root, 24)
	bottom_row.custom_minimum_size.y = tray_height
	_build_dice(bottom_row)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 280
	bottom_row.add_child(actions)
	reroll_button = UI.button(actions, "", _on_reroll)
	reroll_button.custom_minimum_size.y = 56
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
	bar.max_value = combat.enemies[i].type.hp
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
	ui.bar.max_value = combat.enemies[i].type.hp
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
	var d: Dictionary = combat.dice[i]
	menu_die = i
	die_menu.clear()
	die_menu.add_item("Unlock" if d.locked else "Lock", MENU_LOCK)
	die_menu.add_separator()
	for slot in [Combat.Slot.ATTACK, Combat.Slot.GUARD, Combat.Slot.CLEAVE]:
		die_menu.add_radio_check_item(SLOT_NAMES[slot], slot)
		die_menu.set_item_checked(die_menu.item_count - 1, d.slot == slot)
	die_menu.add_item("Unplace", Combat.Slot.NONE)
	die_menu.set_item_disabled(die_menu.item_count - 1, d.slot == Combat.Slot.NONE)
	var r := tray.die_rect(i)
	die_menu.reset_size()
	die_menu.popup(Rect2i(Vector2i(r.end.x + 4, r.position.y), die_menu.size))


func _on_die_menu(id: int) -> void:
	if id == MENU_LOCK:
		_on_lock(menu_die)
	else:
		_on_assign(menu_die, id)


func _show_faces() -> void:
	var lines := []
	for i in combat.dice.size():
		lines.append("Die %d:  %s" % [i + 1, "  ".join(combat.dice[i].faces.map(_face_text))])
	faces_label.text = "\n".join(lines)
	faces_popup.reset_size()
	faces_popup.popup(Rect2i(Vector2i(faces_button.get_global_rect().end), faces_popup.size))


## Throws the dice at `which` (indices); the faces they land on become their values. Until then the
## screen is busy, so nothing acts on Combat's provisional roll. `steer` lands them on that roll instead.
func _roll_anim(which: Array, steer := false) -> void:
	busy = true
	rolling = which
	tray.throw(which, steer)  # first, so the refresh doesn't square resting dice onto the provisional roll
	_refresh()
	await tray.landed
	for i in which:
		combat.dice[i].value = tray.dice[i].value
	rolling = []
	busy = false
	_refresh()


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
