class_name ConfirmPanel
extends Overlay
## Asks before something that can't be undone: what will be lost, then go ahead or back out.

signal confirmed

var title := ""
var text := ""
var yes := "Yes"


## Opens a confirm over `screen` that calls `on_yes` if the player goes ahead.
static func ask(screen: Node, title_text: String, body: String, yes_text: String, on_yes: Callable) -> ConfirmPanel:
	var c := ConfirmPanel.new()
	c.title = title_text
	c.text = body
	c.yes = yes_text
	c.confirmed.connect(on_yes)
	screen.add_child(c)
	return c


func _build() -> void:
	heading(title)
	var l := UI.label(body, 20, text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(yes, _yes)
	button("Back  [Esc]", close)


func _yes() -> void:
	close()
	confirmed.emit()
