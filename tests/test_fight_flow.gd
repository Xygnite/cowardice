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
	ChargeBar.auto = true  # nobody here to hold SPACE
	await _map_moves()
	await _fair_throws()
	await _dice_in_hand()
	await _guided_tutorial()
	await _gambler_throw()
	await _play_events()
	await _hulk_swap()
	await _relic_picks()
	await _fight_belt()
	await _belt_row()
	await _two_floors()
	await _mine_start()
	await _fight_menu()
	await _menu_before_throw()
	await _map_menu()
	await _quick_dice()
	await _campfire_save()
	await _new_run_asks()
	await _death_clears_save()
	await _choices_ask()
	await _camp_board()
	var late: Array = Floor.deal()[7]  # a dealt floor's last fight column, its biggest groups
	var mine: Array = [["miner"], ["crawler", "crawler", "crawler"], ["hulk", "canary"], ["rubble", "shaft_foreman"], ["shaft_foreman", "hulk", "crawler"], ["pit_king"]]
	# Every set fight but the tutorial (_guided_tutorial plays that one), plus dealt ones.
	for keys in Combat.FIGHTS.slice(1) + mine + late.filter(func(r): return r.kind == "fight").map(func(r): return r.enemies):
		await _play(keys)
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
## cursed die included.
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
	var lit := func(i): return screen.tray.dice[i].halo.visible
	screen.combat.skills = ["cleave"]
	for i in 3:
		screen.combat.dice[i].value = [4, 6, 4][i]
		screen.combat.dice[i].slot = Combat.Slot.NONE
	screen._refresh()
	check(lit.call(0) and not lit.call(1) and lit.call(2), "unplaced dice that make a pair (Cleave) glow, and only they do")
	screen.combat.dice[2].value = 5
	screen._refresh()
	check(not (lit.call(0) or lit.call(1) or lit.call(2)), "no die glows when no skill is in reach")
	check(errors.count == errors_before, "fair throws run with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## A turn's dice stay in the hand until its opening throw: none on the felt, none glowing, no damage
## shown while the roll waits; a reroll's dice stay where they lie.
func _dice_in_hand() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	ChargeBar.auto = false
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	await process_frame
	var shown := func(): return range(3).filter(func(i): return screen.tray.dice[i].body.visible or screen.tray.dice[i].halo.visible)
	check(shown.call().is_empty() and screen.summary_label.text == "Rolling...", "the fight opens with the dice in hand (showing %s)" % [shown.call()])
	screen.charge.press(true)
	screen.charge.press(false)
	while screen.busy:
		await process_frame
	check(range(3).all(func(i): return screen.tray.dice[i].body.visible), "the opening throw puts every die on the felt")
	screen._on_roll_key(true)  # a reroll winds up from the dice where they lie
	await process_frame
	check(range(3).all(func(i): return screen.tray.dice[i].body.visible), "a reroll waiting on the press leaves the dice in view")
	screen.charge.press(false)
	while screen.busy:
		await process_frame
	screen.combat.enemies[0].hp = 999  # survives the turn so the next one opens
	screen._on_end_turn()
	while screen.combat.turn == 0 or not screen.charge.waiting:
		await process_frame
	check(shown.call().is_empty(), "the next turn's dice are back in hand until thrown (showing %s)" % [shown.call()])
	screen.charge.press(true)
	screen.charge.press(false)
	while screen.busy:
		await process_frame
	ChargeBar.auto = true
	check(errors.count == errors_before, "dice in hand run with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## The tutorial throws nothing: each turn's dice lie set on the felt, the screen goes dark but for one
## spotlit target, only that target answers (other dice, End turn, R and Enter do nothing), and doing
## each step in turn plays all five lessons through to the run.
func _guided_tutorial() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.meta.tutorial_done = false
	game._show_tutorial()
	var screen: CombatScreen = game.screen
	for i in 3:
		await process_frame
	var values := func(): return screen.combat.dice.map(func(d): return d.value)
	check(values.call() == [5, 2, 3] and range(3).all(func(i): return screen.tray.dice[i].body.visible), "the first lesson's dice lie on the felt: 5, 2, 3")
	check(not screen.reroll_button.visible and not screen.busy, "no Roll button and no throw in the tutorial")
	check(screen.guide.visible and screen._tutorial_step().until == "next", "the first step explains, with a Next button")
	screen.guide.next_button.pressed.emit()
	screen.guide.next_button.pressed.emit()
	var step: Dictionary = screen._tutorial_step()
	check(step.until == "place" and step.die == 0, "the third step asks for the 5 in Attack")
	var hole: Rect2 = screen.tray.die_rect(0)
	check(not screen.guide._has_point(hole.get_center()) and screen.guide._has_point(Vector2(4, 4)), "the spotlit die takes clicks; the dark screen around it doesn't")
	screen._on_die_clicked(1)
	screen._on_left_released()
	screen._on_end_turn()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	screen._unhandled_input(enter)
	check(screen.combat.dice[1].slot == Combat.Slot.NONE and screen.combat.turn == 0 and not screen.busy, "other dice, End turn and Enter do nothing off the step")
	var timing_steps := 0
	var guard := 0
	while game.screen is CombatScreen and guard < 400:
		guard += 1
		step = screen._tutorial_step()
		if screen.guide.visible and screen.guide.panel.visible and step.get("until") == "timing":
			timing_steps += 1
			screen.guide.next_button.pressed.emit()  # the bar then runs out unanswered: a miss
		elif not screen.busy and screen.guide.visible:
			match step.until:
				"next":
					screen.guide.next_button.pressed.emit()
				"place":
					if screen.combat.turn == 2 and step.die == 0:
						check(values.call() == [6, 6, 1], "the Cleave lesson deals a pair of 6s")
					screen._on_die_clicked(step.die)
					screen._on_left_released()
				"end":
					screen._on_end_turn()
		await process_frame
	check(timing_steps == 2, "a block and a parry are each explained before their bar (got %d)" % timing_steps)
	check(not game.screen is CombatScreen and game.meta.tutorial_done, "doing every step finishes the tutorial")
	check(errors.count == errors_before, "the guided tutorial runs with no errors (got %d)" % (errors.count - errors_before))
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
	check(game.screen is RelicPickScreen and game.screen.rarity == "rare" and game.screen.title == "The Warden's hoard", "beating the Warden first offers his hoard")
	if game.screen is RelicPickScreen:
		check(game.screen.choices.size() == 3 and game.screen.choices.all(func(id): return Combat.RELICS[id].rare), "the hoard is three rares")
		_button(game.screen, "Leave").pressed.emit()
		_agree(game)
		await process_frame
	check(game.screen is PerkPickScreen, "then a bonus perk")
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
	_agree(game)
	await process_frame
	check(game.screen is NoticeScreen and game.screen.title == "Campfire", "after the pick comes a campfire")
	check(id in game.combat.perks, "the picked perk is active")
	var heal: int = game.combat.campfire_heal_amount()
	game._save_and_quit("mine")
	game._continue_run()
	check(game.world() == 2, "a continued run keeps its world")
	game.screen.choices[0][1].call()  # Rest
	_agree(game)
	await process_frame
	check(game.screen is MapScreen and game.screen.title == "The Hollow Mine" and game.layer == 0, "then the Mine's map, from its entrance")
	check(game.combat.player_hp == mini(game.combat.max_hp, hp + heal) and game.combat.shards == shards, "HP and Shards carry down")
	check(game.combat.dungeon_turns == 0, "the Mine's murmurs start from their first line")
	game._start_ambush()
	check(game.combat.enemies.all(func(e): return e.max == ceili(e.type.hp * 1.8)), "a world-2 ambush takes the factor")
	game.ambush = false
	game.layer = game.map.size() - 1
	game._on_room_picked(0)
	check(game.world() == 2, "the Mine after the Chapel is world 2")
	check(game.combat.enemies[0].max == ceili(220 * 1.8), "the Pit King in world 2 has %d HP (got %d)" % [ceili(220 * 1.8), game.combat.enemies[0].max])
	check(game.screen.backdrop == "mine", "Mine fights ask for the Mine backdrop")
	check(game.screen.fight_label.text == "Boss" and game.screen.murmur_label.get_parsed_text() == "", "the Pit King's fight says Boss, no murmurs")
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


## A won fight opens the Spoils shop: Buy puts a card on the belt for Shards, Destroy sells a belt relic back, Leave
## goes on to the map. Every buy, destroy and leave asks first.
func _relic_picks() -> void:
	var errors_before := errors.count
	var game: Node = await _won_fight()
	var pick: RelicPickScreen = game.screen if game.screen is RelicPickScreen else null
	check(pick != null and pick.title == "Spoils" and pick.choices.size() == 3, "a won fight opens the Spoils shop, three relics")
	if pick:
		check(pick.choices.all(func(id): return not Combat.RELICS[id].rare), "the first Spoils is commons only")
		var heading: Array = pick.find_children("*", "Label", true, false).filter(func(l): return l.text == "Your belt")
		check(heading.size() == 1 and heading[0].get_theme_font("font") == UI.HEADING_FONT and heading[0].get_theme_font_size("font_size") == 32, "Your belt is a 32 px heading")
		await process_frame  # the slots lay out
		_check_even_slots(pick, "empty belt")
		check(pick.find_children("*", "Button", true, false).all(func(b): return b.text not in ["<", "Skip", "Take", "Break"]), "no free-pick buttons")
		check(pick.buys.all(func(b): return b.disabled), "a Buy you can't afford is disabled")
		check(pick.buys[0].text == "Buy  %d" % Combat.price(pick.choices[0]), "the Buy button shows the price")
		game.combat.shards = 1
		pick._refresh()
		check(pick.reroll_button.text == "Reroll offer  2" and pick.reroll_button.disabled, "Reroll offer costs 2, disabled below that")
		game.combat.shards = 5
		pick._refresh()
		pick.reroll_button.pressed.emit()
		check(game.combat.shards == 3 and pick.rerolls == 1 and pick.reroll_button.text == "Reroll offer  3", "a reroll pays 2 and the next costs 3")
		check(pick.choices.size() == 3 and pick.choices.all(func(id): return not Combat.RELICS[id].rare), "the first Spoils rerolls into commons")
		check(pick.buys.size() == 3 and pick.buys.all(func(b): return b.is_inside_tree()), "the cards are rebuilt with their Buy buttons")
		pick.reroll_button.pressed.emit()
		check(game.combat.shards == 0, "the second costs 3")
		check(pick.reroll_button.disabled and game.combat.shards >= 0, "can't afford the third; Shards never go below 0")
		game.combat.shards = 20
		pick._refresh()
		check(not pick.buys[0].disabled, "with the Shards it is enabled")
		var first: String = pick.choices[0]
		var second: String = pick.choices[1]
		pick.buys[0].pressed.emit()
		check(game.combat.relics.is_empty(), "Buy asks first")
		_agree(game)
		await process_frame  # the closed confirm leaves the tree
		pick.buys[1].pressed.emit()
		_agree(game)
		await process_frame
		check(game.combat.relics.map(func(r): return r.id) == [first, second] and game.combat.shards == 12, "two buys: both on the belt, 8 Shards paid")
		check(game.screen == pick and pick.buys[0].disabled and pick.buys[1].disabled and not pick.buys[2].disabled, "still the shop; the bought cards are sold, the other still buyable")
		check(pick.subtitle.text.contains("Shards 12"), "the Shards line refreshes")
		await process_frame
		_check_even_slots(pick, "two relics")
		pick.reroll_button.pressed.emit()
		check(game.combat.relics.map(func(r): return r.id) == [first, second] and first not in pick.choices and second not in pick.choices,
			"after a reroll the bought relics are still on the belt and not dealt again")
		var rest: Array = Combat.RELICS.keys().filter(func(r): return r not in pick.choices and r not in [first, second])
		for r in rest.slice(0, 3):
			game.combat.take_relic(r)
		pick._refresh()
		check(game.combat.relics.size() == Combat.BELT_SIZE and pick.buys.all(func(b): return b.disabled), "a full belt disables every Buy")
		var destroyed: String = game.combat.relics[0].id
		var shards: int = game.combat.shards
		var destroys := pick.find_children("*", "Button", true, false).filter(func(b): return b.text == "Destroy" and not b.disabled)
		check(destroys.size() == Combat.BELT_SIZE, "a Destroy button under every belt relic")
		destroys[0].pressed.emit()
		_agree(game)
		await process_frame
		check(game.combat.relics.size() == Combat.BELT_SIZE - 1 and game.combat.shards == shards + Combat.sell_value(destroyed), "Destroy pays %d Shards" % Combat.sell_value(destroyed))
		check(not pick.buys[2].disabled and pick.subtitle.text.contains("Shards %d" % game.combat.shards), "the room makes the card buyable again, Shards refreshed")
		shards = game.combat.shards
		_button(pick, "Leave").pressed.emit()
		check(game.screen == pick, "Leave asks first")
		_agree(game)
		await process_frame
		check(game.screen is MapScreen and game.layer == 1 and game.combat.shards == shards, "Leave goes to the map's next column, nothing paid")
		check(game.combat.shopped, "the first Spoils is marked as shopped")
		game.combat.start_group(["skeleton"])
		game._show_fight(game._on_fight_finished)
		game.combat.enemies[0].hp = 1
		await _fight_out(game, "skeleton at 1 HP")
		check(game.screen is RelicPickScreen and game.screen.rarity == "any", "a later Spoils deals any rarity")
		check(game.screen.reroll_button.text == "Reroll offer  2", "a later shop's first reroll costs 2 again")
	game.queue_free()
	game = await _new_game()
	game._on_warden_beaten()
	check(game.screen is RelicPickScreen and game.screen.rarity == "rare", "the Warden's hoard is a rare shop")
	if game.screen is RelicPickScreen:
		game.combat.shards = 20
		game.screen._refresh()
		game.screen.reroll_button.pressed.emit()
		check(game.screen.choices.all(func(id): return Combat.RELICS[id].rare), "the hoard rerolls into rares")
		for id: String in Combat.RELICS:
			if Combat.RELICS[id].rare and game.combat.relics.all(func(r): return r.id != id):
				game.combat.relics.append({"id": id, "n": 0.0, "f": 0.0})  # past BELT_SIZE on purpose
		game.combat.shards = 20
		game.screen._refresh()
		check(game.screen.reroll_button.disabled, "no rare left to deal: Reroll is disabled")
		_button(game.screen, "Leave").pressed.emit()
		_agree(game)
		await process_frame
		check(game.screen is PerkPickScreen, "leaving the hoard goes to the perk pick")
	game.queue_free()
	game = await _new_game()
	game.floor_id = "mine"
	game.map = Floor.deal("mine")
	game.layer = game.map.size() - 1
	game.combat.start_group(["pit_king"])
	game._show_fight(game._on_fight_finished)
	game.combat.enemies[0].hp = 1
	await _fight_out(game, "pit king at 1 HP")
	check(game.screen is NoticeScreen and game.screen.title == "The Pit King falls.", "the Pit King gives no shop, only the run's end")
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "the shop runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## The fight screen's belt is a 5-slot BeltRow along the tray's top edge, right of the Skills button, hidden in the
## tutorial, and the summary counts Hit × Mult = Damage. End turn plays the count, ending on the damage the preview
## showed; Space skips it and goes no further. The belt drags only on the player's turn and fades under the timing bar.
## A turn with every relic on the belt, five at a time, plays with no errors.
func _fight_belt() -> void:
	var errors_before := errors.count
	check(CombatScreen.mult_text(1.95) == "1.95" and CombatScreen.mult_text(2.5) == "2.5" and CombatScreen.mult_text(2.0) == "2",
		"Mult reads 1.95, 2.5, 2 (got %s, %s, %s)" % [CombatScreen.mult_text(1.95), CombatScreen.mult_text(2.5), CombatScreen.mult_text(2.0)])
	var game: Node = await _new_game()
	for r in ["whetstone", "gravedigger", "spare_fuse"]:
		game.combat.take_relic(r)
	game.combat.apply_perks(["steady_hand", "scavenger"])
	var screen: CombatScreen = await _belt_fight(game)
	var belt: BeltRow = screen.belt
	check(screen.perk_row.get_child_count() == 2 and screen.perk_row.get_child(0).tooltip_text.begins_with("Steady Hand"),
		"the run's perks show as badges on the tray, with their text on hover")
	await process_frame
	check(screen.perk_row.position.x > screen.counter_label.position.x + screen.counter_label.size.x, "the perks sit right of the counter")
	screen._show_faces()
	await process_frame
	check(screen.faces_popup.visible and screen.faces_popup.get_child(0).get_child_count() == screen.combat.dice.size(), "Faces shows a row per die")
	screen._show_skill()
	await process_frame
	check(screen.faces_popup.get_child_count() == 1 and screen.faces_popup.get_child(0).get_child_count() == screen.combat.skills.size() + 1, "Skills shows a row per skill and the rule")
	screen.faces_popup.hide()
	check(belt.get_parent() == screen.dice_box and belt.get_child_count() == Combat.BELT_SIZE, "the belt is a 5-slot row on the dice tray")
	check(belt.position == Vector2(28, 8) and screen.faces_button.get_parent() != screen.dice_box and screen.counter_label.get_parent() == screen.dice_box,
		"the belt sits at the tray's top-left, the counter on the tray and Faces above it (belt at %s)" % belt.position)
	check(screen.tray.top_inset > 0, "the tray's top wall sits below the belt")
	check(screen.counter_label.position.x > belt.position.x + belt.size.x, "the counter clears the belt (counter at %.0f, belt ends at %.0f)" % [screen.counter_label.position.x, belt.position.x + belt.size.x])
	check(belt.can_drag.call(), "the belt drags on the player's turn")
	await _press(KEY_ESCAPE)
	check(screen.paused and not belt.can_drag.call(), "no dragging behind the fight menu")
	await _press(KEY_ESCAPE)
	await process_frame
	game.queue_free()
	game = await _new_game()
	for r in ["black_candle", "twin_saints", "whetstone"]:  # with no skill or 5 in Attack, only the Candle has a step
		game.combat.take_relic(r)
	screen = await _belt_fight(game)
	for i in 3:
		screen.combat.dice[i].value = 3
		screen.combat.assign(i, Combat.Slot.ATTACK)
	screen.combat.enemies[0].intent = {"kind": "attack", "value": 2}  # no enemy Guard to cut the hit
	screen.combat.enemies[0].hp = 999  # lives through the turns below
	belt = screen.belt
	var dimmed := func() -> Array: return range(3).filter(func(k): return belt.icon(k).modulate.a < 1.0)
	screen._refresh()
	check(screen.counter_label.text == "Hit 9 × Mult 1 = ?" and screen.combat.preview_damage() == 13,
		"Attack 9 under a Black Candle reads Hit 9 × Mult 1 = ?, the Candle and the 13 kept for the count: %s" % screen.counter_label.text)
	var preview := screen.combat.preview_damage()
	screen._on_end_turn()
	check(screen.counting and not belt.can_drag.call(), "End turn starts the count, and the belt can't drag while busy")
	check(dimmed.call() == [1, 2], "relics with no step in the count stay dim (dim: %s)" % [dimmed.call()])
	var asked := false
	while screen.counting:
		asked = asked or screen.counter_label.text.ends_with("= ?")
		await process_frame
	check(asked, "the count shows Hit × Mult = ? before the damage")
	check(screen.counter_label.text == "Hit 9 × Mult 1.5 = 13", "and ends on the damage: %s" % screen.counter_label.text)
	check(dimmed.call().is_empty(), "the count's end undims them (dim: %s)" % [dimmed.call()])
	check(999 - screen.combat.enemies[0].hp == preview, "the turn deals the %d the preview showed (dealt %d)" % [preview, 999 - screen.combat.enemies[0].hp])
	check(screen.busy and not belt.can_drag.call(), "no dragging while the turn resolves")
	var held := true
	var enemy_phase := false
	while screen.busy:
		if screen.acting >= 0:
			enemy_phase = true
			held = held and screen.counter_label.text.begins_with("Hit 9 × Mult 1.5 = %d" % preview)
		await process_frame
	check(enemy_phase and held, "the summary keeps what was dealt through the enemy phase (now: %s)" % screen.counter_label.text)
	check(screen.counter_label.text.begins_with("Hit 0 "), "and shows the new preview once the next turn starts (now: %s)" % screen.counter_label.text)
	for i in 3:
		screen.combat.dice[i].value = 3
		screen.combat.assign(i, Combat.Slot.ATTACK)
	screen.combat.enemies[0].intent = {"kind": "attack", "value": 2}
	screen._refresh()
	var rerolls: int = screen.combat.rerolls
	Engine.time_scale = 1.0  # so the count is still going when Space comes
	screen._on_end_turn()
	await process_frame
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	check(screen.counting and dimmed.call() == [1, 2], "the count is under way, Twin Saints and Whetstone dim")
	root.push_input(space)
	check(root.is_input_handled(), "the skipping Space is consumed")
	await process_frame
	Engine.time_scale = SPEED
	check(not screen.counting and screen.combat.rerolls == rerolls, "Space ends the count at once and rerolls nothing")
	check(dimmed.call().is_empty(), "a skipped count undims them too (dim: %s)" % [dimmed.call()])
	while screen.busy:
		await process_frame
	for i in 2:
		screen.combat.dice[i].value = [5, 4][i]
		screen.combat.assign(i, Combat.Slot.ATTACK)
	screen.combat.enemies[0].intent = {"kind": "attack", "value": 2}
	screen._refresh()
	check(screen.counter_label.text == "Hit 9 × Mult 1 = ?", "Attack 5 + 4 reads Hit 9, Whetstone's +3 kept for the count: %s" % screen.counter_label.text)
	screen._on_end_turn()
	var plus := false
	while screen.counting:
		plus = plus or screen.find_children("*", "Label", true, false).any(func(l): return l.text == "+3")
		await process_frame
	check(plus, "Whetstone's +3 floats up in the count")
	while screen.busy:
		await process_frame
	screen.combat.assign(0, Combat.Slot.ATTACK)
	screen.combat.assign(1, Combat.Slot.GUARD)
	screen.combat.enemies[0].intent = {"kind": "attack", "value": 2}
	screen._refresh()
	screen._on_end_turn()
	while not screen.timing.running:
		await process_frame
	while screen.timing.running and belt.modulate.a >= 0.5:
		await process_frame
	check(screen.timing.running and belt.modulate.a < 0.5, "the belt fades under the timing bar (alpha %.2f)" % belt.modulate.a)
	while screen.timing_hint.visible:
		await process_frame
	await create_timer(0.3).timeout
	check(belt.modulate.a == 1.0, "and comes back after it (alpha %.2f)" % belt.modulate.a)
	game.queue_free()
	game = await _new_game()
	game._show_tutorial()
	await process_frame
	check(not game.screen.belt.visible, "the tutorial hides the belt")
	game.queue_free()
	var ids: Array = Combat.RELICS.keys()
	for start in range(0, ids.size(), Combat.BELT_SIZE):
		game = await _new_game()
		for r in ids.slice(start, start + Combat.BELT_SIZE):
			game.combat.take_relic(r)
		screen = await _belt_fight(game)
		for r in game.combat.relics:  # growing relics with something to show
			r.n = 8.0
			r.f = 2.0
		screen._refresh()
		screen._on_end_turn()
		var waited := 0
		while game.screen == screen and screen.busy and waited < 600:
			await process_frame
			waited += 1
		check(waited < 600, "a turn with %s ends" % [ids.slice(start, start + Combat.BELT_SIZE)])
		game.queue_free()
	await process_frame
	check(errors.count == errors_before, "fights with relics run with no errors (got %d)" % (errors.count - errors_before))


## Every slot of the shop's belt is as wide as the others, so the gaps look even.
func _check_even_slots(pick: RelicPickScreen, when: String) -> void:
	var widths: Array = range(Combat.BELT_SIZE).map(func(k): return pick.belt_row.get_child(k).size.x)
	check(widths.all(func(w): return is_equal_approx(w, widths[0])), "every belt slot is as wide as the others (%s): %s" % [when, widths])


## BeltRow: five slots, a drop reorders the belt, can_drag shuts dragging, Destroy buttons report their slot.
func _belt_row() -> void:
	var errors_before := errors.count
	var c := Combat.new()
	for id in ["rosary", "whetstone", "mirror_shard"]:
		c.take_relic(id)
	var row := BeltRow.new()
	row.combat = c
	root.add_child(row)
	row.rebuild()
	await process_frame
	check(row.get_child_count() == Combat.BELT_SIZE and row.find_children("*", "RelicIcon", true, false).size() == 3, "the belt row has 5 slots, 3 with an icon")
	check(row.icon(2).tooltip_text.contains("Copying: nothing"), "a Mirror Shard's icon tooltip still names what it copies")
	var moves := [0]
	row.moved.connect(func(): moves[0] += 1)
	var drag: Variant = row.icon(0)._get_drag_data(Vector2.ZERO)
	check(drag is Dictionary and drag.belt_k == 0 and row._can_drop_data(Vector2.ZERO, drag), "an icon hands out its slot and the row takes it")
	row._drop_data(Vector2(row.get_child(2).position.x + 1, 0), {"belt_k": 0})
	check(c.relics[2].id == "rosary" and moves[0] == 1, "dropping on slot 2 moves the first relic there and says so")
	await process_frame  # the rebuilt slots lay out
	row.icon(0)._drop_data(Vector2(1, 1), {"belt_k": 0})  # an icon forwards a drop to its row: onto itself, nothing moves
	check(c.relics[2].id == "rosary" and moves[0] == 1, "dropping a relic where it already is changes nothing")
	row._drop_data(Vector2(row.size.x - 1, 0), {"belt_k": 0})  # past the last relic: the last relic slot
	check(c.relics[2].id == "whetstone" and moves[0] == 2, "dropping on an empty slot goes to the last relic slot")
	await process_frame
	var drag_from: Variant = row.icon(0)._get_drag_data(Vector2.ZERO)
	check(row.icon(0).modulate.a < 1.0, "the dragged relic's slot is dimmed")
	check(row._can_drop_data(Vector2(row.get_child(2).position.x + 1, 0), drag_from), "hovering slot 2 accepts the drop")
	await create_timer(0.5).timeout
	check(row.icon(1).slide_x < 0.0 and row.icon(2).slide_x < 0.0 and row.icon(0).slide_x == 0.0, "hovering slot 2 slides slots 1 and 2 aside to open a gap")
	row._can_drop_data(Vector2(row.get_child(1).position.x + 1, 0), drag_from)
	await create_timer(0.5).timeout
	check(row.icon(1).slide_x < 0.0 and row.icon(2).slide_x == 0.0, "and hovering slot 1 only slides slot 1")
	row.notification(Node.NOTIFICATION_DRAG_END)
	await create_timer(0.5).timeout
	check(range(3).all(func(k): return row.icon(k).slide_x == 0.0) and row.icon(0).modulate.a == 1.0, "the drag ending puts every icon back, undimmed")
	row.can_drag = func() -> bool: return false
	check(row.icon(0)._get_drag_data(Vector2.ZERO) == null and not row._can_drop_data(Vector2.ZERO, {"belt_k": 0}), "nothing drags while can_drag says no")
	row.show_destroy = true
	row.rebuild()
	var buttons := row.find_children("*", "Button", true, false).filter(func(b): return not b.disabled)  # empty slots hold a disabled one
	var hit := [-1]
	row.destroy_pressed.connect(func(k: int): hit[0] = k)
	check(buttons.size() == 3 and buttons.all(func(b): return b.text == "Destroy"), "show_destroy puts a Destroy button under each relic")
	buttons[1].pressed.emit()
	check(hit[0] == 1, "pressing the second reports slot 1")
	row.icon(0).fire()
	await create_timer(0.1).timeout
	check(errors.count == errors_before, "the belt row runs with no errors (got %d)" % (errors.count - errors_before))
	row.queue_free()


## A skeleton fight on screen with the dice landed, two in Attack.
func _belt_fight(game: Node) -> CombatScreen:
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	while screen.busy:
		await process_frame
	for i in 2:
		screen.combat.assign(i, Combat.Slot.ATTACK)
	screen._refresh()
	return screen


## A new run's entrance fight, won (the enemy left at 1 HP).
func _won_fight() -> Node:
	var game: Node = await _new_game()
	game.path = [0]
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	game.combat.enemies[0].hp = 1
	await _fight_out(game, "skeleton at 1 HP")
	return game


## Once the Mine is unlocked the camp can start a run there, without a bonus perk or a relic.
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
	check(game.combat.relics.is_empty(), "a Mine start gives no free relic")
	check(game.screen is MapScreen and game.screen.title == "The Hollow Mine" and game.floor_id == "mine", "the camp starts a run in the Mine")
	check(game.combat.bonus_perk == "" and game.rooms_before == 0, "a Mine start has no bonus perk")
	check(game.world() == 1, "a Mine start is world 1")
	game.layer = game.map.size() - 1
	game._on_room_picked(0)
	check(game.combat.enemies[0].max == 220, "a Mine-start Pit King keeps 220 HP")
	game.combat.start_group(["miner"])
	game._show_fight(game._on_fight_finished)
	await process_frame
	check(game.screen.crypt.texture.resource_path == "res://assets/ui/bg_mine.webp", "Mine fights show the Mine backdrop")
	check(game.screen.fight_label.text == "Mine", "a Mine fight is labelled Mine, got %s" % game.screen.fight_label.text)
	check(game.screen.murmur_label.get_parsed_text() == CombatScreen.MURMURS.mine[0], "a Mine fight murmurs the Mine's lines")
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
			elif not _overlays(game, "ConfirmPanel").is_empty():
				_agree(game)  # every face change asks first
			elif s is ForgeScreen and not s.busy:
				if not s.owed and s.roll_button and not s.roll_button.disabled:
					s.roll_button.pressed.emit()  # every upgrade is thrown first
				else:
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


## Choices that can't be taken back ask first, and Back leaves everything as it was.
func _choices_ask() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	await _at_campfire(game)
	var hp: int = game.combat.player_hp
	game.screen.choices[0][1].call()  # Rest
	var ask: Array = _overlays(game, "ConfirmPanel")
	check(ask.size() == 1 and ask[0].title == "Rest here?", "Rest asks first")
	if ask.size() == 1:
		ask[0].close()
	await process_frame
	check(game.screen is NoticeScreen and game.combat.player_hp == hp and _overlays(game, "ConfirmPanel").is_empty(), "Back keeps the campfire, unrested")
	game._show_menu()
	await process_frame
	_button(game.screen, "Quit").pressed.emit()
	ask = _overlays(game, "ConfirmPanel")
	check(ask.size() == 1 and ask[0].title == "Quit the game?", "Quit asks first")
	if ask.size() == 1:
		ask[0].close()
	await process_frame
	check(game.screen is MenuScreen and not game.is_queued_for_deletion(), "Back stays on the main menu")
	check(errors.count == errors_before, "the confirms run with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## Clicking a camp tile unlocks it (after a confirm), or equips or unequips a perk; a full loadout or too few Embers
## only warn. Skills unlock once and every run gets them all.
func _camp_board() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.meta.embers = 250
	game.meta.owned = ["steady_hand", "thick_skin"]
	game.meta.equipped = ["steady_hand", "thick_skin"]
	game._show_camp()
	await process_frame
	var board: TileBoard = game.screen.board
	check(board.tiles.size() == Combat.SKILLS.size() + Meta.PERKS.size(), "every skill and perk has a tile")
	board._click("scavenger")
	_agree(game)
	await process_frame  # the confirm closes
	check("scavenger" in game.meta.owned and game.meta.embers == 175, "clicking a locked perk unlocks it after a confirm")
	board._click("scavenger")
	check("scavenger" not in game.meta.equipped and board.state.text.contains("full"), "a full loadout only warns")
	board._click("thick_skin")
	board._click("scavenger")
	check(game.meta.equipped == ["steady_hand", "scavenger"], "clicking equipped unequips; then there's room")
	board._click("lantern_bearer")
	check(_overlays(game, "ConfirmPanel").is_empty() and board.state.text.contains("Not enough"), "too few Embers only warns")
	game.meta.embers = 300  # Flurry's price
	board._click("flurry")
	_agree(game)
	await process_frame
	var embers: int = game.meta.embers
	board._click("flurry")
	check("flurry" in game.meta.skills and game.meta.embers == embers and _overlays(game, "ConfirmPanel").is_empty(), "a skill unlocks once; clicking it again does nothing")
	game._start_run()
	check(game.combat.skills == ["cleave", "flurry"], "a run gets every unlocked skill")
	await _at_campfire(game)
	check(not game.screen.choices.any(func(c): return c[0].begins_with("Change skill")), "campfires no longer swap skills")
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "the boards run with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## Goes ahead on the confirm open over the screen.
func _agree(game: Node) -> void:
	var ask: Array = _overlays(game, "ConfirmPanel")
	if ask.size() == 1:
		ask[0]._yes()
	else:
		check(false, "one confirm is open to agree to (got %d)" % ask.size())


func _overlays(game: Node, type: String) -> Array:
	return game.screen.find_children("*", type, true, false)


## Quick dice control, the default (Settings switches it): a click steps a die through Attack, Guard, Skill and unplaced
## (a right-click steps back), and holding it down locks it instead. Off, a click opens the die menu.
func _quick_dice() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	while screen.busy:
		await process_frame
	check(game.meta.quick_dice, "dice control starts on Quick")
	var panel := SettingsPanel.open(screen, game.meta)
	await process_frame
	panel._on_dice()
	check(not game.meta.quick_dice and not Meta.load_from(SAVE).quick_dice, "Settings switches dice control to Menu, and it is saved")
	panel._on_dice()
	check(game.meta.quick_dice and Meta.load_from(SAVE).quick_dice, "and back to Quick")
	panel.close()
	var steps: Array = []
	for n in 4:
		screen._on_die_clicked(0)
		screen._on_left_released()
		steps.append(screen.combat.dice[0].slot)
	check(steps == [Combat.Slot.ATTACK, Combat.Slot.GUARD, Combat.Slot.SKILL, Combat.Slot.NONE], "clicks step through Attack, Guard, Skill, unplaced (got %s)" % [steps])
	screen._on_die_right_clicked(0)
	check(screen.combat.dice[0].slot == Combat.Slot.SKILL and not screen.die_menu.visible, "a right-click steps back, and no menu opens")
	check(not screen.tray.dice[0].chain.visible, "a quick click shows no chains")
	screen._on_die_clicked(1)
	await create_timer(CombatScreen.HOLD_LOCK * 0.7).timeout
	var chain: Sprite3D = screen.tray.dice[1].chain
	check(chain.visible and chain.modulate.a > 0.2 and chain.modulate.a < 1 and not screen.combat.dice[1].locked, "midway through a hold the chains fade in before it locks")
	await create_timer(CombatScreen.HOLD_LOCK * 0.8).timeout
	screen._on_left_released()
	check(screen.combat.dice[1].locked and screen.combat.dice[1].slot == Combat.Slot.NONE, "holding a die locks it without moving it")
	game.meta.quick_dice = false
	screen._on_die_clicked(0)
	check(screen.die_menu.visible, "with Menu control a click opens the die menu")
	screen.die_menu.hide()
	check(errors.count == errors_before, "quick dice control runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


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


## The menu opens while a throw waits on the Roll press, R can't throw behind it, and closing it leaves
## the throw waiting; once the dice are in the air it stays shut.
func _menu_before_throw() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	ChargeBar.auto = false
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	var screen: CombatScreen = game.screen
	await process_frame
	check(screen.charge.waiting and not screen.menu_button.disabled, "the Menu button is on while the throw waits")
	await _press(KEY_ESCAPE)
	check(_overlays(game, "FightMenu").size() == 1, "Esc opens the menu before the dice are thrown")
	screen._on_roll_key(true)
	screen._on_roll_key(false)
	await process_frame
	check(screen.charge.waiting and screen.rolling.size() == 3 and not screen.tray.in_flight, "R throws nothing behind the menu")
	await _press(KEY_ESCAPE)
	await process_frame
	check(_overlays(game, "FightMenu").is_empty() and screen.busy and screen.charge.waiting, "closing it leaves the throw waiting")
	screen._on_roll_key(true)
	screen._on_roll_key(false)
	await process_frame
	check(screen.tray.in_flight, "the throw goes once the menu is shut")
	await _press(KEY_ESCAPE)
	check(_overlays(game, "FightMenu").is_empty(), "the menu stays shut while the dice are in the air")
	ChargeBar.auto = true
	while screen.busy:
		await process_frame
	check(errors.count == errors_before, "the menu before a throw runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame


## The map has the fight's menu: its Menu button or Esc opens it, and quitting from it gives up the run.
func _map_menu() -> void:
	var errors_before := errors.count
	var game: Node = await _new_game()
	var embers: int = game.meta.embers
	check(game.screen is MapScreen and _button(game.screen, "Menu  [Esc]") != null, "the map has a Menu button")
	await _press(KEY_ESCAPE)
	var menu: Array = _overlays(game, "FightMenu")
	check(menu.size() == 1, "Esc opens the menu on the map")
	await _press(KEY_ESCAPE)
	await process_frame
	check(_overlays(game, "FightMenu").is_empty() and game.screen is MapScreen, "Esc again closes it, back on the map")
	_button(game.screen, "Menu  [Esc]").pressed.emit()
	await process_frame
	_button(_overlays(game, "FightMenu")[0], "Quit to main menu").pressed.emit()
	await process_frame
	_agree(game)
	await process_frame
	check(game.screen is MenuScreen and not RunSave.exists(RUN), "quitting from the map gives up the run for the main menu")
	check(game.meta.embers == embers, "quitting from the map pays no Embers")
	check(errors.count == errors_before, "the map menu runs with no errors (got %d)" % (errors.count - errors_before))
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
	_agree(game)
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
	_agree(game)
	await process_frame
	check(game.screen is MapScreen and game.layer == 4 and game.combat.player_hp == 17 + heal, "Rest still heals and moves on")
	await _continue(game)
	check(game.combat.player_hp == 17, "the save is from before the rest")
	game.screen.choices[1][1].call()  # Tend the dice
	_agree(game)
	await process_frame
	check(game.screen is ForgeScreen and game.screen.no_cost, "Tend the dice still gives a free roll")
	if game.screen is ForgeScreen:
		var forge: ForgeScreen = game.screen
		check(forge.face_buttons[2][0].disabled, "no face takes an upgrade before the die is thrown")
		forge.roll_button.pressed.emit()
		while forge.busy:
			await process_frame
		forge.face_buttons[2][0].pressed.emit()
		check(game.screen is ForgeScreen and _overlays(game, "ConfirmPanel").size() == 1, "a face asks before it changes")
		_agree(game)
		await process_frame
	check(game.screen is MapScreen and game.layer == 4 and (game.combat.dice[2].base[0] > 1 or game.combat.dice[2].marks[0] != ""), "and moves on, forged with what the die gave")
	game.layer = game.map.size() - 1  # the stop between the Warden and the Mine
	game.rooms_before = game.map.size()
	game.combat.add_perk("bonfire_keeper")
	game._show_campfire("mine")
	await process_frame
	_button(game.screen, "Save and quit").pressed.emit()
	_agree(game)
	await process_frame
	await _continue(game)
	game.screen.choices[0][1].call()
	_agree(game)
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
	_agree(game)
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
	_agree(game)
	await process_frame
	await _continue(game)
	game.combat.player_hp = 1
	game.combat.relics = [{"id": "tithe_box", "n": 0, "f": 0}, {"id": "mirror_shard", "n": 0, "f": 0}]
	game.combat.best_hit = 41
	game.combat.start_group(["skeleton"])
	game._show_fight(game._on_fight_finished)
	await _fight_out(game, "skeleton at 1 HP")
	check(game.screen is NoticeScreen and game.screen.title == "You fled.", "the run is lost")
	var ls: Array = game.screen.lines
	check("Relics: Tithe Box, Mirror Shard" in ls and "Biggest hit: 41" in ls and ls.any(func(l): return l.begins_with("Highest Mult: ")), "the end notice shows the build")
	check(ls[game.screen.highlight].begins_with("Embers earned"), "the Embers line stays highlighted")
	check(not RunSave.exists(RUN), "the saved run is gone after a death")
	await create_timer(0.3).timeout
	check(errors.count == errors_before, "a death after continuing runs with no errors (got %d)" % (errors.count - errors_before))
	game.queue_free()
	await process_frame
