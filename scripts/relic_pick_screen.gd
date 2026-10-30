class_name RelicPickScreen
extends Control
## The Spoils shop: buy any of up to three relics for Shards onto the belt, destroy belt relics for Shards back, and
## reorder the belt. Every buy, destroy and leave asks first; only Leave emits done.

signal done

const RARE_CHANCE := 1.0 / 6.0
const REROLL_COST := 2  # the first reroll of a visit; each one after costs 1 more

var combat: Combat
var choices: Array = []  # up to three Combat.RELICS ids, from offer()
var rarity := "common"  # what offer() dealt: "any", "common" or "rare"
var title := "Spoils"
var subtitle: Label
var buys: Array = []  # a Buy button per choice, in order
var bought: Array = []  # choices bought here
var cards: HBoxContainer
var reroll_button: Button
var rerolls := 0  # this visit
var belt_row: BeltRow


## Up to three different relics not on `belt`. `rarity` "common" or "rare" deals only that pool; "any" makes each card
## rare with RARE_CHANCE, from the other pool when one runs dry.
static func offer(belt: Array, rarity: String, rng: RandomNumberGenerator) -> Array:
	var owned: Array = belt.map(func(r): return r.id)
	var pools := [[], []]  # commons, rares
	for id: String in Combat.RELICS:
		if id not in owned:
			pools[int(Combat.RELICS[id].rare)].append(id)
	var out := []
	for i in 3:
		var k := 1 if rarity == "rare" or (rarity == "any" and rng.randf() < RARE_CHANCE) else 0
		if pools[k].is_empty() and rarity == "any":
			k = 1 - k
		if pools[k].is_empty():
			break
		out.append(pools[k].pop_at(rng.randi_range(0, pools[k].size() - 1)))
	return out


func _ready() -> void:
	var root := UI.page(self)
	UI.backdrop(self, "campfire")
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.heading(root, 48, title).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = UI.label(root, 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards = UI.row(root, 24)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_deal_cards()
	reroll_button = UI.button(root, "", _reroll)
	reroll_button.custom_minimum_size = Vector2(240, 44)
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.label(root, 20, "Your belt").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	belt_row = BeltRow.new()
	belt_row.add_theme_constant_override("separation", 12)
	belt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	belt_row.combat = combat
	belt_row.show_destroy = true
	belt_row.moved.connect(_refresh)
	belt_row.destroy_pressed.connect(_ask_destroy)
	root.add_child(belt_row)
	var leave := UI.button(root, "Leave", func(): ConfirmPanel.ask(self, "Leave the shop?", "Nothing is paid for leaving.", "Leave", done.emit))
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_refresh()


## What a reroll costs after `n` of them this visit.
static func reroll_cost(n: int) -> int:
	return REROLL_COST + n


## Builds a card per choice into `cards`, replacing any there.
func _deal_cards() -> void:
	for c in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
	buys.clear()
	for id: String in choices:
		var r: Dictionary = Combat.RELICS[id]
		var col := UI.panel(cards)
		col.custom_minimum_size = Vector2(260, 0)
		var head := UI.row(col, 10)
		head.add_child(RelicIcon.of(id))
		UI.label(head, 22, r.name).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UI.label(col, 16, "Rare" if r.rare else "Common").add_theme_color_override("font_color", UI.GOLD if r.rare else UI.QUIET)
		var text := UI.label(col, 16, r.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.y = text.get_line_height() * 3 + text.get_theme_constant("line_spacing") * 2
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL  # so every card's Buy sits on the same line, at the bottom
		text.add_theme_color_override("font_color", UI.QUIET)
		var buy := UI.button(col, "", _ask_buy.bind(id))
		buy.custom_minimum_size.y = 48
		buys.append(buy)


## Redraws the Shards line, the belt and which cards can still be bought.
func _refresh() -> void:
	subtitle.text = "Shards %d. Buy what you can afford and fit on the belt." % combat.shards
	belt_row.rebuild()
	for i in choices.size():
		var id: String = choices[i]
		buys[i].text = "Sold" if id in bought else "Buy  %d" % Combat.price(id)
		buys[i].disabled = id in bought or combat.shards < Combat.price(id) or combat.relics.size() >= Combat.BELT_SIZE
	var cost := reroll_cost(rerolls)
	reroll_button.text = "Reroll offer  %d" % cost
	reroll_button.disabled = combat.shards < cost or not Combat.RELICS.keys().any(func(id: String) -> bool:
		return combat.relics.all(func(r): return r.id != id) and (rarity == "any" or Combat.RELICS[id].rare == (rarity == "rare")))


## Pays for a fresh deal; no confirm, it is cheap and frequent.
func _reroll() -> void:
	if reroll_button.disabled:
		return
	combat.shards -= reroll_cost(rerolls)
	rerolls += 1
	choices = offer(combat.relics, rarity, combat.rng)
	bought.clear()
	_deal_cards()
	_refresh()


func _ask_buy(id: String) -> void:
	ConfirmPanel.ask(self, "Buy %s?" % Combat.RELICS[id].name, "%d Shards. For this run only." % Combat.price(id), "Buy it", _buy.bind(id))


func _buy(id: String) -> void:
	if combat.buy_relic(id):
		bought.append(id)
	_refresh()


func _ask_destroy(k: int) -> void:
	var id: String = combat.relics[k].id
	ConfirmPanel.ask(self, "Destroy %s?" % Combat.RELICS[id].name, "+%d Shards. It's gone for the rest of the run." % Combat.sell_value(id), "Destroy it", _destroy.bind(k))


func _destroy(k: int) -> void:
	combat.destroy_relic(k)
	_refresh()
