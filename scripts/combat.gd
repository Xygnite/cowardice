class_name Combat
extends RefCounted
## Combat rules and per-run state (HP, dice, Shards, kills), no UI.
## One instance lasts a whole run; combat_screen.gd and game.gd drive it, tests/test_combat.gd checks it.

enum Slot { NONE, ATTACK, GUARD, CLEAVE }
enum Grade { MISS, GOOD, PERFECT }

const CURSE := 0  # a cursed face rolls as 0 and counts for nothing; a lasting curse is written into `base`
const REROLLS_PER_TURN := 2
const PLAYER_MAX_HP := 40
const GOOD_MS := 250
const CLEAVE_MULTIPLIER := 1.5
const SHARDS_PER_KILL := 2
const FORGE_COST := 4
const FORGE_STEP := 2  # a forged face goes up by this much
const CAMPFIRE_HEAL := 0.3  # share of max HP

## Enemy types. Optional keys:
## "turns": a tutorial enemy; the fight ends after that many turns and it can't die before.
## "rig_pair_turn": that turn's roll always contains a pair, so the Cleave lesson can happen.
## "bone_wall": blocks your highest Attack die aimed at it.
## "sprite": file name in assets/sprites/; enemies without one show a placeholder box.
## A "ring" intent turns another enemy's attack this turn unblockable.
const TYPES := {
	"dummy": {"name": "Training Dummy", "hp": 30, "sprite": "dummy", "turns": 5, "rig_pair_turn": 2,
		"phase1": [{"kind": "attack", "value": 3}, {"kind": "attack", "value": 4}, {"kind": "guard", "value": 2}, {"kind": "attack", "value": 3}, {"kind": "unblockable", "value": 5}]},
	"rat": {"name": "Bone Rat", "hp": 6, "sprite": "bone_rat",
		"phase1": [{"kind": "attack", "value": 2}]},
	"skeleton": {"name": "Skeleton", "hp": 20, "sprite": "skeleton",
		"phase1": [{"kind": "attack", "value": 5}, {"kind": "guard", "value": 4}, {"kind": "attack", "value": 7}]},
	"acolyte": {"name": "Shield Acolyte", "hp": 18, "sprite": "acolyte",
		"phase1": [{"kind": "guard", "value": 8}, {"kind": "guard", "value": 8}, {"kind": "attack", "value": 10}]},
	"doctor": {"name": "Plague Doctor", "hp": 22, "sprite": "plague_doctor",
		"phase1": [{"kind": "attack", "value": 6}, {"kind": "attack", "value": 4}, {"kind": "guard", "value": 5}]},
	"bell": {"name": "Grave Bell", "hp": 14, "sprite": "grave_bell",
		"phase1": [{"kind": "ring"}, {"kind": "attack", "value": 3}]},
	"treant": {"name": "Rotwood Treant", "hp": 26, "sprite": "rotwood_treant",
		"phase1": [{"kind": "guard", "value": 6}, {"kind": "attack", "value": 9}]},
	"moss": {"name": "Mother Moss", "hp": 22, "sprite": "mother_moss",
		"phase1": [{"kind": "attack", "value": 4}, {"kind": "curse"}, {"kind": "attack", "value": 6}]},
	"grieve": {"name": "Foreman Grieve", "hp": 28, "sprite": "foreman_grieve",
		"phase1": [{"kind": "attack", "value": 7}, {"kind": "guard", "value": 5}, {"kind": "unblockable", "value": 8}]},
	"archivist": {"name": "Archivist", "hp": 18, "sprite": "archivist",
		"phase1": [{"kind": "guard", "value": 6}, {"kind": "ring"}, {"kind": "attack", "value": 5}]},
	"warden": {"name": "Bone Warden", "hp": 75, "boss": true, "bone_wall": true, "sprite": "bone_warden",
		"phase1": [{"kind": "attack", "value": 8}, {"kind": "guard", "value": 6}, {"kind": "attack", "value": 10}],
		"phase2": [{"kind": "curse"}, {"kind": "unblockable", "value": 14}, {"kind": "attack", "value": 9}]},
	# The Hollow Mine. "pack": each other living one adds that much to its attack. "rallies": adds that much to every other
	# enemy's attack. "leaves": a fresh enemy of that type takes its place when it dies.
	"miner": {"name": "Lantern-Eye Miner", "hp": 22,
		"phase1": [{"kind": "attack", "value": 5}, {"kind": "attack", "value": 6}, {"kind": "unblockable", "value": 7}]},
	"crawler": {"name": "Tunnel Crawler", "hp": 8, "pack": 1,
		"phase1": [{"kind": "attack", "value": 3}]},
	"hulk": {"name": "Rubble Hulk", "hp": 30, "leaves": "rubble",
		"phase1": [{"kind": "guard", "value": 6}, {"kind": "attack", "value": 10}]},
	"rubble": {"name": "Rubble", "hp": 8,
		"phase1": [{"kind": "attack", "value": 3}]},
	"canary": {"name": "Canary Wraith", "hp": 12,
		"phase1": [{"kind": "ring"}, {"kind": "attack", "value": 3}]},
	"shaft_foreman": {"name": "Shaft Foreman", "hp": 26, "rallies": 2,
		"phase1": [{"kind": "attack", "value": 5}, {"kind": "guard", "value": 4}, {"kind": "attack", "value": 7}]},
	"pit_king": {"name": "Pit King", "hp": 100, "boss": true, "phase1": [{"kind": "attack", "value": 4}]},
}

## Set fights for the tutorial (0), the boss (6), tests and the --fight shortcut. A run deals its own groups in game.gd.
const FIGHTS := [["dummy"], ["rat", "rat", "rat"], ["skeleton", "bell"], ["acolyte", "doctor", "rat"],
	["treant", "moss"], ["grieve", "archivist"], ["warden"]]

var rng := RandomNumberGenerator.new()
var perks: Array = []  # perk ids from Meta.PERKS equipped for this run
var max_hp := PLAYER_MAX_HP
var player_hp := PLAYER_MAX_HP
var shards := 0
var kills := 0
var replaced := 0  # enemies this fight that died and were replaced (a Hulk's Rubble); they still count as kills
var dungeon_turns := 0  # enemy turns in dungeon fights this run; drives the murmurs
var dice: Array[Dictionary] = []
var rerolls := 0
var grit := 0
var ward_spent := false  # Hex Ward already took this fight's first curse
var fight := 0
var enemies: Array[Dictionary] = []  # {type, name, hp, intent}
var target := 0
var guard_pool := 0  # Guard left to soak this turn's hits; set when you end your turn
var turn := 0
var bonus_embers := 0  # extra embers an event promised for the end of the run


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	for i in 3:
		dice.append({"base": [1, 2, 3, 4, 5, 6], "faces": [1, 2, 3, 4, 5, 6], "value": 1, "locked": false, "slot": Slot.NONE, "uncursed": {}})
	start_fight(0)


func apply_perks(ids: Array) -> void:
	perks = ids.duplicate()
	max_hp = PLAYER_MAX_HP + (10 if "thick_skin" in perks else 0)
	player_hp = max_hp


func heal(amount: int) -> void:
	player_hp = mini(max_hp, player_hp + amount)


func campfire_heal_amount() -> int:
	return ceili(max_hp * (0.45 if "bonfire_keeper" in perks else CAMPFIRE_HEAL))


## Raises face f of die i by FORGE_STEP for the rest of the run. Paid in Shards unless no_cost.
func forge(i: int, f: int, no_cost := false) -> bool:
	if not no_cost:
		if shards < FORGE_COST:
			return false
		shards -= FORGE_COST
	var d: Dictionary = dice[i]
	if d.uncursed.has(f):  # forging a lasting curse lifts it instead
		d.base[f] = d.uncursed[f]
		d.uncursed.erase(f)
	else:
		d.base[f] += FORGE_STEP
	d.faces = d.base.duplicate()
	return true


## Lasting curse: face f of die i is cursed for the rest of the run, and forging it restores the old face.
func curse_face(i: int, f: int) -> void:
	var d: Dictionary = dice[i]
	d.uncursed[f] = d.base[f]
	d.base[f] = CURSE
	d.faces = d.base.duplicate()


## Turns face f of die i into a 9 and lastingly curses another uncursed face. Returns that face, or -1 if none.
func carve(i: int, f: int) -> int:
	var d: Dictionary = dice[i]
	d.base[f] = 9
	d.uncursed.erase(f)
	d.faces = d.base.duplicate()
	var options: Array = []
	for o in d.base.size():
		if o != f and d.base[o] != CURSE:
			options.append(o)
	if options.is_empty():
		return -1
	var pick: int = options[rng.randi_range(0, options.size() - 1)]
	curse_face(i, pick)
	return pick


## Loses up to `amount` HP but never the last one (the last five with Lucky Charm). Returns what was actually lost.
func hurt(amount: int) -> int:
	var lost := clampi(player_hp - (5 if "lucky_charm" in perks else 1), 0, amount)
	player_hp -= lost
	return lost


func lose_max_hp(amount: int) -> void:
	max_hp -= amount
	player_hp = clampi(player_hp, 1, max_hp)


## Rolls the dice at the indices in `which`; returns their new values in order.
func roll_dice(which: Array) -> Array:
	var out: Array = []
	for i in which:
		_roll(dice[i])
		out.append(dice[i].value)
	return out


## Call once when a fight ends, won or lost: counts kills and pays Shards for them.
func claim_fight() -> void:
	var dead := enemies.filter(func(e): return e.hp == 0).size() + replaced
	kills += dead
	if not is_tutorial():
		shards += dead * (SHARDS_PER_KILL + (1 if "scavenger" in perks else 0))


## How much of the boss's HP you took, 0 to 100. 0 outside a boss fight.
func boss_damage_pct() -> int:
	if not is_boss_fight():
		return 0
	return 100 * (enemies[0].type.hp - enemies[0].hp) / enemies[0].type.hp


func start_fight(index: int) -> void:
	fight = index
	start_group(FIGHTS[index])


## Starts a fight against `keys` (TYPES keys, at most three of one type).
func start_group(keys: Array) -> void:
	enemies.clear()
	replaced = 0
	var seen := {}
	for key in keys:
		var t: Dictionary = TYPES[key]
		var name: String = t.name
		if keys.count(key) > 1:  # Bone Rat A, B, C
			seen[key] = seen.get(key, 0) + 1
			name += " " + "ABC"[seen[key] - 1]
		enemies.append({"type": t, "name": name, "hp": t.hp, "intent": {}})
	target = 0
	turn = 0
	grit = 0
	ward_spent = false
	for d in dice:
		d.faces = d.base.duplicate()  # boss tampering ends with the fight
	start_turn()


func start_turn() -> void:
	rerolls = REROLLS_PER_TURN + grit + (1 if "steady_hand" in perks else 0)
	grit = 0
	for e in enemies:
		e.intent = _next_intent(e) if e.hp > 0 else {}
	_apply_bonuses()
	_apply_rings()
	for d in dice:
		d.locked = false
		d.slot = Slot.NONE
		_roll(d)
	if enemies[0].type.get("rig_pair_turn", -1) == turn:
		dice[1].value = dice[0].value


func alive(i: int) -> bool:
	return enemies[i].hp > 0


func fight_won() -> bool:
	return enemies.all(func(e): return e.hp == 0)


func is_tutorial() -> bool:
	return enemies[0].type.has("turns")


func tutorial_done() -> bool:
	return is_tutorial() and turn >= enemies[0].type.turns


func is_boss_fight() -> bool:
	return enemies[0].type.get("boss", false)


func is_phase2(e: Dictionary) -> bool:
	return e.type.get("boss", false) and e.hp * 2 <= e.type.hp


func set_target(i: int) -> void:
	if alive(i):
		target = i


func reroll() -> bool:
	if rerolls <= 0:
		return false
	rerolls -= 1
	for d in dice:
		if not d.locked:
			_roll(d)
	return true


func toggle_lock(i: int) -> void:
	dice[i].locked = not dice[i].locked


func assign(i: int, slot: Slot) -> void:
	dice[i].slot = slot


func guard_total() -> int:
	return _sum(_values_in(Slot.GUARD))


func has_guard() -> bool:
	return not _values_in(Slot.GUARD).is_empty()


func cleave_ready() -> bool:
	var v := _values_in(Slot.CLEAVE)
	return v.size() == 2 and v[0] == v[1] and v[0] != CURSE


func parry_window_ms() -> int:
	return 60 + 10 * _best_guard_pip() + _nerve_ms()


## A high Guard die widens the Perfect window too, so a lone 1 in Guard can't Perfect everything.
func perfect_window_ms() -> int:
	return 40 + 10 * _best_guard_pip() + _nerve_ms()


## Iron Nerve's extra time on the Perfect block and parry windows.
func _nerve_ms() -> int:
	return 40 if "iron_nerve" in perks else 0


## Total Cleave damage, split evenly across living enemies by cleave_share().
func cleave_damage() -> int:
	if not cleave_ready():
		return 0
	var pair := _values_in(Slot.CLEAVE)
	var total := 12 if pair[0] == 1 and "gamblers_heart" in perks else _sum(pair)  # snake eyes count as 12
	return ceili(total * CLEAVE_MULTIPLIER)


## Enemy i's share of the Cleave. Leftover points go one each to the target first, then down the row.
func cleave_share(i: int) -> int:
	var up: Array[int] = []
	for j in enemies.size():
		if alive(j):
			up.append(j)
	if not alive(i):
		return 0
	var total := cleave_damage()
	var rank := (up.find(i) - up.find(target) + up.size()) % up.size()
	return total / up.size() + (1 if rank < total % up.size() else 0)


## The value of a pair in the current roll, or 0 if there is none.
func rolled_pair() -> int:
	for i in dice.size():
		for j in range(i + 1, dice.size()):
			if dice[i].value == dice[j].value and dice[i].value != CURSE:
				return dice[i].value
	return 0


func unplaced_count() -> int:
	return _values_in(Slot.NONE).size()


## Damage your placed dice would deal to enemy i right now: Attack hits the target, Cleave is shared out.
func damage_to(i: int) -> int:
	if not alive(i):
		return 0
	var e := enemies[i]
	var damage := 0
	if i == target:
		var attack := _values_in(Slot.ATTACK)
		if e.type.get("bone_wall", false) and not attack.is_empty():
			attack.erase(attack.max())  # Bone Wall: the Warden blocks your highest Attack die
		damage = _sum(attack)
		if e.intent.get("kind") == "guard":
			damage = maxi(0, damage - e.intent.value)
	return damage + cleave_share(i)  # Cleave ignores Bone Wall and enemy Guard


func preview_damage() -> int:
	var total := 0
	for i in enemies.size():
		total += damage_to(i)
	return total


## Resolves your placed dice. Returns total damage dealt.
func resolve_player() -> int:
	var hits: Array[int] = []
	for i in enemies.size():
		hits.append(damage_to(i))
	var floor_hp := 1 if is_tutorial() else 0
	for i in enemies.size():
		if alive(i):
			enemies[i].hp = maxi(floor_hp, enemies[i].hp - hits[i])
			if enemies[i].hp == 0 and enemies[i].type.has("leaves"):
				var t: Dictionary = TYPES[enemies[i].type.leaves]
				enemies[i] = {"type": t, "name": t.name, "hp": t.hp, "intent": {}, "from": enemies[i].name}  # acts from next turn; "from" lets the screen show the swap
				replaced += 1
	for d in dice:
		if d.slot == Slot.GUARD and d.value == CURSE:
			d.faces = d.base.duplicate()  # a cursed face placed in Guard burns off
		if d.slot == Slot.NONE:
			grit += 2 if "grit_teeth" in perks else 1
	guard_pool = guard_total()
	if not alive(target):
		for i in enemies.size():
			if alive(i):
				target = i
				break
	return _sum(hits)


## Timing only happens with a die in Guard, against something you can block or parry.
func needs_timing(i: int) -> bool:
	return has_guard() and enemies[i].intent.get("kind") in ["attack", "unblockable", "curse"]


func grade_for(remaining_ms: float, i: int) -> Grade:
	if remaining_ms < 0:
		return Grade.MISS
	if enemies[i].intent.kind == "attack":
		if remaining_ms <= perfect_window_ms():
			return Grade.PERFECT
		if remaining_ms <= GOOD_MS:
			return Grade.GOOD
		return Grade.MISS
	return Grade.PERFECT if remaining_ms <= parry_window_ms() else Grade.MISS


## Enemy i acts on its intent. Returns a line for the log. Call end_enemy_phase() after all have acted.
func resolve_enemy(i: int, grade: Grade) -> String:
	var e := enemies[i]
	var text := ""
	match e.intent.kind:
		"attack":
			var hit := 0
			if grade != Grade.PERFECT:
				var soak := ceili(guard_pool * 1.5) if grade == Grade.GOOD else guard_pool
				var blocked := mini(e.intent.value, soak)
				hit = e.intent.value - blocked
				guard_pool = maxi(0, guard_pool - blocked)
			player_hp -= hit
			text = "%s%s hits for %d." % [["", "Good block! ", "Perfect block! "][grade], e.name, hit]
		"unblockable":
			if grade == Grade.PERFECT:
				text = "Parried %s!" % e.name
			else:
				player_hp -= e.intent.value
				text = "%s: unblockable hit for %d." % [e.name, e.intent.value]
		"curse":
			if grade == Grade.PERFECT:
				text = "Parried the Curse sticker!"
			elif "hex_ward" in perks and not ward_spent:
				ward_spent = true
				text = "The Hex Ward takes the curse."
			else:
				_curse(dice[e.intent.target])
				text = "Die %d got a Curse face." % (e.intent.target + 1)
		"guard":
			text = "%s braced behind its guard." % e.name
		"ring":
			text = "%s tolls." % e.name
	player_hp = maxi(0, player_hp)
	return text


func end_enemy_phase() -> void:
	turn += 1
	if not is_tutorial() and not is_boss_fight():
		dungeon_turns += 1


func intent_text(i: int) -> String:
	var it: Dictionary = enemies[i].intent
	match it.get("kind"):
		"attack":
			return "Attack %d" % it.value
		"guard":
			return "Guard %d" % it.value
		"curse":
			return "Curse sticker on die %d" % (it.target + 1)
		"unblockable":
			return "UNBLOCKABLE %d" % it.value
		"ring":
			return "Ring"
	return ""


func _next_intent(e: Dictionary) -> Dictionary:
	var pattern: Array = e.type.phase2 if is_phase2(e) else e.type.phase1
	var next: Dictionary = pattern[turn % pattern.size()].duplicate()
	if next.kind == "curse":
		next.target = rng.randi_range(0, dice.size() - 1)
	return next


## Pack and rally bonuses on attack values, from who is alive now, so the intent shows the final number.
func _apply_bonuses() -> void:
	var rally := 0
	for e in enemies:
		if e.hp > 0:
			rally += e.type.get("rallies", 0)
	for e in enemies:
		if e.intent.get("kind") not in ["attack", "unblockable"]:
			continue
		var pack: int = e.type.get("pack", 0)
		if pack:
			e.intent.value += pack * (enemies.filter(func(o): return o.hp > 0 and o.type == e.type).size() - 1)
		e.intent.value += rally - e.type.get("rallies", 0)


## A ringing enemy makes the first other enemy's attack this turn unblockable, shown in its intent.
func _apply_rings() -> void:
	for bell in enemies:
		if bell.intent.get("kind") != "ring":
			continue
		for e in enemies:
			if not is_same(e, bell) and e.intent.get("kind") == "attack":
				e.intent.kind = "unblockable"
				e.intent.rung = true  # only for show: the screen marks who the bell empowered
				break


func _roll(d: Dictionary) -> void:
	d.value = d.faces[rng.randi_range(0, d.faces.size() - 1)]


func _curse(d: Dictionary) -> void:
	var best := -1
	for i in d.faces.size():
		if d.faces[i] != CURSE and (best < 0 or d.faces[i] > d.faces[best]):
			best = i
	if best >= 0:
		d.faces[best] = CURSE


func _best_guard_pip() -> int:
	var v := _values_in(Slot.GUARD)
	return v.max() if not v.is_empty() else 0


func _values_in(slot: Slot) -> Array[int]:
	var out: Array[int] = []
	for d in dice:
		if d.slot == slot:
			out.append(d.value)
	return out


func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += v
	return total
