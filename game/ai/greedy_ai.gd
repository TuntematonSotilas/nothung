class_name GreedyAI
extends RefCounted

## Normal difficulty: simulates each legal action on a copy of the (masked) state, scores the result
## with StateEvaluator and keeps the best. Ending the turn scores the current state, so the AI stops
## once no action improves its position. A little noise keeps it beatable.


static func choose(state: GameState, player_id: int, profile: AIProfile, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var engine: Match = Match.from_state(state)
	var current: float = StateEvaluator.evaluate(state, player_id, profile)
	var selected: Action = null
	var best_score: float = -INF
	for action: Action in AIPlayer.playable_actions(engine, player_id):
		var score: float = current
		if not action is EndTurnAction:
			var simulation: Match = Match.from_state(state)
			simulation.apply(action)
			score = StateEvaluator.evaluate(simulation.get_state(), player_id, profile)
		if profile.noise > 0.0:
			score += rng.randfn(0.0, profile.noise)
		if score > best_score:
			best_score = score
			selected = action
	return selected.to_record() if selected != null else EndTurnAction.new(player_id).to_record()
