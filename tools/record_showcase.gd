extends SceneTree
## Plays four fights on the real fight screen, each with a bigger Mult build than the last, for a trailer:
##   godot --path . --resolution 1920x1080 --write-movie build/showcase/showcase.avi -s tools/record_showcase.gd
## Uses its own save files, never the player's.

## Each scene: floor, enemies, belt (relic id, or [id, run counter, fight counter]), each die's value, where each goes,
## and a relic to drag from one slot to another before End turn (to show the order mattering), if any.
const SCENES := [
	{"floor": "chapel", "enemies": ["skeleton"], "belt": ["whetstone"],
		"dice": [5, 3, 6], "slots": ["a", "a", "a"]},
	{"floor": "chapel", "enemies": ["acolyte", "rat"], "belt": ["black_candle", "whetstone", ["gravedigger", 8, 0], "twin_saints"],
		"dice": [6, 6, 5], "slots": ["s", "s", "a"], "move": [0, 3]},
	{"floor": "chapel", "enemies": ["warden"], "belt": ["gilded_pip", ["gravedigger", 15, 0], ["hungry_bell", 0, 2], "twin_saints", "black_candle"],
		"dice": [9, 9, 9], "slots": ["s", "s", "s"]},
	{"floor": "mine", "enemies": ["pit_king"], "belt": ["gilded_pip", ["gravedigger", 25, 0], ["hungry_bell", 0, 5], "mirror_shard", "black_candle"],
		"dice": [12, 12, 12], "slots": ["s", "s", "s"]},
]
const SLOTS := {"a": Combat.Slot.ATTACK, "s": Combat.Slot.SKILL}
const FADE := 0.4  # seconds to and from black between scenes

var game: Node
var black := ColorRect.new()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://main.tscn").instantiate()
	game.meta = Meta.load_from("user://showcase_meta.json")
	game.meta.tutorial_done = true
	game.run_path = "user://showcase_run.json"
	root.add_child(game)
	var cover := CanvasLayer.new()
	cover.layer = 100
	root.add_child(cover)
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(black)
	await process_frame
	game._start_run()
	await process_frame
	for scene: Dictionary in SCENES:
		await _play(scene)
	await _fade(1.0)
	quit()


func _play(scene: Dictionary) -> void:
	var combat: Combat = game.combat
	combat.relics.clear()
	for r in scene.belt:
		combat.take_relic(r if r is String else r[0])
	combat.skills = ["cleave", "sunder"]
	for i in 3:  # every face the same, so the throw lands on the value the scene wants
		var faces: Array = []
		faces.resize(6)
		faces.fill(scene.dice[i])
		combat.dice[i].base = faces.duplicate()
		combat.dice[i].faces = faces
	game.floor_id = scene.floor
	combat.start_group(scene.enemies)
	game._show_fight(func(_won: bool) -> void: pass)
	var screen: CombatScreen = game.screen
	for k in scene.belt.size():  # counters after the fight starts, which resets the fight ones
		if scene.belt[k] is Array:
			combat.relics[k].n = scene.belt[k][1]
			combat.relics[k].f = scene.belt[k][2]
	for e in combat.enemies:  # no enemy Guard this turn, so the count shows the build alone
		e.intent = {"kind": "attack", "value": 5}
	screen._refresh()
	await _fade(0.0)
	while not screen.charge.waiting:
		await process_frame
	await _wait(0.5)
	screen._on_roll_key(true)  # a held throw, the charge bar swinging
	await _wait(0.45)
	screen._on_roll_key(false)
	while screen.busy:
		await process_frame
	await _wait(0.5)
	for i in 3:
		combat.assign(i, SLOTS[scene.slots[i]])
		screen._refresh()
		await _wait(0.35)
	await _wait(0.6)
	if scene.has("move"):
		combat.move_relic(scene.move[0], scene.move[1])
		screen.belt.rebuild()
		screen._refresh()
		await _wait(1.0)
	screen._on_end_turn()
	while screen.counting:
		await process_frame
	await _wait(2.4)
	await _fade(1.0)


func _fade(to: float) -> void:
	var t := black.create_tween()
	t.tween_property(black, "color:a", to, FADE)
	await t.finished


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
