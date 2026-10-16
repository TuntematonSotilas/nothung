class_name GameState
extends RefCounted

## Complete deterministic runtime state for a two-player match.

enum Phase { REDRAW, MAIN, GAME_OVER }

var turn: int = 0
var active_player: int = 0
var redraw_player: int = 0
var phase: Phase = Phase.REDRAW
var players: Array[PlayerState] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var next_uid: int = 1
var ring_holder: int = -1
var ring_turns_held: int = 0
var winner: int = -1


## Returns a deep copy suitable for deterministic simulations.
func duplicate_state() -> GameState:
	var copy := GameState.new()
	copy.turn = turn
	copy.active_player = active_player
	copy.redraw_player = redraw_player
	copy.phase = phase
	copy.rng.seed = rng.seed
	copy.rng.state = rng.state
	copy.next_uid = next_uid
	copy.ring_holder = ring_holder
	copy.ring_turns_held = ring_turns_held
	copy.winner = winner
	for player: PlayerState in players:
		copy.players.append(player.duplicate_state())
	return copy


## Returns a player by index.
func player(player_id: int) -> PlayerState:
	return players[player_id]
