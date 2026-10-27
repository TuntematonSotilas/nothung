class_name EasyAI
extends RefCounted

## Selects a simple legal action without touching the live match state.


## Picks a legal action record on a worker thread.
static func choose_action(records: Array[Dictionary]) -> Dictionary:
	var selected: Dictionary = {}
	var best_score: float = -INF
	for record: Dictionary in records:
		var score: float = float(record.get("ai_score", _default_score(record)))
		if score > best_score:
			best_score = score
			selected = record
	return selected


## Adds public-board and own-hand evaluation scores before records leave the main thread.
static func prepare_actions(state: GameState, legal_actions: Array[Action]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for action: Action in legal_actions:
		var record: Dictionary = action.to_record()
		record["ai_score"] = _evaluate_action(state, action)
		records.append(record)
	return records


static func _default_score(record: Dictionary) -> float:
	match String(record.get("type", "")):
		"play_card":
			return 100
		"leader_ability":
			return 70
		"attack":
			return 40 if int(record.get("target_player", -1)) >= 0 else 50
		"end_turn":
			return 0
		"redraw":
			return 0
		"concede":
			return -1000
		_:
			return -1


static func _evaluate_action(state: GameState, action: Action) -> float:
	if action is PlayCardAction:
		return _evaluate_play(state, action as PlayCardAction)
	if action is AttackAction:
		return _evaluate_attack(state, action as AttackAction)
	if action is UseLeaderAbilityAction:
		return _evaluate_ability(state, action as UseLeaderAbilityAction)
	if action is RedrawAction:
		return _evaluate_redraw(state, action as RedrawAction)
	return _default_score(action.to_record())


static func _evaluate_play(state: GameState, action: PlayCardAction) -> float:
	var player: PlayerState = state.player(action.player)
	var card: CardInstance = player.hand.find(action.card_uid)
	if card == null:
		return 100.0
	var score: float = 100.0 + _unit_value(card.data) * 2.0 - card.data.cost * 2.0
	if card.data.type == CardData.Type.ARTIFACT and card.data.is_relic():
		score += float(card.data.relic_attack_bonus) * 2.0 + float(card.data.relic_health_bonus)
	if card.data.is_ring and state.ring_holder == -1:
		score += 25.0
	for ability: AbilityData in card.data.abilities:
		if ability.trigger == &"on_play" and _condition_met(ability.condition, state, action.player):
			score += _effects_value(ability.effects, state, action.player, action.target_uid) * 4.0
	return score


## Mirrors Match._condition_is_met on public information: a conditional effect only counts when it will happen.
static func _condition_met(condition: ConditionData, state: GameState, player_id: int) -> bool:
	if condition == null or condition.kind == ConditionData.Kind.NONE:
		return true
	if condition.kind == ConditionData.Kind.HOLDS_RING:
		return state.ring_holder == player_id
	if condition.kind == ConditionData.Kind.CONTROLS_CARD:
		var player: PlayerState = state.player(player_id)
		if player.leader.id == condition.card_id:
			return true
		for zone: Zone in [player.board, player.artifacts]:
			for card: CardInstance in zone.cards:
				if card.data.id == condition.card_id:
					return true
	return false


static func _evaluate_attack(state: GameState, action: AttackAction) -> float:
	var player: PlayerState = state.player(action.player)
	var opponent: PlayerState = state.player(1 - action.player)
	var attacker: CardInstance = player.board.find(action.attacker_uid)
	if attacker == null:
		return 50.0
	if action.target_player == 1 - action.player:
		var damage: int = _attack_damage(attacker, opponent.leader.faction)
		var score: float = 70.0 + float(damage) * 5.0
		if damage >= opponent.life:
			score += 1000.0
		return score

	var target: CardInstance = opponent.board.find(action.target_uid)
	if target == null:
		return 50.0
	var dealt: int = _attack_damage(attacker, target.data.faction)
	var received: int = _attack_damage(target, attacker.data.faction)
	var score: float = 68.0 + float(mini(dealt, target.health)) * 3.0
	if dealt >= target.health:
		score += 35.0 + _unit_value(target.data) * 2.0
	if received >= attacker.health:
		score -= _unit_value(attacker.data) * 2.5
	elif received > 0:
		score -= float(received) * 1.5
	return score


static func _evaluate_ability(state: GameState, action: UseLeaderAbilityAction) -> float:
	var player: PlayerState = state.player(action.player)
	var leader: LeaderData = player.leader
	var score: float = 75.0
	if leader.ability != null:
		score += _effects_value(leader.ability.effects, state, action.player, action.target_uid) * 4.0
	return score


static func _evaluate_redraw(state: GameState, action: RedrawAction) -> float:
	var hand: Zone = state.player(action.player).hand
	var score: float = 0.0
	for uid: int in action.card_uids:
		var card: CardInstance = hand.find(uid)
		if card == null:
			continue
		var early_cost_penalty: float = float(maxi(card.data.cost - 2, 0)) * 7.0
		score += maxf(early_cost_penalty - _unit_value(card.data) * 0.6, 0.0)
	return score


static func _effects_value(
	effects: Array[EffectData],
	state: GameState,
	player_id: int,
	target_uid: int
) -> float:
	var value: float = 0.0
	for effect: EffectData in effects:
		match effect.kind:
			EffectData.Kind.DEAL_DAMAGE:
				var targets: Array[CardInstance] = _effect_units(state, player_id, effect.target, target_uid)
				for target: CardInstance in targets:
					var damage: int = effect.amount * (2 if effect.bonus_faction != &"" and target.data.faction == effect.bonus_faction else 1)
					var unit_value: float = float(mini(damage, target.health)) * 5.0
					if damage >= target.health:
						unit_value += _unit_value(target.data) * 3.0
					# Damaging your own unit is a loss, not a gain.
					value += unit_value if target.owner != player_id else -unit_value
				if effect.target == EffectData.Target.ENEMY_LEADER:
					var enemy: PlayerState = state.player(1 - player_id)
					var leader_damage: int = effect.amount * (2 if effect.bonus_faction != &"" and enemy.leader.faction == effect.bonus_faction else 1)
					value += float(leader_damage) * 4.0
					if leader_damage >= enemy.life:
						value += 1000.0
			EffectData.Kind.DRAW_CARDS:
				value += float(effect.amount) * 12.0
			EffectData.Kind.GAIN_ENERGY:
				value += float(mini(effect.amount, Match.MAX_ENERGY - state.player(player_id).energy)) * 8.0
			EffectData.Kind.SUMMON:
				if effect.card != null and effect.card.type == CardData.Type.UNIT:
					value += _unit_value(effect.card) * 2.0
			EffectData.Kind.HEAL:
				if effect.target == EffectData.Target.FRIENDLY_LEADER:
					var own: PlayerState = state.player(player_id)
					value += float(mini(effect.amount, own.leader.life - own.life)) * 2.0
			EffectData.Kind.BUFF:
				var buff_targets: Array[CardInstance] = _effect_units(state, player_id, effect.target, target_uid)
				for target: CardInstance in buff_targets:
					var buff_value: float = float(effect.amount) * 5.0 + float(effect.health_amount) * 3.0
					if effect.keyword != &"" and not target.has_keyword(effect.keyword):
						buff_value += 5.0
						# Charge on a unit that could not attack yet means an attack this turn.
						if effect.keyword == &"charge" and not target.can_attack and not target.exhausted:
							buff_value += float(target.attack + effect.amount) * 3.0
					# Buffing an enemy unit helps the opponent.
					value += buff_value if target.owner == player_id else -buff_value
			EffectData.Kind.CREATE_RING:
				if state.ring_holder == -1:
					value += 35.0
			EffectData.Kind.STEAL_RING:
				if state.ring_holder == 1 - player_id:
					value += 35.0
			EffectData.Kind.RESURRECT:
				# Worth something only if a Valhalla unit waits in the graveyard and there is room on the board.
				var own: PlayerState = state.player(player_id)
				if own.board.size() < Match.MAX_BOARD_SIZE:
					for card: CardInstance in own.graveyard.cards:
						if card.data.is_unit() and card.data.keywords.has(&"valhalla"):
							value += 10.0 + _unit_value(card.data) * 2.0
							break
			EffectData.Kind.RETURN_RING:
				# Taking the Ring away from the opponent is good; giving up your own is not.
				if state.ring_holder == 1 - player_id:
					value += 30.0
				elif state.ring_holder == player_id:
					value -= 30.0
			EffectData.Kind.FORGE_CARD:
				value += 15.0
				if effect.card != null:
					value += float(effect.card.relic_attack_bonus) * 4.0 + float(effect.card.relic_health_bonus) * 2.0
			EffectData.Kind.CREATE_ARTIFACT:
				value += 10.0
			EffectData.Kind.TAKE_CONTROL:
				# The opponent loses the unit and you gain it: worth two summons.
				var taken: CardInstance = _find_unit(state, target_uid)
				if taken != null and taken.owner != player_id:
					value += _unit_value(taken.data) * 4.0
	return value


static func _effect_units(
	state: GameState,
	player_id: int,
	target_kind: EffectData.Target,
	target_uid: int
) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if target_kind == EffectData.Target.SELECTED_UNIT:
		var target: CardInstance = _find_unit(state, target_uid)
		if target != null:
			result.append(target)
	elif target_kind == EffectData.Target.SELF:
		for unit: CardInstance in state.player(player_id).board.cards:
			if unit.uid == target_uid:
				result.append(unit)
	elif target_kind == EffectData.Target.ALL_FRIENDLY_UNITS:
		result.append_array(state.player(player_id).board.cards)
	elif target_kind == EffectData.Target.ALL_ENEMY_UNITS:
		result.append_array(state.player(1 - player_id).board.cards)
	elif target_kind == EffectData.Target.ALL_UNITS:
		result.append_array(state.player(player_id).board.cards)
		result.append_array(state.player(1 - player_id).board.cards)
	return result


static func _find_unit(state: GameState, uid: int) -> CardInstance:
	if uid < 0:
		return null
	for player: PlayerState in state.players:
		var unit: CardInstance = player.board.find(uid)
		if unit != null:
			return unit
	return null


static func _attack_damage(attacker: CardInstance, target_faction: StringName) -> int:
	var damage: int = attacker.attack
	if attacker.data.bonus_damage_faction == target_faction:
		damage *= attacker.data.bonus_damage_multiplier
	return damage


static func _unit_value(card: CardData) -> float:
	var value: float = float(card.attack) * 1.8 + float(card.health) * 1.2
	for keyword: StringName in card.keywords:
		match keyword:
			&"guard":
				value += 2.0
			&"charge":
				value += 3.0
			&"flying":
				value += 2.0
			&"valhalla":
				value += 1.0
	return value
