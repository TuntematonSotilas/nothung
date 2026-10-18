extends GdUnitTestSuite


func test_wotan_portrait_is_loaded_and_displayed_in_duel() -> void:
	var leader: LeaderData = CardDatabase.get_leader(&"wotan")
	assert_object(leader).is_not_null()
	assert_object(leader.art).is_not_null()
	var portrait: Image = leader.art.get_image()
	assert_bool(portrait.get_width() < portrait.get_height()).is_true()
	assert_float(portrait.get_pixel(0, 0).a).is_equal(0.0)

	var duel: Control = await _create_duel()
	var frame: Panel = duel.get("_own_leader_portrait_frame") as Panel
	var artwork: TextureRect = duel.get("_own_leader_artwork") as TextureRect
	assert_bool(artwork.texture == leader.art).is_true()
	assert_bool(artwork.visible).is_true()
	var frame_style: StyleBoxFlat = frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_int(frame_style.border_width_left).is_greater_equal(2)
	assert_int(frame_style.corner_radius_top_left).is_greater_equal(8)
	duel.queue_free()
	await get_tree().process_frame


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


func test_tap_then_target_plays_a_targeted_card() -> void:
	var duel: Control = await _create_duel()
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	var player: PlayerState = state.player(0)
	state.phase = GameState.Phase.MAIN
	state.active_player = 0
	state.turn = 2
	player.energy = 2
	player.hand.cards.clear()
	player.board.cards.clear()
	var spell_data: CardData = CardDatabase.get_card(&"war_song")
	var spell: CardInstance = CardInstance.new(spell_data, 0, 101)
	var target: CardInstance = CardInstance.new(CardDatabase.get_card(&"ravens_gather"), 0, 102)
	player.hand.add(spell)
	player.board.add(target)
	duel.call("_refresh")
	await get_tree().process_frame

	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var board: HBoxContainer = duel.get("_own_board") as HBoxContainer
	duel.call("_on_hand_card_pressed", spell.uid, hand.get_child(0))
	assert_int(duel.get("_selected_hand_uid")).is_equal(spell.uid)
	duel.call("_on_board_card_pressed", target.uid, true, &"board", board.get_child(0))

	assert_int(player.hand.size()).is_equal(0)
	assert_int(player.energy).is_equal(0)
	assert_int(target.attack).is_equal(2)
	assert_int(target.health).is_equal(3)
	duel.queue_free()
	await get_tree().process_frame


func test_dragging_a_playable_card_to_the_empty_board_plays_it() -> void:
	var duel: Control = await _create_duel()
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	var player: PlayerState = state.player(0)
	state.phase = GameState.Phase.MAIN
	state.active_player = 0
	state.turn = 1
	player.energy = 1
	player.hand.cards.clear()
	player.board.cards.clear()
	var card: CardInstance = CardInstance.new(CardDatabase.get_card(&"ravens_gather"), 0, 201)
	player.hand.add(card)
	duel.call("_refresh")
	await get_tree().process_frame

	var board: HBoxContainer = duel.get("_own_board") as HBoxContainer
	duel.call(
		"_on_card_drag_released",
		{"kind": "hand", "uid": card.uid},
		board.get_global_rect().get_center()
	)

	assert_int(player.hand.size()).is_equal(0)
	assert_int(player.board.size()).is_equal(1)
	assert_int(player.energy).is_equal(0)
	duel.queue_free()
	await get_tree().process_frame


func test_undoing_a_play_restores_effects_and_returns_card_to_deck() -> void:
	var duel: Control = await _create_duel()
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	var player: PlayerState = state.player(0)
	state.phase = GameState.Phase.MAIN
	state.active_player = 0
	state.turn = 2
	player.energy = 2
	player.hand.cards.clear()
	player.board.cards.clear()
	var spell: CardInstance = CardInstance.new(CardDatabase.get_card(&"war_song"), 0, 301)
	var target: CardInstance = CardInstance.new(CardDatabase.get_card(&"ravens_gather"), 0, 302)
	player.hand.add(spell)
	player.board.add(target)
	var original_deck_size: int = player.deck.size()
	duel.call("_refresh")
	await get_tree().process_frame

	var play: PlayCardAction
	for action: Action in current_match.get_legal_actions(0):
		if action is PlayCardAction and (action as PlayCardAction).card_uid == spell.uid:
			play = action as PlayCardAction
			break
	duel.call("_apply_action", play)

	assert_int(player.energy).is_equal(0)
	assert_int(player.board.find(target.uid).attack).is_equal(2)
	assert_bool((duel.get("_undo_play_button") as Button).visible).is_true()

	duel.call("_on_undo_play_pressed")

	var restored_player: PlayerState = current_match.get_state().player(0)
	assert_int(restored_player.energy).is_equal(2)
	assert_int(restored_player.board.find(target.uid).attack).is_equal(1)
	assert_int(restored_player.hand.size()).is_equal(0)
	assert_int(restored_player.deck.size()).is_equal(original_deck_size + 1)
	assert_int(restored_player.deck.cards.back().uid).is_equal(spell.uid)
	assert_bool((duel.get("_undo_play_button") as Button).visible).is_false()
	assert_bool((duel.get("_log_label") as Label).text.contains("played a card")).is_false()
	duel.queue_free()
	await get_tree().process_frame


func test_drop_zone_covers_artifacts_and_board_and_is_highlighted() -> void:
	var duel: Control = await _create_duel()
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	var player: PlayerState = state.player(0)
	state.phase = GameState.Phase.MAIN
	state.active_player = 0
	state.turn = 1
	player.energy = 1
	player.hand.cards.clear()
	player.board.cards.clear()
	var card: CardInstance = CardInstance.new(CardDatabase.get_card(&"ravens_gather"), 0, 401)
	player.hand.add(card)
	duel.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var artifacts: HBoxContainer = duel.get("_own_artifacts") as HBoxContainer
	var board: HBoxContainer = duel.get("_own_board") as HBoxContainer
	duel.call("_on_card_drag_started", {"kind": "hand", "uid": card.uid})
	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var source: CardView = hand.get_child(0) as CardView
	var hint: PanelContainer = duel.get("_drop_hint") as PanelContainer
	var preview: Control = duel.get("_drag_preview") as Control
	assert_bool(hint.visible).is_true()
	assert_object(preview).is_not_null()
	assert_float(absf(preview.size.x - source.custom_minimum_size.x)).is_less_equal(0.01)
	assert_float(absf(preview.size.y - source.custom_minimum_size.y)).is_less_equal(0.01)
	assert_bool(preview.get_node("CardText") is Label).is_true()
	assert_bool(hint.get_global_rect().has_point(artifacts.get_global_rect().get_center())).is_true()
	assert_bool(hint.get_global_rect().has_point(board.get_global_rect().get_center())).is_true()

	duel.call("_on_card_drag_released", {"kind": "hand", "uid": card.uid}, artifacts.get_global_rect().get_center())

	assert_int(player.hand.size()).is_equal(0)
	assert_int(player.board.size()).is_equal(1)
	assert_bool(hint.visible).is_false()
	assert_bool(duel.get("_drag_preview") == null).is_true()
	duel.queue_free()
	await get_tree().process_frame


func test_ai_playing_a_unit_does_not_change_duel_minimum_height() -> void:
	var duel: Control = await _create_duel()
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	var opponent: PlayerState = state.player(1)
	state.phase = GameState.Phase.MAIN
	state.active_player = 0
	opponent.board.cards.clear()
	duel.call("_refresh")
	await get_tree().process_frame

	var layout: VBoxContainer = duel.get("_main_layout") as VBoxContainer
	var viewport_height: float = duel.get_viewport().get_visible_rect().size.y
	var minimum_height_before_play: float = layout.get_combined_minimum_size().y
	var card: CardInstance = CardInstance.new(CardDatabase.get_card(&"ravens_gather"), 1, 501)
	opponent.board.add(card)
	duel.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var minimum_height_after_play: float = layout.get_combined_minimum_size().y
	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var hand_scroll: ScrollContainer = hand.get_parent() as ScrollContainer
	var hand_card: CardView = hand.get_child(0) as CardView
	var enemy_board: HBoxContainer = duel.get("_enemy_board") as HBoxContainer
	var enemy_card: CardView = enemy_board.get_child(0) as CardView
	assert_bool(minimum_height_before_play <= viewport_height).is_true()
	assert_float(absf(minimum_height_after_play - minimum_height_before_play)).is_less_equal(1.0)
	assert_float(
		absf(
			enemy_card.custom_minimum_size.y
			- 200 * float(duel.get("_board_card_scale"))
		)
	).is_less_equal(0.001)
	assert_float(hand_scroll.size.y).is_greater_equal(hand_card.size.y)
	assert_bool(
		hand_card.get_global_rect().end.y <= hand_scroll.get_global_rect().end.y
	).is_true()
	duel.queue_free()
	await get_tree().process_frame


func _create_duel() -> Control:
	var packed_scene: PackedScene = load("res://scenes/screens/duel.tscn")
	var duel: Control = packed_scene.instantiate() as Control
	add_child(duel)
	await get_tree().process_frame
	await get_tree().process_frame
	return duel
