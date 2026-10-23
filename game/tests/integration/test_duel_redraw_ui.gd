extends GdUnitTestSuite

var _animation_speed: float


# Animations off: these tests check the state right after each action (animations: test_duel_fx.gd).
func before() -> void:
	_animation_speed = Settings.animation_speed
	Settings.animation_speed = 0.0


func after() -> void:
	Settings.animation_speed = _animation_speed


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
	var spell_data: CardData = CardDatabase.get_card(&"freias_golden_apples")
	var spell: CardInstance = CardInstance.new(spell_data, 0, 101)
	var target: CardInstance = CardInstance.new(CardDatabase.get_card(&"wotans_ravens"), 0, 102)
	player.hand.add(spell)
	player.board.add(target)
	duel.call("_refresh")
	await get_tree().process_frame

	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var board: HFlowContainer = duel.get("_own_board") as HFlowContainer
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
	var card: CardInstance = CardInstance.new(CardDatabase.get_card(&"wotans_ravens"), 0, 201)
	player.hand.add(card)
	duel.call("_refresh")
	await get_tree().process_frame

	var board: HFlowContainer = duel.get("_own_board") as HFlowContainer
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
	var spell: CardInstance = CardInstance.new(CardDatabase.get_card(&"freias_golden_apples"), 0, 301)
	var target: CardInstance = CardInstance.new(CardDatabase.get_card(&"wotans_ravens"), 0, 302)
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
	var card: CardInstance = CardInstance.new(CardDatabase.get_card(&"wotans_ravens"), 0, 401)
	player.hand.add(card)
	duel.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var artifacts: HFlowContainer = duel.get("_own_artifacts") as HFlowContainer
	var board: HFlowContainer = duel.get("_own_board") as HFlowContainer
	duel.call("_on_card_drag_started", {"kind": "hand", "uid": card.uid})
	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var source: CardView = hand.get_child(0) as CardView
	var hint: PanelContainer = duel.get("_drop_hint") as PanelContainer
	var preview: Control = duel.get("_drag_preview") as Control
	assert_bool(hint.visible).is_true()
	assert_object(preview).is_not_null()
	assert_float(absf(preview.size.x - source.custom_minimum_size.x)).is_less_equal(0.01)
	assert_float(absf(preview.size.y - source.custom_minimum_size.y)).is_less_equal(0.01)
	assert_bool(preview.find_child("NameLabel", true, false) is Label).is_true()
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
	var card: CardInstance = CardInstance.new(CardDatabase.get_card(&"wotans_ravens"), 1, 501)
	opponent.board.add(card)
	duel.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var minimum_height_after_play: float = layout.get_combined_minimum_size().y
	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var hand_scroll: Control = hand.get_parent() as Control
	var hand_card: CardView = hand.get_child(0) as CardView
	var enemy_board: HFlowContainer = duel.get("_enemy_board") as HFlowContainer
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


func test_leader_panels_share_layout_and_show_named_abilities() -> void:
	var duel: Control = await _create_duel()
	var own_panel: PanelContainer = duel.find_child("OwnLeaderPanel", true, false) as PanelContainer
	var enemy_panel: PanelContainer = duel.find_child("EnemyLeaderPanel", true, false) as PanelContainer
	assert_object(own_panel).is_not_null()
	assert_object(enemy_panel).is_not_null()
	assert_int(own_panel.get_child(0).get_child_count()).is_equal(enemy_panel.get_child(0).get_child_count())

	var own_ability: Button = duel.get("_ability_button") as Button
	var enemy_ability: Button = duel.get("_enemy_ability_button") as Button
	assert_str(own_ability.text).contains(tr("LEADER_WOTAN_ABILITY_NAME"))
	assert_str(enemy_ability.text).contains(tr("LEADER_ALBERICH_ABILITY_NAME"))
	assert_bool(enemy_ability.disabled).is_true()
	assert_str((duel.get("_enemy_leader_label") as Label).text).is_equal(tr("LEADER_ALBERICH_NAME"))
	assert_str((duel.get("_own_leader_label") as Label).text).is_equal(tr("LEADER_WOTAN_NAME"))
	assert_bool(own_panel.is_ancestor_of(duel.get("_energy_label") as Label)).is_true()
	assert_bool(enemy_panel.is_ancestor_of(duel.get("_enemy_energy_label") as Label)).is_true()

	var info_panel: PanelContainer = duel.find_child("MatchInfoPanel", true, false) as PanelContainer
	assert_bool(info_panel.is_ancestor_of(duel.get("_status_label") as Label)).is_true()
	assert_bool(info_panel.is_ancestor_of(duel.get("_turn_label") as Label)).is_true()
	var log_panel: PanelContainer = duel.find_child("BattleLogPanel", true, false) as PanelContainer
	assert_bool(log_panel.is_ancestor_of(duel.get("_log_label") as Label)).is_true()

	var current_match: Match = duel.get("_match") as Match
	current_match.get_state().player(1).board.cards.clear()
	duel.call("_refresh")
	await get_tree().process_frame
	assert_int((duel.get("_enemy_board") as HFlowContainer).get_child_count()).is_equal(0)
	duel.queue_free()
	await get_tree().process_frame


func _create_duel() -> Control:
	var packed_scene: PackedScene = load("res://scenes/screens/duel.tscn")
	var duel: Control = packed_scene.instantiate() as Control
	add_child(duel)
	await get_tree().process_frame
	await get_tree().process_frame
	return duel


func _main_phase_duel_with_hand(card_ids: Array[StringName], energy: int) -> Control:
	var duel: Control = await _create_duel()
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	var player: PlayerState = state.player(0)
	state.phase = GameState.Phase.MAIN
	state.active_player = 0
	player.energy = energy
	player.hand.cards.clear()
	player.board.cards.clear()
	state.player(1).board.cards.clear()
	var uid: int = 700
	for card_id: StringName in card_ids:
		player.hand.add(CardInstance.new(CardDatabase.get_card(card_id), 0, uid))
		uid += 1
	duel.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	return duel


func test_tap_tap_selects_first_then_plays_on_the_play_area() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"wotans_ravens"], 2)
	var player: PlayerState = (duel.get("_match") as Match).get_state().player(0)
	var view: CardView = (duel.get("_own_hand") as HBoxContainer).get_child(0) as CardView
	duel.call("_on_hand_card_pressed", 700, view)
	assert_int(player.hand.size()).is_equal(1)
	assert_int(int(duel.get("_selected_hand_uid"))).is_equal(700)
	assert_bool((duel.get("_drop_hint") as PanelContainer).visible).is_true()

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	duel.call("_on_own_zone_input", release)
	assert_int(player.hand.size()).is_equal(0)
	assert_int(player.board.size()).is_equal(1)
	assert_bool((duel.get("_drop_hint") as PanelContainer).visible).is_false()
	duel.queue_free()
	await get_tree().process_frame


func test_tapping_the_selected_card_again_cancels() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"wotans_ravens"], 2)
	var view: CardView = (duel.get("_own_hand") as HBoxContainer).get_child(0) as CardView
	duel.call("_on_hand_card_pressed", 700, view)
	view = (duel.get("_own_hand") as HBoxContainer).get_child(0) as CardView
	duel.call("_on_hand_card_pressed", 700, view)
	assert_int(int(duel.get("_selected_hand_uid"))).is_equal(-1)
	assert_int((duel.get("_match") as Match).get_state().player(0).hand.size()).is_equal(1)
	duel.queue_free()
	await get_tree().process_frame


func test_unplayable_card_is_greyed_and_zoom_explains_why() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"donner"], 1)
	var view: CardView = (duel.get("_own_hand") as HBoxContainer).get_child(0) as CardView
	assert_float(view.modulate.r).is_less(1.0)
	duel.call("_on_hand_card_pressed", 700, view)
	assert_int(int(duel.get("_selected_hand_uid"))).is_equal(-1)
	# No message in the top bar: the reason is in the zoom popup.
	assert_str((duel.get("_status_label") as Label).text).is_equal(tr("UI_YOUR_TURN"))

	duel.call("_show_card_zoom", view.card_data, view.card_instance, view)
	var reason: Label = duel.find_child("BlockedReason", true, false) as Label
	assert_object(reason).is_not_null()
	assert_str(reason.text).contains("4")
	duel.queue_free()
	await get_tree().process_frame


func test_full_hand_fits_the_screen_width_without_scrollbar() -> void:
	var ids: Array[StringName] = [&"wotans_ravens", &"fricka", &"freia", &"loge", &"donner", &"valhalla_hero", &"wotans_valkyries", &"donners_hammer"]
	var duel: Control = await _main_phase_duel_with_hand(ids, 10)
	await get_tree().process_frame
	assert_int(duel.find_children("*", "ScrollContainer", true, false).size()).is_equal(0)
	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var viewport_width: float = duel.get_viewport().get_visible_rect().size.x
	var last_card: CardView = hand.get_child(hand.get_child_count() - 1) as CardView
	assert_float(last_card.get_global_rect().end.x).is_less_equal(viewport_width)
	duel.queue_free()
	await get_tree().process_frame


func test_redraw_and_pause_panels_fit_without_scrolling() -> void:
	var duel: Control = await _create_duel()
	var state: GameState = (duel.get("_match") as Match).get_state()
	var viewport_size: Vector2 = duel.get_viewport().get_visible_rect().size
	if state.phase == GameState.Phase.REDRAW and state.redraw_player == 0:
		await get_tree().process_frame
		var redraw_panel: PanelContainer = duel.find_child("RedrawPanel", true, false) as PanelContainer
		assert_object(redraw_panel).is_not_null()
		assert_int(redraw_panel.find_children("*", "ScrollContainer", true, false).size()).is_equal(0)
		assert_bool(Rect2(Vector2.ZERO, viewport_size).encloses(redraw_panel.get_global_rect())).is_true()

	duel.call("_on_pause_pressed")
	await get_tree().process_frame
	var pause_panel: PanelContainer = duel.find_child("PausePanel", true, false) as PanelContainer
	assert_object(pause_panel).is_not_null()
	assert_object(pause_panel.find_child("ResumeButton", true, false)).is_not_null()
	assert_bool(duel.call("handle_back")).is_true()
	await get_tree().process_frame
	assert_object(duel.find_child("PausePanel", true, false)).is_null()
	duel.queue_free()
	await get_tree().process_frame


func test_releasing_a_drag_that_plays_the_card_does_not_crash() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"wotans_ravens"], 2)
	var player: PlayerState = (duel.get("_match") as Match).get_state().player(0)
	var view: CardView = (duel.get("_own_hand") as HBoxContainer).get_child(0) as CardView
	var start: Vector2 = view.get_global_rect().get_center()
	var drop: Vector2 = (duel.call("_own_drop_rect") as Rect2).get_center()
	view.call("_begin_press", start)
	view.call("_cancel_moved_press", start + Vector2(0, -60))
	view.call("_end_press", drop)
	await get_tree().process_frame
	assert_int(player.hand.size()).is_equal(0)
	assert_int(player.board.size()).is_equal(1)
	duel.queue_free()
	await get_tree().process_frame


func test_attack_by_tap_shows_targets_and_resolves() -> void:
	var duel: Control = await _main_phase_duel_with_hand([], 2)
	var state: GameState = (duel.get("_match") as Match).get_state()
	var attacker: CardInstance = CardInstance.new(CardDatabase.get_card(&"donner"), 0, 950)
	attacker.can_attack = true
	state.player(0).board.add(attacker)
	var fresh: CardInstance = CardInstance.new(CardDatabase.get_card(&"fricka"), 0, 951)
	state.player(0).board.add(fresh)
	var enemy: CardInstance = CardInstance.new(CardDatabase.get_card(&"nibelung_miner"), 1, 952)
	enemy.can_attack = true
	state.player(1).board.add(enemy)
	duel.call("_refresh")
	await get_tree().process_frame

	var own_board: HFlowContainer = duel.get("_own_board") as HFlowContainer
	var attacker_view: CardView = own_board.get_child(0) as CardView
	var fresh_view: CardView = own_board.get_child(1) as CardView
	assert_str(String(attacker_view.get("_highlight"))).is_equal("ready")
	assert_float(fresh_view.modulate.r).is_less(1.0)
	# The top bar only shows the turn state, no instructions; units cannot be dragged to attack.
	assert_str((duel.get("_status_label") as Label).text).is_equal(tr("UI_YOUR_TURN"))
	assert_bool(attacker_view.get("_draggable")).is_false()

	# A unit played this turn explains why it cannot attack instead of silently selecting.
	duel.call("_on_board_card_pressed", 951, true, &"board", fresh_view)
	assert_int(int(duel.get("_selected_attacker_uid"))).is_equal(-1)
	assert_str((duel.get("_status_label") as Label).text).is_equal(tr("UI_YOUR_TURN"))

	attacker_view = own_board.get_child(0) as CardView
	duel.call("_on_board_card_pressed", 950, true, &"board", attacker_view)
	assert_int(int(duel.get("_selected_attacker_uid"))).is_equal(950)
	assert_str((duel.get("_status_label") as Label).text).is_equal(tr("UI_YOUR_TURN"))
	var enemy_view: CardView = (duel.get("_enemy_board") as HFlowContainer).get_child(0) as CardView
	assert_str(String(enemy_view.get("_highlight"))).is_equal("target")
	var enemy_panel_style: StyleBoxFlat = (duel.get("_enemy_leader_panel") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_str(enemy_panel_style.border_color.to_html(false)).is_equal(Palette.LIFE.to_html(false))

	duel.call("_on_board_card_pressed", 952, false, &"board", enemy_view)
	assert_int(state.player(1).board.size()).is_equal(0)
	assert_bool(attacker.exhausted).is_true()
	duel.queue_free()
	await get_tree().process_frame


func test_full_enemy_board_wraps_and_keeps_layout_inside_the_screen() -> void:
	var ids: Array[StringName] = [&"donners_hammer", &"freias_golden_apples", &"valhalla_hero", &"loge", &"fricka", &"freia"]
	var duel: Control = await _main_phase_duel_with_hand(ids, 5)
	# Lay the duel out at a phone's width (the test window is wider than a phone).
	duel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	duel.size = Vector2(1080, 1920)
	var state: GameState = (duel.get("_match") as Match).get_state()
	for index: int in Match.MAX_BOARD_SIZE:
		state.player(1).board.add(CardInstance.new(CardDatabase.get_card(&"nibelung_miner"), 1, 960 + index))
	duel.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame

	var screen_right: float = duel.get_global_rect().end.x
	var layout: VBoxContainer = duel.get("_main_layout") as VBoxContainer
	assert_float(layout.get_global_rect().end.x).is_less_equal(screen_right)
	var enemy_board: HFlowContainer = duel.get("_enemy_board") as HFlowContainer
	var first_enemy: CardView = enemy_board.get_child(0) as CardView
	var last_enemy: CardView = enemy_board.get_child(enemy_board.get_child_count() - 1) as CardView
	assert_float(last_enemy.get_global_rect().end.x).is_less_equal(screen_right)
	assert_float(last_enemy.get_global_rect().position.y).is_greater(first_enemy.get_global_rect().position.y)
	var hand: HBoxContainer = duel.get("_own_hand") as HBoxContainer
	var last_hand: CardView = hand.get_child(hand.get_child_count() - 1) as CardView
	assert_float(last_hand.get_global_rect().end.x).is_less_equal(screen_right)
	assert_float((duel.get("_end_turn_button") as Button).get_global_rect().end.x).is_less_equal(screen_right)
	duel.queue_free()
	await get_tree().process_frame


func test_hand_cannot_be_dragged_outside_own_turn_and_refresh_cancels_a_drag() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"wotans_ravens"], 2)
	var state: GameState = (duel.get("_match") as Match).get_state()
	var view: CardView = (duel.get("_own_hand") as HBoxContainer).get_child(0) as CardView
	var start: Vector2 = view.get_global_rect().get_center()
	view.call("_begin_press", start)
	view.call("_cancel_moved_press", start + Vector2(0, -60))
	assert_object(duel.get("_drag_preview")).is_not_null()

	# The AI acts mid-drag: the hand is rebuilt, the drag must not stay stuck on screen.
	state.active_player = 1
	duel.call("_refresh")
	assert_object(duel.get("_drag_preview")).is_null()
	assert_bool((duel.get("_drag_source") as Dictionary).is_empty()).is_true()
	view = (duel.get("_own_hand") as HBoxContainer).get_child(0) as CardView
	assert_bool(view.get("_draggable")).is_false()
	duel.queue_free()
	await get_tree().process_frame


func test_leader_ability_is_greyed_when_unusable_and_selected_by_tap_tap() -> void:
	var duel: Control = await _main_phase_duel_with_hand([], 2)
	var state: GameState = (duel.get("_match") as Match).get_state()
	state.player(1).board.add(CardInstance.new(CardDatabase.get_card(&"nibelung_miner"), 1, 952))
	duel.call("_refresh")
	var ability: Button = duel.get("_ability_button") as Button
	# Spear of Treaties costs 3: greyed with 2 Energy.
	assert_bool(ability.disabled).is_true()

	state.player(0).energy = 3
	duel.call("_refresh")
	assert_bool(ability.disabled).is_false()
	duel.call("_on_ability_pressed")
	assert_bool(duel.get("_selected_ability")).is_true()
	assert_str(String(ability.theme_type_variation)).is_equal("ButtonPrimary")
	var enemy_view: CardView = (duel.get("_enemy_board") as HFlowContainer).get_child(0) as CardView
	assert_str(String(enemy_view.get("_highlight"))).is_equal("target")

	duel.call("_on_ability_pressed")
	assert_bool(duel.get("_selected_ability")).is_false()
	assert_str(String(ability.theme_type_variation)).is_equal("")
	duel.queue_free()
	await get_tree().process_frame


func test_first_gotterdammerung_opens_an_explanation_closed_by_a_tap_only_once() -> void:
	var duel: Control = await _main_phase_duel_with_hand([], 2)
	var fx: DuelFx = duel.get("_fx") as DuelFx
	(duel.get("_pending_events") as Array).append(GameEvent.new(&"gotterdammerung_damage", 1, -1, -1, 1))
	duel.call("_play_fx", null)
	await get_tree().process_frame
	var panel: PanelContainer = duel.find_child("DoomPanel", true, false) as PanelContainer
	assert_object(panel).is_not_null()
	# No auto-close: it stays, and the AI waits, until the player taps.
	await get_tree().create_timer(0.5).timeout
	assert_object(duel.find_child("DoomPanel", true, false)).is_not_null()
	assert_bool(fx.is_busy()).is_true()

	# A tap outside the panel (on the dimmed overlay) closes it, like the button.
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	(duel.find_child("DoomOverlay", true, false) as ColorRect).gui_input.emit(release)
	await get_tree().process_frame
	assert_object(duel.find_child("DoomPanel", true, false)).is_null()
	assert_bool(fx.is_busy()).is_false()

	# Later Götterdämmerung damage does not open it again.
	(duel.get("_pending_events") as Array).append(GameEvent.new(&"gotterdammerung_damage", 0, -1, -1, 1))
	duel.call("_play_fx", null)
	await get_tree().process_frame
	assert_object(duel.find_child("DoomPanel", true, false)).is_null()
	duel.queue_free()
	await get_tree().process_frame


func test_gotterdammerung_countdown_follows_each_players_turns_and_triggers_the_popup() -> void:
	var duel: Control = await _main_phase_duel_with_hand([], 2)
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	var turn_label: Label = duel.get("_turn_label") as Label
	# Global turn 10 is only each player's 5th turn: no countdown yet.
	state.turn = 10
	state.player(0).turns_taken = 5
	duel.call("_refresh")
	assert_bool(turn_label.text.contains(tr("UI_DOOM_IN"))).is_false()
	state.player(0).turns_taken = 7
	duel.call("_refresh")
	assert_str(turn_label.text).contains("%s 3" % tr("UI_DOOM_IN"))

	# The AI ends its turn and the human starts their 10th: real engine event, popup opens.
	state.player(0).turns_taken = 9
	state.active_player = 1
	duel.call("_refresh")
	assert_bool(current_match.apply(EndTurnAction.new(1))).is_true()
	duel.call("_play_fx", null)
	await get_tree().process_frame
	assert_object(duel.find_child("DoomPanel", true, false)).is_not_null()
	assert_str(turn_label.text).contains(tr("UI_DOOM_TITLE"))
	(duel.find_child("DoomCloseButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	duel.queue_free()
	await get_tree().process_frame


func test_dragging_targeted_spells_onto_units_plays_them() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"freias_golden_apples", &"donners_hammer"], 6)
	var state: GameState = (duel.get("_match") as Match).get_state()
	var own: CardInstance = CardInstance.new(CardDatabase.get_card(&"fricka"), 0, 950)
	state.player(0).board.add(own)
	var enemy: CardInstance = CardInstance.new(CardDatabase.get_card(&"hoard_bearers"), 1, 952)
	state.player(1).board.add(enemy)
	duel.call("_refresh")
	await get_tree().process_frame
	var own_attack: int = own.attack
	var enemy_health: int = enemy.health

	# Buff spell dropped on an own unit.
	_drag_hand_card_onto(duel, 700, (duel.get("_own_board") as HFlowContainer).get_child(0) as CardView)
	await get_tree().process_frame
	assert_int(own.attack).is_equal(own_attack + 1)
	assert_object(state.player(0).hand.find(700)).is_null()

	# Damage spell dropped on an enemy unit.
	_drag_hand_card_onto(duel, 701, (duel.get("_enemy_board") as HFlowContainer).get_child(0) as CardView)
	await get_tree().process_frame
	assert_int(enemy.health).is_equal(enemy_health - 3)
	assert_object(state.player(0).hand.find(701)).is_null()
	duel.queue_free()
	await get_tree().process_frame


func _drag_hand_card_onto(duel: Control, uid: int, target: CardView) -> void:
	var view: CardView = duel.call("_find_view", uid) as CardView
	var start: Vector2 = view.get_global_rect().get_center()
	view.call("_begin_press", start)
	view.call("_cancel_moved_press", start + Vector2(0, -60))
	view.call("_end_press", target.get_global_rect().get_center())
