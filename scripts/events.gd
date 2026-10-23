class_name Events
extends RefCounted
## Rules for the "?" rooms: what each event offers and what each choice does to the run. No UI.
## events_screen.gd shows EVENTS and calls resolve(); the screen rolls dice and picks faces to forge or carve.

const IDS := ["shrine", "pilgrim", "altar", "niche", "bone_pile", "corridor", "chest", "gambler", "cursed_cast"]
const AMBUSH_CHANCE := 0.2  # chance a "?" room is an ambush instead
const AMBUSH_SHARDS := 4  # what an ambush pays out
const GAMBLER_BET := 4

## `dice` per choice: 0 = no roll, 1 = the player throws one die, 3 = all dice. The last choice is the way out, except in the corridor.
const EVENTS := {
	"shrine": {
		"title": "Cracked Shrine",
		"text": "A cracked shrine, split down the middle. Something still listens.",
		"choices": [
			{"label": "Bleed for it (-6 HP, forge a face)", "dice": 0},
			{"label": "Walk on", "dice": 0},
		],
	},
	"pilgrim": {
		"title": "Drowned Pilgrim",
		"text": "A pilgrim, drowned in a puddle that is barely a puddle. Their pockets are not empty.",
		"choices": [
			{"label": "Take their coin (+6 Shards)", "dice": 0},
			{"label": "Close their eyes (+5 HP)", "dice": 0},
		],
	},
	"altar": {
		"title": "Weeping Altar",
		"text": "An altar that weeps without eyes. It wants something you can't grow back.",
		"choices": [
			{"label": "Give (-5 max HP, forge two faces)", "dice": 0},
			{"label": "Refuse", "dice": 0},
		],
	},
	"niche": {
		"title": "Ember-lit Niche",
		"text": "A niche in the wall, full of warm embers. Nobody is guarding them.",
		"choices": [
			{"label": "Take the embers", "dice": 0},
		],
	},
	"bone_pile": {
		"title": "Bone Pile",
		"text": "A heap of bones. Something glints inside. Something else might be inside too.",
		"choices": [
			{"label": "Dig (throw a die)", "dice": 1},
			{"label": "Leave it", "dice": 0},
		],
	},
	"corridor": {
		"title": "Collapsing Corridor",
		"text": "The ceiling is coming down in pieces. Run, and hope your dice are quick.",
		"choices": [
			{"label": "Run for it (throw all dice)", "dice": 3},
			{"label": "Turn back (-4 HP)", "dice": 0},
		],
	},
	"chest": {
		"title": "Rusted Chest",
		"text": "A rusted chest. The lock is old and so is your patience.",
		"choices": [
			{"label": "Pick the lock (throw a die)", "dice": 1},
			{"label": "Leave it", "dice": 0},
		],
	},
	"gambler": {
		"title": "Gambler's Skull",
		"text": "A skull on a barrel, with three dice of its own. It wants 4 Shards to play.",
		"choices": [
			{"label": "Bet 4 Shards (throw all dice)", "dice": 3},
			{"label": "Decline", "dice": 0},
		],
	},
	"cursed_cast": {
		"title": "Cursed Die Cast",
		"text": "A mold for casting a die face. It will take payment from another.",
		"choices": [
			{"label": "Carve a 9 (curse another face)", "dice": 0},
			{"label": "Leave it", "dice": 0},
		],
	},
}


## A random room not in `seen`, or "" when all are seen (the game ambushes instead).
static func pick(seen: Array) -> String:
	var left: Array = IDS.filter(func(id): return not seen.has(id))
	return "" if left.is_empty() else left.pick_random()


static func can_choose(id: String, choice: int, c: Combat) -> bool:
	return not (id == "gambler" and choice == 0 and c.shards < GAMBLER_BET)


## Applies a choice to the run. `rolled` is what the screen threw (the gambler's skull dice are rolled[3..5]).
## Returns {"text", "forge": free upgrades to grant, "carve": pick a face to carve, "retry": show the choices again}.
static func resolve(id: String, choice: int, c: Combat, rolled: Array, tries := 1) -> Dictionary:
	var r := {"text": "You walk on."}
	match [id, choice]:
		["shrine", 0]:
			r = {"text": "The shrine takes its due. -%d HP. A face is forged." % c.hurt(6), "forge": 1}
		["pilgrim", 0]:
			c.shards += 6
			r.text = "They have no further use for it. +6 Shards."
		["pilgrim", 1]:
			c.heal(5)
			r.text = "A small kindness. It steadies you. +5 HP."
		["altar", 0]:
			c.lose_max_hp(5)
			r = {"text": "The altar takes it. -5 max HP. Two faces are forged.", "forge": 2}
		["niche", 0]:
			c.bonus_embers += 10
			r.text = "The embers are warm. +10 Embers at the end of the run."
		["bone_pile", 0]:
			if rolled[0] <= 2:
				r.text = "Something bites. -%d HP." % c.hurt(4)
			else:
				c.shards += rolled[0]
				r.text = "Shards, under the bones. +%d Shards." % rolled[0]
		["corridor", 0]:
			var total := 0
			for v in rolled:
				total += v
			if total >= 10:
				r.text = "You clear it with a breath to spare. Total %d." % total
			else:
				r.text = "Stone catches you. Total %d. -%d HP." % [total, c.hurt(10 - total)]
		["corridor", 1]:
			r.text = "The way back is no kinder. -%d HP." % c.hurt(4)
		["chest", 0]:
			if rolled[0] >= 5:
				r = {"text": "The lock gives. Inside, a whetstone. A face is forged.", "forge": 1}
			elif rolled[0] <= 1:
				r.text = "The lock bites back. -%d HP. The chest stays shut." % c.hurt(5)
			elif tries < 2:
				r = {"text": "The lock holds. One more try.", "retry": true}
			else:
				r.text = "The lock holds. You give up."
		["gambler", 0]:
			c.shards -= GAMBLER_BET
			var mine := 0
			var skull := 0
			for i in 3:
				mine += rolled[i]
				skull += rolled[i + 3]
			var won := 0
			if mine > skull:
				won = 8
			elif mine == skull:
				won = GAMBLER_BET
			c.shards += won
			r.text = "You %d, the skull %d. %s" % [mine, skull, "It pays out. +%d Shards." % won if won else "It keeps your Shards. -4 Shards."]
		["cursed_cast", 0]:
			r = {"text": "Pick a face to carve.", "carve": true}
	return r
