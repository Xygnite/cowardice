class_name TutorialGuide
extends Control
## The tutorial's spotlight: the whole screen dimmed but for one gold-ringed hole over the step's target,
## and a panel beside it saying what is being learned. Clicks reach the screen only through the hole;
## the panel's Next button moves on a step that only explains. The hole is the target's box grown by
## MARGIN with fully rounded ends: a circle round a die, a pill round a button or a bar.

signal next

const DIM := Color(0, 0, 0, 0.78)
const MARGIN := 14.0  # screen pixels the hole reaches past its target on every side
const RING := 3.0  # screen pixels of gold ring round the hole
const PANEL_WIDTH := 440.0
const GAP := 16.0  # screen pixels between the hole and the panel

const SHADER := "shader_type canvas_item;
uniform vec2 size;
uniform vec2 center;
uniform vec2 half_size;
uniform float ring;
uniform vec4 dim : source_color;
uniform vec4 gold : source_color;
void fragment() {
	vec2 p = floor(UV * size / 2.0) * 2.0 + 1.0;  // 2-pixel steps, like the rest of the art
	float round_by = min(half_size.x, half_size.y);
	vec2 q = abs(p - center) - (half_size - round_by);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - round_by;  // distance out of the hole
	COLOR = d < 0.0 ? vec4(0.0) : (d < ring ? gold : dim);
}"

var target := Callable()  # returns the Rect2, in screen space, the hole goes round
var center := Vector2.ZERO
var half_size := Vector2.ONE
var shade := ColorRect.new()
var panel := PanelContainer.new()
var title: Label
var text: Label
var next_button: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	mat.set_shader_parameter("ring", RING)
	mat.set_shader_parameter("dim", DIM)
	mat.set_shader_parameter("gold", UI.GOLD)
	shade.material = mat
	add_child(shade)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	title = UI.heading(col, 28)
	text = UI.label(col, 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = PANEL_WIDTH
	next_button = UI.button(col, "Next", next.emit)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	hide()


## Spotlights what `at` returns (a Rect2 in screen space, read every frame, so it follows the layout) and
## explains it under `heading`; `with_next` shows the Next button.
func point(at: Callable, heading: String, body: String, with_next: bool) -> void:
	target = at
	title.text = heading
	text.text = body
	next_button.visible = with_next
	panel.show()
	show()
	_place()


## Keeps the spotlight but takes the panel away, so nothing covers what happens there next.
func hide_panel() -> void:
	panel.hide()


## Clicks land on the screen below only inside the hole.
func _has_point(p: Vector2) -> bool:
	var round_by := minf(half_size.x, half_size.y)
	var q := (p - center).abs() - (half_size - Vector2.ONE * round_by)
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - round_by >= 0.0


func _process(_delta: float) -> void:
	if visible:
		_place()


func _place() -> void:
	var r: Rect2 = target.call()
	r.position -= global_position
	center = r.get_center()
	half_size = r.size / 2 + Vector2.ONE * MARGIN
	var mat := shade.material as ShaderMaterial
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("half_size", half_size)
	# Left of a hole near the right edge (the enemies stand under theirs); else under a hole in the top
	# half of the screen and over one in the bottom half. Always kept on screen.
	panel.reset_size()
	var pos: Vector2
	if center.x > size.x * 2 / 3:
		pos = Vector2(center.x - half_size.x - GAP - panel.size.x, center.y - panel.size.y / 2)
	elif center.y < size.y / 2:
		pos = Vector2(center.x - panel.size.x / 2, center.y + half_size.y + GAP)
	else:
		pos = Vector2(center.x - panel.size.x / 2, center.y - half_size.y - GAP - panel.size.y)
	panel.position = pos.clamp(Vector2.ONE * GAP, size - panel.size - Vector2.ONE * GAP)
