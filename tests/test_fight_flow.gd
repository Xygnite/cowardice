extends SceneTree
## Plays whole fights on the real screens: every die into Attack, end turn, no blocking, until the
## fight hands back to game.gd. Fails on any engine or script error along the way, which the rules
## test can't see: rig animations, the combat screen, and the screen shown after the fight.
## Headless: godot --headless --path . -s tests/test_fight_flow.gd

const SPEED := 10.0  # runs animations, waits and the timing bar this many times faster
const TURN_LIMIT := 40
const SAVE := "user://test_fight_flow.json"  # never the player's real save
const RUN := "user://test_fight_flow_run.json"  # nor the player's saved run

var failures := 0
var errors := ErrorCounter.new()


## Counts every error the engine reports, script errors included.
class ErrorCounter extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1


func _init() -> void:
	OS.add_logger(errors)
	Engine.time_scale = SPEED
	await _map_moves()
	await _fair_throws()
	await _gambler_throw()
	await _play_events()
	await _hulk_swap()
	await _two_floors()
	await _mine_start()
	await _fight_menu()
	await _campfire_save()
	await _new_run_asks()
	await _death_clears_save()
	var late: Array = Floor.deal()[7]  # a dealt floor's last fight column, its biggest groups
	var mine: Array = [["miner"], ["crawler", "crawler", "crawler"], ["hulk", "canary"], ["rubble", "shaft_foreman"], ["shaft_foreman", "hulk", "crawler"], ["pit_king"]]
	for keys in Combat.FIGHTS + mine + late.filter(func(r): return r.kind == "fight").map(func(r): return r.enemies):
		await _play(keys)  # every set fight (all enemies are rigged now), plus dealt ones
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	RunSave.erase(RUN)
	print("FAILED: %d" % failures if failures else "All fight-flow checks passed.")
	quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)


## Menu, camp and fight each put exactly one BackdropLife on their backdrop, however often shown.
func _screens_with_life() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.combat.start_group(Combat.FIGHTS[0])
	var shows := {
		"menu": game._show_menu, "camp": game._show_camp,
		"fight": func(): game._show_fight(game._on_fight_finished),
	}
	for art: String in shows:
		for i in 2:
			shows[art].call()
			await process_frame
			var lives := 0
			for r in game.screen.get_children().filter(func(c): return c is TextureRect):
				lives += r.get_children().filter(func(c): return c is BackdropLife).size()
			check(lives == 1, "%s shows exactly one BackdropLife (got %d)" % [art, lives])
	await create_timer(0.5).timeout
	check(errors.count == errors_before, "backdrop life screens show with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## The drawn map: only the rooms linked from the last one taken can be entered.
func _map_moves() -> void:
	var errors_before := errors.count
	var game: Node = load("res://main.tscn").instantiate()
	game.meta = Meta.load_from(SAVE)
	game.meta.tutorial_done = true
	game.run_path = RUN
	root.add_child(game)
	await process_frame
	game._start_run()
	await process_frame
	var screen: MapScreen = game.screen
	check(screen.pickable() == [0], "the entrance is the only room on column 0")
	_check_buttons(screen)
	var p: int = game.map[0][0].next[0]
	game.layer = 2
	game.path = [0, p]
	game._show_map()
	await process_frame
	screen = game.screen
	var want: Array = game.map[1][p].next
	check(screen.pickable() == want, "after room %d the pickable rooms are its links %s" % [p, want])
	_check_buttons(screen)
	await process_frame
	check(game.layer == 2, "the map alone doesn't move the player on")
	check(errors.count == errors_before, "the map shows with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


func _check_buttons(screen: MapScreen) -> void:
	var ok := true
	for c in screen.room_buttons.size():
		for i in screen.room_buttons[c].size():
			var should: bool = c == screen.layer and i in screen.pickable()
			ok = ok and screen.room_buttons[c][i].disabled != should
	check(ok, "only pickable rooms are enabled")


## Starts a run straight into a fight against `keys`, as the --fight dev shortcut does, and plays it out.
func _play(keys: Array) -> void:
	var fight := ", ".join(keys)
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.combat.start_group(keys)
	game._show_fight(game._on_fight_finished)
	await _fight_out(game, fight)
	await create_timer(0.5).timeout  # let the next screen settle, so its errors count too
	check(errors.count == errors_before, "fight %s plays through with no errors (got %d)" % [fight, errors.count - errors_before])
	game.queue_free()
	await process_frame


## Plays the fight on screen to its end: every die into Attack, end turn.
func _fight_out(game: Node, fight: String) -> void:
	var turns := 0
	while game.screen is CombatScreen and turns < TURN_LIMIT:
		var screen: CombatScreen = game.screen
		if not screen.busy:
			for i in screen.combat.dice.size():
				screen.combat.assign(i, Combat.Slot.ATTACK)
			screen._on_end_turn()
			turns += 1
		await process_frame
	check(not game.screen is CombatScreen, "fight %s ends within %d turns" % [fight, TURN_LIMIT])
	print("fight %s: %d turns, %s" % [fight, turns, "won" if game.combat.fight_won() else "lost"])


## The value drawn on die i's highest side, as the camera sees it: the label sitting highest in the world.
func _drawn(tray: DiceTray, i: int) -> int:
	var top: Label3D = tray.dice[i].labels[0]
	for l: Label3D in tray.dice[i].labels:
		if l.global_position.y > top.global_position.y:
			top = l
	return Combat.CURSE if top.text == "X" else int(top.text)


func _all_drawn(screen: CombatScreen) -> bool:
	return range(screen.combat.dice.size()).all(func(i): return screen.combat.dice[i].value == _drawn(screen.tray, i))


## Every throw on the real screen is fair: each die's value is the face drawn on its top, a forged and
## cursed die included, and no steering torque touches the dice, except on the tutorial's pair turn,
## which still lands its pair.
func _fair_throws() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.combat.dice[0].base = [1, 1, 2, Combat.CURSE, 5, 6]
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	for throw in 3:  # the opening throw, then two rerolls
		if throw > 0:
			screen._on_reroll()
		check(screen.busy and screen.summary_label.text == "Rolling...", "throw %d: the screen waits for the dice" % throw)
		while screen.busy:
			await process_frame
		check(_all_drawn(screen), "throw %d: every die's value is the face drawn on its top" % throw)
	check(screen.tray.torques == 0, "fair throws are never steered (got %d pushes)" % screen.tray.torques)
	screen.combat.start_group(["dummy"])
	screen.combat.turn = screen.combat.enemies[0].type.rig_pair_turn
	screen.combat.start_turn()
	screen._roll_anim(range(screen.combat.dice.size()), screen.combat.rigged_turn())
	while screen.busy:
		await process_frame
	check(screen.combat.dice[0].value == screen.combat.dice[1].value, "the tutorial's pair turn still lands a pair")
	check(_all_drawn(screen), "and the pair is what the dice show")
	check(errors.count == errors_before, "fair throws run with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## The gambler's throw: the totals it pays on are the faces drawn on top, the skull's three dice included.
func _gambler_throw() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.combat.shards = Events.GAMBLER_BET
	game.combat.dice[0].faces = [1, 1, 2, Combat.CURSE, 5, 6]
	game._show_event("gambler")
	await process_frame
	var s: EventScreen = game.screen
	s.choose(0)
	while s.busy:
		await process_frame
	var mine := 0
	var skull := 0
	for i in 3:
		mine += _drawn(s.tray, i)
		skull += _drawn(s.tray, i + 3)
	check(s.text.text.begins_with("You %d, the skull %d." % [mine, skull]), "the gambler pays on the drawn faces (%d vs %d): %s" % [mine, skull, s.text.text])
	check(errors.count == errors_before, "the gambler's throw runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## A Hulk dies on screen: its slot shows Rubble's name and HP, the log says so, no engine errors.
func _hulk_swap() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.combat.start_group(["hulk"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	while screen.busy:  # the opening throw lands first
		await process_frame
	screen.combat.enemies[0].hp = 3
	screen.combat.turn = 1  # the Hulk attacks instead of guarding, so any hit kills
	screen.combat.start_turn()
	for i in screen.combat.dice.size():
		screen.combat.assign(i, Combat.Slot.ATTACK)
	screen._on_end_turn()
	await create_timer(3.0).timeout
	check(screen.log_lines.any(func(l): return "collapses into Rubble" in l), "the log tells the Hulk fell to Rubble")
	for i in screen.combat.dice.size():
		screen.combat.assign(i, Combat.Slot.NONE)  # a quiet second turn
	screen._on_end_turn()
	await create_timer(4.0).timeout
	check(screen.log_lines.filter(func(l): return "collapses into Rubble" in l).size() == 1, "the collapse is logged once, not every turn")
	check(screen.enemy_ui[0].hp.text.begins_with("Rubble") and screen.enemy_ui[0].bar.max_value == 8, "the slot shows Rubble's name and HP bar")
	check(errors.count == errors_before, "the Hulk swap runs with no errors")
	game.queue_free()
	await process_frame


## A run beats the Warden, picks a bonus perk, rests at a campfire, walks into the Mine with what it had,
## and beating the Pit King pays for the rooms of both floors.
func _two_floors() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.layer = game.map.size() - 1
	game.combat.start_group(["warden"])
	game._show_fight(game._on_fight_finished)
	game.combat.enemies[0].hp = 1
	await _fight_out(game, "warden at 1 HP")
	check(game.screen is PerkPickScreen, "beating the Warden offers a bonus perk")
	if not game.screen is PerkPickScreen:
		game.queue_free()
		return
	check(Meta.load_from(SAVE).mine_unlocked, "beating the Warden unlocks the Mine, saved")
	var pick: PerkPickScreen = game.screen
	check(pick.choices.size() == 3 and not pick.choices.any(func(p): return p in game.combat.perks), "the pick offers 3 perks, none equipped")
	var hp: int = game.combat.player_hp
	var shards: int = game.combat.shards
	var id: String = pick.choices.filter(func(p): return p != "thick_skin")[0]
	var buttons: Array = pick.find_children("*", "Button", true, false)
	buttons[pick.choices.find(id)].pressed.emit()
	await process_frame
	check(game.screen is NoticeScreen and game.screen.title == "Campfire", "after the pick comes a campfire")
	check(id in game.combat.perks, "the picked perk is active")
	var heal: int = game.combat.campfire_heal_amount()
	game.screen.choices[0][1].call()  # Rest
	await process_frame
	check(game.screen is MapScreen and game.screen.title == "The Hollow Mine" and game.layer == 0, "then the Mine's map, from its entrance")
	check(game.combat.player_hp == mini(game.combat.max_hp, hp + heal) and game.combat.shards == shards, "HP and Shards carry down")
	check(game.combat.dungeon_turns == 0, "the Mine's murmurs start from their first line")
	game.layer = game.map.size() - 1
	game.combat.start_group(["pit_king"])
	game._show_fight(game._on_fight_finished)
	check(game.screen.backdrop == "mine", "Mine fights ask for the Mine backdrop")
	check(game.screen.fight_label.text == "Boss" and game.screen.murmur_label.text == "", "the Pit King's fight says Boss, no murmurs")
	game.combat.enemies[0].hp = 1
	var embers: int = game.meta.embers
	await _fight_out(game, "pit king at 1 HP")
	var want: int = Meta.embers_for(game.combat.kills, 2 * game.map.size(), 100, true)
	check(game.screen is NoticeScreen and game.screen.title == "The Pit King falls.", "beating the Pit King wins the run")
	check(game.meta.embers - embers == want, "the win pays rooms from both floors and +100 (got %d, want %d)" % [game.meta.embers - embers, want])
	check(game.screen is NoticeScreen and "Depth reached: The Hollow Mine, room 10 of 10" in game.screen.lines, "the tally names the floor")
	await create_timer(0.5).timeout
	check(errors.count == errors_before, "two floors play through with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## Once the Mine is unlocked the camp can start a run there, without a bonus perk.
func _mine_start() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.meta.mine_unlocked = true
	game._show_camp()
	await process_frame
	var buttons: Array = game.screen.find_children("*", "Button", true, false)
	buttons.filter(func(b): return b.text == "Start run")[0].pressed.emit()
	await process_frame
	var pick: Array = game.screen.find_children("*", "FloorPanel", true, false)
	check(pick.size() == 1, "Start run opens the floor window once the Mine is unlocked")
	var floors: Array = pick[0].find_children("*", "Button", true, false)
	floors.filter(func(b): return b.text == "The Hollow Mine")[0].pressed.emit()
	await process_frame
	check(game.screen is MapScreen and game.screen.title == "The Hollow Mine" and game.floor_id == "mine", "the camp starts a run in the Mine")
	check(game.combat.bonus_perk == "" and game.rooms_before == 0, "a Mine start has no bonus perk")
	game.combat.start_group(["miner"])
	game._show_fight(game._on_fight_finished)
	await process_frame
	check(game.screen.crypt.texture.resource_path == "res://assets/ui/bg_mine.webp", "Mine fights show the Mine backdrop")
	check(game.screen.fight_label.text == "Mine", "a Mine fight is labelled Mine, got %s" % game.screen.fight_label.text)
	check(game.screen.murmur_label.text == CombatScreen.MURMURS.mine[0], "a Mine fight murmurs the Mine's lines")
	game._show_tutorial()
	await process_frame
	check(game.screen.backdrop == "fight", "the replayed tutorial shows the fight backdrop after a Mine run, got %s" % game.screen.backdrop)
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "a Mine start shows with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## A game started straight onto a run's map, skipping the menu and the tutorial.
func _new_game() -> Node:
	var game: Node = load("res://main.tscn").instantiate()
	game.meta = Meta.load_from(SAVE)
	game.meta.tutorial_done = true
	game.run_path = RUN
	root.add_child(game)
	await process_frame  # the tree only runs the game's _ready once the main loop is going
	game._start_run()
	await process_frame
	return game


## Every "?" event on the real screens: the first choice, its dice, then any forge or carve screens it
## grants (first enabled face), back to the map. Plus one ambush, which pays Shards on a win.
func _play_events() -> void:
	for id: String in Events.IDS:
		var errors_before := errors.count
		var game: Node = await _new_game()
		game.combat.shards = Events.GAMBLER_BET  # enough for the gambler's bet
		game._show_event(id)
		var steps := 0
		while not game.screen is MapScreen and steps < 3000:
			var s: Node = game.screen
			if s is EventScreen and not s.busy:
				var go: Array = s.choice_row.get_children().filter(func(b): return b.text == "Go on")
				if go.is_empty():
					s.choose(0)
				else:
					go[0].pressed.emit()
			elif s is ForgeScreen:
				for b: Button in s.face_buttons.reduce(func(a, r): return a + r, []):
					if not b.disabled:
						b.pressed.emit()
						break
			steps += 1
			await process_frame
		check(game.screen is MapScreen, "event %s goes back to the map" % id)
		check(game.seen_events == [id], "event %s is marked seen" % id)
		await create_timer(0.3).timeout
		check(errors.count == errors_before, "event %s plays through with no errors (got %d)" % [id, errors.count - errors_before])
		game.queue_free()
		await process_frame
	var errors_before := errors.count
	var game: Node = await _new_game()
	var shards: int = game.combat.shards
	game._start_ambush()
	check(game.ambush, "an ambush is flagged")
	await _fight_out(game, "ambush")
	var won: bool = game.combat.fight_won()
	check(not won or game.combat.shards >= shards + Events.AMBUSH_SHARDS, "a won ambush pays at least %d Shards" % Events.AMBUSH_SHARDS)
	check(not game.ambush, "the ambush flag resets after the fight")
	await create_timer(0.5).timeout
	check(errors.count == errors_before, "the ambush plays through with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


func _press(key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = true
	root.push_input(ev)
	await process_frame


func _button(under: Node, text: String) -> Button:
	var found: Array = under.find_children("*", "Button", true, false).filter(func(b): return b.text == text)
	return found[0] if found.size() == 1 else null


func _overlays(game: Node, type: String) -> Array:
	return game.screen.find_children("*", type, true, false)


## Esc or the Menu button pauses a fight on the player's turn: no keys or clicks reach the fight behind it.
## Quitting from it (after a confirm) goes to the main menu with no Embers and no saved run.
func _fight_menu() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	var embers: int = game.meta.embers
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	await process_frame
	check(screen.busy, "the opening throw is still rolling")
	await _press(KEY_ESCAPE)
	check(_overlays(game, "FightMenu").is_empty(), "the menu doesn't open while the dice roll")
	while screen.busy:
		await process_frame
	await _press(KEY_ESCAPE)
	check(_overlays(game, "FightMenu").size() == 1, "Esc opens the fight menu on the player's turn")
	var rerolls: int = screen.combat.rerolls
	var dice: Array = screen.combat.dice.map(func(d): return d.value)
	await _press(KEY_R)
	await _press(KEY_ENTER)
	screen._on_die_clicked(0)
	await process_frame
	check(screen.combat.rerolls == rerolls and screen.combat.dice.map(func(d): return d.value) == dice, "R doesn't reroll behind the menu")
	check(screen.combat.turn == 0 and screen.acting == -1 and not screen.timing.running, "Enter doesn't end the turn behind the menu")
	check(not screen.die_menu.visible, "a die click opens nothing behind the menu")
	check(screen.menu_button.disabled and screen.end_button.disabled, "the fight's buttons are off while it is open")
	await _press(KEY_ESCAPE)
	await process_frame
	check(_overlays(game, "FightMenu").is_empty() and not screen.busy, "Esc again closes it and hands the turn back")
	screen.menu_button.pressed.emit()
	await process_frame
	var menu: FightMenu = _overlays(game, "FightMenu")[0]
	_button(menu, "Settings").pressed.emit()
	await process_frame
	check(_overlays(game, "SettingsPanel").size() == 1, "Settings opens from the fight menu")
	await _press(KEY_ESCAPE)
	await process_frame
	check(_overlays(game, "SettingsPanel").is_empty() and _overlays(game, "FightMenu").size() == 1, "Esc closes Settings, back to the fight menu")
	_button(menu, "Quit to main menu").pressed.emit()
	await process_frame
	var ask: Array = _overlays(game, "ConfirmPanel")
	check(ask.size() == 1 and game.screen == screen, "Quit asks first")
	_button(ask[0], "Back  [Esc]").pressed.emit()
	await process_frame
	check(_overlays(game, "ConfirmPanel").is_empty() and game.screen == screen, "Back stays in the fight")
	_button(menu, "Quit to main menu").pressed.emit()
	await process_frame
	_button(_overlays(game, "ConfirmPanel")[0], "Quit to main menu").pressed.emit()
	await process_frame
	check(game.screen is MenuScreen, "quitting goes to the main menu")
	check(not RunSave.exists(RUN) and _button(game.screen, "Continue") == null, "quitting leaves no saved run")
	check(game.meta.embers == embers and Meta.load_from(SAVE).embers == embers, "quitting pays no Embers")
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "the fight menu runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## A run part way along the Chapel map, standing at a campfire on column 3.
func _at_campfire(game: Node) -> void:
	game.path = [0]
	for c in range(1, 4):
		game.path.append(game.map[c - 1][game.path[-1]].next[0])
	game.layer = 3
	game.combat.player_hp = 17
	game.combat.shards = 9
	game.combat.forge(0, 0, true)
	game.combat.curse_face(1, 5)
	game.seen_events.append(Events.IDS[0])
	game._show_campfire("room")
	await process_frame


func _snapshot(game: Node) -> Dictionary:
	return {"combat": game.combat.to_dict(), "map": game.map.duplicate(true), "layer": game.layer, "path": game.path.duplicate(),
		"floor_id": game.floor_id, "seen_events": game.seen_events.duplicate(), "rooms_before": game.rooms_before}


func _continue(game: Node) -> void:
	game._show_menu()
	await process_frame
	var go := _button(game.screen, "Continue")
	check(go != null, "the main menu offers Continue while a run is saved")
	if go:
		go.pressed.emit()
	await process_frame


## Save and quit at a campfire, then Continue: the same campfire, the same run, and both its choices still work.
func _campfire_save() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	await _at_campfire(game)
	check(game.screen is NoticeScreen and game.screen.choices.size() == 3 and game.screen.choices[2][0] == "Save and quit", "the campfire offers Save and quit")
	var was := _snapshot(game)
	_button(game.screen, "Save and quit").pressed.emit()
	await process_frame
	check(game.screen is MenuScreen and RunSave.exists(RUN), "Save and quit saves and goes to the main menu")
	game.combat = Combat.new()  # forget the run, so only the save can bring it back
	game.map = []
	game.layer = 0
	game.path = []
	game.floor_id = "mine"
	await _continue(game)
	check(game.screen is NoticeScreen and game.screen.title == "Campfire" and game.screen.choices.size() == 3, "Continue comes back to the campfire")
	check(_snapshot(game) == was, "HP, Shards, dice, perks, map, layer, path and floor come back as saved")
	var heal: int = game.combat.campfire_heal_amount()
	game.screen.choices[0][1].call()  # Rest
	await process_frame
	check(game.screen is MapScreen and game.layer == 4 and game.combat.player_hp == 17 + heal, "Rest still heals and moves on")
	await _continue(game)
	check(game.combat.player_hp == 17, "the save is from before the rest")
	game.screen.choices[1][1].call()  # Tend the dice
	await process_frame
	check(game.screen is ForgeScreen and game.screen.no_cost, "Tend the dice still gives a free upgrade")
	if game.screen is ForgeScreen:
		game.screen.face_buttons[2][0].pressed.emit()
		await process_frame
	check(game.screen is MapScreen and game.layer == 4 and game.combat.dice[2].base[0] == 1 + Combat.FORGE_STEP, "and moves on, forged")
	game.layer = game.map.size() - 1  # the stop between the Warden and the Mine
	game.rooms_before = game.map.size()
	game.combat.add_perk("bonfire_keeper")
	game._show_campfire("mine")
	await process_frame
	_button(game.screen, "Save and quit").pressed.emit()
	await process_frame
	await _continue(game)
	game.screen.choices[0][1].call()
	await process_frame
	check(game.screen is MapScreen and game.screen.title == "The Hollow Mine" and game.layer == 0, "a save on the way down continues into the Mine")
	check(game.rooms_before > 0 and game.combat.bonus_perk == "bonfire_keeper", "with the bonus perk and the Chapel's rooms kept")
	var bad := RunSave.read(RUN)
	bad.combat.dice.pop_back()
	RunSave.write(bad, RUN)
	check(game._saved_run().is_empty(), "a save that can't be loaded counts as none, so the menu shows no Continue")
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "saving and continuing run with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## With a run saved, starting another asks first; backing out keeps the save, going ahead deletes it.
func _new_run_asks() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	await _at_campfire(game)
	game.screen.choices[2][1].call()
	await process_frame
	_button(game.screen, "Tutorial").pressed.emit()
	await process_frame
	check(_overlays(game, "ConfirmPanel").size() == 1 and game.screen is MenuScreen, "the tutorial asks before replacing a saved run")
	_button(_overlays(game, "ConfirmPanel")[0], "Back  [Esc]").pressed.emit()
	game.meta.mine_unlocked = false  # straight into the Chapel, no floor window
	game._show_camp()
	await process_frame
	_button(game.screen, "Start run").pressed.emit()
	await process_frame
	var ask: Array = _overlays(game, "ConfirmPanel")
	check(ask.size() == 1 and game.screen is CampScreen, "Start run asks before replacing a saved run")
	_button(ask[0], "Back  [Esc]").pressed.emit()
	await process_frame
	check(game.screen is CampScreen and RunSave.exists(RUN), "backing out keeps the save")
	_button(game.screen, "Start run").pressed.emit()
	await process_frame
	_button(_overlays(game, "ConfirmPanel")[0], "Start a new run").pressed.emit()
	await process_frame
	check(game.screen is MapScreen and game.layer == 0 and not RunSave.exists(RUN), "going ahead starts a new run and deletes the save")
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "the overwrite confirm runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## Dying after continuing deletes the save, so reloading can't undo the loss.
func _death_clears_save() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	await _at_campfire(game)
	game.screen.choices[2][1].call()
	await process_frame
	await _continue(game)
	game.combat.player_hp = 1
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	await _fight_out(game, "skeleton at 1 HP")
	check(game.screen is NoticeScreen and game.screen.title == "You fled.", "the run is lost")
	check(not RunSave.exists(RUN), "the saved run is gone after a death")
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "a death after continuing runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame
