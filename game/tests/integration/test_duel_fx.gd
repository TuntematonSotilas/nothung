extends GdUnitTestSuite

var _animation_speed: float
var _match_path: String


func before() -> void:
	_animation_speed = Settings.animation_speed
	# The duel saves the match in progress: keep the real file out of the tests.
	_match_path = SaveManager.match_path
	SaveManager.match_path = create_temp_dir("duel_%d" % Time.get_ticks_usec()) + "/current_match.json"
	Settings.animation_speed = 2.0


func after() -> void:
	Settings.animation_speed = _animation_speed
	SaveManager.match_path = _match_path


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


func test_gotterdammerung_damage_shows_its_name_under_the_amount() -> void:
	var fx: DuelFx = auto_free(DuelFx.new())
	add_child(fx)
	fx.size = Vector2(1080, 1920)
	fx.play_damage(Rect2(100, 100, 300, 200), 2, DuelFx.DOOM_CAPTION, true)
	assert_str((fx.find_child("DamageAmount", true, false) as Label).text).is_equal("-2")
	assert_str((fx.find_child("DamageCaption", true, false) as Label).text).is_equal("Götterdämmerung")
	fx.play_damage(Rect2(100, 400, 300, 200), 1)
	assert_int(fx.find_children("DamageCaption", "", true, false).size()).is_equal(1)


func test_an_artifact_names_itself_on_the_damage_it_deals_at_the_start_of_a_turn() -> void:
	var duel: Control = await _main_phase_duel_with_hand([], 0)
	var current_match: Match = duel.get("_match") as Match
	var state: GameState = current_match.get_state()
	state.player(0).artifacts.add(CardInstance.new(CardDatabase.get_card(&"wotans_spear"), 0, 960))
	var events: Array[GameEvent] = [GameEvent.new(&"damage_dealt", 0, 960, -1, 1)]
	var end_turn := EndTurnAction.new(1)
	assert_str(duel.call("_automatic_source_name", events[0], end_turn)).is_equal(tr("CARD_WOTANS_SPEAR_NAME"))
	# Not for an attack, nor for the card just played.
	assert_str(duel.call("_automatic_source_name", events[0], AttackAction.new(0, 960, -1, 1))).is_empty()
	assert_str(duel.call("_automatic_source_name", events[0], PlayCardAction.new(0, 960))).is_empty()
	duel.queue_free()
	await get_tree().process_frame
