class_name Combat
extends RefCounted
## Combat rules and per-run state (HP, dice, Shards, kills), no UI.
## One instance lasts a whole run; combat_screen.gd and game.gd drive it, tests/test_combat.gd checks it.

enum Slot { NONE, ATTACK, GUARD, SKILL }  # SKILL fires every unlocked skill (SKILLS) its dice make
enum Grade { MISS, GOOD, PERFECT }

const CURSE := 0  # a cursed face rolls as 0 and counts for nothing; a lasting curse is written into `base`
const REROLLS_PER_TURN := 2
const PLAYER_MAX_HP := 40
const GOOD_MS := 250
const CLEAVE_MULTIPLIER := 1.5
const SUNDER_MULTIPLIER := 2.5
const FLURRY_BONUS := 3
const GAMBIT_DAMAGE := 12
## Skills: the Skill slot fires every unlocked skill (`skills`) whose pattern ("need") its dice make, all at once;
## every skill ignores enemy Guard and Bone Wall, and a cursed die breaks any pattern. Cleave is free; the rest are
## unlocked for good with Embers on the camp board (Meta.skills).
const SKILLS := {
	"cleave": {"name": "Cleave", "cost": 0, "dice": ["a", "a"], "need": "Two matching dice", "text": "x1.5 their total, split across every enemy"},
	"sunder": {"name": "Sunder", "cost": 600, "dice": ["a", "a", "a"], "need": "Three matching dice", "text": "x2.5 their total to every enemy, in full"},
	"flurry": {"name": "Flurry", "cost": 300, "dice": ["2", "3", "4"], "need": "Three dice in a row, like 2-3-4", "text": "Three hits on the target: their total +3"},
	"cower": {"name": "Cower", "cost": 450, "dice": ["1", "2", "1"], "need": "Three dice, each a 1 or 2", "text": "Every enemy action this turn misses you"},
	"oath": {"name": "Oath", "cost": 400, "dice": ["1", "3", "5"], "need": "Three dice, all odd or all even", "text": "Odd: their total to the target. Even: heal half their total"},
	"gambit": {"name": "Gambit", "cost": 300, "dice": ["1", "6"], "need": "A 1 and a 6", "text": "12 to the target; killing it pays +1 Shard"},
}
const SHARDS_PER_KILL := 2
const FORGE_COST := 4
const FORGE_STEP := 2  # a forged face goes up by this much
## A Forge roll (FORGE_COST, a die thrown at the Forge): what it grants by the die's 1 to 6, then put on a face you pick.
const FORGE_ROLL := [{"step": 1}, {"mark": "sharp"}, {"mark": "ember"}, {"mark": "ward"}, {"mark": "shard"}, {"step": 4}]
const CAMPFIRE_HEAL := 0.3  # share of max HP
## Marks a face can be forged with instead of +FORGE_STEP. A mark works when its face is the one rolled and that die is
## placed; a cursed face's mark sleeps until the curse lifts. Kept in each die's "marks", one per face ("" for none).
## Each has a glyph, assets/ui/cut/mark_<key>.png (art/pxl/marks.px.js), so a mark reads without its colour.
const MARKS := {
	"sharp": {"name": "Sharp", "text": "In Attack, ignores enemy Guard and Bone Wall"},
	"ember": {"name": "Ember", "text": "Placed anywhere, heals 2 HP"},
	"ward": {"name": "Ward", "text": "In Guard, counts double"},
	"shard": {"name": "Shard", "text": "Placed anywhere, +1 Shard"},
}
const EMBER_HEAL := 2
## Relics: run-only, on a belt of BELT_SIZE slots, mostly raising the turn's Mult. Every hit is floori(base x Mult);
## Mult builds left to right along the belt: each slot adds, then multiplies (mult()). Relics cost Shards to buy; destroying one pays half its price back.
const RELICS := {
	"whetstone": {"name": "Whetstone", "text": "Attack dice showing 5 or 6 deal +3 each", "rare": false},
	"twin_saints": {"name": "Twin Saints", "text": "Cleave or Sunder fires: +1 Mult", "rare": false},
	"rusted_censer": {"name": "Rusted Censer", "text": "+0.5 Mult per Ember face placed this turn", "rare": false},
	"clenched_jaw": {"name": "Clenched Jaw", "text": "+0.1 Mult per point of Grit this turn", "rare": false},
	"tithe_box": {"name": "Tithe Box", "text": "After each fight, +1 Shard per 5 held, max +3", "rare": false},
	"gravedigger": {"name": "Gravedigger's Tally", "text": "+0.1 Mult per kill since taken", "rare": false},
	"miners_ledger": {"name": "Miner's Ledger", "text": "+1 to the Attack hit per 4 Shards spent at forges since taken", "rare": false},
	"spare_fuse": {"name": "Spare Fuse", "text": "Each unused reroll at end of turn: +0.25 Mult for the rest of the fight", "rare": false},
	"ward_icon": {"name": "Ward Icon", "text": "Guard left after the enemy phase adds to next turn's Attack hit", "rare": false},
	"hungry_bell": {"name": "Hungry Bell", "text": "+1 Mult per turn in a row a skill fires", "rare": true},
	"cursed_crown": {"name": "Cursed Crown", "text": "Cursed faces count as 6 for damage; they still break patterns", "rare": true},
	"gilded_pip": {"name": "Gilded Pip", "text": "+0.5 Mult per placed die showing a face above 6", "rare": true},
	"rosary": {"name": "Rosary of Steps", "text": "Flurry's +3 becomes +9", "rare": true},
	"black_candle": {"name": "Black Candle", "text": "x1.5 Mult", "rare": true},
	"pit_lantern": {"name": "Pit Lantern", "text": "x2 Mult when every placed die is in Attack", "rare": true},
	"mirror_shard": {"name": "Mirror Shard", "text": "Copies the relic to its right", "rare": true},
}
const BELT_SIZE := 5
const COMMON_PRICE := 4
const RARE_PRICE := 8

## Enemy types. Optional keys:
## "turns": a tutorial enemy; the fight ends after that many turns and it can't die before.
## "bone_wall": blocks your highest Attack die aimed at it.
## "sprite": file name in assets/sprites/; enemies without one show a placeholder box.
## A buried die ("buried" > 0) keeps its value and slot, and can't be rolled, locked or placed, for the next turn.
## A "ring" intent turns another enemy's attack this turn unblockable.
const TYPES := {
	"dummy": {"name": "Training Dummy", "hp": 30, "sprite": "dummy", "turns": 5,
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
	"warden": {"name": "Bone Warden", "hp": 120, "boss": true, "bone_wall": true, "sprite": "bone_warden",
		"phase1": [{"kind": "attack", "value": 8}, {"kind": "guard", "value": 6}, {"kind": "attack", "value": 10}],
		"phase2": [{"kind": "curse"}, {"kind": "unblockable", "value": 14}, {"kind": "attack", "value": 9}]},
	# The Hollow Mine. "pack": each other living one adds that much to its attack. "rallies": adds that much to every other
	# enemy's attack. "leaves": a fresh enemy of that type takes its place when it dies.
	"miner": {"name": "Lantern-Eye Miner", "hp": 22, "sprite": "miner",
		"phase1": [{"kind": "attack", "value": 5}, {"kind": "attack", "value": 6}, {"kind": "unblockable", "value": 7}]},
	"crawler": {"name": "Tunnel Crawler", "hp": 8, "sprite": "crawler", "pack": 1,
		"phase1": [{"kind": "attack", "value": 3}]},
	"hulk": {"name": "Rubble Hulk", "hp": 30, "sprite": "hulk", "leaves": "rubble",
		"phase1": [{"kind": "guard", "value": 6}, {"kind": "attack", "value": 10}]},
	"rubble": {"name": "Rubble", "hp": 8, "sprite": "rubble",
		"phase1": [{"kind": "attack", "value": 3}]},
	"canary": {"name": "Canary Wraith", "hp": 12, "sprite": "canary",
		"phase1": [{"kind": "ring"}, {"kind": "attack", "value": 3}]},
	"shaft_foreman": {"name": "Shaft Foreman", "hp": 26, "sprite": "shaft_foreman", "rallies": 2,
		"phase1": [{"kind": "attack", "value": 5}, {"kind": "guard", "value": 4}, {"kind": "attack", "value": 7}]},
	# Cave-ins bury a die (see bury_one). The Pit King's phase 2 attacks all carry one.
	"pit_king": {"name": "Pit King", "hp": 220, "sprite": "pit_king", "boss": true,
		"phase1": [{"kind": "attack", "value": 7}, {"kind": "cave_in"}, {"kind": "attack", "value": 10}, {"kind": "guard", "value": 6}],
		"phase2": [{"kind": "attack", "value": 9, "cave_in": true}, {"kind": "attack", "value": 12, "cave_in": true}, {"kind": "attack", "value": 8, "cave_in": true}]},
}

## Set fights for the tutorial (0), the boss (6), tests and the --fight shortcut. A run deals its own groups in game.gd.
const FIGHTS := [["dummy"], ["rat", "rat", "rat"], ["skeleton", "bell"], ["acolyte", "doctor", "rat"],
	["treant", "moss"], ["grieve", "archivist"], ["warden"]]
## The tutorial's dice, by turn: one lesson each (Attack, Guard, a Cleave pair, Grit, a parry); the screen guides each.
const TUTORIAL_DICE := [[5, 2, 3], [4, 1, 2], [6, 6, 1], [3, 5, 2], [6, 2, 3]]

var rng := RandomNumberGenerator.new()
var perks: Array = []  # perk ids from Meta.PERKS equipped for this run, plus the bonus one
var bonus_perk := ""  # the perk picked after the Warden, active this run only
var max_hp := PLAYER_MAX_HP
var player_hp := PLAYER_MAX_HP
var shards := 0
var kills := 0
var replaced := 0  # enemies this fight that died and were replaced (a Hulk's Rubble); they still count as kills
var dungeon_turns := 0  # enemy turns in dungeon fights on this floor; drives the murmurs
var dice: Array[Dictionary] = []
var rerolls := 0
var grit := 0
var ward_spent := false  # Hex Ward already took this fight's first curse
var skills: Array = ["cleave"]  # unlocked SKILLS ids, from Meta.skills; not saved with a run
var cowered := false  # Cower went off this turn: every enemy action misses
var fight := 0
var enemies: Array[Dictionary] = []  # {type, name, hp, intent}
var target := 0
var guard_pool := 0  # Guard left to soak this turn's hits; set when you end your turn
var turn := 0
var bonus_embers := 0  # extra embers an event promised for the end of the run
var relics: Array = []  # the belt, left to right: {"id": RELICS key, "n": run counter, "f": this fight's counter}
var best_hit := 0  # the biggest single Mult-applied hit this run
var best_mult := 1.0  # the highest Mult a resolve dealt damage at this run
var shopped := false  # the run's first Spoils has shown (it offers commons only)


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	for i in 3:
		dice.append({"base": [1, 2, 3, 4, 5, 6], "faces": [1, 2, 3, 4, 5, 6], "value": 1, "locked": false, "slot": Slot.NONE, "uncursed": {}, "buried": 0, "marks": ["", "", "", "", "", ""], "side": 0})
	start_fight(0)


## What a run save keeps (RunSave): only what lasts between fights, as it is at a campfire.
const SAVED := ["max_hp", "player_hp", "shards", "kills", "perks", "bonus_perk", "bonus_embers", "dungeon_turns"]


## Fields added after run saves existed: an older save may lack them (they load as these defaults), but not hold the wrong type.
const SAVED_LATER := {"relics": [], "best_hit": 0, "best_mult": 1.0, "shopped": false}


func to_dict() -> Dictionary:
	var d := {"dice": dice.map(func(x): return {"base": x.base, "faces": x.faces, "uncursed": x.uncursed, "marks": x.marks})}
	for k in SAVED:
		d[k] = get(k)
	for k in SAVED_LATER:
		d[k] = get(k)
	return d.duplicate(true)


## Whether `d` is a to_dict() that from_dict() can load: every field there, with the right type, and all the dice.
static func valid_dict(d) -> bool:
	if not d is Dictionary or not d.get("dice") is Array:
		return false
	var blank := Combat.new()
	if d.dice.size() != blank.dice.size():
		return false
	for x in d.dice:
		if not (x is Dictionary and x.get("base") is Array and x.get("faces") is Array and x.get("uncursed") is Dictionary):
			return false
	if not SAVED.all(func(k): return d.has(k) and typeof(d[k]) == typeof(blank.get(k))):
		return false
	if d.has("relics") and not (d.relics is Array and d.relics.all(func(r): return r is Dictionary and r.get("id") is String and Combat.RELICS.has(r.id) and r.get("n") is float and r.get("f") is float)):
		return false
	if d.has("shopped") and not d.shopped is bool:
		return false
	return ["best_hit", "best_mult"].all(func(k): return not d.has(k) or typeof(d[k]) in [TYPE_INT, TYPE_FLOAT])


static func from_dict(d: Dictionary) -> Combat:
	var c := Combat.new()
	for k in SAVED:
		c.set(k, d[k])
	c.relics = d.get("relics", []).map(func(r): return {"id": r.id, "n": float(r.n), "f": float(r.f)})
	c.best_hit = int(d.get("best_hit", 0))
	c.best_mult = float(d.get("best_mult", 1.0))
	c.shopped = bool(d.get("shopped", c.kills > 0))  # an older save mid-run has already seen its first Spoils
	for i in c.dice.size():
		c.dice[i].merge(d.dice[i].duplicate(true), true)
	return c


func apply_perks(ids: Array) -> void:
	perks = ids.duplicate()
	max_hp = PLAYER_MAX_HP + (10 if "thick_skin" in perks else 0)
	player_hp = max_hp


## Adds a perk mid-run (the bonus after the Warden). Thick Skin's +10 max HP comes with +10 HP, once.
func add_perk(id: String) -> void:
	if id in perks:
		return
	perks.append(id)
	bonus_perk = id
	if id == "thick_skin":
		max_hp += 10
		player_hp += 10


func heal(amount: int) -> void:
	player_hp = mini(max_hp, player_hp + amount)


func campfire_heal_amount() -> int:
	return ceili(max_hp * (0.45 if "bonfire_keeper" in perks else CAMPFIRE_HEAL))


## Raises face f of die i by `step` for the rest of the run, or with `mark` (a MARKS key) marks it instead.
## Paid in Shards unless no_cost. A mark replaces the face's old one, and on a cursed face it lifts the curse too;
## a face can't take the mark it already has.
func forge(i: int, f: int, no_cost := false, mark := "", step := FORGE_STEP) -> bool:
	var d: Dictionary = dice[i]
	if mark and d.marks[f] == mark:
		return false
	if not no_cost:
		if shards < FORGE_COST:
			return false
		pay_forge()
	if mark:
		d.marks[f] = mark
		if d.base[f] == CURSE:
			d.base[f] = d.uncursed.get(f, 1)
			d.uncursed.erase(f)
	elif d.uncursed.has(f):  # forging a lasting curse lifts it instead
		d.base[f] = d.uncursed[f]
		d.uncursed.erase(f)
	else:
		d.base[f] += step
	d.faces = d.base.duplicate()
	return true


## Whether some face doesn't carry `mark` yet, so a rolled one has somewhere to go.
func can_mark(mark: String) -> bool:
	return dice.any(func(d): return d.marks.count(mark) < d.marks.size())


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
## On screen these are provisional: the thrown dice's landed faces replace them (as for every roll here).
func roll_dice(which: Array) -> Array:
	var out: Array = []
	for i in which:
		_roll(dice[i])
		out.append(dice[i].value)
	return out


## Call once when a fight ends, won or lost: counts kills and pays Shards for them; a won fight pays Tithe Boxes.
func claim_fight(won := true) -> void:
	var dead := enemies.filter(func(e): return e.hp == 0).size() + replaced
	kills += dead
	if not is_tutorial():
		shards += dead * (SHARDS_PER_KILL + (1 if "scavenger" in perks else 0))
	for k in relics.size():
		match relic_id(k):
			"gravedigger":
				relics[k].n += dead
			"tithe_box":
				if won:
					shards += mini(3, shards / 5)


## Pays FORGE_COST Shards for a forge throw; every Miner's Ledger counts it.
func pay_forge() -> void:
	shards -= FORGE_COST
	_ledger(FORGE_COST)


## Gives back a forge throw's Shards, and takes them off every Ledger again.
func refund_forge() -> void:
	shards += FORGE_COST
	_ledger(-FORGE_COST)


func _ledger(amount: int) -> void:
	for k in relics.size():
		if relic_id(k) == "miners_ledger":
			relics[k].n += amount


## How much of the boss's HP you took, 0 to 100. 0 outside a boss fight.
func boss_damage_pct() -> int:
	if not is_boss_fight():
		return 0
	return 100 * (enemies[0].max - enemies[0].hp) / enemies[0].max


var hp_scale := 1.0  # this fight's enemy HP multiplier, so a Rubble spawns scaled too


func start_fight(index: int) -> void:
	fight = index
	start_group(FIGHTS[index])


## Starts a fight against `keys` (TYPES keys, at most three of one type); every enemy's HP is multiplied by `scale`.
func start_group(keys: Array, scale := 1.0) -> void:
	hp_scale = scale
	enemies.clear()
	replaced = 0
	var seen := {}
	for key in keys:
		var t: Dictionary = TYPES[key]
		var name: String = t.name
		if keys.count(key) > 1:  # Bone Rat A, B, C
			seen[key] = seen.get(key, 0) + 1
			name += " " + "ABC"[seen[key] - 1]
		var hp := ceili(t.hp * scale)
		enemies.append({"type": t, "name": name, "hp": hp, "max": hp, "intent": {}})
	target = 0
	turn = 0
	grit = 0
	ward_spent = false
	for r in relics:
		r.f = 0.0
	for d in dice:
		d.faces = d.base.duplicate()  # boss tampering ends with the fight
		d.buried = 0
	start_turn()


func start_turn() -> void:
	cowered = false
	rerolls = REROLLS_PER_TURN + grit + (1 if "steady_hand" in perks else 0)
	grit = 0
	for e in enemies:
		e.intent = _next_intent(e) if e.hp > 0 else {}
	_apply_bonuses()
	_apply_rings()
	for d in dice:
		d.buried = maxi(0, d.buried - 1)  # buried at 2: held this turn (1), free the next
		if d.buried > 0:
			continue
		d.locked = false
		d.slot = Slot.NONE
		_roll(d)
	if is_tutorial():  # no throw: each lesson's dice are set (TUTORIAL_DICE), lying on a side that shows them
		var set: Array = TUTORIAL_DICE[mini(turn, TUTORIAL_DICE.size() - 1)]
		for i in dice.size():
			dice[i].value = set[i]
			dice[i].side = dice[i].faces.find(set[i])


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
	return e.type.get("boss", false) and e.hp * 2 <= e.max


func set_target(i: int) -> void:
	if alive(i):
		target = i


func reroll() -> bool:
	if rerolls <= 0:
		return false
	rerolls -= 1
	for d in dice:
		if not d.locked and d.buried == 0:
			_roll(d)
	return true


func toggle_lock(i: int) -> void:
	if dice[i].buried > 0:
		return
	dice[i].locked = not dice[i].locked


func assign(i: int, slot: Slot) -> void:
	if dice[i].buried > 0:
		return
	dice[i].slot = slot


func guard_total() -> int:
	return _sum(_values_in(Slot.GUARD)) + _sum(_values_in(Slot.GUARD, "ward"))  # a Ward face counts twice


func has_guard() -> bool:
	return not _values_in(Slot.GUARD).is_empty()


## The unlocked skills the Skill slot's dice make right now: all of them fire.
func fired() -> Array:
	var v := _values_in(Slot.SKILL)
	return skills.filter(func(id): return makes(id, v))


func skill_ready() -> bool:
	return not fired().is_empty()


## Whether `values` are exactly skill `id`'s pattern.
static func makes(id: String, values: Array) -> bool:
	if CURSE in values:
		return false
	var v := values.duplicate()
	v.sort()
	match id:
		"cleave":
			return v.size() == 2 and v[0] == v[1]
		"sunder":
			return v.size() == 3 and v[0] == v[2]
		"flurry":
			return v.size() == 3 and v[1] == v[0] + 1 and v[2] == v[1] + 1
		"cower":
			return v.size() == 3 and v[2] <= 2
		"oath":
			return v.size() == 3 and v[0] % 2 == v[1] % 2 and v[1] % 2 == v[2] % 2
		"gambit":
			return v == [1, 6]
	return false


## Whether some of this roll's free dice could make an unlocked skill's pattern (the screen's hint).
func skill_in_roll() -> bool:
	return not skill_dice().is_empty()


## Indices of the dice that could, together, make an unlocked skill's pattern; the screen gives them an aura.
func skill_dice() -> Array:
	var free: Array = range(dice.size()).filter(func(i): return dice[i].buried == 0 or dice[i].slot == Slot.SKILL)
	var hit := {}
	for a in free.size():
		for b in range(a + 1, free.size()):
			var pair: Array = [free[a], free[b]]
			for c in [-1] + range(b + 1, free.size()):  # the pair alone, then with each later die
				var group: Array = pair + ([free[c]] if c >= 0 else [])
				if skills.any(func(id): return makes(id, group.map(func(i): return dice[i].value))):
					for i in group:
						hit[i] = true
	return hit.keys()


func parry_window_ms() -> int:
	return 60 + 10 * _best_guard_pip() + _nerve_ms()


## A high Guard die widens the Perfect window too, so a lone 1 in Guard can't Perfect everything.
func perfect_window_ms() -> int:
	return 40 + 10 * _best_guard_pip() + _nerve_ms()


## Iron Nerve's extra time on the Perfect block and parry windows.
func _nerve_ms() -> int:
	return 40 if "iron_nerve" in perks else 0


## Total Cleave damage, split evenly across living enemies by skill_share().
func cleave_damage() -> int:
	if "cleave" not in fired():
		return 0
	var pair := _values_in(Slot.SKILL)
	var total := 12 if pair[0] == 1 and "gamblers_heart" in perks else _sum(pair)  # snake eyes count as 12
	return ceili(total * CLEAVE_MULTIPLIER)


## What the skills that fire deal enemy i before Mult, added up.
func skill_share(i: int) -> int:
	if not alive(i):
		return 0
	var total := 0
	for id in fired():
		total += _skill_hit(id, i)
	return total


## What skill `id` deals enemy i before Mult, if it fires.
func _skill_hit(id: String, i: int) -> int:
	var total := _sum(_values_in(Slot.SKILL))
	match id:
		"sunder":
			return ceili(total * SUNDER_MULTIPLIER)
		"flurry":
			return total + (9 if _has_relic("rosary") else FLURRY_BONUS) if i == target else 0
		"oath":
			return total if i == target and total % 2 == 1 else 0  # three odd dice sum odd, three even sum even
		"gambit":
			return GAMBIT_DAMAGE if i == target else 0
		"cleave":
			return _cleave_share(i)
	return 0


## Cleave's part for enemy i: its leftover points go one each to the target first, then down the row.
func _cleave_share(i: int) -> int:
	var up: Array[int] = []
	for j in enemies.size():
		if alive(j):
			up.append(j)
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
	return dice.filter(func(d): return d.slot == Slot.NONE and d.buried == 0).size()  # a buried die gives no Grit


## Damage your placed dice would deal to enemy i right now: each hit times Mult, rounded down.
func damage_to(i: int) -> int:
	return _sum(_dealt(i))


## The hits on enemy i with Mult applied, in hits_to() order.
func _dealt(i: int) -> Array[int]:
	var m := mult()
	var out: Array[int] = []
	for h in hits_to(i):
		out.append(floori(h * m + 0.0001))  # float noise can land a whole product a hair under
	return out


## Base hits on enemy i before Mult: the Attack hit first (target only, if a die is in Attack; enemy Guard and Bone
## Wall already taken off), then one per fired skill that reaches it. Skills ignore Bone Wall and enemy Guard.
func hits_to(i: int) -> Array[int]:
	var hits: Array[int] = []
	if not alive(i):
		return hits
	var e := enemies[i]
	if i == target and not _values_in(Slot.ATTACK).is_empty():
		var damage := 0
		var attack := _values_in(Slot.ATTACK)
		var sharp := _values_in(Slot.ATTACK, "sharp")
		for v in sharp:
			attack.erase(v)
		attack.assign(attack.map(_attack_value))  # Crown and Whetstone come before Bone Wall and Guard
		sharp.assign(sharp.map(_attack_value))
		if e.type.get("bone_wall", false) and not attack.is_empty():
			attack.erase(attack.max())  # Bone Wall: the Warden blocks your highest Attack die
		damage = _sum(attack)
		if e.intent.get("kind") == "guard":
			damage = maxi(0, damage - e.intent.value)
		damage += _sum(sharp)  # Sharp faces cut past Guard and Bone Wall
		for k in relics.size():  # Ledger and Ward Icon land after Guard
			damage += _flat_bonus(k)
		hits.append(damage)
	for id in fired():
		var h := _skill_hit(id, i)
		if h > 0:
			hits.append(h)
	return hits


## What belt slot k adds to the Attack hit after Guard: Miner's Ledger or Ward Icon.
func _flat_bonus(k: int) -> int:
	match relic_id(k):
		"miners_ledger":
			return floori(relics[k].n / 4)
		"ward_icon":
			return int(relics[k].f)
	return 0


## The End turn count in order, for the screen to play back. Each step is {kind, die, slot, amount, hit, mult} with the
## running Hit and Mult after it (unused die/slot are -1). Kinds: "die" (an Attack die's face), "relic_die" (Crown or
## Whetstone on that die), "guard" (Bone Wall and enemy Guard: whatever takes the dice down to the real Attack hit),
## "flat" (Ledger, Ward Icon), "skill" (one fired skill over every enemy), "mult" (a belt slot changing Mult). The last
## step's hit is the sum of hits_to() over all enemies and its mult is mult(); no steps when nothing would be dealt.
func count_steps() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var hit := 0
	if alive(target) and not _values_in(Slot.ATTACK).is_empty():
		var flats: Array[int] = []
		for k in relics.size():
			flats.append(_flat_bonus(k))
		for i in dice.size():
			if dice[i].slot != Slot.ATTACK:
				continue
			var v: int = dice[i].value
			hit += v
			steps.append(_step("die", i, -1, v, hit, 1.0))
			for id in ["cursed_crown", "whetstone"]:  # Crown makes a curse a 6, then Whetstone reads the result
				for k in relics.size():
					if relic_id(k) != id:
						continue
					var gain := 0
					if id == "cursed_crown" and v == CURSE:
						gain = 6
						v = 6
					elif id == "whetstone" and v >= 5:
						gain = 3
					if gain > 0:
						hit += gain
						steps.append(_step("relic_die", i, k, gain, hit, 1.0))
		var cut := hits_to(target)[0] - _sum(flats) - hit  # Bone Wall's die, Guard, and Sharp faces that skip them
		if cut != 0:
			hit += cut
			steps.append(_step("guard", -1, -1, cut, hit, 1.0))
		for k in relics.size():
			if flats[k] != 0:
				hit += flats[k]
				steps.append(_step("flat", -1, k, flats[k], hit, 1.0))
	for id in fired():
		var amount := 0
		for i in enemies.size():
			amount += _skill_hit(id, i) if alive(i) else 0
		if amount > 0:
			hit += amount
			steps.append(_step("skill", -1, -1, amount, hit, 1.0))
	if hit == 0:
		return []
	var m := 1.0
	for k in relics.size():
		var add := _relic_add(k)
		var times := _relic_times(relic_id(k))
		if add != 0.0 or times != 1.0:
			var before := m
			m = (m + add) * times
			steps.append(_step("mult", -1, k, m - before, hit, m))
	return steps


func _step(kind: String, die: int, slot: int, amount: float, hit: int, m: float) -> Dictionary:
	return {"kind": kind, "die": die, "slot": slot, "amount": amount, "hit": hit, "mult": m}


## An Attack die's worth: Cursed Crown makes a curse a 6, then each Whetstone adds 3 to a 5 or more.
func _attack_value(v: int) -> int:
	for k in relics.size():
		if relic_id(k) == "cursed_crown" and v == CURSE:
			v = 6
	var out := v
	for k in relics.size():
		if relic_id(k) == "whetstone" and v >= 5:
			out += 3
	return out


func _has_relic(id: String) -> bool:
	return range(relics.size()).any(func(k): return relic_id(k) == id)


## Grit this turn's unplaced dice would give.
func grit_gain() -> int:
	return unplaced_count() * (2 if "grit_teeth" in perks else 1)


## The id belt slot k acts as: a Mirror Shard copies its right neighbour, or nothing at the end or next to a Mirror.
func relic_id(k: int) -> String:
	var id: String = relics[k].id
	if id != "mirror_shard":
		return id
	if k + 1 >= relics.size() or relics[k + 1].id == "mirror_shard":
		return ""
	return relics[k + 1].id


## What relic `id` costs in Shards at the shop.
static func price(id: String) -> int:
	return RARE_PRICE if RELICS[id].rare else COMMON_PRICE


## What destroying relic `id` pays back.
static func sell_value(id: String) -> int:
	return price(id) / 2


## Puts relic `id` on the end of the belt for free. Refuses one already on it, or a full belt.
func take_relic(id: String) -> bool:
	if relics.size() >= BELT_SIZE or relics.any(func(r): return r.id == id):
		return false
	var before := _acting_ids()
	relics.append({"id": id, "n": 0.0, "f": 0.0})
	_reset_changed_mirrors(before)
	return true


## Buys relic `id` onto the belt; refuses if it is owned, the belt is full, or the Shards fall short.
func buy_relic(id: String) -> bool:
	if shards < price(id) or not take_relic(id):
		return false
	shards -= price(id)
	return true


## Destroys belt slot k for Shards; the belt closes the gap.
func destroy_relic(k: int) -> void:
	var before := _acting_ids()
	shards += sell_value(relics[k].id)
	relics.remove_at(k)
	_reset_changed_mirrors(before)


func move_relic(from: int, to: int) -> void:
	var before := _acting_ids()
	relics.insert(to, relics.pop_at(from))
	_reset_changed_mirrors(before)


## Each Mirror Shard's belt entry with the id it acts as, to see what a belt change did to it.
func _acting_ids() -> Array:
	return range(relics.size()).filter(func(k): return relics[k].id == "mirror_shard").map(func(k): return [relics[k], relic_id(k)])


## A Mirror Shard's counters belong to what it copies: when that changes, they start over.
func _reset_changed_mirrors(before: Array) -> void:
	for pair in before:
		var k := range(relics.size()).filter(func(i): return is_same(relics[i], pair[0]))  # by identity: two Mirrors can look alike
		if not k.is_empty() and relic_id(k[0]) != pair[1]:
			relics[k[0]].n = 0.0
			relics[k[0]].f = 0.0


## This turn's Mult, folded left to right along the belt: each slot adds to it, then multiplies it.
func mult() -> float:
	var m := 1.0
	for k in relics.size():
		m = (m + _relic_add(k)) * _relic_times(relic_id(k))
	return m


## What belt slot k adds to Mult right now (growing relics read the slot's own counters).
func _relic_add(k: int) -> float:
	var r: Dictionary = relics[k]
	match relic_id(k):
		"gravedigger":
			return 0.1 * r.n
		"spare_fuse":
			return r.f
		"hungry_bell":
			return r.f + 1.0 if not fired().is_empty() else 0.0
		"twin_saints":
			return 1.0 if "cleave" in fired() or "sunder" in fired() else 0.0
		"rusted_censer":
			return 0.5 * dice.filter(func(d): return d.slot != Slot.NONE and d.buried == 0 and mark_of(d) == "ember").size()
		"clenched_jaw":
			return 0.1 * grit_gain()
		"gilded_pip":
			return 0.5 * dice.filter(func(d): return d.slot != Slot.NONE and d.value > 6).size()
	return 0.0


## What relic `id` multiplies Mult by right now.
func _relic_times(id: String) -> float:
	match id:
		"black_candle":
			return 1.5
		"pit_lantern":
			var placed := dice.filter(func(d): return d.slot != Slot.NONE)
			return 2.0 if not placed.is_empty() and placed.all(func(d): return d.slot == Slot.ATTACK) else 1.0
	return 1.0


## Belt slots that change this turn's damage or Mult right now (the screen flashes them): a Mult add or multiplier,
## Whetstone with a 5 or more in Attack, Cursed Crown with a curse in Attack, Ledger or Ward Icon with a bonus and a
## die in Attack, Rosary when Flurry fires.
func firing() -> Array[int]:
	var attack := _values_in(Slot.ATTACK)
	var out: Array[int] = []
	for k in relics.size():
		var id := relic_id(k)
		var lit := _relic_add(k) != 0.0 or _relic_times(id) != 1.0
		match id:
			"whetstone":
				lit = attack.any(func(v): return v >= 5 or (v == CURSE and _has_relic("cursed_crown")))
			"cursed_crown":
				lit = CURSE in attack
			"miners_ledger":
				lit = not attack.is_empty() and floori(relics[k].n / 4) > 0
			"ward_icon":
				lit = not attack.is_empty() and relics[k].f > 0
			"rosary":
				lit = "flurry" in fired()
		if lit:
			out.append(k)
	return out


func preview_damage() -> int:
	var total := 0
	for i in enemies.size():
		total += damage_to(i)
	return total


## Resolves your placed dice. Returns total damage dealt.
func resolve_player() -> int:
	var hits: Array[int] = []
	var m := mult()
	for i in enemies.size():
		var dealt := _dealt(i)
		for h in dealt:
			best_hit = maxi(best_hit, h)
		hits.append(_sum(dealt))
	if _sum(hits) > 0:
		best_mult = maxf(best_mult, m)
	var gain := grit_gain()
	var struck := target  # a Gambit that kills it pays a Shard
	var fire := fired()
	var gambit := "gambit" in fire and alive(struck)
	cowered = "cower" in fire
	if "oath" in fire:
		var total := _sum(_values_in(Slot.SKILL))
		if total % 2 == 0:
			heal(ceili(total / 2.0))
	var floor_hp := 1 if is_tutorial() else 0
	for i in enemies.size():
		if alive(i):
			enemies[i].hp = maxi(floor_hp, enemies[i].hp - hits[i])
			if enemies[i].hp == 0 and enemies[i].type.has("leaves"):
				var t: Dictionary = TYPES[enemies[i].type.leaves]
				var old: String = enemies[i].name
				var tag: String = old.substr(enemies[i].type.name.length())  # a Hulk's " A" stays on its Rubble
				var rhp := ceili(t.hp * hp_scale)
				enemies[i] = {"type": t, "name": t.name + tag, "hp": rhp, "max": rhp, "intent": {}, "from": old}  # acts from next turn; "from" lets the screen show the swap
				replaced += 1
	if gambit and (enemies[struck].hp == 0 or enemies[struck].has("from")):
		shards += 1
	for d in dice:
		if d.slot != Slot.NONE and d.buried == 0:
			match mark_of(d):
				"ember":
					heal(EMBER_HEAL)
				"shard":
					shards += 1
		if d.slot == Slot.GUARD and d.value == CURSE:
			d.faces = d.base.duplicate()  # a cursed face placed in Guard burns off
	grit += gain
	guard_pool = guard_total()
	for k in relics.size():  # growing relics count this turn once its damage is dealt
		match relic_id(k):
			"spare_fuse":
				relics[k].f += 0.25 * rerolls
			"hungry_bell":
				relics[k].f = relics[k].f + 1.0 if not fire.is_empty() else 0.0
			"ward_icon":
				relics[k].f = 0.0
	if not alive(target):
		for i in enemies.size():
			if alive(i):
				target = i
				break
	return _sum(hits)


## Timing only happens with a die in Guard, against something you can block or parry.
func needs_timing(i: int) -> bool:
	return not cowered and has_guard() and enemies[i].intent.get("kind") in ["attack", "unblockable", "curse"]


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
	if cowered and e.intent.kind in ["attack", "unblockable", "curse", "cave_in"]:
		return "You cower; %s misses." % e.name
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
			if e.intent.get("cave_in", false):
				text += " " + _cave_in()
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
		"cave_in":
			text = _cave_in()
	player_hp = maxi(0, player_hp)
	return text


func end_enemy_phase() -> void:
	for k in relics.size():
		if relic_id(k) == "ward_icon":
			relics[k].f = float(guard_pool)
	turn += 1
	if not is_tutorial() and not is_boss_fight():
		dungeon_turns += 1


func intent_text(i: int) -> String:
	var it: Dictionary = enemies[i].intent
	match it.get("kind"):
		"attack":
			return "Attack %d%s" % [it.value, " + cave-in" if it.get("cave_in", false) else ""]
		"guard":
			return "Guard %d" % it.value
		"curse":
			return "Curse sticker on die %d" % (it.target + 1)
		"unblockable":
			return "UNBLOCKABLE %d" % it.value
		"ring":
			return "Ring"
		"cave_in":
			return "Cave-in"
	return ""


## Buries one random unburied die until the turn after next. Never the last unburied one. Returns its index, or -1.
func bury_one() -> int:
	var free: Array = []
	for i in dice.size():
		if dice[i].buried == 0:
			free.append(i)
	if free.size() < 2:
		return -1
	var i: int = free[rng.randi_range(0, free.size() - 1)]
	dice[i].buried = 2
	return i


func _cave_in() -> String:
	var i := bury_one()
	return "Rubble buries die %d." % (i + 1) if i >= 0 else "Rubble falls, but your last free die holds."


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
	d.side = rng.randi_range(0, d.faces.size() - 1)
	d.value = d.faces[d.side]


## The mark on die d's rolled face, or "" (none, a cursed face, or a value set without rolling that side).
static func mark_of(d: Dictionary) -> String:
	return d.marks[d.side] if d.faces[d.side] == d.value and d.value != CURSE else ""


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


## Values of the dice in `slot`; with `mark`, only those whose rolled face carries it.
func _values_in(slot: Slot, mark := "") -> Array[int]:
	var out: Array[int] = []
	for d in dice:
		if d.slot == slot and (mark == "" or mark_of(d) == mark):
			out.append(d.value)
	return out


func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += v
	return total
