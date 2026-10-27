class_name MctsAI
extends RefCounted

## Hard difficulty: information-set Monte Carlo tree search over the AI's own turn.
## Each iteration samples the hidden cards again (AIPlayer.reshuffle_hidden), walks the tree of the
## AI's actions with UCB1, then plays out the rest of the turn and the opponent's reply with the Easy
## heuristic and scores the result with StateEvaluator. The most visited first action wins.

## Evaluation points that move the reward from 0.5 to about 0.73.
const REWARD_SCALE: float = 20.0
## Actions per player in a playout, so a playout always ends.
const PLAYOUT_ACTION_LIMIT: int = 30


class TreeNode:
	extends RefCounted
	var action: Action
	var visits: int = 0
	## Times this node's action was legal when its parent was visited (information-set MCTS).
	var available: int = 0
	var reward: float = 0.0
	var children: Dictionary = {}


static func choose(state: GameState, player_id: int, profile: AIProfile, seed: int) -> Dictionary:
	var root_actions: Array[Action] = AIPlayer.playable_actions(Match.from_state(state), player_id)
	if root_actions.size() == 1:
		return root_actions[0].to_record()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var baseline: float = StateEvaluator.evaluate(state, player_id, profile)
	var root := TreeNode.new()
	var started: int = Time.get_ticks_msec()
	var iterations: int = 0
	while true:
		if profile.max_iterations > 0 and iterations >= profile.max_iterations:
			break
		if profile.time_budget_msec > 0 and Time.get_ticks_msec() - started >= profile.time_budget_msec:
			break
		_iterate(root, state, player_id, profile, rng, baseline)
		iterations += 1

	var best: TreeNode = null
	for child: TreeNode in root.children.values():
		if best == null or child.visits > best.visits:
			best = child
	return best.action.to_record() if best != null else root_actions[0].to_record()


static func _iterate(root: TreeNode, state: GameState, player_id: int, profile: AIProfile, rng: RandomNumberGenerator, baseline: float) -> void:
	var sample: GameState = state.duplicate_state()
	AIPlayer.reshuffle_hidden(sample, player_id, rng)
	var engine: Match = Match.from_state(sample)
	var path: Array[TreeNode] = [root]
	var node: TreeNode = root
	# Selection and expansion, within the AI's own turn.
	while _is_turn_of(engine, player_id):
		var legal: Array[Action] = AIPlayer.playable_actions(engine, player_id)
		var untried: Array[Action] = []
		var tried: Array[TreeNode] = []
		for action: Action in legal:
			var key: String = JSON.stringify(action.to_record())
			if node.children.has(key):
				var child: TreeNode = node.children[key]
				child.available += 1
				tried.append(child)
			else:
				untried.append(action)
		if not untried.is_empty():
			var expanded := TreeNode.new()
			expanded.action = untried[rng.randi_range(0, untried.size() - 1)]
			expanded.available = 1
			node.children[JSON.stringify(expanded.action.to_record())] = expanded
			engine.apply(expanded.action)
			path.append(expanded)
			break
		node = _select(tried, profile.exploration)
		engine.apply(node.action)
		path.append(node)

	_playout(engine, player_id)
	var score: float = StateEvaluator.evaluate(engine.get_state(), player_id, profile)
	var reward: float = 1.0 / (1.0 + exp(-(score - baseline) / REWARD_SCALE))
	for visited: TreeNode in path:
		visited.visits += 1
		visited.reward += reward


## UCB1, counting only the visits during which the child was available.
static func _select(children: Array[TreeNode], exploration: float) -> TreeNode:
	var best: TreeNode = null
	var best_value: float = -INF
	for child: TreeNode in children:
		var value: float = child.reward / child.visits + exploration * sqrt(log(float(child.available)) / child.visits)
		if value > best_value:
			best_value = value
			best = child
	return best


## Finishes the AI's turn, then plays the opponent's whole turn, with the Easy heuristic.
static func _playout(engine: Match, player_id: int) -> void:
	for side: int in [player_id, 1 - player_id]:
		var actions: int = 0
		while _is_turn_of(engine, side) and actions < PLAYOUT_ACTION_LIMIT:
			var records: Array[Dictionary] = EasyAI.prepare_actions(engine.get_state(), AIPlayer.playable_actions(engine, side))
			engine.apply(Action.from_record(EasyAI.choose_action(records)))
			actions += 1
		if _is_turn_of(engine, side):
			engine.apply(EndTurnAction.new(side))


static func _is_turn_of(engine: Match, player_id: int) -> bool:
	var state: GameState = engine.get_state()
	return state.phase == GameState.Phase.MAIN and state.active_player == player_id
