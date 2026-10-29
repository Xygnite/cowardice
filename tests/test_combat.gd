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
	_face_marks()
	_skills()
	_fight_rewards()
	_meta()
	_floors()
	_hp_scaling()
	_mine_enemies()
	_mine_sprites()
	_pit_king()
	_lasting_curse()
	_event_helpers()
	_events()
	_event_backdrops()
	_backdrop_life()
	_run_save()
	_relic_belt()
	_relic_save()
	_mult()
	_relic_effects()
	_relic_icons()
	_relic_offer()
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
	place(c, 0, 4, CombatScript.Slot.SKILL)
	place(c, 1, 4, CombatScript.Slot.SKILL)
	check(c.preview_damage() == 12, "a Cleave pair of 4s deals 12 past Bone Wall; the lone Attack 1 is walled")
	c.enemies[0].intent = {"kind": "guard", "value": 6}
	check(c.preview_damage() == 12, "Cleave ignores enemy Guard")
	check(c.rolled_pair() == 4, "the pair of 4s is spotted")


func _cleave_hits_every_enemy() -> void:
	var c := fresh(RATS)
	place(c, 0, 4, CombatScript.Slot.SKILL)
	place(c, 1, 4, CombatScript.Slot.SKILL)
	check(c.preview_damage() == 12, "Cleave 12 is split, not copied, across three rats")
	c.resolve_player()
	check(c.enemies.all(func(e): return e.hp == 2), "each rat takes 4 and survives")
	c.enemies[0].hp = 0
	c.target = 2
	place(c, 0, 4, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	check(not c.skill_ready(), "4 and 3 are not a pair")
	place(c, 1, 5, CombatScript.Slot.SKILL)
	place(c, 0, 5, CombatScript.Slot.SKILL)
	check(c.skill_share(2) == 8 and c.skill_share(1) == 7, "Cleave 15 over two rats: the odd point goes to the target")


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
	place(c, 0, 1, CombatScript.Slot.SKILL)
	place(c, 1, 1, CombatScript.Slot.SKILL)
	check(c.cleave_damage() == 3, "a pair of 1s Cleaves for 3 without Gambler's Heart")
	c.apply_perks(["gamblers_heart"])
	check(c.cleave_damage() == 18, "Gambler's Heart: a pair of 1s counts as 12, so 18")
	_new_perks()
	_bonus_perk()


## The perk picked after the Warden: added for this run, Thick Skin's HP given once, never one already equipped.
func _bonus_perk() -> void:
	var c := fresh()
	c.apply_perks(["steady_hand"])
	c.player_hp = 30
	c.add_perk("thick_skin")
	c.add_perk("thick_skin")
	check(c.perks == ["steady_hand", "thick_skin"] and c.bonus_perk == "thick_skin", "add_perk adds the perk once")
	check(c.max_hp == 50 and c.player_hp == 40, "a bonus Thick Skin gives +10 max HP and +10 HP, once")
	var ok := true
	for i in 50:
		var offer: Array = PerkPickScreen.offer(["thick_skin", "scavenger"])
		ok = ok and offer.size() == 3 and offer.all(func(id): return Meta.PERKS.has(id) and id not in ["thick_skin", "scavenger"])
		ok = ok and offer[0] != offer[1] and offer[0] != offer[2] and offer[1] != offer[2]
	check(ok, "the bonus pick offers 3 different perks, never an equipped one")


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


## Forged marks: Sharp cuts past Guard and Bone Wall, Ward doubles in Guard, Ember heals, Shard pays,
## each only when its own face is the one rolled; a mark replaces another and lifts a curse, and marks survive a save.
func _face_marks() -> void:
	var c := fresh(WARDEN)
	check(c.forge(0, 5, true, "sharp") and c.dice[0].base[5] == 6, "a mark leaves the number alone")
	check(not c.forge(0, 5, true, "sharp"), "a face can't take the mark it has")
	c.curse_face(1, 0)
	check(c.forge(1, 0, true, "ember") and c.dice[1].base[0] == 1 and not c.dice[1].uncursed.has(0) and c.dice[1].marks[0] == "ember", "a mark on a cursed face lifts the curse")
	var swap := fresh()
	swap.forge(0, 0, true, "ward")
	check(swap.forge(0, 0, true, "shard") and swap.dice[0].marks[0] == "shard", "a new mark replaces the old one")
	c.forge(1, 3, true, "ward")
	c.forge(2, 0, true, "ember")
	c.forge(2, 1, true, "shard")
	c.start_turn()
	c.enemies[0].intent = {"kind": "guard", "value": 4}
	for i in 3:
		c.dice[i].side = 5 if i == 0 else 4
		c.dice[i].value = c.dice[i].faces[c.dice[i].side]
		c.assign(i, Combat.Slot.ATTACK)
	check(c.damage_to(0) == 7, "Sharp 6 dodges Bone Wall and Guard: the wall eats a 5, Guard 4 takes the other to 1 (got %d)" % c.damage_to(0))
	c.dice[0].side = 4
	c.dice[0].value = 6  # a 6 that isn't the marked side, as the tutorial's rigged pair sets it
	check(Combat.mark_of(c.dice[0]) == "", "a value set without its side carries no mark")
	c.dice[1].side = 3
	c.dice[1].value = 4
	c.assign(1, Combat.Slot.GUARD)
	check(c.guard_total() == 8, "Ward 4 in Guard counts 8")
	c.player_hp = 10
	c.shards = 0
	c.dice[2].side = 0
	c.dice[2].value = 1
	c.resolve_player()
	check(c.player_hp == 10 + Combat.EMBER_HEAL, "a placed Ember face heals")
	c.dice[2].side = 1
	c.dice[2].value = 2
	c.resolve_player()
	check(c.shards == 1, "a placed Shard face pays a Shard")
	check(c.forge(1, 4, true, "", 4) and c.dice[1].base[4] == 9, "a rolled 6 raises a face by 4")
	check(CombatScript.FORGE_ROLL.size() == 6 and CombatScript.FORGE_ROLL.all(func(u): return u.has("step") or CombatScript.MARKS.has(u.mark)), "every Forge roll face grants a real upgrade")
	var full := fresh()
	for d in full.dice:
		d.marks = ["ward", "ward", "ward", "ward", "ward", "ward"]
	check(not full.can_mark("ward") and full.can_mark("sharp"), "only every face already Ward leaves a rolled Ward nowhere to go")
	var back := CombatScript.from_dict(c.to_dict())
	check(back.dice[0].marks[5] == "sharp" and back.dice[2].marks == ["ember", "shard", "", "", "", ""], "marks come back from a save")
	var old := c.to_dict()
	for x in old.dice:
		x.erase("marks")
	check(CombatScript.valid_dict(old) and CombatScript.from_dict(old).dice[0].marks == ["", "", "", "", "", ""], "a save from before marks still loads, unmarked")


## Each skill fires only on its pattern in the Skill slot and ignores Guard and Bone Wall; every unlocked one that fits fires.
func _skills() -> void:
	var c := fresh(ACOLYTE_RATS)
	c.enemies[0].intent = {"kind": "guard", "value": 8}
	var put := func(values: Array) -> void:
		for i in 3:
			c.dice[i].slot = CombatScript.Slot.NONE
		for i in values.size():
			place(c, i, values[i], CombatScript.Slot.SKILL)
	c.skills = ["sunder"]
	put.call([4, 4])
	check(not c.skill_ready(), "Sunder needs three of a kind, not a pair")
	put.call([4, 4, 4])
	check(c.skill_ready() and c.damage_to(0) == 30 and c.damage_to(1) == 30, "Sunder 4-4-4: 30 to every enemy, past the Acolyte's Guard")
	c.skills = ["cleave"]
	check(not c.skill_ready(), "Cleave wants exactly two")
	c.skills = ["flurry"]
	put.call([5, 3, 4])
	check(c.skill_ready() and c.damage_to(0) == 15 and c.damage_to(1) == 0, "Flurry 3-4-5: 12 +3 to the target only")
	put.call([2, 4, 5])
	check(not c.skill_ready(), "2-4-5 is no run")
	c.skills = ["oath"]
	put.call([1, 3, 5])
	check(c.damage_to(0) == 9, "odd Oath: 9 to the target")
	put.call([2, 4, 6])
	c.player_hp = 10
	check(c.damage_to(0) == 0, "even Oath deals nothing")
	c.resolve_player()
	check(c.player_hp == 16, "even Oath 2-4-6 heals 6")
	c.skills = ["gambit"]
	c.target = 2
	c.shards = 0
	put.call([6, 1])
	check(c.damage_to(2) == 12, "Gambit 1+6: 12 to the target")
	c.resolve_player()
	check(c.shards == 1, "a Gambit that kills pays a Shard")
	put.call([CombatScript.CURSE, 6])
	check(not c.skill_ready(), "a cursed die breaks a skill")
	c.skills = ["flurry"]
	for i in 3:
		place(c, i, [5, 3, 4][i], CombatScript.Slot.NONE)
	check(c.skill_dice().size() == 3, "all three unplaced dice of a 3-4-5 run get the aura")
	c.skills = ["gambit"]
	check(c.skill_dice().is_empty(), "and none do when no unlocked skill fits")
	var w := fresh(WARDEN)
	w.skills = ["cower"]
	w.enemies[0].intent = {"kind": "unblockable", "value": 14}
	for i in 3:
		place(w, i, [1, 2, 2][i], CombatScript.Slot.SKILL)
	place(w, 0, 1, CombatScript.Slot.GUARD)
	check(not w.skill_ready(), "Cower needs all three dice")
	place(w, 0, 1, CombatScript.Slot.SKILL)
	w.resolve_player()
	check(not w.needs_timing(0) and w.resolve_enemy(0, CombatScript.Grade.MISS).begins_with("You cower") and w.player_hp == w.max_hp, "Cower: the unblockable 14 misses")
	w.end_enemy_phase()
	w.start_turn()
	check(not w.cowered, "Cower lasts one turn")
	var m := Meta.new()
	check(not m.unlock_skill("sunder"), "no Embers, no Sunder")
	m.embers = 650
	check(m.unlock_skill("sunder") and m.embers == 50 and "sunder" in m.skills, "unlocking Sunder costs 600, for good")
	check(not m.unlock_skill("sunder") and m.embers == 50, "unlocking it again does nothing")
	var all := fresh(ACOLYTE_RATS)
	all.skills = CombatScript.SKILLS.keys()
	for i in 3:
		place(all, i, 4, CombatScript.Slot.SKILL)
	check(all.fired() == ["sunder", "oath"] and all.damage_to(0) == 30, "4-4-4 fires Sunder and even Oath at once")
	for i in 3:
		place(all, i, 1, CombatScript.Slot.SKILL)
	check(all.fired() == ["sunder", "cower", "oath"] and all.damage_to(all.target) == 8 + 3, "1-1-1 fires Sunder, Cower and odd Oath together")
	all.resolve_player()
	check(all.cowered, "Cower fires alongside the others")
	var old := w.to_dict()
	old["skill"] = "flurry"
	check(CombatScript.valid_dict(old) and CombatScript.from_dict(old).skills == ["cleave"], "a save from when one skill was equipped still loads")


func _fight_rewards() -> void:
	var c := fresh(RATS)
	c.enemies[0].hp = 0
	c.enemies[1].hp = 0
	c.claim_fight()
	check(c.kills == 2 and c.shards == 4, "two dead rats: 2 kills, 4 Shards")
	c.start_fight(WARDEN)
	c.enemies[0].hp = 48
	check(c.boss_damage_pct() == 60, "Warden at 48/120 took 60%")
	c.start_fight(RATS)
	c.end_enemy_phase()
	c.start_fight(WARDEN)
	c.end_enemy_phase()
	check(c.dungeon_turns == 1, "only dungeon turns advance the murmurs")


## Many dealt floors, each checked against the branching map's rules in Floor.deal().
func _mine_group(keys: Array, at_turn := 0) -> CombatScript:
	var c := fresh()
	c.start_group(keys)
	c.turn = at_turn
	c.start_turn()
	return c


## Every Hollow Mine type is drawn: a sprite with its baked frames scene, so no placeholder box shows.
func _mine_sprites() -> void:
	for key in ["miner", "crawler", "hulk", "rubble", "canary", "shaft_foreman", "pit_king"]:
		var sprite: String = CombatScript.TYPES[key].get("sprite", "")
		check(sprite != "" and FileAccess.file_exists("res://assets/sprites/%s.png" % sprite)
			and FileAccess.file_exists("res://scenes/%s_frames.tscn" % sprite), "%s has a sprite and its frames scene" % key)

func _mine_enemies() -> void:
	var c := _mine_group(["miner"], 2)
	check(c.enemies[0].intent.kind == "unblockable", "the Miner's third intent is unblockable")
	c = _mine_group(["crawler", "crawler"])
	check(c.enemies.all(func(e): return e.intent.value == 4), "two Crawlers attack for base + 1")
	c = _mine_group(["crawler", "crawler", "crawler"])
	check(c.enemies.all(func(e): return e.intent.value == 5), "three Crawlers attack for base + 2")
	c.enemies[0].hp = 0
	c.start_turn()
	check(c.enemies[1].intent.value == 4 and c.enemies[2].intent.value == 4, "after a Crawler dies the others drop")
	c = _mine_group(["skeleton", "shaft_foreman"])
	check(c.enemies[0].intent.value == 7 and c.enemies[1].intent.value == 5, "the Foreman adds 2 to others, not himself")
	c = _mine_group(["skeleton", "shaft_foreman"], 1)
	check(c.enemies[0].intent.kind == "guard" and c.enemies[0].intent.value == 4, "a guard intent is unchanged")
	c = _mine_group(["crawler", "crawler", "shaft_foreman"])
	check(c.enemies[0].intent.value == 3 + 1 + 2, "Crawler bonus and Foreman bonus add")
	c = _mine_group(["hulk"], 1)
	c.enemies[0].hp = 3
	place(c, 0, 5, CombatScript.Slot.ATTACK)
	c.resolve_player()
	check(c.enemies[0].name == "Rubble" and c.enemies[0].hp == 8 and c.enemies[0].intent.is_empty(), "a dead Hulk leaves Rubble in its place")
	check(c.enemies[0].from == "Rubble Hulk", "the Rubble is marked as coming from the Hulk")
	check(not c.fight_won() and c.replaced == 1, "the Hulk's kill is counted and the fight goes on")
	c.start_turn()
	check(c.enemies[0].intent.kind == "attack", "Rubble acts from next turn")
	c.enemies[0].hp = 0
	var before := c.kills
	c.claim_fight()
	check(c.fight_won() and c.kills - before == 2, "Hulk and Rubble are two kills")
	c = _mine_group(["hulk", "hulk"], 1)
	c.enemies[0].hp = 3
	c.enemies[1].hp = 3
	place(c, 0, 5, CombatScript.Slot.ATTACK)
	c.resolve_player()
	c.target = 1
	c.resolve_player()
	check(c.enemies[0].name == "Rubble A" and c.enemies[1].name == "Rubble B", "two Hulks leave Rubble A and B, got %s and %s" % [c.enemies[0].name, c.enemies[1].name])
	c = _mine_group(["hulk", "crawler"], 1)
	c.enemies[0].hp = 3
	c.enemies[1].hp = 2
	place(c, 0, 3, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	c.resolve_player()
	check(c.enemies[0].name == "Rubble" and c.enemies[1].hp == 0 and not c.fight_won(), "a Cleave kills the Hulk and a Crawler: Rubble stands")
	c = _mine_group(["canary", "miner"])
	check(c.enemies[1].intent.kind == "unblockable" and c.enemies[1].intent.value == 5, "a Canary's ring makes another's attack unblockable")


func _hp_scaling() -> void:
	var c := fresh(RATS)
	c.start_group(["skeleton"], 1.5)
	check(c.enemies[0].hp == 30 and c.enemies[0].max == 30, "a 1.5x Skeleton has 30 HP")
	c = fresh()
	c.start_group(["hulk"], 1.5)
	c.turn = 1
	c.start_turn()
	c.enemies[0].hp = 3
	place(c, 0, 5, CombatScript.Slot.ATTACK)
	c.resolve_player()
	check(c.enemies[0].name == "Rubble" and c.enemies[0].hp == ceili(8 * 1.5) and c.enemies[0].max == 12, "a scaled Hulk leaves a scaled Rubble")
	c.start_fight(WARDEN)
	check(c.enemies[0].max == 120, "the Warden has 120 HP")
	c.enemies[0].hp = 60
	check(c.is_phase2(c.enemies[0]) and c.boss_damage_pct() == 50, "the Warden enters phase 2 and has taken 50% at 60/120")
	var map := Floor.deal("chapel")
	var ok := true
	for col in map.size():
		for room in map[col]:
			if room.kind == "fight":
				ok = ok and room.scale == (1.5 if col >= 5 and col <= 7 else 1.0)
	check(ok, "only columns 5-7 fights are dealt a 1.5 scale")


func _pit_king() -> void:
	var c := _mine_group(["pit_king"], 1)  # turn 1 is the cave-in
	check(c.is_boss_fight() and c.enemies[0].max == 220, "the Pit King is a 220 HP boss")
	check(c.enemies[0].intent.kind == "cave_in" and c.intent_text(0) == "Cave-in", "the Pit King's second move is a cave-in")
	place(c, 0, 4, CombatScript.Slot.GUARD)
	place(c, 1, 2, CombatScript.Slot.SKILL)
	place(c, 2, 2, CombatScript.Slot.SKILL)
	c.resolve_player()
	var buried := 0
	c.resolve_enemy(0, CombatScript.Grade.MISS)
	check(c.dice.filter(func(d): return d.buried > 0).size() == 1, "a cave-in buries exactly one die")
	for i in 3:
		if c.dice[i].buried > 0:
			buried = i
	var value: int = c.dice[buried].value
	var slot: int = c.dice[buried].slot
	c.end_enemy_phase()
	c.start_turn()
	check(c.dice[buried].value == value and c.dice[buried].slot == slot, "a buried die keeps its value and slot")
	c.assign(buried, CombatScript.Slot.ATTACK)
	c.toggle_lock(buried)
	check(c.dice[buried].slot == slot and not c.dice[buried].locked, "a buried die can't be placed or locked")
	c.rerolls = 5
	for n in 20:
		c.reroll()
		check(c.dice[buried].value == value, "reroll leaves a buried die alone")
	c.resolve_player()
	c.end_enemy_phase()
	c.start_turn()
	check(c.dice[buried].buried == 0 and c.dice[buried].slot == CombatScript.Slot.NONE, "a buried die is free the turn after")
	# Two buried: nothing more to bury, the last free die stays free.
	c = fresh()
	c.dice[0].buried = 2
	c.dice[1].buried = 1
	check(c.bury_one() == -1, "the last unburied die is never buried")
	c.dice[1].buried = 0
	check(c.bury_one() in [1, 2], "with two free dice one can be buried")
	# A buried Guard die guards again; a buried Cleave pair cleaves again.
	c = _mine_group(["pit_king"], 1)
	place(c, 0, 5, CombatScript.Slot.GUARD)
	c.dice[0].buried = 2
	c.start_turn()
	place(c, 1, 1, CombatScript.Slot.NONE)
	c.resolve_player()
	check(c.guard_pool == 5, "a buried die in Guard guards again with the same value")
	c = _mine_group(["pit_king"], 1)
	place(c, 0, 3, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	c.dice[1].buried = 2
	c.start_turn()
	check(c.dice[1].slot == CombatScript.Slot.SKILL and c.dice[1].value == 3, "a buried die keeps its Cleave slot and value")
	place(c, 0, 3, CombatScript.Slot.SKILL)
	check(c.skill_ready(), "a buried die in Cleave keeps its pair")
	# Unplaced buried dice give no Grit.
	c = _mine_group(["pit_king"], 1)
	c.dice[0].buried = 2
	c.start_turn()
	c.assign(1, CombatScript.Slot.ATTACK)
	c.assign(2, CombatScript.Slot.ATTACK)
	c.resolve_player()
	check(c.grit == 0, "a buried die gives no Grit")
	c.dice[0].buried = 2
	c.start_group(["rat"])
	check(c.dice.all(func(d): return d.buried == 0), "a new fight starts with no buried dice")
	# Phase 2: every attack comes with a cave-in.
	for t in 3:
		c = _mine_group(["pit_king"], t)
		c.enemies[0].hp = 55
		c.start_turn()
		check(c.enemies[0].intent.kind == "attack" and c.enemies[0].intent.get("cave_in", false), "phase 2 attack %d carries a cave-in" % t)
	c.resolve_enemy(0, CombatScript.Grade.MISS)
	check(c.dice.any(func(d): return d.buried > 0), "a phase 2 attack buries a die")


func _floors() -> void:
	for id in Floor.FLOORS:
		_floor(id)
	var used := {}
	for i in 100:  # more groups than fit, so repeats must be accepted instead of looping forever
		Floor.group(Floor.FLOORS.chapel.hp[0], used)
	var c := CombatScript.new(7)
	c.start_group(["rat", "rat", "rat"])
	check(c.enemies.map(func(e): return e.name) == ["Bone Rat A", "Bone Rat B", "Bone Rat C"], "a dealt group starts like a set fight")


func _floor(id: String) -> void:
	var data: Dictionary = Floor.FLOORS[id]
	var kinds_mid := {}
	var shapes := {}
	for n in 200:
		var f: Array = Floor.deal(id)
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
			var hp: Array = data.hp[0] if c == 0 else (data.hp[1] if c <= 4 else data.hp[2])
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
					check(r.enemies.size() in [1, 2, 3] and r.enemies.all(func(k): return k in data.enemies), "a fight is 1-3 %s enemies" % id)
					groups.append(r.enemies)
			if c < 9:
				check(linked.size() == f[c + 1].size(), "every room in column %d has a parent" % (c + 1))
		shapes[str(f[4].map(func(r): return r.lane))] = true
		check(f[-1][0].enemies == data.boss and f[-1][0].label == "Boss: " + CombatScript.TYPES[data.boss[0]].name and f[-1][0].next == [], "the boss is last")
		check(groups.size() == groups.reduce(func(u, g): return u if g in u else u + [g], []).size(), "no group twice")
	for k in ["fight", "unknown", "forge", "campfire"]:
		check(kinds_mid.get(k, 0) > 0, "%s shows up in columns 3-7" % k)
	check(shapes.size() > 5, "column 4 differs from floor to floor")


func _meta() -> void:
	check(Meta.embers_for(7, 3, 50, false) == 35 + 30 + 25, "Embers: 5 per kill, 10 per room, half the boss %")
	check(Meta.embers_for(0, 0, 0, true) == 100, "a win (the Pit King) adds 100")
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
	check(not back.mine_unlocked, "the Mine starts locked")
	m.mine_unlocked = true
	m.save()
	check(Meta.load_from(path).mine_unlocked, "an unlocked Mine round-trips")
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
	check(not back.mine_unlocked, "an old save without the Mine loads it locked")
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	back.music = 0.5
	back.apply_sound()
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5)), "apply_sound sets the Music bus")
	back.muted = false
	back.apply_sound()
	DirAccess.remove_absolute(path)
	check(Meta.load_from(path).embers == 0, "a missing save starts fresh")


func _relic_icons() -> void:
	for id in Combat.RELICS:
		check(ResourceLoader.exists("res://assets/ui/cut/relic_%s.png" % id), "relic %s has its icon" % id)


func _event_backdrops() -> void:
	for id in Events.IDS:
		check(ResourceLoader.exists("res://assets/ui/bg_event_%s.webp" % id), "event %s has its backdrop" % id)


func _backdrop_life() -> void:
	var t: Transform2D = BackdropLife.cover(Vector2(1280, 720))
	check(is_equal_approx(t.get_scale().x, 720.0 / 572), "backdrop life: height decides the scale")
	var tl: Vector2 = t * Vector2.ZERO
	var br: Vector2 = t * BackdropLife.IMAGE
	check(absf(tl.x + 4.45) < 0.05 and absf(tl.y) < 0.01, "backdrop life: image top-left, got %s" % tl)
	check(absf(br.x - 1284.45) < 0.05 and absf(br.y - 720) < 0.01, "backdrop life: image bottom-right, got %s" % br)
	var wide: Transform2D = BackdropLife.cover(Vector2(1812, 720))
	check(is_equal_approx(wide.get_scale().x, 1812.0 / 1024), "backdrop life: width decides on a wide rect")
	var mid: Vector2 = wide * Vector2(512, 286)
	check(mid.is_equal_approx(Vector2(906, 360)), "backdrop life: image centre stays centred, got %s" % mid)
	var keys: Array = BackdropLife.LIFE.keys()
	keys.sort()
	check(keys == ["camp", "fight", "menu", "mine"], "backdrop life: menu, camp, fight and mine only")
	for art: String in keys:
		for part: Dictionary in BackdropLife.LIFE[art].parts:
			check(ResourceLoader.exists("res://assets/ui/life/%s.png" % part.art), "backdrop life: %s art %s exists" % [art, part.art])
	for want: Array in [["menu", 2], ["camp", 1], ["fight", 2], ["mine", 2]]:
		var flames: Array = BackdropLife.LIFE[want[0]].parts.filter(func(p): return p.kind == "flame")
		check(flames.size() >= want[1], "backdrop life: %s has %d+ flames, got %d" % [want[0], want[1], flames.size()])
	var rect := TextureRect.new()
	var life: BackdropLife = BackdropLife.attach(rect, "fight")
	var parts: Array = BackdropLife.LIFE.fight.parts
	var kids: Array = life.stage.get_children()
	check(kids.size() == parts.size(), "backdrop life: attach builds every fight part")
	var s0: AnimatedSprite2D = kids[0]
	check(s0.is_playing() and s0.position == parts[0].at and s0.scale == Vector2(2, 2), "backdrop life: a flame plays at its spot, px-scaled")
	rect.free()

	for want: Array in [["menu", "moat"], ["camp", "ground"], ["mine", "dust"]]:
		var fogs: Array = BackdropLife.LIFE[want[0]].parts.filter(func(p): return p.kind == "fog" and p.art == want[1])
		check(fogs.size() == 1, "backdrop life: %s has %s fog" % want)
	for art: String in keys:
		for part: Dictionary in BackdropLife.LIFE[art].parts:
			if part.kind != "fog" or not ResourceLoader.exists("res://assets/ui/life/%s.png" % part.art):
				continue
			var band: Image = (load("res://assets/ui/life/%s.png" % part.art) as Texture2D).get_image()
			var p: int = part.period
			var h := band.get_height()
			check(band.get_width() % p == 0 and band.get_width() >= 2 * p, "backdrop life: %s band is whole periods" % part.art)
			check(band.get_region(Rect2i(0, 0, p, h)).get_data() == band.get_region(Rect2i(p, 0, p, h)).get_data(), "backdrop life: %s band repeats without a seam" % part.art)
			if CombatScreen.LEDGES.has(art):
				var bottom: float = part.at.y + h * BackdropLife.LIFE[art].px
				check(bottom < CombatScreen.LEDGES[art] * 572, "backdrop life: %s fog stays above the floor ledge, bottom %s" % [art, bottom])
	var menu := TextureRect.new()
	var mlife: BackdropLife = BackdropLife.attach(menu, "menu")
	var mparts: Array = BackdropLife.LIFE.menu.parts
	var fi: int = mparts.find_custom(func(p): return p.kind == "fog")
	var fog: Sprite2D = mlife.stage.get_child(fi)
	var fp: Dictionary = mparts[fi]
	check(fog.region_enabled and fog.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED and fog.region_rect.size.x == fp.width / BackdropLife.LIFE.menu.px, "backdrop life: fog is a repeating region as wide as its part")
	var tick: Timer = fog.get_child(0)
	for n in fp.period:
		tick.timeout.emit()
		if n == 0:
			check(fog.region_rect.position.x == 1, "backdrop life: fog steps one pxl pixel per tick")
	check(fog.region_rect.position.x == 0 and is_equal_approx(tick.wait_time, fp.step_s), "backdrop life: fog wraps at its period")
	menu.free()

	var dir := "user://test_life/"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(12, 4, false, Image.FORMAT_RGBA8)
	img.save_png(dir + "sheet.png")
	var f := FileAccess.open(dir + "sheet.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames": {
		"zz": {"frame": {"x": 0, "y": 0, "w": 4, "h": 4}}, "aa": {"frame": {"x": 4, "y": 0, "w": 4, "h": 4}},
		"mm": {"frame": {"x": 8, "y": 0, "w": 4, "h": 4}}}}, "", false))  # unsorted, as pxl writes
	f.close()
	var sf: SpriteFrames = BackdropLife.frames("sheet", 6.0, dir)
	check(sf.get_frame_count("default") == 3 and sf.get_animation_speed("default") == 6.0, "backdrop life: frames() reads 3 frames at fps")
	var xs: Array = []
	for i in sf.get_frame_count("default"):
		xs.append((sf.get_frame_texture("default", i) as AtlasTexture).region.position.x)
	check(xs == [0.0, 4.0, 8.0], "backdrop life: frames() keeps sheet order, got %s" % [xs])
	for n in ["sheet.png", "sheet.json"]:
		DirAccess.remove_absolute(dir + n)
	DirAccess.remove_absolute(dir)
	_chains()


func _chains() -> void:
	var rect := TextureRect.new()
	var life: BackdropLife = BackdropLife.attach(rect, "fight")
	var parts: Array = BackdropLife.LIFE.fight.parts
	var ci: int = parts.find_custom(func(p): return p.kind == "chain")
	var s: AnimatedSprite2D = life.stage.get_child(ci)
	var xs: Array = []
	for f in s.sprite_frames.get_frame_count("default"):
		xs.append(int((s.sprite_frames.get_frame_texture("default", f) as AtlasTexture).region.position.x))
	var w: int = xs[1]
	check(xs == [0, w, 2 * w, 3 * w, 4 * w, 3 * w, 2 * w, w], "chains: frames play ping-pong, got %s" % [xs])
	check(is_equal_approx(s.sprite_frames.get_animation_speed("default"), 8.0 / parts[ci].period), "chains: one swing there and back per period")
	check(s.is_playing() and s.scale == Vector2.ONE, "chains: strips are in image px, unscaled")
	rect.free()
	# Every backdrop with chains draws them as strips (art/pxl/bg_fights.px.js, bg_screens.px.js).
	for want: Array in [["fight", 3], ["mine", 1], ["menu", 3]]:
		var art: String = want[0]
		var bg: Texture2D = load("res://assets/ui/bg_%s.webp" % art)
		check(bg != null and bg.get_size() == BackdropLife.IMAGE, "%s: backdrop is 1024x572" % art)
		var drawn: Array = BackdropLife.LIFE[art].parts.filter(func(p): return p.kind == "chain")
		check(drawn.size() >= want[1], "%s: has %d+ swaying chains" % want)
		for i in drawn.size():
			var part: Dictionary = drawn[i]
			check(part.art == "chain_%s_%d" % [art, i], "%s: chain %d is chain_%s_%d" % [art, i, art, i])
			check(BackdropLife.frames(part.art, 1.0).get_frame_count("default") == 5 and part.period >= 3.0 and part.period <= 4.0, "%s: %s is a 5-frame strip swinging in 3-4 s" % [art, part.art])
	check(CombatScreen.LEDGES.keys() == ["fight", "mine"], "mine: a floor ledge per fight backdrop")


## A run saved at a campfire comes back as it was; a broken or old save is no save at all.
func _run_save() -> void:
	const PATH := "user://test_run_save.json"  # never the player's real save
	var c := CombatScript.new(7)
	c.apply_perks(["steady_hand", "thick_skin"])
	c.add_perk("bonfire_keeper")
	c.player_hp = 23
	c.shards = 11
	c.kills = 5
	c.bonus_embers = 30
	c.dungeon_turns = 4
	c.forge(0, 2, true)
	c.curse_face(1, 5)
	c.dice[2].faces[3] = CombatScript.CURSE  # a fight's curse, not lasting
	check(RunSave.write({"combat": c.to_dict(), "layer": 3}, PATH), "the run saves")
	check(RunSave.write({"combat": c.to_dict(), "layer": 3}, PATH), "and saves again over the old file")
	var data := RunSave.read(PATH)
	check(data.get("layer") is int and data.get("layer") == 3, "ints come back as ints")
	var back := CombatScript.from_dict(data.combat)
	check(back.player_hp == 23 and back.max_hp == 50 and back.shards == 11 and back.kills == 5, "HP, max HP, Shards and kills come back")
	check(back.perks == ["steady_hand", "thick_skin", "bonfire_keeper"] and back.bonus_perk == "bonfire_keeper", "perks and the bonus perk come back")
	check(back.bonus_embers == 30 and back.dungeon_turns == 4, "promised Embers and the murmur count come back")
	check(back.dice[0].base == [1, 2, 5, 4, 5, 6], "a forged face comes back")
	check(back.dice[1].base[5] == CombatScript.CURSE and back.dice[1].uncursed == {5: 6}, "a lasting curse comes back, still liftable")
	back.forge(1, 5, true)
	check(back.dice[1].base[5] == 6, "and forging lifts it")
	check(back.dice[2].faces[3] == CombatScript.CURSE and back.dice[2].base[3] == 4, "a fight's curse comes back on the faces only")
	check(back.dice[0].slot == CombatScript.Slot.NONE and back.dice[0].buried == 0, "the dice keep their other fields")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(RunSave.read(PATH).is_empty() and not RunSave.exists(PATH), "a corrupt save loads as no save")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(JSON.from_native({"version": RunSave.VERSION + 1, "layer": 3})))
	f.close()
	check(RunSave.read(PATH).is_empty(), "a save from another version loads as no save")
	check(CombatScript.valid_dict(c.to_dict()), "a saved Combat is valid")
	var short := c.to_dict()
	short.dice.pop_back()
	check(not CombatScript.valid_dict(short) and not CombatScript.valid_dict({}), "a Combat missing dice or fields is not")
	RunSave.write({"layer": 3}, PATH)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".tmp"))
	check(RunSave.read(PATH).get("layer") == 3, "a save left only as its temp file is recovered")
	RunSave.erase(PATH)
	check(not FileAccess.file_exists(PATH) and not FileAccess.file_exists(PATH + ".tmp") and RunSave.read(PATH).is_empty(), "an erased save is gone")


func _relic_save() -> void:
	const PATH := "user://test_relic_save.json"
	var c := fresh()
	for id in ["black_candle", "gravedigger", "mirror_shard", "miners_ledger"]:
		c.take_relic(id)
	c.relics[1].n = 7.0
	c.relics[3].n = 8.0
	c.best_hit = 42
	c.best_mult = 2.5
	RunSave.write({"combat": c.to_dict()}, PATH)
	var d := RunSave.read(PATH)
	RunSave.erase(PATH)
	check(CombatScript.valid_dict(d.combat), "a saved belt passes valid_dict after a real file round trip")
	var back := CombatScript.from_dict(d.combat)
	check(back.relics.map(func(r): return r.id) == ["black_candle", "gravedigger", "mirror_shard", "miners_ledger"], "the belt keeps its order")
	check(back.relics[1].n == 7.0 and typeof(back.relics[1].n) == TYPE_FLOAT and back.relics[3].n == 8.0, "relic counters come back as floats")
	check(back.best_hit == 42 and typeof(back.best_hit) == TYPE_INT and is_equal_approx(back.best_mult, 2.5), "best hit and best Mult come back")
	var old := c.to_dict()
	for k in ["relics", "best_hit", "best_mult"]:
		old.erase(k)
	check(CombatScript.valid_dict(old) and CombatScript.from_dict(old).relics.is_empty(), "a save from before relics loads with an empty belt")
	var bad := c.to_dict()
	bad.relics = "x"
	check(not CombatScript.valid_dict(bad), "a belt of the wrong type is refused")
	# a Mirror's counters don't follow it onto another relic
	c = fresh()
	for id in ["mirror_shard", "miners_ledger", "gravedigger"]:
		c.take_relic(id)
	c.relics[0].n = 40.0
	c.relics[0].f = 2.0
	c.move_relic(2, 1)  # Mirror now copies the Tally
	check(c.relic_id(0) == "gravedigger" and c.relics[0].n == 0.0 and c.relics[0].f == 0.0, "a Mirror's counters reset when it copies something else")
	c.relics[0].n = 40.0
	c.move_relic(2, 1)  # back: copies the Ledger again, reset again
	check(c.relics[0].n == 0.0, "and again when it swaps back")
	c.relics[0].n = 40.0
	c.move_relic(2, 2)  # nothing moves
	check(c.relics[0].n == 40.0, "a move that keeps the copied relic keeps the counter")
	c.take_relic("whetstone")
	c.take_relic("twin_saints")
	c.take_relic("tithe_box")  # full belt now refuses; replace the copied relic
	c.relics[0].n = 40.0
	c.take_relic("rosary", 1)
	check(c.relics[0].n == 0.0, "breaking the relic a Mirror copies resets the Mirror")


func _relic_belt() -> void:
	var c := fresh()
	check(c.take_relic("black_candle"), "a relic goes on the belt")
	check(not c.take_relic("black_candle"), "the same relic can't go on twice")
	for id in ["whetstone", "twin_saints", "tithe_box", "ward_icon"]:
		c.take_relic(id)
	check(c.relics.size() == CombatScript.BELT_SIZE, "the belt holds five")
	check(not c.take_relic("rosary"), "a full belt refuses a new relic without a slot to break")
	var shards := c.shards
	check(c.take_relic("rosary", 2) and c.relic_id(2) == "rosary" and c.shards == shards + CombatScript.BREAK_SHARDS,
		"breaking slot 2 puts the Rosary there and pays 2 Shards")
	check(c.relics.size() == CombatScript.BELT_SIZE, "breaking keeps the belt at five")
	c.move_relic(2, 0)
	check(c.relic_id(0) == "rosary" and c.relic_id(1) == "black_candle", "a relic can move along the belt")
	for id in CombatScript.RELICS:
		var r: Dictionary = CombatScript.RELICS[id]
		check(r.name != "" and r.text != "" and r.has("rare"), "relic %s has a name, text and rarity" % id)
	c.relics.clear()
	c.take_relic("mirror_shard")
	check(c.relic_id(0) == "", "a Mirror at the end of the belt copies nothing")
	c.relics = [{"id": "mirror_shard", "n": 0.0, "f": 0.0}, {"id": "mirror_shard", "n": 0.0, "f": 0.0}]
	check(c.relic_id(0) == "" and is_equal_approx(c.mult(), 1.0), "a Mirror before a Mirror copies nothing")
	c.relics.clear()
	c.take_relic("mirror_shard")
	c.take_relic("black_candle")
	check(c.relic_id(0) == "black_candle" and is_equal_approx(c.mult(), 2.25), "a Mirror before Black Candle: x1.5 twice")
	c.relics[0].f = 3.0
	c.start_group(["rat"])
	check(c.relics[0].f == 0.0, "a new fight zeroes each relic's fight counter")


func _mult() -> void:
	var c := fresh()
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	c.take_relic("twin_saints")
	place(c, 0, 3, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	check(is_equal_approx(c.mult(), 2.0) and c.firing() == [0], "Twin Saints with a Cleave pair: x2")
	c.dice[1].slot = CombatScript.Slot.NONE
	check(is_equal_approx(c.mult(), 1.0) and c.firing().is_empty(), "no pattern, no Twin Saints")

	c = fresh()
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	c.take_relic("black_candle")
	place(c, 0, 5, CombatScript.Slot.ATTACK)
	place(c, 1, 4, CombatScript.Slot.ATTACK)
	check(c.hits_to(0) == [9] and c.damage_to(0) == 13, "Black Candle: Attack 9 deals floor(13.5) = 13")
	check(c.firing() == [0], "Black Candle flags its slot as firing")

	c = fresh(RATS)
	c.start_group(["rat", "rat", "rat"], 5.0)  # 30 HP rats, so nobody dies and every hit lands in full
	for d in c.dice:
		d.slot = CombatScript.Slot.NONE
	c.take_relic("black_candle")
	c.enemies[2].hp = 0  # two rats left, so Cleave 15 splits unevenly: 8 to the target, 7 to the other
	place(c, 0, 5, CombatScript.Slot.SKILL)
	place(c, 1, 5, CombatScript.Slot.SKILL)
	var each: Array[int] = []
	for i in 3:
		each.append(c.damage_to(i))
	var preview := c.preview_damage()
	check(each == [12, 10, 0], "Cleave 8 and 7, times 1.5, floor to 12 and 10")
	check(c.resolve_player() == preview, "resolve deals exactly the preview")
	check(range(3).all(func(i): return c.enemies[i].hp == (30 - each[i] if i < 2 else 0)), "each rat lost what damage_to said")
	check(c.best_hit == 12 and is_equal_approx(c.best_mult, 1.5), "best hit and best Mult are recorded")

	c = fresh()
	c.take_relic("pit_lantern")
	check(is_equal_approx(c.mult(), 1.0), "Pit Lantern with no die placed: x1")
	place(c, 0, 4, CombatScript.Slot.ATTACK)
	place(c, 1, 2, CombatScript.Slot.ATTACK)
	check(is_equal_approx(c.mult(), 2.0), "Pit Lantern, every placed die in Attack: x2")
	place(c, 2, 3, CombatScript.Slot.GUARD)
	check(is_equal_approx(c.mult(), 1.0), "Pit Lantern with a die in Guard: x1")

	c = fresh()
	c.take_relic("clenched_jaw")
	c.take_relic("rusted_censer")
	c.take_relic("gilded_pip")
	place(c, 0, 8, CombatScript.Slot.ATTACK)
	check(is_equal_approx(c.mult(), 1.0 + 0.2 + 0.5), "two unplaced dice give Clenched Jaw +0.2; an 8 gives Gilded Pip +0.5")
	c.dice[0].faces[c.dice[0].side] = 8  # mark_of reads the rolled face
	c.dice[0].marks[c.dice[0].side] = "ember"
	check(is_equal_approx(c.mult(), 1.0 + 0.2 + 0.5 + 0.5), "a placed Ember face gives Rusted Censer +0.5")


## A fight against three 150 HP rats, all dice unplaced, so many turns of hits leave them standing.
func _rats() -> CombatScript:
	var c := fresh(RATS)
	c.start_group(["rat", "rat", "rat"], 50.0)
	for d in c.dice:
		d.slot = CombatScript.Slot.NONE
	for e in c.enemies:
		e.intent = {"kind": "attack", "value": 1}
	return c


func _relic_effects() -> void:
	var c := fresh()
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	c.take_relic("whetstone")
	place(c, 0, 5, CombatScript.Slot.ATTACK)
	place(c, 1, 2, CombatScript.Slot.ATTACK)
	check(c.hits_to(0) == [10], "Whetstone: a 5 deals +3")
	check(c.firing() == [0], "Whetstone fires with a 5 in Attack")
	c.dice[0].slot = CombatScript.Slot.GUARD
	check(c.firing().is_empty(), "Whetstone doesn't fire with no 5 or 6 in Attack")
	c.dice[0].slot = CombatScript.Slot.ATTACK
	c.enemies[0].intent = {"kind": "guard", "value": 4}
	check(c.hits_to(0) == [6], "Whetstone adds before enemy Guard")

	c = fresh()
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	c.take_relic("cursed_crown")
	place(c, 0, CombatScript.CURSE, CombatScript.Slot.ATTACK)
	place(c, 1, 3, CombatScript.Slot.ATTACK)
	check(c.hits_to(0) == [9], "Cursed Crown: a curse in Attack counts as 6")
	c = fresh(WARDEN)
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	c.take_relic("cursed_crown")
	place(c, 0, CombatScript.CURSE, CombatScript.Slot.ATTACK)
	place(c, 1, 5, CombatScript.Slot.ATTACK)
	check(c.hits_to(0) == [5], "Bone Wall drops the crowned curse as the highest die")

	c = fresh()
	c.enemies[0].intent = {"kind": "guard", "value": 9}
	c.take_relic("miners_ledger")
	c.shards = 8
	c.pay_forge()
	c.pay_forge()
	check(c.shards == 0 and c.relics[0].n == 8.0, "paying for forges feeds the Ledger")
	place(c, 0, 3, CombatScript.Slot.ATTACK)
	check(c.hits_to(0) == [2], "Ledger at 8: +2 after Guard soaks the 3")
	c.refund_forge()
	check(c.shards == 4 and c.relics[0].n == 4.0, "a refund takes it back")
	c.relics[0].n = 7.0
	check(c.hits_to(0) == [1], "Ledger at 7: +1")
	c.dice[0].slot = CombatScript.Slot.NONE
	check(c.hits_to(0).is_empty(), "no die in Attack, no Ledger hit")
	c.shards = 4
	c.forge(0, 0)
	check(c.relics[0].n == 11.0, "a paid forge() feeds the Ledger too")

	c = fresh()
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	c.take_relic("ward_icon")
	c.guard_pool = 5
	c.end_enemy_phase()
	check(c.relics[0].f == 5.0, "Ward Icon keeps the Guard left")
	place(c, 0, 3, CombatScript.Slot.ATTACK)
	place(c, 1, 2, CombatScript.Slot.SKILL)
	place(c, 2, 2, CombatScript.Slot.SKILL)
	check(c.hits_to(0) == [8, 3], "Ward Icon adds to the Attack hit, not the Cleave")
	check(c.skill_share(0) == 3, "skill_share leaves the Attack hit out")
	c.resolve_player()
	check(c.relics[0].f == 0.0, "Ward Icon is spent on the Attack")
	c.relics[0].f = 4.0
	c.start_group(["rat"])
	check(c.relics[0].f == 0.0, "Ward Icon's Guard is gone at fight start")

	c = fresh()
	c.take_relic("gravedigger")
	for e in c.enemies:
		e.hp = 0
	c.claim_fight()
	check(c.relics[0].n == 2.0 and is_equal_approx(c.mult(), 1.2), "Gravedigger: two kills, +0.2")

	c = _rats()
	c.take_relic("spare_fuse")
	place(c, 0, 3, CombatScript.Slot.ATTACK)
	c.rerolls = 2
	check(is_equal_approx(c.mult(), 1.0), "Spare Fuse gives nothing the turn it's earned")
	c.resolve_player()
	check(is_equal_approx(c.mult(), 1.5), "Spare Fuse: two unused rerolls, +0.5 after")

	c = _rats()
	c.take_relic("hungry_bell")
	check(is_equal_approx(c.mult(), 1.0), "Hungry Bell without a skill: +0")
	place(c, 0, 3, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	var bell: Array = []
	for t in 3:
		bell.append(c.mult())
		c.resolve_player()
	check(bell == [2.0, 3.0, 4.0], "Hungry Bell: +1, +2, +3 over three skill turns")
	c.dice[1].slot = CombatScript.Slot.NONE
	c.resolve_player()
	c.dice[1].slot = CombatScript.Slot.SKILL
	check(is_equal_approx(c.mult(), 2.0), "Hungry Bell is back to +1 after a turn without a skill")
	c.resolve_player()
	c.start_group(["rat"], 50.0)
	place(c, 0, 3, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	check(is_equal_approx(c.mult(), 2.0), "Hungry Bell is back to +1 in a new fight")

	c = fresh()
	c.skills = ["flurry"]
	c.take_relic("rosary")
	place(c, 0, 2, CombatScript.Slot.SKILL)
	place(c, 1, 3, CombatScript.Slot.SKILL)
	place(c, 2, 4, CombatScript.Slot.SKILL)
	check(c.hits_to(c.target) == [18], "Rosary: Flurry 2-3-4 deals 9 + 9")

	c = fresh()
	c.take_relic("tithe_box")
	c.shards = 10
	c.claim_fight()
	check(c.shards == 12, "Tithe Box: 10 held, +2")
	c.shards = 30
	c.claim_fight()
	check(c.shards == 33, "Tithe Box pays at most +3")
	c.shards = 10
	c.claim_fight(false)
	check(c.shards == 10, "Tithe Box pays nothing for a lost fight")
	c.relics.clear()
	c.take_relic("mirror_shard")
	c.take_relic("tithe_box")
	c.shards = 10
	c.claim_fight()
	check(c.shards == 14, "Mirror + Tithe Box pays twice: 10 +2, then 12 +2")

	c = fresh()
	c.take_relic("whetstone")
	c.shards = 0
	check(c.take_relic("rosary", 0) and c.relics.size() == 2 and c.relic_id(0) == "whetstone" and c.shards == 0,
		"a belt with room appends and breaks nothing")


## A pick offers up to three different relics, none on the belt; a rare pick only rares.
func _relic_offer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rares: Array = Combat.RELICS.keys().filter(func(id): return Combat.RELICS[id].rare)
	var belt: Array = rares.slice(0, 4).map(func(id): return {"id": id, "n": 0.0, "f": 0.0})
	var got: Array = RelicPickScreen.offer(belt, true, rng)
	got.sort()
	var want: Array = rares.slice(4)
	want.sort()
	check(got == want, "a rare pick with 4 rares on the belt offers the other 3 (got %s)" % [got])
	belt = [{"id": "whetstone"}, {"id": "black_candle"}, {"id": "tithe_box"}, {"id": "mirror_shard"}, {"id": "ward_icon"}]
	var ok := true
	var saw_rare := false
	for i in 200:
		var o: Array = RelicPickScreen.offer(belt, false, rng)
		ok = ok and o.size() == 3 and o.all(func(id): return id not in ["whetstone", "black_candle", "tithe_box", "mirror_shard", "ward_icon"])
		ok = ok and o[0] != o[1] and o[1] != o[2] and o[0] != o[2]
		saw_rare = saw_rare or o.any(func(id): return Combat.RELICS[id].rare)
	check(ok, "200 picks each offer 3 different relics, none on the belt")
	check(saw_rare, "a common pick sometimes offers a rare")
