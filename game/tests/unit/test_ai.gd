extends GdUnitTestSuite

## Normal (GreedyAI) and Hard (MctsAI) opponents, and the hidden-information mask they work on.


func test_mask_hidden_redeals_the_enemy_hand_from_their_own_cards_only() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 901)
	var state: GameState = engine.get_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var enemy_before: Array[StringName] = _card_ids(state.player(0).hand.cards + state.player(0).deck.cards)
	var hand_before: Array[StringName] = _card_ids(state.player(0).hand.cards)
	var own_hand_before: Array[StringName] = _card_ids(state.player(1).hand.cards)
	var hash_before: String = engine.state_hash()

	var changed: bool = false
	for attempt: int in 5:
		var masked: GameState = AIPlayer.mask_hidden(state, 1, rng)
		var enemy: PlayerState = masked.player(0)
		assert_int(enemy.hand.size()).is_equal(hand_before.size())
		assert_array(_card_ids(enemy.hand.cards + enemy.deck.cards)).is_equal(enemy_before)
		assert_array(_card_ids(masked.player(1).hand.cards)).is_equal(own_hand_before)
		if _card_ids(enemy.hand.cards) != hand_before:
			changed = true
	assert_bool(changed).is_true()
	# The live state is never touched.
	assert_str(engine.state_hash()).is_equal(hash_before)


func test_easy_jobs_carry_no_state_copy() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 902)
	var state: GameState = engine.get_state()
	state.phase = GameState.Phase.MAIN
	state.active_player = 1
	var easy: Dictionary = AIPlayer.prepare(engine, 1, AIProfile.preset(AIProfile.Difficulty.EASY), 1)
	var hard: Dictionary = AIPlayer.prepare(engine, 1, AIProfile.preset(AIProfile.Difficulty.HARD), 1)
	assert_bool(easy.has("state")).is_false()
	assert_bool(hard.has("state")).is_true()
	assert_bool(hard["state"] == state).is_false()


func test_normal_and_hard_take_a_lethal_attack() -> void:
	for level: AIProfile.Difficulty in [AIProfile.Difficulty.NORMAL, AIProfile.Difficulty.HARD]:
		var engine: Match = _main_phase_match(903)
		var state: GameState = engine.get_state()
		state.player(0).life = 3
		var attacker := CardInstance.new(_unit(&"test_attacker", 3, 3), 1, 701)
		attacker.can_attack = true
		state.player(1).board.add(attacker)

		var selected: Dictionary = _choose(engine, level)

		assert_str(String(selected["type"])).is_equal("attack")
		assert_int(int(selected["target_player"])).is_equal(0)


func test_normal_does_not_throw_a_unit_into_a_bigger_one() -> void:
	var engine: Match = _main_phase_match(904)
	var state: GameState = engine.get_state()
	var small := CardInstance.new(_unit(&"test_small", 2, 2), 1, 711)
	small.can_attack = true
	state.player(1).board.add(small)
	state.player(0).board.add(CardInstance.new(_unit(&"test_big", 6, 6), 0, 712))

	var profile: AIProfile = AIProfile.preset(AIProfile.Difficulty.NORMAL)
	profile.noise = 0.0
	var selected: Dictionary = AIPlayer.choose(AIPlayer.prepare(engine, 1, profile, 3))

	assert_bool(String(selected["type"]) == "attack" and int(selected["target_uid"]) == 712).is_false()


func test_hard_stays_within_its_time_budget_and_plays_legal_actions() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"walsungs_starter"), CardDatabase.get_deck(&"valkyries_starter"), 905)
	var profile: AIProfile = AIProfile.preset(AIProfile.Difficulty.HARD)
	profile.time_budget_msec = 150
	var easy: AIProfile = AIProfile.preset(AIProfile.Difficulty.EASY)
	var decisions: int = 0
	while engine.get_state().phase != GameState.Phase.GAME_OVER and decisions < 40:
		var state: GameState = engine.get_state()
		var player_id: int = state.redraw_player if state.phase == GameState.Phase.REDRAW else state.active_player
		var started: int = Time.get_ticks_msec()
		var record: Dictionary = AIPlayer.choose(AIPlayer.prepare(engine, player_id, profile if player_id == 1 else easy, decisions))
		# One iteration may still be running when the budget runs out.
		assert_int(Time.get_ticks_msec() - started).is_less(profile.time_budget_msec + 250)
		assert_bool(engine.apply(Action.from_record(record))).is_true()
		decisions += 1


func _choose(engine: Match, level: AIProfile.Difficulty) -> Dictionary:
	var profile: AIProfile = AIProfile.preset(level)
	profile.max_iterations = 150
	profile.time_budget_msec = 0
	return AIPlayer.choose(AIPlayer.prepare(engine, 1, profile, 7))


## Player 1's main phase with empty boards and hand, nothing else to do.
func _main_phase_match(seed: int) -> Match:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), seed)
	var state: GameState = engine.get_state()
	state.phase = GameState.Phase.MAIN
	state.active_player = 1
	for player: PlayerState in state.players:
		player.board.cards.clear()
		player.redraw_done = true
	var own: PlayerState = state.player(1)
	own.hand.cards.clear()
	own.energy = 0
	own.leader_ability_used = true
	return engine


func _unit(id: StringName, attack: int, health: int) -> CardData:
	var data := CardData.new()
	data.id = id
	data.faction = &"nibelungs"
	data.type = CardData.Type.UNIT
	data.cost = 1
	data.attack = attack
	data.health = health
	return data


func _card_ids(cards: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardInstance in cards:
		ids.append(card.data.id)
	ids.sort()
	return ids
