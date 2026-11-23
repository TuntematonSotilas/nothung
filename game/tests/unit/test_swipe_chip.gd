extends GdUnitTestSuite

## Deck chip gestures: a sideways swipe, a long press, and neither for a tap or a vertical drag.

var _chip: Button
var _gesture: SwipeChip
var _events: Array[String] = []


func before_test() -> void:
	_chip = auto_free(Button.new())
	add_child(_chip)
	_gesture = SwipeChip.attach(_chip)
	_events.clear()
	_gesture.swiped.connect(func() -> void: _events.append("swiped"))
	_gesture.long_pressed.connect(func() -> void: _events.append("long"))


func test_a_sideways_swipe_takes_the_copy_out() -> void:
	_press(true, Vector2(100, 100))
	_move(Vector2(220, 110))
	assert_array(_events).contains_exactly(["swiped"])


func test_a_vertical_drag_scrolls_and_a_tap_does_nothing() -> void:
	_press(true, Vector2(100, 100))
	_move(Vector2(110, 260))
	_press(false, Vector2(110, 260))
	_press(true, Vector2(100, 100))
	_press(false, Vector2(100, 100))
	await get_tree().create_timer(SwipeChip.LONG_PRESS_SECONDS + 0.1).timeout
	assert_array(_events).is_empty()


func test_a_long_press_shows_the_card() -> void:
	_press(true, Vector2(100, 100))
	await get_tree().create_timer(SwipeChip.LONG_PRESS_SECONDS + 0.1).timeout
	assert_array(_events).contains_exactly(["long"])


func _press(pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = at
	_gesture._on_gui_input(event)


func _move(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.global_position = to
	_gesture._on_gui_input(event)
