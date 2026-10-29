extends Control
## Runs the game: a title menu, the tutorial on first play, then runs of map -> rooms -> boss,
## the Chapel's Warden leading down to the Mine's Pit King, with Embers and perks carried between runs by Meta.

var meta := Meta.load_from()
var combat: Combat
var floor_id := "chapel"
var map: Array = []  # this run's floor, from Floor.deal()
var layer := 0
var rooms_before := 0  # rooms cleared on earlier floors this run
var path: Array = []  # room picked on each layer so far
var seen_events: Array = []  # "?" events met this run; each happens once
var run_path := RunSave.PATH  # tests point it elsewhere, as they do Meta's
var ambush := false  # the fight on now came from a "?" room
var screen: Control
var music := AudioStreamPlayer.new()
var ui_sfx := AudioStreamPlayer.new()

const MENU_BGM := preload("res://assets/audio/menu_bgm.wav")
const DUNGEON_BGM := preload("res://assets/audio/dungeon_bgm.wav")
const BOSS_BGM := preload("res://assets/audio/boss_bgm.wav")
const HOVER := preload("res://assets/audio/hover.wav")
const CLICK := preload("res://assets/audio/click.wav")
const CONFIRM := preload("res://assets/audio/confirm.wav")


func _ready() -> void:
	for bus in ["Music", "SFX"]:  # made here rather than in a bus layout file; Meta.apply_sound sets their volume
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	meta.apply_sound()
	music.volume_db = -8.0
	music.bus = "Music"
	music.finished.connect(music.play)  # loop without touching the wav import settings
	add_child(music)
	ui_sfx.bus = "SFX"
	add_child(ui_sfx)
	get_tree().node_added.connect(_on_node_added)
	for arg in OS.get_cmdline_user_args():  # dev shortcut: `-- --fight=6` jumps straight into that fight
		if arg.begins_with("--fight="):
			_start_run()
			combat.start_fight(int(arg.trim_prefix("--fight=")))
			_show_fight(_on_fight_finished)
			return
	_show_menu()


## Players still playing at quit leak their streams (Godot's exit warning), so the music and UI sound stop first.
func _exit_tree() -> void:
	music.stop()
	ui_sfx.stop()


func _show_menu() -> void:
	var s := MenuScreen.new()
	s.tutorial_done = meta.tutorial_done
	s.meta = meta
	s.can_continue = not _saved_run().is_empty()
	s.play.connect(_on_play)
	s.resume.connect(_continue_run)
	s.tutorial.connect(_confirm_new_run.bind(_show_tutorial))
	_show(s)


func _on_play() -> void:
	if meta.tutorial_done:
		_show_camp()
	else:
		_confirm_new_run(_show_tutorial)


## Calls `start` now, or once the player agrees to throw away the saved run it would replace.
func _confirm_new_run(start: Callable) -> void:
	if not RunSave.exists(run_path):
		start.call()
		return
	var c := ConfirmPanel.new()
	c.title = "Abandon saved run?"
	c.text = "The run saved at the campfire will be lost."
	c.yes = "Start a new run"
	c.confirmed.connect(func() -> void:
		RunSave.erase(run_path)
		start.call())
	screen.add_child(c)


func _show_tutorial() -> void:
	floor_id = "chapel"  # the tutorial's backdrop, even after a Mine run
	combat = Combat.new()  # a new Combat starts on fight 0, the tutorial
	_show_fight(_on_tutorial_finished)


func _show(next: Control) -> void:
	if screen:
		screen.queue_free()
		_play_ui(CONFIRM)  # a press that changes screen confirms rather than clicks
	screen = next
	add_child(next)
	var track: AudioStream = MENU_BGM if (next is MenuScreen or next is CampScreen) else DUNGEON_BGM
	if next is CombatScreen and combat.is_boss_fight():
		track = BOSS_BGM
	if music.stream != track:
		music.stream = track
		music.play()


## M mutes or unmutes everything, on any screen.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		meta.muted = not meta.muted
		meta.apply_sound()
		meta.save()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.mouse_entered.connect(func() -> void: if not node.disabled: _play_ui(HOVER))
		node.pressed.connect(_play_ui.bind(CLICK))


func _play_ui(sfx: AudioStream) -> void:
	if sfx == CLICK and ui_sfx.stream == CONFIRM and ui_sfx.playing and ui_sfx.get_playback_position() < 0.1:
		return  # this press already played confirm
	ui_sfx.stream = sfx
	ui_sfx.play()


func _on_tutorial_finished(_won: bool) -> void:
	meta.tutorial_done = true
	meta.save()
	_start_run()


func _start_run(first_floor := "chapel") -> void:
	RunSave.erase(run_path)  # one run at a time
	combat = Combat.new()
	combat.apply_perks(meta.equipped)
	combat.skills = meta.skills.duplicate()
	rooms_before = 0
	seen_events.clear()
	if first_floor == "mine":  # a Mine start opens with a rare pick
		_show_relic_pick("Into the Mine", true, _enter_floor.bind("mine"))
	else:
		_enter_floor(first_floor)


## A fresh map of floor `id`, from its entrance. HP, Shards, dice, perks and seen events stay as they are; the murmurs start over.
func _enter_floor(id: String) -> void:
	floor_id = id
	combat.dungeon_turns = 0
	map = Floor.deal(floor_id)
	layer = 0
	path.clear()
	_show_map()


func _show_map() -> void:
	var s := MapScreen.new()
	s.rooms = map
	s.title = Floor.FLOORS[floor_id].title
	s.lair = Floor.FLOORS[floor_id].lair
	s.layer = layer
	s.path = path
	s.combat = combat
	s.seen_events = seen_events
	s.picked.connect(_on_room_picked)
	_show(s)


func _on_room_picked(i: int) -> void:
	path.append(i)
	var room: Dictionary = map[layer][i]
	match room.kind:
		"fight":
			combat.start_group(room.enemies, room.get("scale", 1.0))
			_show_fight(_on_fight_finished)
		"unknown":
			var id: String = Events.pick(seen_events)
			if id == "" or randf() < Events.ambush_chance(combat):
				_start_ambush()
			else:
				_show_event(id)
		"forge":
			_show_forge(false)
		"campfire":
			_show_campfire("room")


## Rest or a free upgrade, then on `into`: "room" (the map's next column) or "mine" (down from the Warden).
## Or save the run here and quit; continuing comes back to this same campfire.
func _show_campfire(into: String) -> void:
	var then := _next_room if into == "room" else _enter_floor.bind("mine")
	var heal := combat.campfire_heal_amount()
	var choices := [
		["Rest  (+%d HP)" % heal, _ask.bind("Rest here?", "Heal %d HP and move on. The dice stay as they are." % heal, "Rest", _on_rest.bind(then))],
		["Tend the dice  (one free roll)", _ask.bind("Tend the dice?", "One free throw to upgrade a die face, instead of resting.", "Tend the dice", _show_forge.bind(true, then))],
		["Save and quit", _ask.bind("Save and quit?", "The run is saved at this campfire. Continue on the main menu picks it up here.", "Save and quit", _save_and_quit.bind(into))],
	]
	_show_notice("Campfire", ["HP %d/%d" % [combat.player_hp, combat.max_hp]], -1, choices, "campfire")


## Asks over the current screen before `then`.
func _ask(title: String, text: String, yes: String, then: Callable) -> void:
	ConfirmPanel.ask(screen, title, text, yes, then)


func _save_and_quit(into: String) -> void:
	var data := {"combat": combat.to_dict(), "floor_id": floor_id, "map": map, "layer": layer, "path": path,
		"rooms_before": rooms_before, "seen_events": seen_events, "into": into}
	if RunSave.write(data, run_path):  # on failure stay at the campfire rather than lose the run
		_show_menu()


## Back to the campfire the run was saved at. The save stays until the run ends.
func _continue_run() -> void:
	var data := _saved_run()
	if data.is_empty():
		_show_menu()
		return
	combat = Combat.from_dict(data.combat)
	combat.skills = meta.skills.duplicate()  # unlocked for good, so not part of the save
	floor_id = data.floor_id
	map = data.map
	layer = data.layer
	path = data.path
	rooms_before = data.rooms_before
	seen_events = data.seen_events
	ambush = false
	_show_campfire(data.into)


## The campfire save, or {} if there is none or it can't be loaded as _save_and_quit wrote it.
func _saved_run() -> Dictionary:
	var d := RunSave.read(run_path)
	var ok: bool = Combat.valid_dict(d.get("combat")) and Floor.FLOORS.has(d.get("floor_id")) 		and d.get("map") is Array and d.get("path") is Array and d.get("seen_events") is Array 		and d.get("rooms_before") is int and d.get("into") in ["room", "mine"] 		and d.get("layer") is int and d.layer >= 0 and d.layer < d.map.size()
	return d if ok else {}


func _show_fight(on_finished: Callable) -> void:
	var s := CombatScreen.new()
	s.combat = combat
	s.backdrop = Floor.FLOORS[floor_id].backdrop
	s.meta = meta
	s.finished.connect(on_finished)
	s.abandoned.connect(_abandon_run)
	_show(s)


func _on_fight_finished(won: bool) -> void:
	combat.claim_fight(won)
	if ambush and won:
		combat.shards += Events.AMBUSH_SHARDS
	ambush = false
	if not won:
		_end_run(false)
	elif layer < map.size() - 1:
		_show_relic_pick("Spoils", false, _next_room)
	elif floor_id == "chapel":  # the Warden always leads on down
		_on_warden_beaten()
	else:
		_end_run(true)


## The Mine opens for good; this run takes a rare relic, a bonus perk, a campfire, then the way down.
func _on_warden_beaten() -> void:
	meta.mine_unlocked = true
	meta.save()
	rooms_before += map.size()
	_show_relic_pick("The Warden's hoard", true, _show_perk_pick)


func _show_perk_pick() -> void:
	var s := PerkPickScreen.new()
	s.choices = PerkPickScreen.offer(combat.perks)
	s.picked.connect(func(id: String) -> void:
		combat.add_perk(id)
		_show_campfire("mine"))
	_show(s)


## A pick of relics for the belt (only rares if `rares`), then `then`; straight to `then` if there are none to offer.
func _show_relic_pick(title: String, rares: bool, then: Callable) -> void:
	var choices := RelicPickScreen.offer(combat.relics, rares, combat.rng)
	if choices.is_empty():
		then.call()
		return
	var s := RelicPickScreen.new()
	s.combat = combat
	s.choices = choices
	s.rares = rares
	s.title = title
	s.done.connect(then)
	_show(s)


func _show_event(id: String) -> void:
	seen_events.append(id)
	var s := EventScreen.new()
	s.combat = combat
	s.id = id
	s.finished.connect(_on_event_finished)
	_show(s)


## Hands out an event's rewards one screen at a time, `forge` free upgrades then a carve, then moves on.
func _on_event_finished(result: Dictionary) -> void:
	if result.get("forge", 0) == 0 and not result.get("carve", false):
		_next_room()
		return
	var s := ForgeScreen.new()
	s.combat = combat
	s.no_cost = true
	if result.get("forge", 0) > 0:
		result.forge -= 1
	else:
		s.carve = true
		result.carve = false
	s.done.connect(_on_event_finished.bind(result))
	_show(s)


func _start_ambush() -> void:
	ambush = true
	combat.start_group(Floor.group(Floor.FLOORS[floor_id].hp[1], {}, Floor.FLOORS[floor_id].enemies))
	_show_fight(_on_fight_finished)
	screen._log("Something moves in the dark.")
	screen._refresh()


func _show_forge(no_cost: bool, then := _next_room) -> void:
	var s := ForgeScreen.new()
	s.combat = combat
	s.no_cost = no_cost
	s.done.connect(then)
	_show(s)


func _on_rest(then: Callable) -> void:
	combat.heal(combat.campfire_heal_amount())
	then.call()


func _next_room() -> void:
	layer += 1
	_show_map()


## Quit from the fight menu: the run is given up, with no Embers.
func _abandon_run() -> void:
	RunSave.erase(run_path)
	ambush = false
	_show_menu()


func _end_run(won: bool) -> void:
	RunSave.erase(run_path)
	var rooms_cleared := rooms_before + layer + (1 if won else 0)
	var boss_pct := combat.boss_damage_pct()
	var earned := Meta.embers_for(combat.kills, rooms_cleared, boss_pct, won) + combat.bonus_embers
	meta.embers += earned
	meta.save()
	var title := "The Pit King falls." if won else "You fled."
	var narrator := "The mine goes still."
	if not won:
		var boss := "Pit King" if floor_id == "mine" else "Warden"
		var place := "mine" if floor_id == "mine" else "dungeon"
		narrator = "The %s will remember your back." % boss if combat.is_boss_fight() else "The %s keeps what you dropped." % place
	_show_notice(title, [
		narrator,
		"Depth reached: %s, room %d of %d" % [Floor.FLOORS[floor_id].title, mini(layer + 1, map.size()), map.size()],
		"Enemies slain: %d" % combat.kills,
		"Boss damage dealt: %d%%" % boss_pct,
		"Relics: " + (", ".join(combat.relics.map(func(r): return Combat.RELICS[r.id].name)) if not combat.relics.is_empty() else "none"),
		"Highest Mult: ×%.1f" % combat.best_mult,
		"Biggest hit: %d" % combat.best_hit,
		"Embers earned: +%d" % earned,
		"Embers: %d" % meta.embers,
	], 7, [["Walk back in", _confirm_new_run.bind(_start_run.bind("chapel" if rooms_before > 0 else floor_id))], ["Return to camp", _show_camp]],
		"victory" if won else "defeat")  # walking back in starts where this run did


func _show_camp() -> void:
	var s := CampScreen.new()
	s.meta = meta
	s.start_run.connect(func(id: String) -> void: _confirm_new_run(_start_run.bind(id)))
	s.main_menu.connect(_show_menu)
	_show(s)


func _show_notice(title: String, lines: Array, highlight: int, choices: Array, backdrop := "") -> void:
	var s := NoticeScreen.new()
	s.title = title
	s.lines = lines
	s.highlight = highlight
	s.choices = choices
	s.backdrop = backdrop
	_show(s)
