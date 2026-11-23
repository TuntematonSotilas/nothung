class_name LongPress
extends Node

## A long press on a control emits `long_pressed` (the deck editor shows the card of a deck chip). A tap
## or a drag (the list scrolls) does not. Mouse events (touch is emulated as mouse on Android).

signal long_pressed

const SECONDS: float = 0.5
## Beyond this, the press is a move: no long press.
const MOVE_TOLERANCE: float = 14.0

var _pressed: bool = false
var _moved: bool = false
var _start: Vector2
var _press_count: int = 0


static func attach(control: Control) -> LongPress:
	var gesture := LongPress.new()
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
			get_tree().create_timer(SECONDS).timeout.connect(_on_timer.bind(_press_count))
	elif event is InputEventMouseMotion and _pressed:
		if ((event as InputEventMouseMotion).global_position - _start).length() > MOVE_TOLERANCE:
			_moved = true


func _on_timer(press: int) -> void:
	if _pressed and not _moved and press == _press_count:
		_pressed = false
		long_pressed.emit()
