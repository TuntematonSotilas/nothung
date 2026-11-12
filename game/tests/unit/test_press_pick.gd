extends GdUnitTestSuite

## PressPick: a tap is a tap, a press that scrolled the container is not.

var _scroll: ScrollContainer
var _button: Button
var _taps: int = 0


func before_test() -> void:
	_taps = 0
	_scroll = auto_free(ScrollContainer.new())
	_scroll.custom_minimum_size = Vector2(200, 200)
	add_child(_scroll)
	var tall := VBoxContainer.new()
	_scroll.add_child(tall)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(200, 1000)
	tall.add_child(_button)
	PressPick.attach(_button, _scroll).tapped.connect(func() -> void: _taps += 1)
	await get_tree().process_frame


func test_short_press_is_a_tap() -> void:
	_button.button_down.emit()
	_button.pressed.emit()
	assert_int(_taps).is_equal(1)


func test_press_that_scrolled_is_not_a_tap() -> void:
	_button.button_down.emit()
	_scroll.scroll_vertical = 300
	_button.pressed.emit()
	assert_int(_taps).is_equal(0)
