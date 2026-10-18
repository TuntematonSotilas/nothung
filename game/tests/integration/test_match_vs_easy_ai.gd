extends GdUnitTestSuite


func test_starter_match_completes_against_easy_ai() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 20261016)
	assert_bool(engine.apply(RedrawAction.new(0))).is_true()
	assert_bool(engine.apply(RedrawAction.new(1))).is_true()
	var action_count: int = 2

	while engine.get_state().phase != GameState.Phase.GAME_OVER and action_count < 200:
		var player: int = engine.get_state().active_player
		var legal: Array[Action] = engine.get_legal_actions(player)
		var selected: Action
		if player == 1:
			var records: Array[Dictionary] = EasyAI.prepare_actions(engine.get_state(), legal)
			var worker: Thread = Thread.new()
			assert_int(worker.start(EasyAI.choose_action.bind(records))).is_equal(OK)
			selected = Action.from_record(worker.wait_to_finish())
		else:
			selected = _choose_human_action(legal)
		assert_object(selected).is_not_null()
		assert_bool(engine.apply(selected)).is_true()
		action_count += 1

	assert_int(engine.get_state().phase).is_equal(GameState.Phase.GAME_OVER)
	assert_int(engine.get_state().winner).is_between(-1, 1)
	assert_int(action_count).is_less(200)


func _choose_human_action(legal: Array[Action]) -> Action:
	for action: Action in legal:
		if action is PlayCardAction:
			return action
	for action: Action in legal:
		if action is AttackAction:
			return action
	for action: Action in legal:
		if action is EndTurnAction:
			return action
	return null
