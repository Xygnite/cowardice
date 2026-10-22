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
	DirAccess.remove_absolute(path)
	check(Meta.load_from(path).embers == 0, "a missing save starts fresh")
