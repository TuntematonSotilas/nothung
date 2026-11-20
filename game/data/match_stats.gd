class_name MatchStats
extends RefCounted

## What the human player (player 0) did in one match, gathered while MatchRecord.replay() rebuilds it:
## the facts achievements count that the final state no longer shows. An undone play is taken back
## (checkpoint before each play, rollback on its undo). See docs/functional/06-progression.md#achievements.

const PLAYER: int = 0

var artifacts_played: int = 0
var reforged: bool = false
var opponent_held_ring: bool = false
var units_lost: int = 0
var _saved: Array = []


## Before an action is applied: counts the artifacts the player plays from the hand.
func before_action(engine: Match, action: Action) -> void:
	if not action is PlayCardAction or action.player != PLAYER:
		return
	var card: CardInstance = engine.get_state().player(PLAYER).hand.find((action as PlayCardAction).card_uid)
	if card != null and card.data.type == CardData.Type.ARTIFACT:
		artifacts_played += 1


func on_event(event: GameEvent) -> void:
	match event.type:
		&"card_reforged":
			if event.player == PLAYER:
				reforged = true
		&"ring_taken":
			if event.player == 1 - PLAYER:
				opponent_held_ring = true
		&"unit_destroyed":
			if event.player == PLAYER:
				units_lost += 1


## Saved before each card play, restored when that play is undone.
func checkpoint() -> void:
	_saved = [artifacts_played, reforged, opponent_held_ring, units_lost]


func rollback() -> void:
	if _saved.size() == 4:
		artifacts_played = _saved[0]
		reforged = _saved[1]
		opponent_held_ring = _saved[2]
		units_lost = _saved[3]
