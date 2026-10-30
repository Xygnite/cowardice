extends SceneTree
## Plays whole runs on Combat's rules with a greedy bot and prints damage per turn by stage, per profile
## ("new": Cleave only; "veteran": every skill). Enemy HP follows Floor.world_factor for each world's place.
## Ignores the player's HP (healed after each fight and enemy phase), perks, event details (a "?" is a free
## forge half the time) and map links (one random room per column).
## Run: godot --headless --path . -s tools/balance_sim.gd -- --runs=500   (runs per profile, default 500)

const DEFAULT_RUNS := 500
const WORLDS := ["chapel", "mine", "mine", "mine", "mine"]  # worlds 3-5 stand in with the Mine's enemies
const PROFILES := {"new": ["cleave"], "veteran": ["cleave", "sunder", "flurry", "cower", "oath", "gambit"]}
const ASSIGN := [Combat.Slot.NONE, Combat.Slot.ATTACK, Combat.Slot.SKILL]
## Rough strength order for buying; later = better. Multipliers sort to the belt's right end.
const PRIORITY := ["tithe_box", "ward_icon", "miners_ledger", "rosary", "clenched_jaw", "rusted_censer", "spare_fuse",
	"whetstone", "cursed_crown", "gravedigger", "twin_saints", "gilded_pip", "hungry_bell", "pit_lantern", "mirror_shard", "black_candle"]
const RIGHT := ["mirror_shard", "black_candle", "pit_lantern"]

var out := {}  # "profile|stage" -> {turn: [damage...], kill_turns: [...], hp: [...], mult: [...]}


func _init() -> void:
	var runs := DEFAULT_RUNS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
	for p in PROFILES:
		for r in runs:
			_run(p)
	_report()
	quit()


func _run(profile: String) -> void:
	var c := Combat.new()
	c.skills = PROFILES[profile].duplicate()
	var shopped := false
	for w in WORLDS.size():
		var floor_id: String = WORLDS[w]
		var map := Floor.deal(floor_id)
		for col in map.size():
			var room: Dictionary = map[col][randi_range(0, map[col].size() - 1)] if col > 0 else map[0][0]
			var stage := "w%d %d" % [w + 1, col]
			match room.kind:
				"fight":
					_fight(c, profile, stage if col < 9 else "w%d boss" % (w + 1), room.enemies, room.get("scale", 1.0) * Floor.world_factor(w + 1))
					if col < 9:
						_shop(c, "any" if shopped else "common")
						shopped = true
					elif w < WORLDS.size() - 1:
						_shop(c, "rare")
						_free_forge(c)  # the campfire after the Warden
				"unknown":
					if randf() < Events.AMBUSH_CHANCE:
						_fight(c, profile, stage, Floor.group(Floor.FLOORS[floor_id].hp[1], {}, Floor.FLOORS[floor_id].enemies), Floor.world_factor(w + 1))
						c.shards += Events.AMBUSH_SHARDS
						_shop(c, "any" if shopped else "common")
					elif randf() < 0.5:
						_free_forge(c)
				"forge":
					while c.shards >= Combat.FORGE_COST:
						c.pay_forge()
						_apply_forge(c)
				"campfire":
					if randf() < 0.5:
						_free_forge(c)


func _fight(c: Combat, profile: String, stage: String, keys: Array, scale: float) -> void:
	c.start_group(keys, scale)
	var key := profile + "|" + _bucket(stage)
	if not out.has(key):
		out[key] = {"dmg": [], "kill": [], "hp": [], "mult": []}
	var total_hp := 0
	for e in c.enemies:
		total_hp += e.max
	out[key].hp.append(total_hp)
	var turns := 0
	while not c.fight_won() and turns < 60:
		_play_turn(c)
		var m := c.mult()
		var dealt := c.resolve_player()
		out[key].dmg.append(dealt)
		out[key].mult.append(m)
		turns += 1
		if c.fight_won():
			break
		for i in c.enemies.size():
			if c.alive(i) and not c.enemies[i].intent.is_empty():
				c.resolve_enemy(i, Combat.Grade.MISS)
		c.player_hp = c.max_hp
		c.end_enemy_phase()
		c.start_turn()
	out[key].kill.append(turns)
	c.claim_fight(true)
	c.player_hp = c.max_hp


## Rerolls toward a skill or high Attack, then places the dice for the most damage.
func _play_turn(c: Combat) -> void:
	while c.rerolls > 0:
		var best := _best(c)
		if best.dmg > 0 and not c.fired().is_empty() and c.fired().any(func(id): return id in ["sunder", "flurry", "oath"]):
			break
		var vals: Array = c.dice.map(func(d): return d.value)
		var keep := []
		for i in 3:  # keep a pair, else the highest die
			for j in 3:
				if i != j and vals[i] == vals[j] and vals[i] != Combat.CURSE:
					keep.append(i)
		if keep.is_empty():
			var hi := 0
			for i in 3:
				if vals[i] > vals[hi]:
					hi = i
			keep = [hi]
		if keep.size() == 3:
			break
		for i in 3:
			c.dice[i].locked = i in keep
		c.reroll()
	for d in c.dice:
		d.locked = false
	var b := _best(c)
	for i in 3:
		c.assign(i, b.slots[i])


func _best(c: Combat) -> Dictionary:
	var best := {"dmg": -1, "slots": [0, 0, 0]}
	for a in ASSIGN:
		for b in ASSIGN:
			for d in ASSIGN:
				var slots := [a, b, d]
				for i in 3:
					c.dice[i].slot = slots[i]
				var dmg := c.preview_damage()
				if dmg > best.dmg:
					best = {"dmg": dmg, "slots": slots}
	for i in 3:
		c.dice[i].slot = Combat.Slot.NONE
	return best


func _shop(c: Combat, rarity: String) -> void:
	var offer := RelicPickScreen.offer(c.relics, rarity, c.rng)
	offer.sort_custom(func(x, y): return PRIORITY.find(x) > PRIORITY.find(y))
	for id: String in offer:
		if c.relics.size() >= Combat.BELT_SIZE:
			var worst := 0
			for k in c.relics.size():
				if PRIORITY.find(c.relic_id(k)) < PRIORITY.find(c.relic_id(worst)):
					worst = k
			if PRIORITY.find(c.relic_id(worst)) >= PRIORITY.find(id) or c.shards + Combat.sell_value(c.relics[worst].id) < Combat.price(id):
				continue
			c.destroy_relic(worst)
		if c.shards >= Combat.price(id):
			c.buy_relic(id)
	_order(c)


## Adds left, then Mirror Shard before the Candle, then the multipliers.
func _order(c: Combat) -> void:
	var ids: Array = c.relics.map(func(r): return r.id)
	var want := ids.filter(func(id): return id not in RIGHT)
	for id in ["mirror_shard", "black_candle", "pit_lantern"]:
		if id in ids:
			want.append(id)
	for t in want.size():
		var from := -1
		for k in c.relics.size():
			if c.relics[k].id == want[t]:
				from = k
		if from != t:
			c.move_relic(from, t)


func _free_forge(c: Combat) -> void:
	_apply_forge(c)


## A forge throw: +1 or +4 goes on the lowest face of the weakest die; a mark on a random face.
func _apply_forge(c: Combat) -> void:
	var u: Dictionary = Combat.FORGE_ROLL[randi_range(0, 5)]
	var di := 0
	for i in 3:
		if c.dice[i].base.reduce(func(a, b): return a + b, 0) < c.dice[di].base.reduce(func(a, b): return a + b, 0):
			di = i
	var lo := 0
	for f in 6:
		if c.dice[di].base[f] < c.dice[di].base[lo]:
			lo = f
	if u.has("step"):
		c.forge(di, lo, true, "", u.step)
	else:
		c.forge(randi_range(0, 2), randi_range(0, 5), true, u.mark)


func _bucket(stage: String) -> String:
	if stage.ends_with("boss"):
		return stage
	var parts := stage.split(" ")
	var col := int(parts[1])
	return parts[0] + (" 0" if col == 0 else (" 1-4" if col <= 4 else " 5-8"))


func _pct(a: Array, p: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(p * (s.size() - 1)), 0, s.size() - 1)] if not s.is_empty() else 0.0


func _report() -> void:
	var keys := out.keys()
	keys.sort()
	print("stage | fights | enemy HP med | dmg/turn med p75 p90 p99 max | mult med p90 max | turns-to-kill med p25 min")
	for k in keys:
		var o: Dictionary = out[k]
		print("%s | %d | %d | %d %d %d %d %d | %.2f %.2f %.2f | %d %d %d" % [k, o.kill.size(), _pct(o.hp, 0.5),
			_pct(o.dmg, 0.5), _pct(o.dmg, 0.75), _pct(o.dmg, 0.9), _pct(o.dmg, 0.99), _pct(o.dmg, 1.0),
			_pct(o.mult, 0.5), _pct(o.mult, 0.9), _pct(o.mult, 1.0),
			_pct(o.kill, 0.5), _pct(o.kill, 0.25), _pct(o.kill, 0.0)])
		if k.ends_with("boss"):
			var hist := {}
			for t in o.kill:
				hist[mini(t, 8)] = hist.get(mini(t, 8), 0) + 1
			var line := "   kill turns:"
			for t in range(1, 9):
				line += "  %d%s: %d%%" % [t, "+" if t == 8 else "", roundi(100.0 * hist.get(t, 0) / o.kill.size())]
			print(line)
