class_name SwipeChip
extends Node

## Gestures on a deck chip (deck editor): a long press emits `long_pressed` (the card is shown), a
## horizontal swipe emits `swiped` (a copy is taken out). A plain tap does nothing, and a vertical drag
## is left to the scroll container. Mouse events (touch is emulated as mouse on Android).

signal long_pressed
signal swiped

const LONG_PRESS_SECONDS: float = 0.5
## Horizontal distance that takes the copy out, in pixels of the 1080-wide reference.
const SWIPE_DISTANCE: float = 90.0
## Beyond this, the press is a move: no long press.
const MOVE_TOLERANCE: float = 14.0

var _pressed: bool = false
var _moved: bool = false
var _start: Vector2
var _press_count: int = 0


static func attach(control: Control) -> SwipeChip:
	var gesture := SwipeChip.new()
	control.add_child(gesture)
	control.gui_input.connect(gesture._on_gui_input)
	return gesture


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		_pressed = button.pressed
		if button.pressed:
			_moved = false
			_start = button.global_position
			_press_count += 1
			get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_long_press_timer.bind(_press_count))
	elif event is InputEventMouseMotion and _pressed:
		var offset: Vector2 = (event as InputEventMouseMotion).global_position - _start
		if offset.length() > MOVE_TOLERANCE:
			_moved = true
		# Clearly sideways: a swipe; mostly vertical: the list scrolls.
		if absf(offset.x) >= SWIPE_DISTANCE and absf(offset.x) > 1.5 * absf(offset.y):
			_pressed = false
			swiped.emit()


func _on_long_press_timer(press: int) -> void:
	if _pressed and not _moved and press == _press_count:
		_pressed = false
		long_pressed.emit()
