extends Control
## Runs the game: a title menu, the tutorial on first play, then runs of map -> rooms -> boss,
## with Embers and perks carried between runs by Meta.

var meta := Meta.load_from()
var combat: Combat
var map: Array = []  # this run's floor, from Floor.deal()
var layer := 0
var path: Array = []  # room picked on each layer so far
var seen_events: Array = []  # "?" events met this run; each happens once
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


func _show_menu() -> void:
	var s := MenuScreen.new()
	s.tutorial_done = meta.tutorial_done
	s.meta = meta
	s.play.connect(_on_play)
	s.tutorial.connect(_show_tutorial)
	_show(s)


func _on_play() -> void:
	if meta.tutorial_done:
		_show_camp()
	else:
		_show_tutorial()


func _show_tutorial() -> void:
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


func _start_run() -> void:
	combat = Combat.new()
	combat.apply_perks(meta.equipped)
	map = Floor.deal()
	layer = 0
	path.clear()
	seen_events.clear()
	_show_map()


func _show_map() -> void:
	var s := MapScreen.new()
	s.rooms = map
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
			combat.start_group(room.enemies)
			_show_fight(_on_fight_finished)
		"unknown":
			var id: String = Events.pick(seen_events)
			if id == "" or randf() < Events.AMBUSH_CHANCE:
				_start_ambush()
			else:
				_show_event(id)
		"forge":
			_show_forge(false)
		"campfire":
			var heal := combat.campfire_heal_amount()
			_show_notice("Campfire", ["HP %d/%d" % [combat.player_hp, combat.max_hp]], -1, [
				["Rest  (+%d HP)" % heal, _on_rest],
				["Tend the dice  (one free upgrade)", _show_forge.bind(true)],
			], "campfire")


func _show_fight(on_finished: Callable) -> void:
	var s := CombatScreen.new()
	s.combat = combat
	s.finished.connect(on_finished)
	_show(s)


func _on_fight_finished(won: bool) -> void:
	combat.claim_fight()
	if ambush and won:
		combat.shards += Events.AMBUSH_SHARDS
	ambush = false
	if not won:
		_end_run(false)
	elif layer == map.size() - 1:
		_end_run(true)
	else:
		_next_room()


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
	combat.start_group(Floor.group(Floor.EARLY_HP, {}))
	_show_fight(_on_fight_finished)
	screen._log("Something moves in the dark.")
	screen._refresh()


func _show_forge(no_cost: bool) -> void:
	var s := ForgeScreen.new()
	s.combat = combat
	s.no_cost = no_cost
	s.done.connect(_next_room)
	_show(s)


func _on_rest() -> void:
	combat.heal(combat.campfire_heal_amount())
	_next_room()


func _next_room() -> void:
	layer += 1
	_show_map()


func _end_run(won: bool) -> void:
	var rooms_cleared := layer + (1 if won else 0)
	var boss_pct := combat.boss_damage_pct()
	var earned := Meta.embers_for(combat.kills, rooms_cleared, boss_pct, won) + combat.bonus_embers
	meta.embers += earned
	meta.save()
	var title := "The Bone Warden falls." if won else "You fled."
	var narrator := "The chapel goes quiet." if won else ("The Warden will remember your back." if combat.is_boss_fight() else "The dungeon keeps what you dropped.")
	_show_notice(title, [
		narrator,
		"Depth reached: room %d of %d" % [mini(layer + 1, map.size()), map.size()],
		"Enemies slain: %d" % combat.kills,
		"Boss damage dealt: %d%%" % boss_pct,
		"Embers earned: +%d" % earned,
		"Embers: %d" % meta.embers,
	], 4, [["Walk back in", _start_run], ["Return to camp", _show_camp]], "victory" if won else "defeat")


func _show_camp() -> void:
	var s := CampScreen.new()
	s.meta = meta
	s.start_run.connect(_start_run)
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
