extends SceneTree
## Plays whole fights on the real screens: every die into Attack, end turn, no blocking, until the
## fight hands back to game.gd. Fails on any engine or script error along the way, which the rules
## test can't see: rig animations, the combat screen, and the screen shown after the fight.
## Headless: godot --headless --path . -s tests/test_fight_flow.gd

const SPEED := 10.0  # runs animations, waits and the timing bar this many times faster
const TURN_LIMIT := 40
const SAVE := "user://test_fight_flow.json"  # never the player's real save

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
	await _play_events()
	await _hulk_swap()
	var late: Array = Floor.deal()[7]  # a dealt floor's last fight column, its biggest groups
	var mine: Array = [["miner"], ["crawler", "crawler", "crawler"], ["hulk", "canary"], ["rubble", "shaft_foreman"], ["shaft_foreman", "hulk", "crawler"], ["pit_king"]]
	for keys in Combat.FIGHTS + mine + late.filter(func(r): return r.kind == "fight").map(func(r): return r.enemies):
		await _play(keys)  # every set fight (all enemies are rigged now), plus dealt ones
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
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


## A Hulk dies on screen: its slot shows Rubble's name and HP, the log says so, no engine errors.
func _hulk_swap() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.combat.start_group(["hulk"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	screen.combat.enemies[0].hp = 3
	screen.combat.turn = 1  # the Hulk attacks instead of guarding, so any hit kills
	screen.combat.start_turn()
	for i in screen.combat.dice.size():
		screen.combat.assign(i, Combat.Slot.ATTACK)
	screen._on_end_turn()
	await create_timer(3.0).timeout
	check(screen.log_lines.any(func(l): return "collapses into Rubble" in l), "the log tells the Hulk fell to Rubble")
	check(screen.enemy_ui[0].hp.text.begins_with("Rubble") and screen.enemy_ui[0].bar.max_value == 8, "the slot shows Rubble's name and HP bar")
	check(errors.count == errors_before, "the Hulk swap runs with no errors")
	game.queue_free()
	await process_frame


## A game started straight onto a run's map, skipping the menu and the tutorial.
func _new_game() -> Node:
	var game: Node = load("res://main.tscn").instantiate()
	game.meta = Meta.load_from(SAVE)
	game.meta.tutorial_done = true
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
