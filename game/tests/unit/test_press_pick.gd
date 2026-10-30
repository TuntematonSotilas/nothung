extends GdUnitTestSuite

## PressPick: a tap is a tap, a long press picks up, a press that scrolled is neither.

var _scroll: ScrollContainer
var _button: Button
var _press: PressPick
var _events: Array[String] = []


func before_test() -> void:
	_events.clear()
	_scroll = auto_free(ScrollContainer.new())
	_scroll.custom_minimum_size = Vector2(200, 200)
	add_child(_scroll)
	var tall := VBoxContainer.new()
	_scroll.add_child(tall)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(200, 1000)
	tall.add_child(_button)
	_press = PressPick.attach(_button, _scroll)
	_press.tapped.connect(func() -> void: _events.append("tapped"))
	_press.picked.connect(func() -> void: _events.append("picked"))
	_press.released.connect(func(_position: Vector2) -> void: _events.append("released"))
	await get_tree().process_frame


func test_short_press_is_a_tap() -> void:
	_button.button_down.emit()
	_button.button_up.emit()
	_button.pressed.emit()
	assert_array(_events).is_equal(["tapped"])


func test_long_press_picks_up_keeps_the_moves_and_releases() -> void:
	_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_button.button_down.emit()
	_press.timeout.emit()
	assert_bool(_press.is_carrying()).is_true()
	# The carried button keeps the moves: the ScrollContainer does not scroll.
	assert_int(_button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	_button.button_up.emit()
	_button.pressed.emit()
	assert_array(_events).is_equal(["picked", "released"])
	assert_int(_button.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


func test_a_mouse_drag_picks_up_at_once_a_finger_drag_scrolls() -> void:
	_button.button_down.emit()
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(0, 80)
	_press._input(mouse)
	assert_array(_events).is_equal(["picked"])
	_button.button_up.emit()

	_events.clear()
	_button.button_down.emit()
	var finger := InputEventScreenDrag.new()
	finger.position = Vector2(0, 160)
	_press._input(finger)
	assert_bool(_press.is_carrying()).is_false()
	assert_bool(_press.is_stopped()).is_true()
	assert_array(_events).is_empty()


func test_press_that_scrolled_is_not_a_tap() -> void:
	_button.button_down.emit()
	_scroll.scroll_vertical = 300
	_button.button_up.emit()
	_button.pressed.emit()
	assert_array(_events).is_empty()


func test_without_pick_a_long_press_does_nothing() -> void:
	_press.pick_enabled = false
	_button.button_down.emit()
	assert_bool(_press.is_stopped()).is_true()
