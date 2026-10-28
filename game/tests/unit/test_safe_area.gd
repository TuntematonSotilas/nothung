extends GdUnitTestSuite

## On desktop (tests) there is no notch: insets are zero and pad() keeps the screen's own margins.


func test_no_inset_off_mobile() -> void:
	var node: Control = auto_free(Control.new()) as Control
	add_child(node)
	var insets: Dictionary = SafeArea.insets(node)
	for side: String in ["left", "top", "right", "bottom"]:
		assert_float(insets[side]).is_equal(0.0)


func test_pad_keeps_the_base_margins() -> void:
	var margin: MarginContainer = auto_free(MarginContainer.new()) as MarginContainer
	add_child(margin)
	SafeArea.pad(margin, {"left": 10.0, "top": 20.0, "right": 30.0, "bottom": 40.0})
	assert_int(margin.get_theme_constant("margin_left")).is_equal(10)
	assert_int(margin.get_theme_constant("margin_top")).is_equal(20)
	assert_int(margin.get_theme_constant("margin_right")).is_equal(30)
	assert_int(margin.get_theme_constant("margin_bottom")).is_equal(40)
