extends SceneTree
## Headless rules check: godot --headless --path . -s tests/test_combat.gd

const CombatScript := preload("res://scripts/combat.gd")
const RATS := 1
const SKELETON_BELL := 2
const ACOLYTE_RATS := 3
const WARDEN := 6

var failures := 0


func _init() -> void:
	_timing_grades()
	_parry_window_follows_guard_die()
	_block_math()
	_guard_pool_spreads_over_hits()
	_unblockable_ignores_guard()
	_curse_and_burn_off()
	_bone_wall_and_cleave()
	_cleave_hits_every_enemy()
	_attack_hits_only_the_target()
	_enemy_guard_and_grit()
	_grave_bell_rings()
	_phase2()
	_tutorial()
	_perks()
	_forge_and_campfire()
	_fight_rewards()
	_meta()
	_floors()
	_lasting_curse()
	_event_helpers()
	_events()
	print("FAILED: %d" % failures if failures else "All combat checks passed.")
	quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)


## A fight with all dice unplaced. Enemy 0 of SKELETON_BELL is the Skeleton.
func fresh(fight := SKELETON_BELL) -> CombatScript:
	var c := CombatScript.new(7)
	c.start_fight(fight)
	for d in c.dice:
		d.slot = CombatScript.Slot.NONE
	return c


func place(c: CombatScript, i: int, value: int, slot: int) -> void:
	c.dice[i].value = value
	c.dice[i].slot = slot


func _lasting_curse() -> void:
	var c := CombatScript.new(7)
	c.curse_face(0, 5)  # the 6
	check(c.dice[0].base[5] == CombatScript.CURSE and c.dice[0].faces[5] == CombatScript.CURSE, "a lasting curse is on the die")
	c.start_fight(SKELETON_BELL)
	check(c.dice[0].faces[5] == CombatScript.CURSE, "it survives into the next fight")
	c.dice[0].value = CombatScript.CURSE
	c.assign(0, CombatScript.Slot.GUARD)
	c.resolve_player()
	check(c.dice[0].faces[5] == CombatScript.CURSE, "Guard doesn't burn a lasting curse off")
	c.forge(0, 5, true)
	check(c.dice[0].base[5] == 6, "forging clears it back to the old face")
	c.forge(0, 5, true)
	check(c.dice[0].base[5] == 6 + CombatScript.FORGE_STEP, "after that, forging adds as usual")
	var k := CombatScript.new(7)
	var g: int = k.carve(1, 0)
	check(k.dice[1].base[0] == 9 and g != 0 and k.dice[1].base[g] == CombatScript.CURSE, "carve: a 9, and another face cursed")
	var all := CombatScript.new(7)
	for f in range(1, 6):
		all.curse_face(2, f)
	check(all.carve(2, 0) == -1 and all.dice[2].base[0] == 9, "carving with every other face cursed curses nothing more")


func _event_helpers() -> void:
	var c := CombatScript.new(7)
	c.player_hp = 3
	check(c.hurt(6) == 2 and c.player_hp == 1, "hurt stops at 1 HP")
	c.player_hp = 3
	c.lose_max_hp(5)
	check(c.max_hp == CombatScript.PLAYER_MAX_HP - 5 and c.player_hp == 3, "max HP drops; HP below it stays")
	c.player_hp = c.max_hp
	c.lose_max_hp(5)
	check(c.player_hp == c.max_hp, "HP is capped by the new max")
	var v: Array = c.roll_dice([0, 2])
	check(v.size() == 2 and v[0] == c.dice[0].value and v[1] == c.dice[2].value, "roll_dice returns the rolled values")


func _events() -> void:
	var c := CombatScript.new(7)
	c.player_hp = 3
	var r: Dictionary = Events.resolve("shrine", 0, c, [])
	check(c.player_hp == 1 and r.forge == 1, "shrine at 3 HP: 1 HP left, one forge")
	c = CombatScript.new(7)
	Events.resolve("pilgrim", 0, c, [])
	check(c.shards == 6, "pilgrim gives 6 Shards")
	c.player_hp = 10
	Events.resolve("pilgrim", 1, c, [])
	check(c.player_hp == 15, "pilgrim heals 5")
	r = Events.resolve("altar", 0, c, [])
	check(c.max_hp == CombatScript.PLAYER_MAX_HP - 5 and r.forge == 2, "altar: -5 max HP, two forges")
	c = CombatScript.new(7)
	Events.resolve("niche", 0, c, [])
	check(c.bonus_embers == 10, "niche: 10 embers")
	Events.resolve("bone_pile", 0, c, [2])
	check(c.player_hp == c.max_hp - 4 and c.shards == 0, "bone pile 2 hurts 4")
	Events.resolve("bone_pile", 0, c, [0])
	check(c.player_hp == c.max_hp - 8, "bone pile on a cursed face hurts")
	Events.resolve("bone_pile", 0, c, [5])
	check(c.shards == 5, "bone pile 5 gives 5 Shards")
	c = CombatScript.new(7)
	Events.resolve("corridor", 0, c, [1, 2, 3])
	check(c.player_hp == c.max_hp - 4, "corridor total 6 loses 4")
	Events.resolve("corridor", 0, c, [4, 4, 4])
	check(c.player_hp == c.max_hp - 4, "corridor total 12 loses nothing")
	Events.resolve("corridor", 1, c, [])
	check(c.player_hp == c.max_hp - 8, "corridor, going back, loses 4")
	c.player_hp = 2
	Events.resolve("corridor", 0, c, [1, 1, 1])
	check(c.player_hp == 1, "corridor at 2 HP leaves 1")
	c = CombatScript.new(7)
	r = Events.resolve("chest", 0, c, [1])
	check(c.player_hp == c.max_hp - 5 and not r.get("retry", false), "chest 1 hurts 5 and ends")
	r = Events.resolve("chest", 0, c, [0])
	check(c.player_hp == c.max_hp - 10 and not r.get("retry", false), "chest on a cursed face hurts 5")
	r = Events.resolve("chest", 0, c, [3])
	check(r.get("retry", false), "chest 3 on the first try retries")
	r = Events.resolve("chest", 0, c, [3], 2)
	check(not r.get("retry", false) and r.get("forge", 0) == 0, "chest 3 on the second try ends")
	r = Events.resolve("chest", 0, c, [6])
	check(r.forge == 1, "chest 6 forges")
	c = CombatScript.new(7)
	c.shards = 3
	check(not Events.can_choose("gambler", 0, c) and Events.can_choose("gambler", 1, c), "the bet needs 4 Shards")
	c.shards = 4
	check(Events.can_choose("gambler", 0, c), "4 Shards is enough")
	Events.resolve("gambler", 0, c, [6, 6, 6, 1, 1, 1])
	check(c.shards == 8, "gambler win: 4 - 4 + 8")
	c.shards = 4
	Events.resolve("gambler", 0, c, [1, 1, 1, 6, 6, 6])
	check(c.shards == 0, "gambler loss")
	c.shards = 4
	Events.resolve("gambler", 0, c, [2, 2, 2, 3, 2, 1])
	check(c.shards == 4, "gambler tie: 4 - 4 + 4")
	c = CombatScript.new(7)
	r = Events.resolve("cursed_cast", 0, c, [])
	check(r.carve, "cursed cast asks for a carve")
	check(Events.pick(Events.IDS) == "" and Events.IDS.has(Events.pick([])), "pick skips seen rooms")
	var odds: Array = Events.odds(["shrine"])
	check(odds[0] == ["Ambush", 20.0] and odds.size() == Events.IDS.size(), "odds: ambush first, then each unseen event")
	check(is_equal_approx(odds.reduce(func(t, o): return t + o[1], 0.0), 100.0), "odds add up to 100%")
	check(Events.odds(Events.IDS) == [["Ambush", 100.0]], "with every event seen, a ? is an ambush")
	for id in Events.IDS:
		if id == "corridor" or id == "niche":
			continue
		c = CombatScript.new(7)
		c.shards = 5
		var last: int = Events.EVENTS[id].choices.size() - 1
		var before := [c.player_hp, c.max_hp, c.shards, c.bonus_embers]
		r = Events.resolve(id, last, c, [3, 3, 3, 3, 3, 3])
		check(before == [c.player_hp, c.max_hp, c.shards, c.bonus_embers] and r.get("forge", 0) == 0 and not r.get("carve", false), "%s: the way out costs nothing" % id)


func _timing_grades() -> void:
	var c := fresh()
	c.enemies[0].intent = {"kind": "attack", "value": 10}
	place(c, 0, 6, CombatScript.Slot.GUARD)
	check(c.perfect_window_ms() == 100, "a 6 in Guard gives a 100 ms Perfect window")
	check(c.grade_for(90, 0) == CombatScript.Grade.PERFECT, "90 ms is Perfect with a 6")
	check(c.grade_for(200, 0) == CombatScript.Grade.GOOD, "200 ms is a Good block")
	check(c.grade_for(400, 0) == CombatScript.Grade.MISS, "400 ms early is a miss")
	check(c.grade_for(-1, 0) == CombatScript.Grade.MISS, "after impact is a miss")
	c.dice[0].value = 1
	check(c.grade_for(90, 0) == CombatScript.Grade.GOOD, "90 ms is only Good with a 1")


func _parry_window_follows_guard_die() -> void:
	var c := fresh()
	c.enemies[0].intent = {"kind": "unblockable", "value": 14}
	place(c, 0, 6, CombatScript.Slot.GUARD)
	check(c.parry_window_ms() == 120, "a 6 in Guard gives a 120 ms parry")
	check(c.grade_for(110, 0) == CombatScript.Grade.PERFECT, "110 ms parries with a 6")
	c.dice[0].value = 1
	check(c.parry_window_ms() == 70, "a 1 in Guard gives a 70 ms parry")
	check(c.grade_for(110, 0) == CombatScript.Grade.MISS, "110 ms misses with a 1")


func _block_math() -> void:
	for case in [[CombatScript.Grade.MISS, 6], [CombatScript.Grade.GOOD, 4], [CombatScript.Grade.PERFECT, 0]]:
		var c := fresh()
		place(c, 0, 4, CombatScript.Slot.GUARD)
		c.resolve_player()
		c.enemies[0].intent = {"kind": "attack", "value": 10}
		c.resolve_enemy(0, case[0])
		check(c.player_hp == CombatScript.PLAYER_MAX_HP - case[1], "Guard 4 vs Attack 10, grade %d takes %d" % case)


func _guard_pool_spreads_over_hits() -> void:
	var c := fresh(RATS)
	place(c, 0, 3, CombatScript.Slot.GUARD)
	c.resolve_player()
	for i in 3:
		c.enemies[i].intent = {"kind": "attack", "value": 2}
		c.resolve_enemy(i, CombatScript.Grade.MISS)
	check(c.player_hp == CombatScript.PLAYER_MAX_HP - 3, "Guard 3 soaks 3 of three rats' 6 damage")


func _unblockable_ignores_guard() -> void:
	var c := fresh()
	place(c, 0, 6, CombatScript.Slot.GUARD)
	c.resolve_player()
	c.enemies[0].intent = {"kind": "unblockable", "value": 14}
	c.resolve_enemy(0, CombatScript.Grade.GOOD)
	check(c.player_hp == CombatScript.PLAYER_MAX_HP - 14, "unblockable ignores Guard")
	c.player_hp = CombatScript.PLAYER_MAX_HP
	c.resolve_enemy(0, CombatScript.Grade.PERFECT)
	check(c.player_hp == CombatScript.PLAYER_MAX_HP, "parry cancels the unblockable")


func _curse_and_burn_off() -> void:
	var c := fresh(WARDEN)
	c.enemies[0].intent = {"kind": "curse", "target": 1}
	c.resolve_enemy(0, CombatScript.Grade.PERFECT)
	check(not c.dice[1].faces.has(CombatScript.CURSE), "parried curse never lands")
	c.resolve_enemy(0, CombatScript.Grade.MISS)
	check(c.dice[1].faces == [1, 2, 3, 4, 5, CombatScript.CURSE], "curse replaces the highest face")
	c.enemies[0].intent = {"kind": "attack", "value": 1}
	place(c, 1, CombatScript.CURSE, CombatScript.Slot.GUARD)
	c.resolve_player()
	check(c.dice[1].faces == [1, 2, 3, 4, 5, 6], "a cursed roll placed in Guard burns the curse off")


func _bone_wall_and_cleave() -> void:
	var c := fresh(WARDEN)
	c.enemies[0].intent = {"kind": "attack", "value": 8}
	place(c, 0, 6, CombatScript.Slot.ATTACK)
	place(c, 1, 5, CombatScript.Slot.ATTACK)
	place(c, 2, 1, CombatScript.Slot.ATTACK)
	check(c.preview_damage() == 6, "Bone Wall drops the 6, leaving 5 + 1")
	place(c, 0, 4, CombatScript.Slot.CLEAVE)
	place(c, 1, 4, CombatScript.Slot.CLEAVE)
	check(c.preview_damage() == 12, "a Cleave pair of 4s deals 12 past Bone Wall; the lone Attack 1 is walled")
	c.enemies[0].intent = {"kind": "guard", "value": 6}
	check(c.preview_damage() == 12, "Cleave ignores enemy Guard")
	check(c.rolled_pair() == 4, "the pair of 4s is spotted")


func _cleave_hits_every_enemy() -> void:
	var c := fresh(RATS)
	place(c, 0, 4, CombatScript.Slot.CLEAVE)
	place(c, 1, 4, CombatScript.Slot.CLEAVE)
	check(c.preview_damage() == 12, "Cleave 12 is split, not copied, across three rats")
	c.resolve_player()
	check(c.enemies.all(func(e): return e.hp == 2), "each rat takes 4 and survives")
	c.enemies[0].hp = 0
	c.target = 2
	place(c, 0, 4, CombatScript.Slot.CLEAVE)
	place(c, 1, 3, CombatScript.Slot.CLEAVE)
	check(not c.cleave_ready(), "4 and 3 are not a pair")
	place(c, 1, 5, CombatScript.Slot.CLEAVE)
	place(c, 0, 5, CombatScript.Slot.CLEAVE)
	check(c.cleave_share(2) == 8 and c.cleave_share(1) == 7, "Cleave 15 over two rats: the odd point goes to the target")


func _attack_hits_only_the_target() -> void:
	var c := fresh()
	c.enemies[1].intent = {"kind": "attack", "value": 3}
	c.set_target(1)
	place(c, 0, 6, CombatScript.Slot.ATTACK)
	c.resolve_player()
	check(c.enemies[1].hp == 8 and c.enemies[0].hp == 20, "Attack 6 hits only the Grave Bell")
	c.enemies[1].hp = 0
	c.set_target(1)
	check(c.target == 1, "set_target keeps the bell only while it is alive")
	c.target = 0
	c.set_target(1)
	check(c.target == 0, "a dead enemy can't be targeted")
	c.target = 1
	c.resolve_player()
	check(c.target == 0, "the target moves on when it dies")


func _enemy_guard_and_grit() -> void:
	var c := fresh(ACOLYTE_RATS)
	c.enemies[0].intent = {"kind": "guard", "value": 8}
	place(c, 0, 6, CombatScript.Slot.ATTACK)
	check(c.resolve_player() == 0, "the Acolyte's Guard 8 soaks Attack 6")
	check(c.grit == 2, "two unplaced dice give 2 Grit")
	c.start_turn()
	check(c.rerolls == CombatScript.REROLLS_PER_TURN + 2, "Grit adds rerolls next turn")


func _grave_bell_rings() -> void:
	var c := fresh()  # turn 0: the Skeleton attacks, the Bell rings
	check(c.enemies[1].intent.kind == "ring", "the Bell opens by ringing")
	check(c.enemies[0].intent.kind == "unblockable", "the ring makes the Skeleton's attack unblockable")
	check(c.intent_text(0) == "UNBLOCKABLE 5", "and its intent says so")


func _phase2() -> void:
	var c := fresh(WARDEN)
	c.enemies[0].hp = 37
	check(c.is_phase2(c.enemies[0]), "Warden at half HP is in phase 2")
	c = fresh()
	c.enemies[0].hp = 1
	check(not c.is_phase2(c.enemies[0]), "Skeleton has no phase 2")


func _tutorial() -> void:
	var c := CombatScript.new(3)
	check(c.is_tutorial(), "a new game starts in the tutorial")
	place(c, 0, 6, CombatScript.Slot.ATTACK)
	c.enemies[0].hp = 2
	c.resolve_player()
	check(c.enemies[0].hp == 1, "the dummy can't die before the lessons end")
	for t in 2:
		c.resolve_enemy(0, CombatScript.Grade.MISS)
		c.end_enemy_phase()
		c.start_turn()
	check(c.rolled_pair() != 0, "the Cleave lesson turn always rolls a pair")
	for t in 3:
		c.end_enemy_phase()
	check(c.tutorial_done(), "the tutorial ends after 5 enemy turns")
	check(c.dungeon_turns == 0, "tutorial turns don't advance the murmurs")


func _perks() -> void:
	var c := fresh()
	c.apply_perks(["steady_hand", "thick_skin"])
	check(c.max_hp == 50 and c.player_hp == 50, "Thick Skin: 50 max HP")
	c.start_turn()
	check(c.rerolls == CombatScript.REROLLS_PER_TURN + 1, "Steady Hand: +1 reroll")
	place(c, 0, 1, CombatScript.Slot.CLEAVE)
	place(c, 1, 1, CombatScript.Slot.CLEAVE)
	check(c.cleave_damage() == 3, "a pair of 1s Cleaves for 3 without Gambler's Heart")
	c.apply_perks(["gamblers_heart"])
	check(c.cleave_damage() == 18, "Gambler's Heart: a pair of 1s counts as 12, so 18")
	_new_perks()


## The perks past the first three, each against its own rule with and without it.
func _new_perks() -> void:
	var c := fresh()
	c.enemies[0].hp = 0
	c.claim_fight()
	var plain := c.shards
	var s := fresh()
	s.apply_perks(["scavenger"])
	s.enemies[0].hp = 0
	s.claim_fight()
	check(plain == CombatScript.SHARDS_PER_KILL and s.shards == CombatScript.SHARDS_PER_KILL + 1, "Scavenger: +1 Shard per kill")

	var b := fresh()
	check(b.campfire_heal_amount() == 12, "a campfire heals 30% of 40")
	b.apply_perks(["bonfire_keeper"])
	check(b.campfire_heal_amount() == 18, "Bonfire Keeper: 45% of 40")

	var l := fresh()
	l.apply_perks(["lucky_charm"])
	l.player_hp = 8
	check(l.hurt(6) == 3 and l.player_hp == 5, "Lucky Charm: events stop at 5 HP")
	l.player_hp = 3
	check(l.hurt(6) == 0 and l.player_hp == 3, "Lucky Charm: already under 5, events take nothing")

	var n := fresh()
	var parry := n.parry_window_ms()
	var perfect := n.perfect_window_ms()
	n.apply_perks(["iron_nerve"])
	check(n.parry_window_ms() == parry + 40 and n.perfect_window_ms() == perfect + 40, "Iron Nerve: +40 ms on Perfect and parry")

	var g := fresh()
	g.apply_perks(["grit_teeth"])
	g.resolve_player()
	check(g.grit == 2 * g.dice.size(), "Grit Teeth: +2 Grit per unplaced die")

	var h := fresh()
	h.apply_perks(["hex_ward"])
	h.enemies[0].intent = {"kind": "curse", "target": 0}
	h.resolve_enemy(0, CombatScript.Grade.MISS)
	check(not h.dice[0].faces.has(CombatScript.CURSE), "Hex Ward: the first curse of a fight fails")
	h.resolve_enemy(0, CombatScript.Grade.MISS)
	check(h.dice[0].faces.has(CombatScript.CURSE), "Hex Ward: the second one lands")
	h.start_fight(SKELETON_BELL)
	check(not h.ward_spent, "Hex Ward comes back each fight")

	var a := fresh()
	check(Events.ambush_chance(a) == Events.AMBUSH_CHANCE, "ambush chance is 20% by default")
	a.apply_perks(["lantern_bearer"])
	check(is_equal_approx(Events.ambush_chance(a), 0.1) and Events.odds([], Events.ambush_chance(a))[0] == ["Ambush", 10.0], "Lantern Bearer: ambushes 10%, and the map's odds say so")
	for id in Meta.PERKS:
		check(ResourceLoader.exists(UI.ART % ("perk_" + id)), "%s has badge art" % id)


func _forge_and_campfire() -> void:
	var c := fresh()
	check(not c.forge(0, 0), "no Shards, no forging")
	c.shards = 5
	check(c.forge(0, 0) and c.shards == 1, "a forge costs 4 Shards")
	check(c.dice[0].faces == [3, 2, 3, 4, 5, 6], "the 1 face became a 3")
	check(c.forge(0, 5, true) and c.shards == 1, "the campfire upgrade is free")
	c.start_fight(WARDEN)
	check(c.dice[0].faces == [3, 2, 3, 4, 5, 8], "forged faces survive into the next fight")
	c.player_hp = 30
	c.heal(c.campfire_heal_amount())
	check(c.player_hp == 40, "the campfire heals 12, capped at max HP")


func _fight_rewards() -> void:
	var c := fresh(RATS)
	c.enemies[0].hp = 0
	c.enemies[1].hp = 0
	c.claim_fight()
	check(c.kills == 2 and c.shards == 4, "two dead rats: 2 kills, 4 Shards")
	c.start_fight(WARDEN)
	c.enemies[0].hp = 30
	check(c.boss_damage_pct() == 60, "Warden at 30/75 took 60%")
	c.start_fight(RATS)
	c.end_enemy_phase()
	c.start_fight(WARDEN)
	c.end_enemy_phase()
	check(c.dungeon_turns == 1, "only dungeon turns advance the murmurs")


## Many dealt floors, each checked against the branching map's rules in Floor.deal().
func _floors() -> void:
	var kinds_mid := {}
	var shapes := {}
	for n in 200:
		var f: Array = Floor.deal()
		var groups := []
		check(f.size() == 10, "a floor is ten columns")
		for c in f.size():
			var col: Array = f[c]
			check(col.size() == 1 if c in [0, 9] else (col.size() >= 2 and col.size() <= 5), "column %d has a legal room count" % c)
			var lanes: Array = col.map(func(r): return r.lane)
			var sorted_lanes := lanes.duplicate()
			sorted_lanes.sort()
			check(lanes == sorted_lanes and sorted_lanes.all(func(l): return l >= 0 and l < 5), "column %d lanes are sorted and in 0..4" % c)
			check(lanes.size() == sorted_lanes.reduce(func(u, l): return u if l in u else u + [l], []).size(), "column %d lanes are distinct" % c)
			var hp: Array = Floor.ENTRANCE_HP if c == 0 else (Floor.EARLY_HP if c <= 4 else Floor.LATE_HP)
			var linked := {}
			for r in col:
				check(r.next.size() > 0 or c == 9, "column %d room has a way on" % c)
				for i in r.next:
					check(i >= 0 and i < f[c + 1].size(), "a link points at a real room")
					linked[i] = true
					var child: Dictionary = f[c + 1][i]
					check(not (r.kind in ["forge", "campfire"] and child.kind == r.kind), "no forge/campfire links to its own kind")
					for r2 in col:
						for j in r2.next:
							check(not (r.lane < r2.lane and child.lane > f[c + 1][j].lane), "links don't cross")
				if c < 9:
					kinds_mid[r.kind] = kinds_mid.get(r.kind, 0) + (1 if c in range(3, 8) else 0)
				if c == 8:
					check(r.kind == "campfire", "column 8 is all campfires")
				if c in [1, 2]:
					check(r.kind in ["fight", "unknown"], "columns 1-2 are fights or ?")
				if r.kind == "fight" and c < 9:
					var total: int = r.enemies.reduce(func(t, k): return t + CombatScript.TYPES[k].hp, 0)
					check(total >= hp[0] and total <= hp[1], "column %d fight has %d HP, wants %s" % [c, total, hp])
					check(r.enemies.size() in [1, 2, 3] and r.enemies.all(func(k): return k in Floor.ENEMIES), "a fight is 1-3 dungeon enemies")
					groups.append(r.enemies)
			if c < 9:
				check(linked.size() == f[c + 1].size(), "every room in column %d has a parent" % (c + 1))
		shapes[str(f[4].map(func(r): return r.lane))] = true
		check(f[-1][0].enemies == ["warden"] and f[-1][0].label == "Boss: Bone Warden" and f[-1][0].next == [], "the boss is last")
		check(groups.size() == groups.reduce(func(u, g): return u if g in u else u + [g], []).size(), "no group twice")
	for k in ["fight", "unknown", "forge", "campfire"]:
		check(kinds_mid.get(k, 0) > 0, "%s shows up in columns 3-7" % k)
	check(shapes.size() > 5, "column 4 differs from floor to floor")
	var used := {}
	for i in 100:  # more groups than fit, so repeats must be accepted instead of looping forever
		Floor.group(Floor.ENTRANCE_HP, used)
	var c := CombatScript.new(7)
	c.start_group(["rat", "rat", "rat"])
	check(c.enemies.map(func(e): return e.name) == ["Bone Rat A", "Bone Rat B", "Bone Rat C"], "a dealt group starts like a set fight")


func _meta() -> void:
	check(Meta.embers_for(7, 3, 50, false) == 35 + 30 + 25, "Embers: 5 per kill, 10 per room, half the boss %")
	check(Meta.embers_for(0, 0, 0, true) == 50, "a win adds 50")
	var m := Meta.new()
	m.embers = 120
	check(m.unlock("thick_skin") and m.embers == 20, "unlock spends Embers")
	check(not m.unlock("thick_skin"), "can't unlock twice")
	check(not m.unlock("gamblers_heart"), "can't unlock what you can't afford")
	m.owned = ["steady_hand", "thick_skin", "gamblers_heart"]
	check(m.toggle_equip("steady_hand") and m.toggle_equip("thick_skin"), "two perks fit")
	check(not m.toggle_equip("gamblers_heart"), "a third doesn't")
	check(m.toggle_equip("steady_hand") and m.equipped == ["thick_skin"], "toggling again unequips")
	var path := "user://test_meta.json"
	m.tutorial_done = true
	m.save_path = path
	m.save()
	var back := Meta.load_from(path)
	check(back.embers == m.embers and back.owned == m.owned and back.equipped == m.equipped and back.tutorial_done, "save and load round-trip")
	check(back.music == 1.0 and back.sounds == 1.0 and not back.muted, "sound starts at full volume, unmuted")
	m.music = 0.25
	m.sounds = 0.0
	m.muted = true
	m.save()
	back = Meta.load_from(path)
	check(back.music == 0.25 and back.sounds == 0.0 and back.muted, "sound settings round-trip")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"music": 7, "sounds": -2}')
	f.close()
	back = Meta.load_from(path)
	check(back.music == 1.0 and back.sounds == 0.0, "out-of-range volumes in a save are clamped")
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	back.music = 0.5
	back.apply_sound()
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5)), "apply_sound sets the Music bus")
	back.muted = false
	back.apply_sound()
	DirAccess.remove_absolute(path)
	check(Meta.load_from(path).embers == 0, "a missing save starts fresh")
