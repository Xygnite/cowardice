extends SceneTree
## Bakes assets/ui/cut/perk_<id>.png for perks without their own art: the bronze-rimmed disc of an
## original perk badge with its picture cleared, and a small icon from the same folder set in the middle.
## Run: godot --headless --path . -s tools/make_perk_badges.gd
## Then `--import` so Godot picks up new files.

const CUT := "res://assets/ui/cut/"
const BASE := "perk_thick_skin"  # whose rim and disc the new badges borrow
const CLEAR_RADIUS := 20.0  # screen pixels from the centre; inside the rim's dark inner line
const FILL_AT := Vector2i(6, 27)  # a pixel of plain disc between rim and picture, to fill the cleared middle with

## Perk id -> the icon it wears.
const BADGES := {
	"scavenger": "icon_shard",
	"bonfire_keeper": "icon_ember",
	"lucky_charm": "icon_bandage",
	"iron_nerve": "icon_shield",
	"grit_teeth": "icon_skull",
	"hex_ward": "icon_rune",
	"lantern_bearer": "icon_bell",
}


func _init() -> void:
	var base := Image.load_from_file(ProjectSettings.globalize_path(CUT + BASE + ".png"))
	var fill := base.get_pixelv(FILL_AT)
	var centre := Vector2(base.get_size()) / 2.0
	for x in base.get_width():
		for y in base.get_height():
			if Vector2(x + 0.5, y + 0.5).distance_to(centre) < CLEAR_RADIUS:
				base.set_pixel(x, y, fill)
	for id in BADGES:
		var badge := base.duplicate()
		var icon := Image.load_from_file(ProjectSettings.globalize_path(CUT + BADGES[id] + ".png"))
		# The badges are drawn at 2x; halve the icon and blow it back up so its pixels match.
		var size := icon.get_size()
		icon.resize(size.x / 2, size.y / 2, Image.INTERPOLATE_NEAREST)
		icon.resize(size.x / 2 * 2, size.y / 2 * 2, Image.INTERPOLATE_NEAREST)
		# Even offsets keep the icon on the same 2x pixel grid as the badge.
		var at := (Vector2i(badge.get_size() - icon.get_size()) / 2 / 2) * 2
		badge.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), at)
		badge.save_png(ProjectSettings.globalize_path(CUT + "perk_" + id + ".png"))
		print("perk_%s.png <- %s" % [id, BADGES[id]])
	quit()
