extends GdUnitTestSuite

## Long press on a deck chip: emitted after holding still, not for a tap or a drag.

var _gesture: LongPress
var _count: int = 0


func before_test() -> void:
	var chip: Button = auto_free(Button.new())
	add_child(chip)
	_gesture = LongPress.attach(chip)
	_count = 0
	_gesture.long_pressed.connect(func() -> void: _count += 1)


func test_holding_still_shows_the_card() -> void:
	_press(true, Vector2(100, 100))
	await get_tree().create_timer(LongPress.SECONDS + 0.1).timeout
	assert_int(_count).is_equal(1)


func test_a_tap_or_a_drag_does_nothing() -> void:
	_press(true, Vector2(100, 100))
	_press(false, Vector2(100, 100))
	_press(true, Vector2(100, 100))
	var motion := InputEventMouseMotion.new()
	motion.global_position = Vector2(110, 200)
	_gesture._on_gui_input(motion)
	await get_tree().create_timer(LongPress.SECONDS + 0.1).timeout
	assert_int(_count).is_equal(0)


func _press(pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = at
	_gesture._on_gui_input(event)
