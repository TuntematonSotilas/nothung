extends GdUnitTestSuite


func test_match_initializes_seeded_decks_and_completes_redraw() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 417)
	var initial := engine.get_state()
	assert_int(initial.players[0].hand.size() + initial.players[1].hand.size()).is_equal(9)
	assert_int(initial.active_player).is_between(0, 1)
	assert_int(engine.get_legal_actions(0).size()).is_equal(17)
	assert_array(engine.get_legal_actions(1)).is_empty()

	assert_bool(engine.apply(RedrawAction.new(0))).is_true()
	assert_int(initial.phase).is_equal(GameState.Phase.REDRAW)
	assert_bool(engine.apply(RedrawAction.new(1))).is_true()
	assert_int(initial.phase).is_equal(GameState.Phase.MAIN)
	assert_int(initial.turn).is_equal(1)
	assert_int(initial.player(initial.active_player).energy).is_equal(Match.FIRST_TURN_MAX_ENERGY)
	assert_int(initial.player(1 - initial.active_player).opening_energy).is_equal(1)
	var second_player: int = 1 - initial.active_player
	assert_bool(engine.apply(EndTurnAction.new(initial.active_player))).is_true()
	assert_int(initial.player(second_player).energy).is_equal(Match.FIRST_TURN_MAX_ENERGY + 1)


func test_generated_card_catalogue_provides_valid_starter_decks() -> void:
	assert_int(CardDatabase.card_count()).is_equal(21)
	var gods_deck: DeckData = CardDatabase.get_deck(&"gods_starter")
	var nibelungs_deck: DeckData = CardDatabase.get_deck(&"nibelungs_starter")
	assert_object(gods_deck).is_not_null()
	assert_object(nibelungs_deck).is_not_null()
	assert_int(gods_deck.cards.size()).is_equal(20)
	assert_int(nibelungs_deck.cards.size()).is_equal(20)
	assert_int(CardDatabase.get_card(&"loge").abilities[0].effects[0].amount).is_equal(2)
	assert_int(CardDatabase.get_leader(&"wotan").ability.cost).is_equal(3)

	var engine := Match.new(gods_deck, nibelungs_deck, 20261016)
	assert_int(engine.get_state().phase).is_equal(GameState.Phase.REDRAW)


func test_easy_ai_selects_a_legal_action_on_a_worker_thread() -> void:
	var candidates: Array[Dictionary] = [
		{"type": "end_turn", "player": 1},
		{"type": "attack", "player": 1, "attacker_uid": 10, "target_uid": -1, "target_player": 0},
		{"type": "play_card", "player": 1, "card_uid": 20, "target_uid": -1, "target_player": -1},
	]
	var worker: Thread = Thread.new()
	assert_int(worker.start(EasyAI.choose_action.bind(candidates))).is_equal(OK)
	var selected: Dictionary = worker.wait_to_finish()
	assert_str(String(selected["type"])).is_equal("play_card")
	assert_int(int(selected["card_uid"])).is_equal(20)


func test_easy_ai_prefers_a_better_unit_over_the_first_playable_card() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 501)
	var state: GameState = engine.get_state()
	state.phase = GameState.Phase.MAIN
	state.active_player = 1
	var player: PlayerState = state.player(1)
	player.energy = 5
	player.leader_ability_used = true
	player.hand.cards.clear()

	var weak_data: CardData = CardData.new()
	weak_data.id = &"weak_test_unit"
	weak_data.faction = &"nibelungs"
	weak_data.type = CardData.Type.UNIT
	weak_data.cost = 1
	weak_data.attack = 1
	weak_data.health = 1
	var strong_data: CardData = CardData.new()
	strong_data.id = &"strong_test_unit"
	strong_data.faction = &"nibelungs"
	strong_data.type = CardData.Type.UNIT
	strong_data.cost = 2
	strong_data.attack = 4
	strong_data.health = 4
	player.hand.add(CardInstance.new(weak_data, 1, 601))
	player.hand.add(CardInstance.new(strong_data, 1, 602))

	var legal: Array[Action] = engine.get_legal_actions(1)
	var records: Array[Dictionary] = EasyAI.prepare_actions(state, legal)
	var selected: Dictionary = EasyAI.choose_action(records)

	assert_str(String(selected["type"])).is_equal("play_card")
	assert_int(int(selected["card_uid"])).is_equal(602)


func test_easy_ai_redraws_expensive_cards_and_keeps_cheap_units() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 503)
	var state: GameState = engine.get_state()
	state.redraw_player = 1
	var player: PlayerState = state.player(1)
	player.hand.cards.clear()

	var cheap_data: CardData = CardData.new()
	cheap_data.id = &"cheap_test_unit"
	cheap_data.faction = &"nibelungs"
	cheap_data.type = CardData.Type.UNIT
	cheap_data.cost = 1
	cheap_data.attack = 2
	cheap_data.health = 2
	var expensive_data: CardData = CardData.new()
	expensive_data.id = &"expensive_test_unit"
	expensive_data.faction = &"nibelungs"
	expensive_data.type = CardData.Type.UNIT
	expensive_data.cost = 5
	expensive_data.attack = 5
	expensive_data.health = 5
	player.hand.add(CardInstance.new(cheap_data, 1, 801))
	player.hand.add(CardInstance.new(expensive_data, 1, 802))

	var legal: Array[Action] = engine.get_legal_actions(1)
	var records: Array[Dictionary] = EasyAI.prepare_actions(state, legal)
	var selected: Dictionary = EasyAI.choose_action(records)

	assert_str(String(selected["type"])).is_equal("redraw")
	assert_array(selected["card_uids"]).is_equal([802])


func test_easy_ai_takes_a_lethal_attack_before_playing_a_card() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 502)
	var state: GameState = engine.get_state()
	state.phase = GameState.Phase.MAIN
	state.active_player = 1
	var player: PlayerState = state.player(1)
	player.energy = 5
	player.hand.cards.clear()
	var unit_data: CardData = CardData.new()
	unit_data.id = &"test_attacker"
	unit_data.faction = &"nibelungs"
	unit_data.type = CardData.Type.UNIT
	unit_data.cost = 1
	unit_data.attack = 3
	unit_data.health = 3
	var attacker: CardInstance = CardInstance.new(unit_data, 1, 701)
	attacker.can_attack = true
	player.board.add(attacker)
	var playable_data: CardData = unit_data.duplicate() as CardData
	playable_data.id = &"test_playable"
	player.hand.add(CardInstance.new(playable_data, 1, 702))
	state.player(0).life = 3

	var legal: Array[Action] = engine.get_legal_actions(1)
	var records: Array[Dictionary] = EasyAI.prepare_actions(state, legal)
	var selected: Dictionary = EasyAI.choose_action(records)

	assert_str(String(selected["type"])).is_equal("attack")
	assert_int(int(selected["target_player"])).is_equal(0)


func test_invalid_actions_do_not_mutate_state() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 54)
	var before := engine.state_hash()
	assert_bool(engine.apply(EndTurnAction.new(0))).is_false()
	assert_bool(engine.apply(RedrawAction.new(1))).is_false()
	assert_str(engine.state_hash()).is_equal(before)


func test_deck_validation_rejects_excess_copies_and_foreign_factions() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 49)
	var invalid_copy_deck := _deck(&"gods")
	invalid_copy_deck.cards[2].id = invalid_copy_deck.cards[0].id
	assert_bool(engine._valid_deck(invalid_copy_deck)).is_false()
	var invalid_faction_deck := _deck(&"gods")
	invalid_faction_deck.cards[0].faction = &"valkyries"
	assert_bool(engine._valid_deck(invalid_faction_deck)).is_false()


func test_state_duplication_copies_runtime_cards_and_rng() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 421)
	var original := engine.get_state()
	var copy := original.duplicate_state()
	var original_card: CardInstance = original.player(0).hand.cards[0]
	var copied_card: CardInstance = copy.player(0).hand.cards[0]
	assert_bool(original_card == copied_card).is_false()
	copied_card.health -= 1
	assert_int(original_card.health).is_equal(original_card.data.health)
	assert_int(copy.rng.randi()).is_equal(original.rng.randi())


func test_actions_round_trip_through_replay_records() -> void:
	var original := PlayCardAction.new(1, 23, 45)
	var restored := Action.from_record(original.to_record())
	assert_bool(restored is PlayCardAction).is_true()
	assert_int((restored as PlayCardAction).player).is_equal(1)
	assert_int((restored as PlayCardAction).card_uid).is_equal(23)
	assert_int((restored as PlayCardAction).target_uid).is_equal(45)


func test_guard_blocks_attacks_unless_attacker_has_flying() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 27)
	_prepare_main_phase(engine)
	var attacker := _unit(&"attacker", 0, 101, 3, 4, [&"charge"])
	attacker.can_attack = true
	var guard := _unit(&"guard", 1, 201, 1, 5, [&"guard"])
	var other := _unit(&"other", 1, 202, 1, 5, [])
	engine.get_state().player(0).board.add(attacker)
	engine.get_state().player(1).board.add(guard)
	engine.get_state().player(1).board.add(other)

	assert_bool(engine.is_legal(AttackAction.new(0, attacker.uid, guard.uid))).is_true()
	assert_bool(engine.is_legal(AttackAction.new(0, attacker.uid, other.uid))).is_false()
	assert_bool(engine.is_legal(AttackAction.new(0, attacker.uid, -1, 1))).is_false()

	attacker.statuses.append(&"flying")
	assert_bool(engine.is_legal(AttackAction.new(0, attacker.uid, other.uid))).is_true()
	assert_bool(engine.is_legal(AttackAction.new(0, attacker.uid, -1, 1))).is_true()


func test_simultaneous_leader_damage_produces_a_draw() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 903)
	_prepare_main_phase(engine)
	var spell_data := CardData.new()
	spell_data.id = &"ending"
	spell_data.faction = &"gods"
	spell_data.type = CardData.Type.SPELL
	var ability := AbilityData.new()
	ability.trigger = &"on_play"
	var damage := EffectData.new()
	damage.kind = EffectData.Kind.DEAL_DAMAGE
	damage.target = EffectData.Target.ALL_LEADERS
	damage.amount = 20
	ability.effects.append(damage)
	spell_data.abilities.append(ability)
	var spell := CardInstance.new(spell_data, 0, 119)
	engine.get_state().player(0).hand.add(spell)

	assert_bool(engine.apply(PlayCardAction.new(0, spell.uid))).is_true()
	assert_int(engine.get_state().phase).is_equal(GameState.Phase.GAME_OVER)
	assert_int(engine.get_state().winner).is_equal(-1)


func test_relic_requires_matching_bearer_and_moves_to_graveyard_on_death() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 88)
	_prepare_main_phase(engine)
	var bearer := _unit(&"walsung", 0, 110, 1, 1, [])
	bearer.data.subtypes.append(&"walsung")
	engine.get_state().player(0).board.add(bearer)
	var wrong_bearer := _unit(&"dwarf", 0, 111, 1, 5, [])
	wrong_bearer.data.subtypes.append(&"dwarf")
	engine.get_state().player(0).board.add(wrong_bearer)

	var relic_data := CardData.new()
	relic_data.id = &"nothung"
	relic_data.faction = &"neutral"
	relic_data.type = CardData.Type.ARTIFACT
	relic_data.subtypes.append(&"relic")
	relic_data.bearer.append(&"walsung")
	relic_data.relic_attack_bonus = 2
	var relic := CardInstance.new(relic_data, 0, 112)
	engine.get_state().player(0).hand.add(relic)

	assert_bool(engine.is_legal(PlayCardAction.new(0, relic.uid, wrong_bearer.uid))).is_false()
	assert_bool(engine.apply(PlayCardAction.new(0, relic.uid, bearer.uid))).is_true()
	assert_int(bearer.attack).is_equal(3)
	assert_object(bearer.relic).is_not_null()

	var attacker := _unit(&"killer", 1, 210, 3, 5, [&"charge"])
	attacker.can_attack = true
	engine.get_state().player(1).board.add(attacker)
	engine.get_state().active_player = 1
	assert_bool(engine.apply(AttackAction.new(1, attacker.uid, bearer.uid))).is_true()
	assert_int(engine.get_state().player(0).graveyard.size()).is_equal(2)
	assert_bool(engine.get_state().player(0).graveyard.find(relic.uid) != null).is_true()
	assert_bool(engine.get_state().player(0).board.find(bearer.uid) == null).is_true()


func test_conditional_forge_upgrades_a_relic_onto_its_required_bearer() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 119)
	_prepare_main_phase(engine)
	var siegfried := _unit(&"siegfried", 0, 130, 5, 5, [])
	siegfried.data.subtypes.append(&"walsung")
	engine.get_state().player(0).board.add(siegfried)

	var reforged := CardData.new()
	reforged.id = &"nothung"
	reforged.faction = &"neutral"
	reforged.type = CardData.Type.ARTIFACT
	reforged.subtypes.append(&"relic")
	reforged.bearer.append(&"walsung")
	reforged.relic_attack_bonus = 3
	var broken := CardData.new()
	broken.id = &"nothung_broken"
	broken.faction = &"neutral"
	broken.type = CardData.Type.ARTIFACT
	broken.cost = 1
	broken.subtypes.append(&"relic")
	broken.attachable = false
	var forge_condition := ConditionData.new()
	forge_condition.kind = ConditionData.Kind.CONTROLS_CARD
	forge_condition.card_id = &"siegfried"
	var forge_effect := EffectData.new()
	forge_effect.kind = EffectData.Kind.FORGE_CARD
	forge_effect.amount = 4
	forge_effect.card = reforged
	var forge_ability := AbilityData.new()
	forge_ability.condition = forge_condition
	forge_ability.effects.append(forge_effect)
	broken.abilities.append(forge_ability)
	var broken_instance := CardInstance.new(broken, 0, 131)
	engine.get_state().player(0).hand.add(broken_instance)

	var play_action := PlayCardAction.new(0, broken_instance.uid)
	engine.get_state().player(0).energy = 4
	assert_bool(engine.is_legal(play_action)).is_false()
	engine.get_state().player(0).energy = 5
	assert_bool(engine.is_legal(play_action)).is_true()
	assert_bool(engine.apply(play_action)).is_true()
	assert_int(engine.get_state().player(0).energy).is_equal(0)
	assert_int(engine.get_state().player(0).artifacts.size()).is_equal(0)
	assert_str(String(siegfried.relic.data.id)).is_equal("nothung")
	assert_int(siegfried.attack).is_equal(8)


func test_leader_ability_costs_energy_targets_a_unit_and_is_once_per_turn() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 314)
	_prepare_main_phase(engine)
	var target := _unit(&"target", 0, 140, 2, 3, [])
	engine.get_state().player(0).board.add(target)
	var effect := EffectData.new()
	effect.kind = EffectData.Kind.BUFF
	effect.amount = 1
	effect.health_amount = 2
	effect.keyword = &"guard"
	var ability := AbilityData.new()
	ability.cost = 2
	ability.effects.append(effect)
	engine.get_state().player(0).leader.ability = ability

	assert_bool(engine.is_legal(UseLeaderAbilityAction.new(0, target.uid))).is_true()
	assert_bool(engine.apply(UseLeaderAbilityAction.new(0, target.uid))).is_true()
	assert_int(engine.get_state().player(0).energy).is_equal(8)
	assert_int(target.attack).is_equal(3)
	assert_int(target.health).is_equal(5)
	assert_bool(target.has_keyword(&"guard")).is_true()
	assert_bool(engine.is_legal(UseLeaderAbilityAction.new(0, target.uid))).is_false()


func test_ring_bonus_and_stealing_reset_its_curse_counter() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 52)
	_prepare_main_phase(engine)
	var state := engine.get_state()
	state.ring_holder = 0
	state.ring_turns_held = 2
	state.active_player = 1
	state.player(0).opening_energy = 0
	var alberich := LeaderData.new()
	alberich.id = &"alberich"
	alberich.faction = &"gods"
	state.player(0).leader = alberich
	assert_bool(engine._controls_alberich(0)).is_true()
	var hand_before: int = state.player(0).hand.size()

	assert_bool(engine.apply(EndTurnAction.new(1))).is_true()
	assert_int(state.player(0).energy).is_equal(Match.FIRST_TURN_MAX_ENERGY + 2)
	assert_int(state.player(0).hand.size()).is_equal(hand_before + 2)
	assert_int(state.ring_turns_held).is_equal(2)

	var spell_data := CardData.new()
	spell_data.id = &"steal_ring"
	spell_data.faction = &"nibelungs"
	spell_data.type = CardData.Type.SPELL
	var ability := AbilityData.new()
	var steal := EffectData.new()
	steal.kind = EffectData.Kind.STEAL_RING
	ability.effects.append(steal)
	spell_data.abilities.append(ability)
	var spell := CardInstance.new(spell_data, 1, 141)
	state.player(1).hand.add(spell)
	state.active_player = 1

	assert_bool(engine.apply(PlayCardAction.new(1, spell.uid))).is_true()
	assert_int(state.ring_holder).is_equal(1)
	assert_int(state.ring_turns_held).is_equal(0)


func test_only_nibelung_effects_create_the_ring_once() -> void:
	var engine := Match.new(_deck(&"nibelungs"), _deck(&"gods"), 72)
	_prepare_main_phase(engine)
	var spell_data := CardData.new()
	spell_data.id = &"forge_the_ring"
	spell_data.faction = &"nibelungs"
	spell_data.type = CardData.Type.SPELL
	var ability := AbilityData.new()
	var create := EffectData.new()
	create.kind = EffectData.Kind.CREATE_RING
	ability.effects.append(create)
	spell_data.abilities.append(ability)
	var spell := CardInstance.new(spell_data, 0, 160)
	engine.get_state().player(0).hand.add(spell)

	assert_bool(engine.apply(PlayCardAction.new(0, spell.uid))).is_true()
	assert_int(engine.get_state().ring_holder).is_equal(0)


func test_summon_and_transform_effects_update_the_board() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 21)
	_prepare_main_phase(engine)
	var original := _unit(&"original", 0, 150, 1, 2, [])
	engine.get_state().player(0).board.add(original)
	var summoned_data := _unit(&"summoned", 0, 0, 2, 3, [&"charge"]).data
	var transformed_data := _unit(&"transformed", 0, 0, 4, 6, []).data

	var spell_data := CardData.new()
	spell_data.id = &"summon_and_transform"
	spell_data.faction = &"gods"
	spell_data.type = CardData.Type.SPELL
	var ability := AbilityData.new()
	var summon := EffectData.new()
	summon.kind = EffectData.Kind.SUMMON
	summon.card = summoned_data
	ability.effects.append(summon)
	spell_data.abilities.append(ability)
	var spell := CardInstance.new(spell_data, 0, 151)
	engine.get_state().player(0).hand.add(spell)

	assert_bool(engine.apply(PlayCardAction.new(0, spell.uid))).is_true()
	assert_int(engine.get_state().player(0).board.size()).is_equal(2)
	var summoned: CardInstance = engine.get_state().player(0).board.cards[1]
	assert_bool(summoned.can_attack).is_true()

	var transform_spell := CardData.new()
	transform_spell.id = &"transform"
	transform_spell.faction = &"gods"
	transform_spell.type = CardData.Type.SPELL
	var transform_ability := AbilityData.new()
	var transform := EffectData.new()
	transform.kind = EffectData.Kind.TRANSFORM
	transform.target = EffectData.Target.SELECTED_UNIT
	transform.card = transformed_data
	transform_ability.effects.append(transform)
	transform_spell.abilities.append(transform_ability)
	var transform_instance := CardInstance.new(transform_spell, 0, 152)
	engine.get_state().player(0).hand.add(transform_instance)

	assert_bool(engine.apply(PlayCardAction.new(0, transform_instance.uid, original.uid))).is_true()
	assert_str(String(original.data.id)).is_equal("transformed")
	assert_int(original.attack).is_equal(4)
	assert_int(original.health).is_equal(6)


func test_ring_curse_and_gotterdammerung_apply_at_their_turn_boundaries() -> void:
	var engine := Match.new(_deck(&"gods"), _deck(&"nibelungs"), 813)
	_prepare_main_phase(engine)
	var state := engine.get_state()
	state.ring_holder = 0
	state.ring_turns_held = 0
	var starting_life: int = state.player(0).life
	assert_bool(engine.apply(EndTurnAction.new(0))).is_true()
	assert_int(state.player(0).life).is_equal(starting_life - 1)
	assert_int(state.ring_turns_held).is_equal(1)

	state.player(0).turns_taken = Match.DOOM_START_TURN - 1
	state.active_player = 1
	assert_bool(engine.apply(EndTurnAction.new(1))).is_true()
	assert_int(state.player(0).turns_taken).is_equal(Match.DOOM_START_TURN)
	assert_int(state.player(0).life).is_equal(starting_life - 2)


func _prepare_main_phase(engine: Match) -> void:
	var state := engine.get_state()
	state.phase = GameState.Phase.MAIN
	state.active_player = 0
	state.players[0].energy = 10
	state.players[1].energy = 10
	state.players[0].hand = Zone.new()
	state.players[1].hand = Zone.new()
	state.players[0].board = Zone.new()
	state.players[1].board = Zone.new()


func _unit(id: StringName, faction: int, uid: int, attack: int, health: int, keywords: Array[StringName]) -> CardInstance:
	var factions: Array[StringName] = [&"gods", &"nibelungs"]
	var data := CardData.new()
	data.id = id
	data.faction = factions[faction]
	data.type = CardData.Type.UNIT
	data.attack = attack
	data.health = health
	data.keywords = keywords.duplicate()
	return CardInstance.new(data, faction, uid)


func _deck(faction: StringName) -> DeckData:
	var deck := DeckData.new()
	deck.id = faction
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
		card.attack = 5
		card.health = 20
		card.keywords.append(&"charge")
		deck.cards.append(card)
		deck.cards.append(card)
	return deck


func test_play_block_reason_explains_unplayable_cards() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 20261021)
	var state: GameState = engine.get_state()
	assert_bool(engine.apply(RedrawAction.new(0))).is_true()
	assert_bool(engine.apply(RedrawAction.new(1))).is_true()
	var active: int = state.active_player
	var player: PlayerState = state.player(active)
	player.hand.cards.clear()
	for unit: CardInstance in state.player(0).board.cards.duplicate():
		state.player(0).board.remove_uid(unit.uid)
	for unit: CardInstance in state.player(1).board.cards.duplicate():
		state.player(1).board.remove_uid(unit.uid)
	var faction_prefix: StringName = player.leader.faction
	var cheap: CardInstance = CardInstance.new(CardDatabase.get_card(&"wotans_ravens" if faction_prefix == &"gods" else &"nibelung_miner"), active, 9001)
	var costly: CardInstance = CardInstance.new(CardDatabase.get_card(&"donner" if faction_prefix == &"gods" else &"giant_serpent"), active, 9002)
	var targeted: CardInstance = CardInstance.new(CardDatabase.get_card(&"donners_hammer" if faction_prefix == &"gods" else &"mimes_brew"), active, 9003)
	player.hand.add(cheap)
	player.hand.add(costly)
	player.hand.add(targeted)
	player.energy = 3

	assert_str(String(engine.play_block_reason(active, cheap.uid))).is_empty()
	assert_str(String(engine.play_block_reason(active, costly.uid))).is_equal("energy")
	player.energy = 10
	assert_str(String(engine.play_block_reason(active, targeted.uid))).is_equal("no_target")
	assert_str(String(engine.play_block_reason(1 - active, cheap.uid))).is_equal("not_your_turn")
	for index: int in Match.MAX_BOARD_SIZE:
		player.board.add(CardInstance.new(cheap.data, active, 9100 + index))
	assert_str(String(engine.play_block_reason(active, cheap.uid))).is_equal("board_full")
	state.player(1 - active).board.add(CardInstance.new(cheap.data, 1 - active, 9200))
	assert_str(String(engine.play_block_reason(active, targeted.uid))).is_empty()
