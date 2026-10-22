extends Control
## Runs the game: the tutorial on first launch, then runs of map -> rooms -> boss,
## with Embers and perks carried between runs by Meta.

## One floor of the Sunken Chapel, entrance first. You pick one room per layer.
const MAP := [
	[{"kind": "fight", "fight": 1, "label": "Fight: Bone Rats"}],
	[{"kind": "fight", "fight": 2, "label": "Fight: Skeleton, Grave Bell"}, {"kind": "forge", "label": "Forge"}],
	[{"kind": "campfire", "label": "Campfire"}, {"kind": "fight", "fight": 3, "label": "Fight: Shield Acolyte, Bone Rats"}],
	[{"kind": "fight", "fight": 4, "label": "Boss: Bone Warden"}],
]

var meta := Meta.load_from()
var combat: Combat
var layer := 0
var path: Array = []  # room picked on each layer so far
var screen: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():  # dev shortcut: `-- --fight=4` jumps straight into that fight
		if arg.begins_with("--fight="):
			_start_run()
			combat.start_fight(int(arg.trim_prefix("--fight=")))
			_show_fight(_on_fight_finished)
			return
	if meta.tutorial_done:
		_show_camp()
	else:
		combat = Combat.new()  # a new Combat starts on fight 0, the tutorial
		_show_fight(_on_tutorial_finished)


func _show(next: Control) -> void:
	if screen:
		screen.queue_free()
	screen = next
	add_child(next)


func _on_tutorial_finished(_won: bool) -> void:
	meta.tutorial_done = true
	meta.save()
	_start_run()


func _start_run() -> void:
	combat = Combat.new()
	combat.apply_perks(meta.equipped)
	layer = 0
	path.clear()
	_show_map()


func _show_map() -> void:
	var s := MapScreen.new()
	s.rooms = MAP
	s.layer = layer
	s.path = path
	s.combat = combat
	s.picked.connect(_on_room_picked)
	_show(s)


func _on_room_picked(i: int) -> void:
	path.append(i)
	var room: Dictionary = MAP[layer][i]
	match room.kind:
		"fight":
			combat.start_fight(room.fight)
			_show_fight(_on_fight_finished)
		"forge":
			_show_forge(false)
		"campfire":
			var heal := combat.campfire_heal_amount()
			_show_notice("Campfire", ["HP %d/%d" % [combat.player_hp, combat.max_hp]], -1, [
				["Rest  (+%d HP)" % heal, _on_rest],
				["Tend the dice  (one free upgrade)", _show_forge.bind(true)],
			])


func _show_fight(on_finished: Callable) -> void:
	var s := CombatScreen.new()
	s.combat = combat
	s.finished.connect(on_finished)
	_show(s)


func _on_fight_finished(won: bool) -> void:
	combat.claim_fight()
	if not won:
		_end_run(false)
	elif layer == MAP.size() - 1:
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
		"Depth reached: room %d of %d" % [mini(layer + 1, MAP.size()), MAP.size()],
		"Enemies slain: %d" % combat.kills,
		"Boss damage dealt: %d%%" % boss_pct,
		"Embers earned: +%d" % earned,
		"Embers: %d" % meta.embers,
	], 4, [["Walk back in", _start_run], ["Return to camp", _show_camp]])


func _show_camp() -> void:
	var s := CampScreen.new()
	s.meta = meta
	s.start_run.connect(_start_run)
	_show(s)


func _show_notice(title: String, lines: Array, highlight: int, choices: Array) -> void:
	var s := NoticeScreen.new()
	s.title = title
	s.lines = lines
	s.highlight = highlight
	s.choices = choices
	_show(s)
