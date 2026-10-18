extends GdUnitTestSuite


func test_opening_redraw_overlay_is_visible_after_initial_layout() -> void:
	var packed_scene: PackedScene = load("res://scenes/screens/duel.tscn")
	var duel: Control = packed_scene.instantiate() as Control
	add_child(duel)
	await get_tree().process_frame
	await get_tree().process_frame

	var current_match: Match = duel.get("_match") as Match
	var overlay: ColorRect = duel.get_node("ModalLayer/ModalOverlay") as ColorRect
	assert_object(current_match).is_not_null()
	assert_int(current_match.get_state().phase).is_equal(GameState.Phase.REDRAW)
	assert_bool(overlay.visible).is_true()
	assert_int(current_match.get_state().player(0).hand.size()).is_between(4, 5)
	assert_bool(overlay.size.x > 0.0).is_true()
	assert_bool(overlay.size.y > 0.0).is_true()

	duel.queue_free()
	await get_tree().process_frame
