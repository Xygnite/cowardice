class_name ConfirmPanel
extends Overlay
## Asks before something that can't be undone: what will be lost, then go ahead or back out.

signal confirmed

var title := ""
var text := ""
var yes := "Yes"


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
