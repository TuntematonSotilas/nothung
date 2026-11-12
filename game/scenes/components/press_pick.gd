class_name PressPick
extends Node

## Tells a tap from a scroll on a button that sits in a ScrollContainer: `tapped` is emitted only when
## the press did not scroll the container (a finger swipe over a card scrolls the grid, it does not
## open or add the card).

signal tapped

const MOVE_TOLERANCE: int = 12

var _scroll: ScrollContainer
var _scroll_at_press: int = 0


static func attach(button: BaseButton, scroll: ScrollContainer) -> PressPick:
	var press := PressPick.new()
	press._scroll = scroll
	button.add_child(press)
	button.button_down.connect(press._on_down)
	button.pressed.connect(press._on_pressed)
	return press


func _on_down() -> void:
	_scroll_at_press = _scroll.scroll_vertical if _scroll != null else 0


func _on_pressed() -> void:
	var scrolled: int = absi((_scroll.scroll_vertical if _scroll != null else 0) - _scroll_at_press)
	if scrolled <= MOVE_TOLERANCE:
		tapped.emit()
