class_name Meta
extends RefCounted
## What survives between runs and launches: Embers, perks, skills (Combat.SKILLS), whether the tutorial is done and the Mine unlocked, sound settings.

signal sound_changed  # so on-screen sound controls follow the M key

const SAVE_PATH := "user://meta.json"
const SLOTS := 2

const PERKS := {
	"steady_hand": {"name": "Steady Hand", "cost": 50, "text": "+1 reroll every turn"},
	"thick_skin": {"name": "Thick Skin", "cost": 100, "text": "+10 max HP"},
	"gamblers_heart": {"name": "Gambler's Heart", "cost": 150, "text": "A pair of 1s in Cleave counts as 12"},
	"scavenger": {"name": "Scavenger", "cost": 75, "text": "+1 Shard for every kill"},
	"bonfire_keeper": {"name": "Bonfire Keeper", "cost": 100, "text": "Campfires heal 45% instead of 30%"},
	"lucky_charm": {"name": "Lucky Charm", "cost": 125, "text": "Events never take you below 5 HP"},
	"iron_nerve": {"name": "Iron Nerve", "cost": 150, "text": "Perfect block and parry windows +40 ms"},
	"grit_teeth": {"name": "Grit Teeth", "cost": 150, "text": "Each die left unplaced gives +2 Grit"},
	"hex_ward": {"name": "Hex Ward", "cost": 200, "text": "The first curse each fight fails"},
	"lantern_bearer": {"name": "Lantern Bearer", "cost": 200, "text": "\"?\" rooms are ambushes 10% of the time, not 20%"},
}

var embers := 0
var owned: Array = []
var equipped: Array = []
var skills: Array = ["cleave"]  # unlocked Combat.SKILLS ids; Cleave is free
var tutorial_done := false
var mine_unlocked := false  # beating the Warden opens the Hollow Mine as a starting floor
var music := 1.0  # Music bus loudness, 0 to 1
var sounds := 1.0  # SFX bus loudness, 0 to 1
var muted := false
var quick_dice := true  # dice control: true, clicks cycle the slot and a hold locks; false, a click opens the die menu
var save_path := SAVE_PATH


## Pushes the sound settings to the audio buses (game.gd makes "Music" and "SFX").
func apply_sound() -> void:
	for bus in [["Music", music], ["SFX", sounds]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(bus[1]))
	AudioServer.set_bus_mute(0, muted)
	sound_changed.emit()


## Embers paid out at the end of a run, won (the Pit King beaten) or lost.
static func embers_for(kills: int, rooms_cleared: int, boss_pct: int, won: bool) -> int:
	return kills * 5 + rooms_cleared * 10 + boss_pct / 2 + (100 if won else 0)


func unlock(id: String) -> bool:
	if id in owned or embers < PERKS[id].cost:
		return false
	embers -= PERKS[id].cost
	owned.append(id)
	return true


## Unlocks skill `id` for good, for its Embers.
func unlock_skill(id: String) -> bool:
	if id in skills or embers < Combat.SKILLS[id].cost:
		return false
	embers -= Combat.SKILLS[id].cost
	skills.append(id)
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
	f.store_string(JSON.stringify({"embers": embers, "owned": owned, "equipped": equipped, "skills": skills, "tutorial_done": tutorial_done,
		"mine_unlocked": mine_unlocked, "music": music, "sounds": sounds, "muted": muted,
		"quick_dice": quick_dice}))


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
		m.skills = ["cleave"] + data.get("skills", []).filter(func(id): return Combat.SKILLS.has(id) and id != "cleave")
		m.tutorial_done = bool(data.get("tutorial_done", false))
		m.mine_unlocked = bool(data.get("mine_unlocked", false))
		m.music = clampf(float(data.get("music", 1.0)), 0.0, 1.0)
		m.sounds = clampf(float(data.get("sounds", 1.0)), 0.0, 1.0)
		m.muted = bool(data.get("muted", false))
		m.quick_dice = bool(data.get("quick_dice", true))
	return m
