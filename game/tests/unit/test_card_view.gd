extends GdUnitTestSuite


func test_long_press_requests_zoom_and_is_consumed() -> void:
	var view: CardView = auto_free(CardView.new())
	view.set_card(CardDatabase.get_card(&"freia"))
	view.size = Vector2(100, 100)
	add_child(view)
	await get_tree().process_frame
	assert_bool(view.is_processing_input()).is_true()
	var zoomed_card_ids: Array[StringName] = []
	view.zoom_requested.connect(func(data: CardData, _instance: CardInstance) -> void:
		zoomed_card_ids.append(data.id)
	)

	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = Vector2(20, 20)
	touch.pressed = true
	view._input(touch)
	await get_tree().create_timer(0.65).timeout
	touch.pressed = false
	view._input(touch)

	assert_array(zoomed_card_ids).contains([&"freia"])
	assert_bool(view.consume_long_press()).is_true()
	assert_bool(view.consume_long_press()).is_false()


func test_card_drop_emits_source_and_target_information() -> void:
	var card_data: CardData = CardDatabase.get_card(&"freia")
	var instance: CardInstance = CardInstance.new(card_data, 0, 42)
	var view: CardView = auto_free(CardView.new())
	view.set_card(card_data, instance, false, 1)
	var dropped: Array[Dictionary] = []
	view.drop_requested.connect(func(data: Dictionary, target_uid: int, target_player: int) -> void:
		dropped.append({
			"kind": data["kind"],
			"uid": data["uid"],
			"target_uid": target_uid,
			"target_player": target_player,
		})
	)

	view._drop_data(Vector2.ZERO, {"kind": "hand", "uid": 9})

	assert_array(dropped).is_equal([{
		"kind": "hand",
		"uid": 9,
		"target_uid": 42,
		"target_player": 1,
	}])


func test_drag_release_emits_drop_position_and_is_consumed() -> void:
	var card_data: CardData = CardDatabase.get_card(&"freia")
	var instance: CardInstance = CardInstance.new(card_data, 0, 42)
	var view: CardView = auto_free(CardView.new())
	view.set_card(card_data, instance, true, -1)
	view.position = Vector2(20, 20)
	view.size = Vector2(100, 100)
	add_child(view)
	await get_tree().process_frame
	var releases: Array[Dictionary] = []
	view.drag_released.connect(func(data: Dictionary, position: Vector2) -> void:
		releases.append({"data": data, "position": position})
	)

	view._input(_mouse_button(Vector2(40, 40), true))
	view._input(_mouse_motion(Vector2(80, 90)))
	view._input(_mouse_button(Vector2(180, 190), false))

	assert_array(releases).is_equal([{
		"data": {"kind": "hand", "uid": 42},
		"position": Vector2(180, 190),
	}])
	assert_bool(view.consume_drag()).is_true()
	assert_bool(view.consume_drag()).is_false()
	assert_bool(view._get_drag_data(Vector2.ZERO) == null).is_true()


func test_drag_motion_emits_position_for_custom_preview() -> void:
	var card_data: CardData = CardDatabase.get_card(&"freia")
	var instance: CardInstance = CardInstance.new(card_data, 0, 43)
	var view: CardView = auto_free(CardView.new())
	view.set_card(card_data, instance, true)
	view.size = Vector2(100, 100)
	add_child(view)
	await get_tree().process_frame
	var positions: Array[Vector2] = []
	view.drag_moved.connect(func(_data: Dictionary, position: Vector2) -> void:
		positions.append(position)
	)

	view._input(_mouse_button(Vector2(40, 40), true))
	view._input(_mouse_motion(Vector2(80, 90)))
	view._input(_mouse_motion(Vector2(120, 130)))

	assert_array(positions).is_equal([Vector2(80, 90), Vector2(120, 130)])


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	return event
