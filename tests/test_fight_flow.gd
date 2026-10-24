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
	await _two_floors()
	await _mine_start()
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
