extends GdUnitTestSuite

const MATCH_COUNT: int = 40
const ACTION_LIMIT: int = 300


func test_easy_ai_soak_completes_matches_with_legal_actions() -> void:
	var deck_wins: Dictionary = {"gods_starter": 0, "nibelungs_starter": 0}
	var draws: int = 0
	var total_turns: int = 0
	var total_actions: int = 0

	for match_index: int in MATCH_COUNT:
		var gods_first: bool = match_index % 2 == 0
		var first_deck_id: StringName = &"gods_starter" if gods_first else &"nibelungs_starter"
		var second_deck_id: StringName = &"nibelungs_starter" if gods_first else &"gods_starter"
		var engine := Match.new(
			CardDatabase.get_deck(first_deck_id),
			CardDatabase.get_deck(second_deck_id),
			20261000 + match_index
		)
		var action_count: int = 0

		while engine.get_state().phase != GameState.Phase.GAME_OVER and action_count < ACTION_LIMIT:
			var state: GameState = engine.get_state()
			var player_id: int = state.redraw_player if state.phase == GameState.Phase.REDRAW else state.active_player
			var legal: Array[Action] = engine.get_legal_actions(player_id)
			var records: Array[Dictionary] = EasyAI.prepare_actions(state, legal)

			var selected: Action = Action.from_record(EasyAI.choose_action(records))
			assert_object(selected).override_failure_message(
				"AI returned no action in match %d, turn %d" % [match_index, state.turn]
			).is_not_null()
			assert_bool(engine.is_legal(selected)).override_failure_message(
				"AI returned an illegal action in match %d, turn %d: %s" % [
					match_index,
					state.turn,
					selected.to_record(),
				]
			).is_true()
			assert_bool(engine.apply(selected)).override_failure_message(
				"Rules engine rejected AI action in match %d, turn %d" % [match_index, state.turn]
			).is_true()
			action_count += 1

		var result: GameState = engine.get_state()
		assert_int(result.phase).override_failure_message(
			"AI match %d did not finish within %d actions" % [match_index, ACTION_LIMIT]
		).is_equal(GameState.Phase.GAME_OVER)
		total_actions += action_count
		total_turns += result.turn
		if result.winner < 0:
			draws += 1
		else:
			var winning_deck_id: StringName = first_deck_id if result.winner == 0 else second_deck_id
			deck_wins[winning_deck_id] = int(deck_wins[winning_deck_id]) + 1

	print("AI soak: %d matches, average %.1f turns, %.1f actions; gods %d wins, nibelungs %d wins, %d draws." % [
		MATCH_COUNT,
		float(total_turns) / MATCH_COUNT,
		float(total_actions) / MATCH_COUNT,
		int(deck_wins["gods_starter"]),
		int(deck_wins["nibelungs_starter"]),
		draws,
	])
	print("AI soak win rate: gods_starter %.1f%%, nibelungs_starter %.1f%%." % [
		float(deck_wins["gods_starter"]) * 100.0 / MATCH_COUNT,
		float(deck_wins["nibelungs_starter"]) * 100.0 / MATCH_COUNT,
	])
