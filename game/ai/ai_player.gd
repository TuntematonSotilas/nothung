class_name AIPlayer
extends RefCounted

## Entry point for every AI difficulty. The main thread builds a job with prepare(); a worker thread
## turns it into an action record with choose(). The job holds copies only: the worker never sees the
## live match, and the opponent's hand is shuffled back into their deck (see mask_hidden()).


## Main thread: everything the AI may know, as copies safe to hand to a worker.
static func prepare(engine: Match, player_id: int, profile: AIProfile, seed: int) -> Dictionary:
	var state: GameState = engine.get_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var job: Dictionary = {
		"player": player_id,
		"profile": profile,
		"seed": rng.randi(),
		# Easy scores and the opening-hand Redraw use the heuristic records for every difficulty.
		"records": EasyAI.prepare_actions(state, engine.get_legal_actions(player_id)),
	}
	if profile.difficulty != AIProfile.Difficulty.EASY and state.phase == GameState.Phase.MAIN:
		job["state"] = mask_hidden(state, player_id, rng)
	return job


## Worker thread: picks one action record.
static func choose(job: Dictionary) -> Dictionary:
	var profile: AIProfile = job["profile"]
	if not job.has("state"):
		return EasyAI.choose_action(job["records"])
	if profile.difficulty == AIProfile.Difficulty.HARD:
		return MctsAI.choose(job["state"], int(job["player"]), profile, int(job["seed"]))
	return GreedyAI.choose(job["state"], int(job["player"]), profile, int(job["seed"]))


## Copy of the state with what the player cannot know randomised: the opponent's hand is redealt from
## their hand and deck together, both decks are reshuffled and the rules RNG is reseeded.
## The AI therefore knows the opponent's remaining cards (their decklist), not which ones are in hand.
static func mask_hidden(state: GameState, player_id: int, rng: RandomNumberGenerator) -> GameState:
	var copy: GameState = state.duplicate_state()
	reshuffle_hidden(copy, player_id, rng)
	return copy


## Re-randomises the hidden cards of an already masked copy in place (one sample per search iteration).
static func reshuffle_hidden(state: GameState, player_id: int, rng: RandomNumberGenerator) -> void:
	var enemy: PlayerState = state.player(1 - player_id)
	var hand_size: int = enemy.hand.size()
	var pool: Array[CardInstance] = []
	pool.append_array(enemy.hand.cards)
	pool.append_array(enemy.deck.cards)
	_shuffle(pool, rng)
	enemy.hand.cards = pool.slice(0, hand_size)
	enemy.deck.cards = pool.slice(hand_size)
	_shuffle(state.player(player_id).deck.cards, rng)
	state.rng = RandomNumberGenerator.new()
	state.rng.seed = rng.randi()


## Legal actions without Concede, which the AI never plays.
static func playable_actions(engine: Match, player_id: int) -> Array[Action]:
	var actions: Array[Action] = []
	for action: Action in engine.get_legal_actions(player_id):
		if not action is ConcedeAction:
			actions.append(action)
	return actions


static func _shuffle(cards: Array[CardInstance], rng: RandomNumberGenerator) -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var card: CardInstance = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = card
