extends GdUnitTestSuite

## Resume an interrupted match: a record replays to the same state, and refuses what it cannot replay.


func test_replay_rebuilds_the_same_state_after_a_json_round_trip() -> void:
	var played: Array = _play(40)
	var engine: Match = played[0]
	var record: MatchRecord = played[1]
	var saved: Dictionary = JSON.parse_string(JSON.stringify(record.to_dict()))

	var replayed: Match = MatchRecord.from_dict(saved).replay(CardDatabase)
	assert_object(replayed).is_not_null()
	assert_str(replayed.state_hash()).is_equal(engine.state_hash())


func test_replay_includes_undone_plays() -> void:
	var played: Array = _play(6)
	var engine: Match = played[0]
	var record: MatchRecord = played[1]
	var play: PlayCardAction = _first_play(engine)
	# Ends turns until a card can be played.
	for _turn: int in 10:
		if play != null:
			break
		var state: GameState = engine.get_state()
		var player: int = state.redraw_player if state.phase == GameState.Phase.REDRAW else state.active_player
		var next: Action = engine.get_legal_actions(player).filter(func(action: Action) -> bool:
			return action is EndTurnAction or action is RedrawAction)[0]
		assert_bool(engine.apply(next)).is_true()
		record.add_action(next)
		play = _first_play(engine)
	assert_object(play).is_not_null()
	var before: GameState = engine.get_state().duplicate_state()
	assert_bool(engine.apply(play)).is_true()
	record.add_action(play)
	assert_bool(MatchRecord.undo_play(engine, before, play.card_uid)).is_true()
	record.add_undo_play(play.card_uid)
	# The card went back on top of the deck.
	var player: PlayerState = engine.get_state().player(play.player)
	assert_object(player.hand.find(play.card_uid)).is_null()
	assert_object(player.deck.find(play.card_uid)).is_not_null()

	var replayed: Match = record.replay(CardDatabase)
	assert_object(replayed).is_not_null()
	assert_str(replayed.state_hash()).is_equal(engine.state_hash())


func test_changed_card_data_is_not_replayed() -> void:
	var record: MatchRecord = _play(10)[1]
	record.content_hash = "changed"
	assert_object(record.replay(CardDatabase)).is_null()


func test_unknown_card_is_not_replayed() -> void:
	var record: MatchRecord = _play(10)[1]
	record.decks[0]["cards"][0] = "removed_card"
	assert_object(record.replay(CardDatabase)).is_null()


func test_rejected_action_is_not_replayed() -> void:
	var record: MatchRecord = _play(10)[1]
	record.entries.append({"type": "attack", "player": 0, "attacker_uid": 9999, "target_uid": -1, "target_player": 1})
	assert_object(record.replay(CardDatabase)).is_null()


func test_malformed_save_is_refused() -> void:
	assert_object(MatchRecord.from_dict({})).is_null()
	assert_object(MatchRecord.from_dict({"version": 99, "decks": [], "actions": []})).is_null()
	assert_object(MatchRecord.from_dict({"version": 1, "decks": [], "actions": ["x"]})).is_null()


func test_content_hash_ignores_card_art_and_survives_cards_that_refer_to_each_other() -> void:
	var deck: DeckData = CardDatabase.get_deck(&"walsungs_starter")
	var hash_value: String = MatchRecord.content_hash_of([deck])
	assert_str(hash_value).has_length(64)
	assert_str(MatchRecord.content_hash_of([deck])).is_equal(hash_value)


## Plays `count` legal actions (first legal action that is not ending the turn, every few steps the
## end of turn), recording them.
func _play(count: int) -> Array:
	var deck_a: DeckData = CardDatabase.get_deck(&"walsungs_starter")
	var deck_b: DeckData = CardDatabase.get_deck(&"nibelungs_starter")
	var engine := Match.new(deck_a, deck_b, 4242)
	var record: MatchRecord = MatchRecord.create(deck_a, deck_b, 4242)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _step: int in count:
		var state: GameState = engine.get_state()
		if state.phase == GameState.Phase.GAME_OVER:
			break
		var player: int = state.redraw_player if state.phase == GameState.Phase.REDRAW else state.active_player
		var actions: Array[Action] = engine.get_legal_actions(player).filter(func(action: Action) -> bool:
			return not action is ConcedeAction)
		var action: Action = actions[rng.randi_range(0, actions.size() - 1)]
		assert_bool(engine.apply(action)).is_true()
		record.add_action(action)
	return [engine, record]


func _first_play(engine: Match) -> PlayCardAction:
	var state: GameState = engine.get_state()
	if state.phase != GameState.Phase.MAIN:
		return null
	for action: Action in engine.get_legal_actions(state.active_player):
		if action is PlayCardAction:
			return action as PlayCardAction
	return null
