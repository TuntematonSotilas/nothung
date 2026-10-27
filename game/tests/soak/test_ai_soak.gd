extends GdUnitTestSuite

const MATCH_COUNT: int = 40
const ACTION_LIMIT: int = 300
## Every starter deck meets every other one.
const PAIRINGS: Array = [
	[&"gods_starter", &"nibelungs_starter"],
	[&"walsungs_starter", &"gods_starter"],
	[&"walsungs_starter", &"nibelungs_starter"],
	[&"valkyries_starter", &"gods_starter"],
	[&"valkyries_starter", &"nibelungs_starter"],
	[&"valkyries_starter", &"walsungs_starter"],
	# Neutral cards are in no starter deck: a test deck plays each of them once.
	[&"neutral_test", &"gods_starter"],
	[&"neutral_test", &"nibelungs_starter"],
]


func test_easy_ai_soak_completes_matches_with_legal_actions() -> void:
	for pairing: Array in PAIRINGS:
		_soak(pairing[0], pairing[1])


func _soak(deck_a: StringName, deck_b: StringName) -> void:
	var deck_wins: Dictionary = {deck_a: 0, deck_b: 0}
	var draws: int = 0
	var total_turns: int = 0
	var total_actions: int = 0

	for match_index: int in MATCH_COUNT:
		# Alternate who plays first.
		var a_first: bool = match_index % 2 == 0
		var first_deck_id: StringName = deck_a if a_first else deck_b
		var second_deck_id: StringName = deck_b if a_first else deck_a
		var engine := Match.new(
			_deck(first_deck_id),
			_deck(second_deck_id),
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
				"AI returned no action in %s vs %s match %d, turn %d" % [deck_a, deck_b, match_index, state.turn]
			).is_not_null()
			assert_bool(engine.is_legal(selected)).override_failure_message(
				"AI returned an illegal action in %s vs %s match %d, turn %d: %s" % [
					deck_a,
					deck_b,
					match_index,
					state.turn,
					selected.to_record(),
				]
			).is_true()
			assert_bool(engine.apply(selected)).override_failure_message(
				"Rules engine rejected AI action in %s vs %s match %d, turn %d" % [deck_a, deck_b, match_index, state.turn]
			).is_true()
			action_count += 1

		var result: GameState = engine.get_state()
		assert_int(result.phase).override_failure_message(
			"AI match %d (%s vs %s) did not finish within %d actions" % [match_index, deck_a, deck_b, ACTION_LIMIT]
		).is_equal(GameState.Phase.GAME_OVER)
		total_actions += action_count
		total_turns += result.turn
		if result.winner < 0:
			draws += 1
		else:
			var winning_deck_id: StringName = first_deck_id if result.winner == 0 else second_deck_id
			deck_wins[winning_deck_id] = int(deck_wins[winning_deck_id]) + 1

	print("AI soak %s vs %s: %d matches, average %.1f turns, %.1f actions; %d / %d wins, %d draws (%.1f%% / %.1f%%)." % [
		deck_a,
		deck_b,
		MATCH_COUNT,
		float(total_turns) / MATCH_COUNT,
		float(total_actions) / MATCH_COUNT,
		int(deck_wins[deck_a]),
		int(deck_wins[deck_b]),
		draws,
		float(deck_wins[deck_a]) * 100.0 / MATCH_COUNT,
		float(deck_wins[deck_b]) * 100.0 / MATCH_COUNT,
	])


## A starter deck, or "neutral_test": Alberich with each of the 20 Neutral cards once.
func _deck(deck_id: StringName) -> DeckData:
	if deck_id != &"neutral_test":
		return CardDatabase.get_deck(deck_id)
	var deck := DeckData.new()
	deck.id = deck_id
	deck.leader = CardDatabase.get_leader(&"alberich")
	for card_id: StringName in [
		&"woglinde", &"woodbird", &"wellgunde", &"flosshilde", &"hundings_kinsmen",
		&"gibichung_vassal", &"hunding", &"gutrune", &"gunther", &"erda",
		&"hagen", &"fasolt", &"fafner", &"rhinegold_lament", &"giants_wage",
		&"the_norns", &"hagens_call", &"valhalla_in_flames", &"the_rhinegold", &"hagens_spear",
	]:
		deck.cards.append(CardDatabase.get_card(card_id))
	return deck
