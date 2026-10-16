extends GdUnitTestSuite


func test_full_scripted_match_replays_to_the_same_state_hash() -> void:
	var first: Dictionary = _play_to_completion(20261016)
	var replay: Dictionary = _replay_recorded(20261016, first["action_records"])
	assert_int(int(first["winner"])).is_between(0, 1)
	assert_int(int(first["actions"])).is_less(100)
	assert_int(int(first["turn"])).is_greater(1)
	assert_str(String(first["hash"])).is_equal(String(replay["hash"]))
	assert_array(first["events"]).is_equal(replay["events"])


func _play_to_completion(seed: int) -> Dictionary:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), seed)
	var events: Array[Dictionary] = []
	engine.event_emitted.connect(func(event: GameEvent) -> void:
		events.append(event.to_record())
	)
	var actions: Array[Dictionary] = []
	var action_zero := RedrawAction.new(0)
	assert_bool(engine.apply(action_zero)).is_true()
	actions.append(action_zero.to_record())
	var action_one := RedrawAction.new(1)
	assert_bool(engine.apply(action_one)).is_true()
	actions.append(action_one.to_record())
	var actions_applied: int = 2

	while engine.get_state().phase != GameState.Phase.GAME_OVER and actions_applied < 100:
		var active: int = engine.get_state().active_player
		var legal_actions := engine.get_legal_actions(active)
		var selected: Action
		for action: Action in legal_actions:
			if action is PlayCardAction:
				selected = action
				break
		if selected == null:
			for action: Action in legal_actions:
				if action is AttackAction and (action as AttackAction).target_player == 1 - active:
					selected = action
					break
		if selected == null:
			for action: Action in legal_actions:
				if action is EndTurnAction:
					selected = action
					break
		assert_object(selected).is_not_null()
		assert_bool(engine.apply(selected)).is_true()
		actions.append(selected.to_record())
		actions_applied += 1

	assert_int(engine.get_state().phase).is_equal(GameState.Phase.GAME_OVER)
	return {
		"winner": engine.get_state().winner,
		"turn": engine.get_state().turn,
		"actions": actions_applied,
		"action_records": actions,
		"hash": engine.state_hash(),
		"events": events,
	}


func _replay_recorded(seed: int, records: Array) -> Dictionary:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), seed)
	var events: Array[Dictionary] = []
	engine.event_emitted.connect(func(event: GameEvent) -> void:
		events.append(event.to_record())
	)
	for record: Variant in records:
		var action := Action.from_record(record as Dictionary)
		assert_object(action).is_not_null()
		assert_bool(engine.apply(action)).is_true()
	assert_int(engine.get_state().phase).is_equal(GameState.Phase.GAME_OVER)
	return {
		"hash": engine.state_hash(),
		"events": events,
	}


func _deck(faction: StringName) -> DeckData:
	var deck := DeckData.new()
	var leader := LeaderData.new()
	leader.id = StringName(String(faction) + "_leader")
	leader.faction = faction
	deck.leader = leader
	for index: int in 10:
		var card := CardData.new()
		card.id = StringName("%s_unit_%d" % [faction, index])
		card.faction = faction
		card.type = CardData.Type.UNIT
		card.cost = 0
		card.attack = 1
		card.health = 20
		card.keywords.append(&"charge")
		deck.cards.append(card)
		deck.cards.append(card)
	return deck
