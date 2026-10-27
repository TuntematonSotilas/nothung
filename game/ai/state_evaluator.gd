class_name StateEvaluator
extends RefCounted

## Scores a game state from one player's point of view, for the Normal and Hard AI.
## Higher is better; a won match is WIN_SCORE, a lost one -WIN_SCORE.

const WIN_SCORE: float = 10000.0
## Life below this is in danger: each missing point weighs more.
const DANGER_LIFE: int = 8
const LETHAL_THREAT_PENALTY: float = 30.0
const LETHAL_THREAT_BONUS: float = 10.0


static func evaluate(state: GameState, player_id: int, profile: AIProfile) -> float:
	if state.phase == GameState.Phase.GAME_OVER:
		if state.winner == player_id:
			return WIN_SCORE
		if state.winner == 1 - player_id:
			return -WIN_SCORE
		return 0.0
	var own: PlayerState = state.player(player_id)
	var enemy: PlayerState = state.player(1 - player_id)
	var score: float = 0.0
	score += _life_value(own.life) * profile.own_life_weight
	score -= _life_value(enemy.life) * profile.enemy_life_weight
	score += (_board_value(own) - _board_value(enemy)) * profile.board_weight
	score += float(own.hand.size() - enemy.hand.size()) * 3.0 * profile.hand_weight
	score += float(_artifact_value(own) - _artifact_value(enemy)) * profile.artifact_weight
	score += _ring_value(state, player_id, profile) * profile.ring_weight
	# Whoever can kill next turn is far ahead.
	if _threat(enemy, own) >= own.life:
		score -= LETHAL_THREAT_PENALTY * profile.own_life_weight
	if _threat(own, enemy) >= enemy.life:
		score += LETHAL_THREAT_BONUS * profile.enemy_life_weight
	return score


## A unit's worth on the board, from its current stats.
static func unit_value(unit: CardInstance) -> float:
	var value: float = float(maxi(unit.attack, 0)) * 1.8 + float(maxi(unit.health, 0)) * 1.2
	if unit.has_keyword(&"guard"):
		value += 2.0
	if unit.has_keyword(&"flying"):
		value += 2.0
	if unit.has_keyword(&"valhalla"):
		value += 1.0
	if unit.is_hidden():
		value += 2.0
	return value


## Two points per Life, more when low: the last points are the ones that lose the match.
static func _life_value(life: int) -> float:
	var value: float = float(life) * 2.0
	if life < DANGER_LIFE:
		value -= float(DANGER_LIFE - life) * 1.5
	return value


static func _board_value(player: PlayerState) -> float:
	var value: float = 0.0
	for unit: CardInstance in player.board.cards:
		value += unit_value(unit)
	return value


static func _artifact_value(player: PlayerState) -> float:
	var value: float = 0.0
	for artifact: CardInstance in player.artifacts.cards:
		value += 2.0 + float(artifact.data.cost) * 1.5
	return value


## The Ring's bonus next turn minus its next curse, for its holder.
static func _ring_value(state: GameState, player_id: int, profile: AIProfile) -> float:
	if state.ring_holder < 0:
		return 0.0
	var holder: PlayerState = state.player(state.ring_holder)
	var bonus: float = 8.0 if Match.controls_alberich(holder) else 3.0
	var curse: float = float(mini(state.ring_turns_held + 1, Match.RING_MAX_CURSE)) * 2.0 * profile.own_life_weight
	var value: float = bonus - curse
	return value if state.ring_holder == player_id else -value


## Damage the attacker's units could deal to the defender's Leader next turn; Guard units soak up attacks.
static func _threat(attacker: PlayerState, defender: PlayerState) -> int:
	var attacks: Array[int] = []
	var damage: int = 0
	for unit: CardInstance in attacker.board.cards:
		if unit.has_keyword(&"flying"):
			damage += maxi(unit.attack, 0)
		else:
			attacks.append(maxi(unit.attack, 0))
	var guards: int = 0
	for unit: CardInstance in defender.board.cards:
		if unit.has_keyword(&"guard") and not unit.is_hidden():
			guards += 1
	attacks.sort()
	# Flying ignores Guard; the smallest other attackers are spent on the guards.
	for index: int in range(mini(guards, attacks.size()), attacks.size()):
		damage += attacks[index]
	return damage
