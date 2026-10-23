extends Control
## Runs the game: a title menu, the tutorial on first play, then runs of map -> rooms -> boss,
## with Embers and perks carried between runs by Meta.

## Enemies a run can deal into its fights, and how much total enemy HP a fight gets by depth.
const ENEMIES := ["rat", "skeleton", "acolyte", "doctor", "bell", "treant", "moss", "grieve", "archivist"]
const ENTRANCE_HP := [18, 26]
const EARLY_HP := [18, 38]
const LATE_HP := [42, 56]
const BOSS := 6  # Combat.FIGHTS index
const LAYERS := 10
const EARLY_LAYERS := 4  # layers 1-4 get EARLY_HP fights, the rest LATE_HP
## Forges and campfires: each lands on one layer of its band, so they spread out. The last sits right before the boss.
const SPECIALS := [["forge", [1, 2]], ["campfire", [3, 4]], ["forge", [5, 6]], ["campfire", [8]]]

var meta := Meta.load_from()
var combat: Combat
var map: Array = []  # this run's floor, from make_map()
var layer := 0
var path: Array = []  # room picked on each layer so far
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
	music.volume_db = -8.0
	music.finished.connect(music.play)  # loop without touching the wav import settings
	add_child(music)
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
	map = make_map()
	layer = 0
	path.clear()
	_show_map()


## One floor of the Sunken Chapel, dealt fresh each run, entrance first: an easy fight, eight layers of
## two rooms (two fights, or a fight and a forge or campfire), then the boss. Every fight is a fresh
## random group, and no group appears twice.
static func make_map() -> Array:
	var used := {}
	var result := [[_fight_room(_group(ENTRANCE_HP, used))]]
	var specials := {}
	for s in SPECIALS:
		specials[s[1].pick_random()] = s[0]
	for li in range(1, LAYERS - 1):
		var row := []
		if specials.has(li):
			row.append({"kind": specials[li], "label": specials[li].capitalize()})
		while row.size() < 2:
			row.append(_fight_room(_group(EARLY_HP if li <= EARLY_LAYERS else LATE_HP, used)))
		row.shuffle()
		result.append(row)
	result.append([_fight_room(Combat.FIGHTS[BOSS])])
	return result


## One to three random ENEMIES whose total HP is within `hp`, a group not yet in `used`.
static func _group(hp: Array, used: Dictionary) -> Array:
	while true:
		var keys := []
		for i in randi_range(1, 3):
			keys.append(ENEMIES.pick_random())
		keys.sort()
		var total: int = keys.reduce(func(t, k): return t + Combat.TYPES[k].hp, 0)
		var id := ",".join(keys)
		if total >= hp[0] and total <= hp[1] and not used.has(id):
			used[id] = true
			return keys
	return []


## "Fight: Archivist, Bone Rats" from the fight's enemies.
static func _fight_room(keys: Array) -> Dictionary:
	var names := []
	for key in keys:
		var name: String = Combat.TYPES[key].name + ("s" if keys.count(key) > 1 else "")
		if name not in names:
			names.append(name)
	var boss: bool = Combat.TYPES[keys[0]].get("boss", false)
	return {"kind": "fight", "enemies": keys, "label": ("Boss: " if boss else "Fight: ") + ", ".join(names)}


func _show_map() -> void:
	var s := MapScreen.new()
	s.rooms = map
	s.layer = layer
	s.path = path
	s.combat = combat
	s.picked.connect(_on_room_picked)
	_show(s)


func _on_room_picked(i: int) -> void:
	path.append(i)
	var room: Dictionary = map[layer][i]
	match room.kind:
		"fight":
			combat.start_group(room.enemies)
			_show_fight(_on_fight_finished)
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
	if not won:
		_end_run(false)
	elif layer == map.size() - 1:
		_end_run(true)
	else:
		_next_room()


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
	var earned := Meta.embers_for(combat.kills, rooms_cleared, boss_pct, won)
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
