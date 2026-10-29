class_name Floor
extends RefCounted
## Deals one floor (see FLOORS): a left-to-right map of columns, each a list of rooms sorted by lane.
## Room: {kind: fight|unknown|forge|campfire, lane, next: indices into the next column, label, enemies (fights)}.

## Each floor's name, boss-lair label, enemies a run can deal into its fights, total enemy HP of a fight by depth
## (entrance, columns 1-4, columns 5-7), boss (a Combat.TYPES key list) and fight backdrop.
const FLOORS := {
	"chapel": {"title": "The Sunken Chapel", "lair": "The Warden's Lair",
		"enemies": ["rat", "skeleton", "acolyte", "doctor", "bell", "treant", "moss", "grieve", "archivist"],
		"hp": [[18, 26], [18, 38], [42, 56]], "boss": ["warden"], "backdrop": "fight"},
	"mine": {"title": "The Hollow Mine", "lair": "The Pit King's Throne",
		"enemies": ["miner", "crawler", "hulk", "canary", "shaft_foreman"],
		"hp": [[24, 36], [34, 50], [56, 72]], "boss": ["pit_king"], "backdrop": "mine"},
}
const COLUMNS := 10
const LANES := 5
const EARLY_COLUMNS := 4  # columns 1-4 get early-HP fights, 5-7 late-HP
const LATE_SCALE := 1.5  # late-column enemies get this much HP
const MID := 2  # the entrance and boss lane


## A fresh floor: entrance, eight columns of branching rooms (the last all campfires), then the boss.
static func deal(floor_id := "chapel") -> Array:
	var data: Dictionary = FLOORS[floor_id]
	var rooms: Array = []  # per column: lane -> room
	var links: Array = []  # per gap: [from_lane, to_lane] pairs
	while true:
		rooms.clear()
		links.clear()
		_walk(rooms, links)
		if range(1, COLUMNS - 1).all(func(c): return rooms[c].size() >= 2):  # walkers can merge into one lane
			break
	_roll_kinds(rooms, links)
	var used := {}
	for c in COLUMNS - 1:
		for lane in rooms[c]:
			var room: Dictionary = rooms[c][lane]
			if room.kind == "fight":
				var hp: Array = data.hp[0] if c == 0 else (data.hp[1] if c <= EARLY_COLUMNS else data.hp[2])
				room.merge(fight_room(group(hp, used, data.enemies)), true)
				room["scale"] = LATE_SCALE if c > EARLY_COLUMNS else 1.0
	rooms[COLUMNS - 1][MID].merge(fight_room(data.boss), true)
	rooms[COLUMNS - 1][MID]["scale"] = 1.0
	var floor_map: Array = []
	for c in COLUMNS:
		var lanes: Array = rooms[c].keys()
		lanes.sort()
		var col: Array = []
		for lane in lanes:
			var room: Dictionary = rooms[c][lane]
			room["next"] = []
			if c < COLUMNS - 1:
				var to: Array = rooms[c + 1].keys()
				to.sort()
				for l in links[c]:
					if l[0] == lane:
						room["next"].append(to.find(l[1]))
				room["next"].sort()
			col.append(room)
		floor_map.append(col)
	return floor_map


## Five walkers leave the entrance, first to lanes 0, 1, 3, 4 and a random one, then step a lane up, down or straight each
## column without crossing another link; every column-8 room links to the boss.
static func _walk(rooms: Array, links: Array) -> void:
	rooms.append({MID: {"lane": MID}})
	var walkers: Array = [0, 1, 3, 4, randi_range(0, LANES - 1)]
	var first := {}
	for l in walkers:
		first[l] = {"lane": l}
	links.append(first.keys().map(func(t): return [MID, t]))
	rooms.append(first)
	for c in range(2, COLUMNS - 1):
		var gap: Array = []
		var col := {}
		walkers.sort()
		for i in walkers.size():
			var l: int = walkers[i]
			var options: Array = []
			for t in [l - 1, l, l + 1]:
				if t >= 0 and t < LANES and not gap.any(func(e): return (e[0] < l and e[1] > t) or (e[0] > l and e[1] < t)):
					options.append(t)
			var t: int = options.pick_random()
			if [l, t] not in gap:
				gap.append([l, t])
			walkers[i] = t
			col[t] = {"lane": t}
		links.append(gap)
		rooms.append(col)
	links.append(rooms[COLUMNS - 2].keys().map(func(l): return [l, MID]))
	rooms.append({MID: {"lane": MID}})


## Kinds column by column once the links exist, so a forge or campfire can look at its parents.
static func _roll_kinds(rooms: Array, links: Array) -> void:
	for c in COLUMNS:
		for lane in rooms[c]:
			var kind := "fight"
			if c == COLUMNS - 2:
				kind = "campfire"
			elif c in [1, 2]:
				kind = "fight" if randf() < 55.0 / 75.0 else "unknown"
			elif c > 2 and c < COLUMNS - 2:
				var parents: Array = links[c - 1].filter(func(e): return e[1] == lane).map(func(e): return rooms[c - 1][e[0]].kind)
				while true:
					var roll := randf()
					kind = "fight" if roll < 0.55 else ("unknown" if roll < 0.75 else ("campfire" if roll < 0.88 else "forge"))
					# a campfire in column 7 would link to column 8's campfires
					if kind in ["forge", "campfire"] and (kind in parents or (kind == "campfire" and c == COLUMNS - 3)):
						continue
					break
			var room: Dictionary = rooms[c][lane]
			room["kind"] = kind
			room["label"] = {"unknown": "?", "forge": "Forge", "campfire": "Campfire"}.get(kind, "")


## One to three random `enemies` whose total HP is within `hp`, a group not yet in `used`.
## Picks from every group that fits, so a repeat only happens once all of them are used.
static func group(hp: Array, used: Dictionary, enemies: Array = FLOORS.chapel.enemies) -> Array:
	var fits: Array = []
	var pool: Array = enemies.duplicate()
	pool.sort()
	for a in pool.size():  # every multiset of 1-3 enemies; index pool.size() means "no enemy here"
		for b in range(a, pool.size() + 1):
			for c in range(b, pool.size() + 1):
				var keys: Array = [pool[a]]
				if b < pool.size():
					keys.append(pool[b])
					if c < pool.size():
						keys.append(pool[c])
				var total: int = keys.reduce(func(t, k): return t + Combat.TYPES[k].hp, 0)
				if total >= hp[0] and total <= hp[1] and not fits.has(keys):
					fits.append(keys)
	if fits.is_empty():
		push_error("No group of %s fits %s HP" % [enemies, hp])
		return [enemies[0]]
	var fresh := fits.filter(func(k): return not used.has(",".join(k)))
	var keys: Array = (fresh if fresh else fits).pick_random()
	used[",".join(keys)] = true
	return keys


## "Fight: Archivist, Bone Rats" from the fight's enemies.
static func fight_room(keys: Array) -> Dictionary:
	var names := []
	for key in keys:
		var name: String = Combat.TYPES[key].name + ("s" if keys.count(key) > 1 else "")
		if name not in names:
			names.append(name)
	var boss: bool = Combat.TYPES[keys[0]].get("boss", false)
	return {"kind": "fight", "enemies": keys, "label": ("Boss: " if boss else "Fight: ") + ", ".join(names)}
