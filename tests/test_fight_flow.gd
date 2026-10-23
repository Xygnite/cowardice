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
	var late: Array = Floor.deal()[7]  # a dealt floor's last fight column, its biggest groups
	for keys in Combat.FIGHTS + late.filter(func(r): return r.kind == "fight").map(func(r): return r.enemies):
		await _play(keys)  # every set fight (all enemies are rigged now), plus dealt ones
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("FAILED: %d" % failures if failures else "All fight-flow checks passed.")
	quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)


## Starts a run straight into a fight against `keys`, as the --fight dev shortcut does, and plays it out.
func _play(keys: Array) -> void:
	var fight := ", ".join(keys)
	var errors_before := errors.count
	var game: Node = load("res://main.tscn").instantiate()
	game.meta = Meta.load_from(SAVE)
	game.meta.tutorial_done = true  # start at camp, not in the tutorial
	root.add_child(game)
	await process_frame  # the tree only runs the game's _ready once the main loop is going
	game._start_run()
	game.combat.start_group(keys)
	game._show_fight(game._on_fight_finished)
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
	await create_timer(0.5).timeout  # let the next screen settle, so its errors count too
	check(errors.count == errors_before, "fight %s plays through with no errors (got %d)" % [fight, errors.count - errors_before])
	game.queue_free()
	await process_frame
