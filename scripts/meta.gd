class_name Meta
extends RefCounted
## What survives between runs and launches: Embers, perks, whether the tutorial is done.

const SAVE_PATH := "user://meta.json"
const SLOTS := 2

const PERKS := {
	"steady_hand": {"name": "Steady Hand", "cost": 50, "text": "+1 reroll every turn"},
	"thick_skin": {"name": "Thick Skin", "cost": 100, "text": "+10 max HP"},
	"gamblers_heart": {"name": "Gambler's Heart", "cost": 150, "text": "A pair of 1s in Cleave counts as 12"},
}

var embers := 0
var owned: Array = []
var equipped: Array = []
var tutorial_done := false
var save_path := SAVE_PATH


## Embers paid out at the end of a run, won or lost.
static func embers_for(kills: int, rooms_cleared: int, boss_pct: int, won: bool) -> int:
	return kills * 5 + rooms_cleared * 10 + boss_pct / 2 + (50 if won else 0)


func unlock(id: String) -> bool:
	if id in owned or embers < PERKS[id].cost:
		return false
	embers -= PERKS[id].cost
	owned.append(id)
	return true


## Equips an owned perk if a slot is free, or unequips it if it's on.
func toggle_equip(id: String) -> bool:
	if id in equipped:
		equipped.erase(id)
		return true
	if id in owned and equipped.size() < SLOTS:
		equipped.append(id)
		return true
	return false


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Could not save progress to %s" % save_path)
		return
	f.store_string(JSON.stringify({"embers": embers, "owned": owned, "equipped": equipped, "tutorial_done": tutorial_done}))


## A missing or unreadable save starts fresh rather than crashing.
static func load_from(path := SAVE_PATH) -> Meta:
	var m := Meta.new()
	m.save_path = path
	if not FileAccess.file_exists(path):
		return m
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		m.embers = int(data.get("embers", 0))
		m.owned = data.get("owned", []).filter(func(id): return PERKS.has(id))
		m.equipped = data.get("equipped", []).filter(func(id): return id in m.owned)
		m.tutorial_done = bool(data.get("tutorial_done", false))
	return m
