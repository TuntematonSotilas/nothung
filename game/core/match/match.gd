class_name Match
extends RefCounted

## Synchronous, deterministic rules engine for a two-player duel.

signal event_emitted(event: GameEvent)
signal match_ended(winner: int)

const MAX_ENERGY: int = 10
const MAX_HAND_SIZE: int = 10
const MAX_BOARD_SIZE: int = 6
const MAX_ARTIFACTS: int = 3
const MAX_EFFECT_RESOLUTIONS: int = 500
const RING_MAX_CURSE: int = 3
const DOOM_START_TURN: int = 10
## Max Energy on each player's first turn (the second player still gets +1 once).
const FIRST_TURN_MAX_ENERGY: int = 2

var _state: GameState
var _trigger_queue: Array[Dictionary] = []
var _resolving_triggers: bool = false
var _resolution_count: int = 0


## Creates a match, shuffles both decks with the supplied seed and deals opening hands.
func _init(deck_a: DeckData, deck_b: DeckData, seed: int) -> void:
	_state = GameState.new()
	_state.rng.seed = seed
	if not _valid_deck(deck_a) or not _valid_deck(deck_b):
		push_error("Match requires two decks with a leader and exactly 20 valid cards.")
		_state.phase = GameState.Phase.GAME_OVER
		return

	_state.players = [
		_create_player(0, deck_a),
		_create_player(1, deck_b),
	]
	_state.active_player = _state.rng.randi_range(0, 1)
	_state.redraw_player = 0
	for player: PlayerState in _state.players:
		_shuffle(player.deck.cards)

	for player_id: int in 2:
		var opening_count: int = 4 if player_id == _state.active_player else 5
		for _index: int in opening_count:
			_draw_card(player_id)
		if player_id != _state.active_player:
			_state.player(player_id).opening_energy = 1


## Returns the current runtime state. Callers must treat it as read-only.
func get_state() -> GameState:
	return _state


## Restores a previously captured state snapshot for an explicit undo operation.
func restore_snapshot(snapshot: GameState) -> bool:
	if snapshot == null or snapshot.players.size() != 2:
		push_error("Match cannot restore an invalid state snapshot.")
		return false
	_state = snapshot.duplicate_state()
	_trigger_queue.clear()
	_resolving_triggers = false
	_resolution_count = 0
	return true


## Returns every currently legal action for the given player.
func get_legal_actions(player_id: int) -> Array[Action]:
	var actions: Array[Action] = []
	if _state.phase == GameState.Phase.GAME_OVER or player_id < 0 or player_id > 1:
		return actions

	if _state.phase == GameState.Phase.REDRAW:
		if player_id != _state.redraw_player:
			return actions
		var player := _state.player(player_id)
		if not player.redraw_done:
			actions.append_array(_get_redraw_actions(player_id, player.hand.cards))
			actions.append(ConcedeAction.new(player_id))
		return actions

	if player_id != _state.active_player:
		return actions

	var current := _state.player(player_id)
	for card: CardInstance in current.hand.cards:
		if _play_cost(card.data, player_id) > current.energy:
			continue
		if card.data.is_ring:
			continue
		if card.data.type == CardData.Type.UNIT and current.board.size() >= MAX_BOARD_SIZE:
			continue
		if card.data.type == CardData.Type.ARTIFACT and not card.data.is_ring:
			if card.data.is_relic():
				for bearer: CardInstance in current.board.cards:
					if _can_bear(bearer, card.data):
						actions.append(PlayCardAction.new(player_id, card.uid, bearer.uid))
			elif not card.data.is_ring and not card.data.artifact_limit_exempt and current.artifacts.size() >= MAX_ARTIFACTS:
				continue
			elif _has_selected_unit_target(card.data):
				for target: CardInstance in _all_units():
					if _is_legal_selected_target(card.data, player_id, target):
						actions.append(PlayCardAction.new(player_id, card.uid, target.uid))
			else:
				actions.append(PlayCardAction.new(player_id, card.uid))
		elif _has_selected_unit_target(card.data):
			for target: CardInstance in _all_units():
				if _is_legal_selected_target(card.data, player_id, target):
					actions.append(PlayCardAction.new(player_id, card.uid, target.uid))
		else:
			actions.append(PlayCardAction.new(player_id, card.uid))

	for attacker: CardInstance in current.board.cards:
		if not attacker.can_attack or attacker.exhausted:
			continue
		var opponent := _state.player(1 - player_id)
		var guards: Array[CardInstance] = _guard_units(opponent)
		var may_ignore_guard: bool = attacker.has_keyword(&"flying")
		if guards.is_empty() or may_ignore_guard:
			actions.append(AttackAction.new(player_id, attacker.uid, -1, 1 - player_id))
		var targets: Array[CardInstance] = guards if not guards.is_empty() and not may_ignore_guard else opponent.board.cards
		for target: CardInstance in targets:
			actions.append(AttackAction.new(player_id, attacker.uid, target.uid))

	if _can_use_leader_ability(player_id):
		var ability: AbilityData = current.leader.ability
		if _ability_needs_unit_target(ability):
			for target: CardInstance in _all_units():
				if _ability_target_is_legal(ability, player_id, target):
					actions.append(UseLeaderAbilityAction.new(player_id, target.uid))
		else:
			actions.append(UseLeaderAbilityAction.new(player_id))

	actions.append(EndTurnAction.new(player_id))
	actions.append(ConcedeAction.new(player_id))
	return actions


## Why a card in hand cannot be played right now (&"" when it can). Order follows what the player can act on first.
## Values: &"not_your_turn", &"energy", &"board_full", &"artifact_limit", &"no_target", &"unplayable".
func play_block_reason(player_id: int, card_uid: int) -> StringName:
	if _state.phase != GameState.Phase.MAIN or player_id != _state.active_player:
		return &"not_your_turn"
	var player := _state.player(player_id)
	var card := player.hand.find(card_uid)
	if card == null or card.data.is_ring:
		return &"unplayable"
	if _play_cost(card.data, player_id) > player.energy:
		return &"energy"
	if card.data.type == CardData.Type.UNIT and player.board.size() >= MAX_BOARD_SIZE:
		return &"board_full"
	if (
		card.data.type == CardData.Type.ARTIFACT
		and not card.data.is_relic()
		and not card.data.artifact_limit_exempt
		and player.artifacts.size() >= MAX_ARTIFACTS
	):
		return &"artifact_limit"
	for action: Action in get_legal_actions(player_id):
		if action is PlayCardAction and (action as PlayCardAction).card_uid == card_uid:
			return &""
	return &"no_target"


## Why a unit on the board cannot attack right now (&"" when it can).
## Values: &"not_your_turn", &"summoning_sick" (played this turn, no Charge), &"already_attacked", &"no_target", &"unknown".
func attack_block_reason(player_id: int, unit_uid: int) -> StringName:
	if _state.phase != GameState.Phase.MAIN or player_id != _state.active_player:
		return &"not_your_turn"
	var unit := _state.player(player_id).board.find(unit_uid)
	if unit == null:
		return &"unknown"
	if unit.exhausted:
		return &"already_attacked"
	if not unit.can_attack:
		return &"summoning_sick"
	for action: Action in get_legal_actions(player_id):
		if action is AttackAction and (action as AttackAction).attacker_uid == unit_uid:
			return &""
	return &"no_target"


## Returns whether an action satisfies the current phase and all game rules.
func is_legal(action: Action) -> bool:
	if action == null or _state.phase == GameState.Phase.GAME_OVER:
		return false
	if action.player < 0 or action.player > 1:
		return false

	if action is ConcedeAction:
		if _state.phase == GameState.Phase.REDRAW:
			return action.player == _state.redraw_player
		return action.player == _state.active_player
	if _state.phase == GameState.Phase.REDRAW:
		return _is_legal_redraw(action)
	if action.player != _state.active_player:
		return false

	if action is EndTurnAction:
		return true
	if action is PlayCardAction:
		return _is_legal_play(action as PlayCardAction)
	if action is AttackAction:
		return _is_legal_attack(action as AttackAction)
	if action is UseLeaderAbilityAction:
		return _is_legal_leader_ability(action as UseLeaderAbilityAction)
	return false


## Validates and applies a command, returning false without mutation when illegal.
func apply(action: Action) -> bool:
	if not is_legal(action):
		return false
	_resolution_count = 0
	if action is ConcedeAction:
		_finish_match(1 - action.player)
	elif action is RedrawAction:
		_apply_redraw(action as RedrawAction)
	elif action is PlayCardAction:
		_play_card(action as PlayCardAction)
	elif action is AttackAction:
		_attack(action as AttackAction)
	elif action is UseLeaderAbilityAction:
		_use_leader_ability(action as UseLeaderAbilityAction)
	elif action is EndTurnAction:
		_end_turn(action.player)
	return true


## Returns a stable state representation suitable for replay comparison.
func state_hash() -> String:
	var state_record: Dictionary = {
		"turn": _state.turn,
		"active": _state.active_player,
		"redraw_player": _state.redraw_player,
		"phase": _state.phase,
		"rng": _state.rng.state,
		"next_uid": _state.next_uid,
		"ring_holder": _state.ring_holder,
		"ring_turns_held": _state.ring_turns_held,
		"winner": _state.winner,
		"players": [],
	}
	var player_records: Array[Dictionary] = []
	for player: PlayerState in _state.players:
		player_records.append({
			"life": player.life,
			"energy": player.energy,
			"max_energy": player.max_energy,
			"opening_energy": player.opening_energy,
			"turns_taken": player.turns_taken,
			"leader_ability_used": player.leader_ability_used,
			"redraw_done": player.redraw_done,
			"deck": _zone_record(player.deck),
			"hand": _zone_record(player.hand),
			"board": _zone_record(player.board),
			"artifacts": _zone_record(player.artifacts),
			"graveyard": _zone_record(player.graveyard),
			"banished": _zone_record(player.banished),
		})
	state_record["players"] = player_records
	var hashing_context := HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(JSON.stringify(state_record).to_utf8_buffer())
	return hashing_context.finish().hex_encode()


func _valid_deck(deck: DeckData) -> bool:
	if (
		deck == null
		or deck.leader == null
		or deck.leader.id == &""
		or deck.leader.faction == &""
		or deck.leader.life < 1
		or deck.cards.size() != 20
	):
		return false
	if deck.leader.ability != null:
		for effect: EffectData in deck.leader.ability.effects:
			if effect.kind == EffectData.Kind.CREATE_RING and deck.leader.faction != &"nibelungs":
				return false
	var copy_counts: Dictionary = {}
	for card: CardData in deck.cards:
		if card == null or card.id == &"" or card.cost < 0 or card.cost > MAX_ENERGY:
			return false
		if card.type == CardData.Type.UNIT and (card.attack < 0 or card.health < 1):
			return false
		if card.type == CardData.Type.SPELL and card.abilities.is_empty():
			return false
		if card.is_ring:
			return false
		if card.faction != deck.leader.faction and card.faction != &"neutral":
			return false
		for ability: AbilityData in card.abilities:
			for effect: EffectData in ability.effects:
				if effect.kind == EffectData.Kind.CREATE_RING and card.faction != &"nibelungs":
					return false
		var copies: int = int(copy_counts.get(card.id, 0)) + 1
		copy_counts[card.id] = copies
		var limit: int = 1 if card.rarity in [CardData.Rarity.EPIC, CardData.Rarity.LEGENDARY] else 2
		if copies > limit:
			return false
	return true


func _create_player(player_id: int, deck_data: DeckData) -> PlayerState:
	var player := PlayerState.new(player_id, deck_data.leader)
	# Raised by 1 at the start of each turn, so the first turn starts at FIRST_TURN_MAX_ENERGY.
	player.max_energy = FIRST_TURN_MAX_ENERGY - 1
	for card_data: CardData in deck_data.cards:
		player.deck.add(_new_instance(card_data, player_id))
	return player


func _new_instance(data: CardData, owner: int) -> CardInstance:
	var card := CardInstance.new(data, owner, _state.next_uid)
	_state.next_uid += 1
	return card


func _shuffle(cards: Array[CardInstance]) -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var swap_index: int = _state.rng.randi_range(0, index)
		var card: CardInstance = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = card


func _append_redraw_actions(actions: Array[Action], player_id: int, hand: Array[CardInstance], index: int, selected: Array[int]) -> void:
	if index == hand.size():
		actions.append(RedrawAction.new(player_id, selected.duplicate()))
		return
	_append_redraw_actions(actions, player_id, hand, index + 1, selected.duplicate())
	var included := selected.duplicate()
	included.append(hand[index].uid)
	_append_redraw_actions(actions, player_id, hand, index + 1, included)


func _get_redraw_actions(player_id: int, hand: Array[CardInstance]) -> Array[Action]:
	var actions: Array[Action] = []
	_append_redraw_actions(actions, player_id, hand, 0, [])
	return actions


func _is_legal_redraw(action: Action) -> bool:
	if not action is RedrawAction:
		return false
	var redraw := action as RedrawAction
	var player := _state.player(redraw.player)
	if player.redraw_done or _state.redraw_player != redraw.player:
		return false
	var seen: Dictionary = {}
	for uid: int in redraw.card_uids:
		if seen.has(uid) or player.hand.find(uid) == null:
			return false
		seen[uid] = true
	return true


func _apply_redraw(action: RedrawAction) -> void:
	var player := _state.player(action.player)
	for uid: int in action.card_uids:
		var card := player.hand.remove_uid(uid)
		if card != null:
			player.deck.add(card)
	_shuffle(player.deck.cards)
	for _index: int in action.card_uids.size():
		_draw_card(action.player)
	player.redraw_done = true
	_emit(&"redraw_completed", action.player)

	var next_player := -1
	for player_id: int in 2:
		if not _state.player(player_id).redraw_done:
			next_player = player_id
			break
	if next_player >= 0:
		_state.redraw_player = next_player
	else:
		_begin_turn(_state.active_player)


func _is_legal_play(action: PlayCardAction) -> bool:
	var player := _state.player(action.player)
	var card := player.hand.find(action.card_uid)
	if card == null or _play_cost(card.data, action.player) > player.energy:
		return false
	if card.data.type == CardData.Type.UNIT and player.board.size() >= MAX_BOARD_SIZE:
		return false
	if card.data.is_ring:
		return false
	if card.data.type == CardData.Type.ARTIFACT:
		if card.data.is_relic():
			var bearer := player.board.find(action.target_uid)
			return bearer != null and action.target_player == -1 and _can_bear(bearer, card.data)
		if not card.data.artifact_limit_exempt and player.artifacts.size() >= MAX_ARTIFACTS:
			return false
	if _has_selected_unit_target(card.data):
		var target := _find_unit(action.target_uid)
		return target != null and _is_legal_selected_target(card.data, action.player, target) and action.target_player == -1
	return action.target_uid == -1 and action.target_player == -1


func _play_card(action: PlayCardAction) -> void:
	var player := _state.player(action.player)
	var card := player.hand.remove_uid(action.card_uid)
	var cost: int = _play_cost(card.data, action.player)
	player.energy -= cost
	_emit(&"energy_changed", action.player, card.uid, -cost)
	_emit(&"card_played", action.player, card.uid)

	match card.data.type:
		CardData.Type.UNIT:
			card.can_attack = card.data.keywords.has(&"charge")
			player.board.add(card)
			_emit(&"unit_summoned", action.player, card.uid)
			_queue_card_trigger(&"on_play", card, action.player, _find_unit(action.target_uid))
		CardData.Type.SPELL:
			_queue_card_trigger(&"on_play", card, action.player, _find_unit(action.target_uid))
			_drain_triggers()
			player.graveyard.add(card)
		CardData.Type.ARTIFACT:
			if card.data.is_ring:
				_set_ring_holder(action.player)
			elif card.data.is_relic():
				var bearer := player.board.find(action.target_uid)
				bearer.relic = card
				bearer.attack += card.data.relic_attack_bonus
				bearer.health += card.data.relic_health_bonus
				_emit(&"relic_attached", action.player, card.uid, bearer.uid)
			else:
				player.artifacts.add(card)
				_queue_card_trigger(&"on_play", card, action.player, null)
	_drain_triggers()
	_check_victory()


func _is_legal_attack(action: AttackAction) -> bool:
	var attacker := _state.player(action.player).board.find(action.attacker_uid)
	if attacker == null or not attacker.can_attack or attacker.exhausted:
		return false
	if action.target_player == 1 - action.player and action.target_uid == -1:
		var guards := _guard_units(_state.player(1 - action.player))
		if not guards.is_empty() and not attacker.has_keyword(&"flying"):
			return false
		return true
	if action.target_player != -1 or action.target_uid < 0:
		return false
	var target := _state.player(1 - action.player).board.find(action.target_uid)
	if target == null:
		return false
	var guards := _guard_units(_state.player(1 - action.player))
	return guards.is_empty() or attacker.has_keyword(&"flying") or target.has_keyword(&"guard")


func _attack(action: AttackAction) -> void:
	var attacker := _state.player(action.player).board.find(action.attacker_uid)
	attacker.exhausted = true
	attacker.can_attack = false
	_emit(&"attack_declared", action.player, attacker.uid, action.target_uid)
	var defender := _find_unit(action.target_uid)
	if defender != null:
		var attacker_damage: int = _effective_attack(attacker, defender)
		var defender_damage: int = _effective_attack(defender, attacker)
		defender.health -= attacker_damage
		attacker.health -= defender_damage
		_emit(&"damage_dealt", action.player, attacker.uid, defender.uid, attacker_damage)
		_emit(&"damage_dealt", defender.owner, defender.uid, attacker.uid, defender_damage)
		_queue_card_trigger(&"on_damage", attacker, action.player, defender)
		_queue_card_trigger(&"on_damage", defender, defender.owner, attacker)
		_check_deaths()
	else:
		var target_player := _state.player(action.target_player)
		var damage: int = _effective_attack(attacker, null, target_player.leader.faction)
		target_player.life -= damage
		_emit(&"damage_dealt", action.player, attacker.uid, -1, damage)
		_queue_card_trigger(&"on_damage", attacker, action.player, null)
		_check_victory()
	_queue_card_trigger(&"on_attack", attacker, action.player, defender)
	_drain_triggers()


func _effective_attack(attacker: CardInstance, defender: CardInstance, target_faction: StringName = &"") -> int:
	var damage := maxi(0, attacker.attack)
	if defender != null:
		target_faction = defender.data.faction
	if attacker.data.bonus_damage_faction != &"" and target_faction == attacker.data.bonus_damage_faction:
		damage *= attacker.data.bonus_damage_multiplier
	return damage


func _can_use_leader_ability(player_id: int) -> bool:
	var player := _state.player(player_id)
	return (
		player.leader.ability != null
		and not player.leader_ability_used
		and player.energy >= player.leader.ability.cost
		and _condition_is_met(player.leader.ability.condition, player_id)
	)


func _is_legal_leader_ability(action: UseLeaderAbilityAction) -> bool:
	if not _can_use_leader_ability(action.player):
		return false
	var ability: AbilityData = _state.player(action.player).leader.ability
	if _ability_needs_unit_target(ability):
		var target := _find_unit(action.target_uid)
		return target != null and _ability_target_is_legal(ability, action.player, target) and action.target_player == -1
	return action.target_uid == -1 and action.target_player == -1


func _use_leader_ability(action: UseLeaderAbilityAction) -> void:
	var player := _state.player(action.player)
	var ability: AbilityData = player.leader.ability
	player.energy -= ability.cost
	player.leader_ability_used = true
	_emit(&"energy_changed", action.player, -1, -ability.cost)
	_queue_ability(ability, null, action.player, _find_unit(action.target_uid))
	_drain_triggers()
	_check_victory()


func _end_turn(player_id: int) -> void:
	_queue_board_trigger(&"end_of_turn", player_id)
	_drain_triggers()
	if _state.ring_holder == player_id:
		_state.ring_turns_held += 1
		var curse: int = mini(_state.ring_turns_held, RING_MAX_CURSE)
		_state.player(player_id).life -= curse
		_emit(&"ring_cursed", player_id, -1, -1, curse)
		_check_victory()
	if _state.phase == GameState.Phase.GAME_OVER:
		return
	_emit(&"turn_ended", player_id)
	_state.active_player = 1 - player_id
	_begin_turn(_state.active_player)


func _begin_turn(player_id: int) -> void:
	if _state.phase == GameState.Phase.GAME_OVER:
		return
	_state.phase = GameState.Phase.MAIN
	_state.active_player = player_id
	_state.turn += 1
	var player := _state.player(player_id)
	player.turns_taken += 1
	player.max_energy = mini(player.max_energy + 1, MAX_ENERGY)
	player.energy = player.max_energy + player.opening_energy
	player.opening_energy = 0
	player.leader_ability_used = false
	for unit: CardInstance in player.board.cards:
		unit.exhausted = false
		unit.can_attack = true
	_emit(&"turn_started", player_id, -1, -1, player.energy)

	_queue_board_trigger(&"start_of_turn", player_id)
	_drain_triggers()
	if _state.phase == GameState.Phase.GAME_OVER:
		return
	if _state.ring_holder == player_id:
		if _controls_alberich(player_id):
			player.energy += 2
			_draw_card(player_id)
			_emit(&"ring_bonus", player_id, -1, -1, 2)
		else:
			player.energy += 1
			_emit(&"ring_bonus", player_id, -1, -1, 1)
	if player.turns_taken >= DOOM_START_TURN:
		var doom_damage: int = player.turns_taken - DOOM_START_TURN + 1
		player.life -= doom_damage
		_emit(&"gotterdammerung_damage", player_id, -1, -1, doom_damage)
		_check_victory()
	if _state.phase == GameState.Phase.GAME_OVER:
		return
	_draw_card(player_id)


func _draw_card(player_id: int) -> CardInstance:
	var player := _state.player(player_id)
	var card: CardInstance = player.deck.cards.pop_back() if not player.deck.is_empty() else null
	if card == null:
		return null
	if player.hand.size() >= MAX_HAND_SIZE:
		player.graveyard.add(card)
		_emit(&"card_burned", player_id, card.uid)
		return card
	player.hand.add(card)
	_emit(&"card_drawn", player_id, card.uid)
	return card


func _queue_card_trigger(trigger: StringName, card: CardInstance, player_id: int, target: CardInstance) -> void:
	for ability: AbilityData in card.data.abilities:
		if ability.trigger == trigger:
			_queue_ability(ability, card, player_id, target)


func _queue_board_trigger(trigger: StringName, active_player_id: int) -> void:
	for offset: int in 2:
		var player_id: int = (active_player_id + offset) % 2
		var player := _state.player(player_id)
		for card: CardInstance in player.board.cards:
			_queue_card_trigger(trigger, card, player_id, null)
			if card.relic != null:
				_queue_card_trigger(trigger, card.relic, player_id, card)
		for card: CardInstance in player.artifacts.cards:
			_queue_card_trigger(trigger, card, player_id, null)


func _queue_ability(ability: AbilityData, source: CardInstance, player_id: int, target: CardInstance) -> void:
	_trigger_queue.append({
		"ability": ability,
		"source": source,
		"player": player_id,
		"target": target,
	})


func _drain_triggers() -> void:
	if _resolving_triggers:
		return
	_resolving_triggers = true
	while not _trigger_queue.is_empty():
		_resolution_count += 1
		if _resolution_count > MAX_EFFECT_RESOLUTIONS:
			_trigger_queue.clear()
			_resolving_triggers = false
			push_error("Effect resolution exceeded the safety limit of %d." % MAX_EFFECT_RESOLUTIONS)
			_finish_match(-1)
			return
		var queued: Dictionary = _trigger_queue.pop_front()
		var ability: AbilityData = queued["ability"]
		if not _condition_is_met(ability.condition, int(queued["player"])):
			continue
		for effect: EffectData in ability.effects:
			_resolve_effect(effect, queued["source"], queued["player"], queued["target"])
			_check_deaths()
			_check_victory()
			if _state.phase == GameState.Phase.GAME_OVER:
				_trigger_queue.clear()
				break
	_resolving_triggers = false


func _resolve_effect(effect: EffectData, source: CardInstance, player_id: int, selected: CardInstance) -> void:
	match effect.kind:
		EffectData.Kind.DEAL_DAMAGE:
			for target: Variant in _effect_targets(effect.target, player_id, source, selected):
				if target is CardInstance:
					(target as CardInstance).health -= effect.amount
					_emit(&"damage_dealt", player_id, source.uid if source != null else -1, (target as CardInstance).uid, effect.amount)
					_queue_card_trigger(&"on_damage", target as CardInstance, (target as CardInstance).owner, source)
				else:
					var target_player: int = int(target)
					_state.player(target_player).life -= effect.amount
					_emit(&"damage_dealt", player_id, source.uid if source != null else -1, -1, effect.amount)
		EffectData.Kind.DRAW_CARDS:
			for _index: int in maxi(effect.amount, 0):
				_draw_card(player_id)
		EffectData.Kind.GAIN_ENERGY:
			var player := _state.player(player_id)
			var previous := player.energy
			player.energy = mini(player.energy + effect.amount, MAX_ENERGY)
			_emit(&"energy_changed", player_id, -1, -1, player.energy - previous)
		EffectData.Kind.SUMMON:
			if effect.card != null and effect.card.type == CardData.Type.UNIT:
				var player := _state.player(player_id)
				if player.board.size() < MAX_BOARD_SIZE:
					var summoned := _new_instance(effect.card, player_id)
					summoned.can_attack = effect.card.keywords.has(&"charge")
					player.board.add(summoned)
					_emit(&"unit_summoned", player_id, summoned.uid)
					_queue_card_trigger(&"on_play", summoned, player_id, null)
		EffectData.Kind.HEAL:
			for target: Variant in _effect_targets(effect.target, player_id, source, selected):
				if target is CardInstance:
					var unit := target as CardInstance
					unit.health = mini(unit.health + effect.amount, unit.data.health + (unit.relic.data.relic_health_bonus if unit.relic != null else 0))
				else:
					var target_player: PlayerState = _state.player(int(target))
					target_player.life = mini(target_player.life + effect.amount, target_player.leader.life)
		EffectData.Kind.BUFF:
			for target: Variant in _effect_targets(effect.target, player_id, source, selected):
				if target is CardInstance:
					var unit := target as CardInstance
					unit.attack += effect.amount
					unit.health += effect.health_amount
					if effect.keyword != &"" and not unit.statuses.has(effect.keyword):
						unit.statuses.append(effect.keyword)
		EffectData.Kind.TRANSFORM:
			if effect.card != null and effect.card.type == CardData.Type.UNIT:
				for target: Variant in _effect_targets(effect.target, player_id, source, selected):
					if target is CardInstance:
						var unit := target as CardInstance
						unit.data = effect.card
						unit.attack = effect.card.attack + (unit.relic.data.relic_attack_bonus if unit.relic != null else 0)
						unit.health = effect.card.health + (unit.relic.data.relic_health_bonus if unit.relic != null else 0)
						unit.statuses = effect.card.keywords.duplicate()
						_emit(&"unit_transformed", player_id, unit.uid)
		EffectData.Kind.CREATE_RING:
			if source != null and source.data.faction == &"nibelungs" and _state.ring_holder == -1:
				_set_ring_holder(player_id)
		EffectData.Kind.STEAL_RING:
			_set_ring_holder(player_id)
		EffectData.Kind.RETURN_RING:
			_set_ring_holder(-1)
		EffectData.Kind.RESURRECT:
			_resurrect(player_id, effect.card)
		EffectData.Kind.FORGE_CARD:
			_forge_card(source, player_id, effect.card)


func _effect_targets(target_kind: EffectData.Target, player_id: int, source: CardInstance, selected: CardInstance) -> Array[Variant]:
	var result: Array[Variant] = []
	match target_kind:
		EffectData.Target.SELF:
			if source != null:
				result.append(source)
		EffectData.Target.SELECTED_UNIT:
			if selected != null:
				result.append(selected)
		EffectData.Target.FRIENDLY_LEADER:
			result.append(player_id)
		EffectData.Target.ENEMY_LEADER:
			result.append(1 - player_id)
		EffectData.Target.ALL_FRIENDLY_UNITS:
			for card: CardInstance in _state.player(player_id).board.cards:
				result.append(card)
		EffectData.Target.ALL_ENEMY_UNITS:
			for card: CardInstance in _state.player(1 - player_id).board.cards:
				result.append(card)
		EffectData.Target.ALL_UNITS:
			for card: CardInstance in _all_units():
				result.append(card)
		EffectData.Target.ALL_LEADERS:
			result.append(0)
			result.append(1)
		EffectData.Target.BEARER:
			if source != null and source.owner >= 0 and source.owner < 2:
				for unit: CardInstance in _state.player(source.owner).board.cards:
					if unit.relic != null and unit.relic.uid == source.uid:
						result.append(unit)
	return result


func _check_deaths() -> void:
	for offset: int in 2:
		var player_id: int = (_state.active_player + offset) % 2
		var board := _state.player(player_id).board
		var dead: Array[CardInstance] = []
		for unit: CardInstance in board.cards:
			if unit.health <= 0:
				dead.append(unit)
		for unit: CardInstance in dead:
			board.remove_uid(unit.uid)
			if unit.relic != null:
				var relic := unit.relic
				unit.attack -= relic.data.relic_attack_bonus
				unit.health -= relic.data.relic_health_bonus
				unit.relic = null
				_emit(&"relic_detached", player_id, relic.uid, unit.uid)
				_queue_card_trigger(&"on_bearer_death", relic, player_id, unit)
				if relic.data.shatters_into != null:
					_state.player(player_id).artifacts.add(_new_instance(relic.data.shatters_into, player_id))
				else:
					_state.player(player_id).graveyard.add(relic)
			_state.player(player_id).graveyard.add(unit)
			_emit(&"unit_destroyed", player_id, unit.uid)
			_queue_card_trigger(&"on_death", unit, player_id, null)


func _resurrect(player_id: int, requested_card: CardData) -> void:
	var player := _state.player(player_id)
	if player.board.size() >= MAX_BOARD_SIZE:
		return
	for card: CardInstance in player.graveyard.cards.duplicate():
		if card.data.type == CardData.Type.UNIT and card.data.keywords.has(&"valhalla"):
			if requested_card == null or card.data.id == requested_card.id:
				player.graveyard.remove_uid(card.uid)
				card.health = card.data.health
				card.exhausted = true
				card.can_attack = false
				player.board.add(card)
				_emit(&"unit_resurrected", player_id, card.uid)
				return


func _forge_card(source: CardInstance, player_id: int, forged_data: CardData) -> void:
	if source == null or forged_data == null:
		return
	var player := _state.player(player_id)
	if player.artifacts.find(source.uid) == null:
		return
	if forged_data.is_relic():
		var bearer: CardInstance
		for unit: CardInstance in player.board.cards:
			if _can_bear(unit, forged_data):
				bearer = unit
				break
		if bearer == null:
			return
		player.artifacts.remove_uid(source.uid)
		var relic := _new_instance(forged_data, player_id)
		bearer.relic = relic
		bearer.attack += forged_data.relic_attack_bonus
		bearer.health += forged_data.relic_health_bonus
		_emit(&"relic_attached", player_id, relic.uid, bearer.uid)
	else:
		player.artifacts.remove_uid(source.uid)
		player.artifacts.add(_new_instance(forged_data, player_id))
	_emit(&"card_forged", player_id, source.uid)


func _condition_is_met(condition: ConditionData, player_id: int) -> bool:
	if condition == null or condition.kind == ConditionData.Kind.NONE:
		return true
	if condition.kind == ConditionData.Kind.HOLDS_RING:
		return _state.ring_holder == player_id
	if condition.kind == ConditionData.Kind.CONTROLS_CARD:
		var player := _state.player(player_id)
		if player.leader.id == condition.card_id:
			return true
		for unit: CardInstance in player.board.cards:
			if unit.data.id == condition.card_id:
				return true
	return false


func _play_cost(card: CardData, player_id: int) -> int:
	var cost: int = card.cost
	for ability: AbilityData in card.abilities:
		if ability.trigger != &"on_play" or not _condition_is_met(ability.condition, player_id):
			continue
		for effect: EffectData in ability.effects:
			if effect.kind == EffectData.Kind.FORGE_CARD and _forge_has_bearer(player_id, effect.card):
				cost += maxi(effect.amount, 0)
	return cost


func _forge_has_bearer(player_id: int, card: CardData) -> bool:
	if card == null or not card.is_relic():
		return true
	for unit: CardInstance in _state.player(player_id).board.cards:
		if _can_bear(unit, card):
			return true
	return false


func _check_victory() -> void:
	if _state.phase == GameState.Phase.GAME_OVER:
		return
	var player_zero_dead: bool = _state.player(0).life <= 0
	var player_one_dead: bool = _state.player(1).life <= 0
	if player_zero_dead and player_one_dead:
		_finish_match(-1)
	elif player_zero_dead:
		_finish_match(1)
	elif player_one_dead:
		_finish_match(0)


func _finish_match(winner: int) -> void:
	if _state.phase == GameState.Phase.GAME_OVER:
		return
	_state.phase = GameState.Phase.GAME_OVER
	_state.winner = winner
	_emit(&"match_ended", winner, -1, -1, winner)
	match_ended.emit(winner)


func _set_ring_holder(player_id: int) -> void:
	if player_id == _state.ring_holder:
		return
	_state.ring_holder = player_id
	_state.ring_turns_held = 0
	_emit(&"ring_taken" if player_id >= 0 else &"ring_returned", player_id)


func _controls_alberich(player_id: int) -> bool:
	var player := _state.player(player_id)
	if player.leader.id == &"alberich":
		return true
	for unit: CardInstance in player.board.cards:
		if unit.data.id == &"alberich" or unit.data.id == &"alberich_lord":
			return true
	return false


func _can_bear(unit: CardInstance, relic: CardData) -> bool:
	if not unit.data.is_unit() or unit.relic != null:
		return false
	if relic.bearer.is_empty():
		return true
	for required: StringName in relic.bearer:
		if unit.data.id == required or unit.data.subtypes.has(required):
			return true
	return false


func _has_selected_unit_target(card: CardData) -> bool:
	for ability: AbilityData in card.abilities:
		for effect: EffectData in ability.effects:
			if _effect_requires_selected_unit(effect):
				return true
	return false


func _effect_requires_selected_unit(effect: EffectData) -> bool:
	return (
		effect.target == EffectData.Target.SELECTED_UNIT
		and effect.kind in [EffectData.Kind.DEAL_DAMAGE, EffectData.Kind.HEAL, EffectData.Kind.BUFF, EffectData.Kind.TRANSFORM]
	)


func _is_legal_selected_target(card: CardData, player_id: int, target: CardInstance) -> bool:
	for ability: AbilityData in card.abilities:
		for effect: EffectData in ability.effects:
			if not _effect_requires_selected_unit(effect):
				continue
			if effect.kind == EffectData.Kind.DEAL_DAMAGE and target.owner == player_id:
				return false
			if effect.kind in [EffectData.Kind.HEAL, EffectData.Kind.BUFF] and target.owner != player_id:
				return false
	return true


func _ability_needs_unit_target(ability: AbilityData) -> bool:
	for effect: EffectData in ability.effects:
		if _effect_requires_selected_unit(effect):
			return true
	return false


func _ability_target_is_legal(ability: AbilityData, player_id: int, target: CardInstance) -> bool:
	for effect: EffectData in ability.effects:
		if not _effect_requires_selected_unit(effect):
			continue
		if effect.kind == EffectData.Kind.DEAL_DAMAGE and target.owner == player_id:
			return false
		if effect.kind in [EffectData.Kind.HEAL, EffectData.Kind.BUFF] and target.owner != player_id:
			return false
	return true


func _guard_units(player: PlayerState) -> Array[CardInstance]:
	var guards: Array[CardInstance] = []
	for unit: CardInstance in player.board.cards:
		if unit.has_keyword(&"guard"):
			guards.append(unit)
	return guards


func _all_units() -> Array[CardInstance]:
	var units: Array[CardInstance] = []
	for player: PlayerState in _state.players:
		units.append_array(player.board.cards)
	return units


func _find_unit(uid: int) -> CardInstance:
	if uid < 0:
		return null
	for player: PlayerState in _state.players:
		var unit := player.board.find(uid)
		if unit != null:
			return unit
	return null


func _emit(event_type: StringName, player: int = -1, card_uid: int = -1, target_uid: int = -1, amount: int = 0) -> void:
	event_emitted.emit(GameEvent.new(event_type, player, card_uid, target_uid, amount, _state.turn))


func _zone_record(zone: Zone) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for card: CardInstance in zone.cards:
		records.append(_card_record(card))
	return records


func _card_record(card: CardInstance) -> Dictionary:
	return {
		"uid": card.uid,
		"id": String(card.data.id),
		"owner": card.owner,
		"attack": card.attack,
		"health": card.health,
		"statuses": card.statuses.map(func(status: StringName) -> String: return String(status)),
		"exhausted": card.exhausted,
		"can_attack": card.can_attack,
		"relic": _card_record(card.relic) if card.relic != null else {},
	}
