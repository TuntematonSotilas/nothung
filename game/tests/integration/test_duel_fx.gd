extends GdUnitTestSuite

var _animation_speed: float


func before() -> void:
	_animation_speed = Settings.animation_speed
	Settings.animation_speed = 2.0


func after() -> void:
	Settings.animation_speed = _animation_speed


func test_spell_plays_over_the_old_board_then_refreshes() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"donners_hammer"], 4)
	var state: GameState = (duel.get("_match") as Match).get_state()
	state.player(1).board.add(CardInstance.new(CardDatabase.get_card(&"nibelung_miner"), 1, 952))
	duel.call("_refresh")
	await get_tree().process_frame
	var fx: DuelFx = duel.get("_fx") as DuelFx

	var play: PlayCardAction = duel.call("_find_play_action", 700, 952) as PlayCardAction
	assert_object(play).is_not_null()
	duel.call("_apply_action", play)
	# The rules state is already resolved; the screen still shows the old board while the spell flies.
	assert_int(state.player(0).hand.size()).is_equal(0)
	assert_int(state.player(1).board.size()).is_equal(0)
	assert_bool(fx.is_busy()).is_true()
	assert_int(fx.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_object(fx.find_child("FxCard", false, false)).is_not_null()
	assert_int((duel.get("_enemy_board") as HFlowContainer).get_child_count()).is_equal(1)

	await _wait_idle(fx)
	assert_int((duel.get("_enemy_board") as HFlowContainer).get_child_count()).is_equal(0)
	assert_int(fx.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await get_tree().process_frame
	assert_object(fx.find_child("FxCard", false, false)).is_null()
	duel.queue_free()
	await get_tree().process_frame


func test_lethal_attack_lunges_then_the_unit_dies() -> void:
	var duel: Control = await _main_phase_duel_with_hand([], 2)
	var state: GameState = (duel.get("_match") as Match).get_state()
	var attacker: CardInstance = CardInstance.new(CardDatabase.get_card(&"donner"), 0, 950)
	attacker.can_attack = true
	state.player(0).board.add(attacker)
	state.player(1).board.add(CardInstance.new(CardDatabase.get_card(&"nibelung_miner"), 1, 952))
	duel.call("_refresh")
	await get_tree().process_frame
	var fx: DuelFx = duel.get("_fx") as DuelFx
	var attacker_view: CardView = (duel.get("_own_board") as HFlowContainer).get_child(0) as CardView

	duel.call("_apply_action", duel.call("_find_attack_action", 950, 952, -1))
	assert_int(state.player(1).board.size()).is_equal(0)
	# The real attacker is hidden while its ghost lunges.
	assert_float(attacker_view.modulate.a).is_equal(0.0)
	assert_object(fx.find_child("FxCard", false, false)).is_not_null()

	await _wait_idle(fx)
	assert_int((duel.get("_enemy_board") as HFlowContainer).get_child_count()).is_equal(0)
	var own_view: CardView = (duel.get("_own_board") as HFlowContainer).get_child(0) as CardView
	assert_float(own_view.modulate.a).is_equal(1.0)
	duel.queue_free()
	await get_tree().process_frame


func test_drawn_card_is_revealed_when_its_ghost_lands() -> void:
	var duel: Control = await _main_phase_duel_with_hand([&"fricka"], 2)
	var state: GameState = (duel.get("_match") as Match).get_state()
	var fx: DuelFx = duel.get("_fx") as DuelFx
	state.player(0).hand.add(CardInstance.new(CardDatabase.get_card(&"freia"), 0, 800))
	(duel.get("_pending_events") as Array).append(GameEvent.new(&"card_drawn", 0, 800))
	duel.call("_play_fx", null)
	await get_tree().process_frame
	await get_tree().process_frame
	var drawn: CardView = duel.call("_find_view", 800) as CardView
	assert_object(drawn).is_not_null()
	assert_float(drawn.modulate.a).is_equal(0.0)
	assert_bool(fx.is_busy()).is_true()

	await _wait_idle(fx)
	assert_float(drawn.modulate.a).is_equal(1.0)
	duel.queue_free()
	await get_tree().process_frame


func test_instant_speed_refreshes_without_animation() -> void:
	Settings.animation_speed = 0.0
	var duel: Control = await _main_phase_duel_with_hand([&"wotans_ravens"], 2)
	var fx: DuelFx = duel.get("_fx") as DuelFx
	duel.call("_apply_action", duel.call("_find_play_action", 700, -1))
	assert_bool(fx.is_busy()).is_false()
	assert_int((duel.get("_own_board") as HFlowContainer).get_child_count()).is_equal(1)
	Settings.animation_speed = 2.0
	duel.queue_free()
	await get_tree().process_frame


func _wait_idle(fx: DuelFx) -> void:
	var frames: int = 0
	while fx.is_busy() and frames < 600:
		await get_tree().process_frame
		frames += 1
	assert_bool(fx.is_busy()).is_false()


func _main_phase_duel_with_hand(card_ids: Array[StringName], energy: int) -> Control:
	var duel: Control = (load("res://scenes/screens/duel.tscn") as PackedScene).instantiate() as Control
	add_child(duel)
	await get_tree().process_frame
	await get_tree().process_frame
	var state: GameState = (duel.get("_match") as Match).get_state()
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
