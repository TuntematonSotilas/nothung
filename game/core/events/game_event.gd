class_name GameEvent
extends RefCounted

## Immutable notification emitted after a rules-engine state change.

var type: StringName
var player: int
var card_uid: int
var target_uid: int
var amount: int
var turn: int


func _init(
	event_type: StringName,
	event_player: int = -1,
	event_card_uid: int = -1,
	event_target_uid: int = -1,
	event_amount: int = 0,
	event_turn: int = 0
) -> void:
	type = event_type
	player = event_player
	card_uid = event_card_uid
	target_uid = event_target_uid
	amount = event_amount
	turn = event_turn


## Returns a stable serialization of this event.
func to_record() -> Dictionary:
	return {
		"type": String(type),
		"player": player,
		"card_uid": card_uid,
		"target_uid": target_uid,
		"amount": amount,
		"turn": turn,
	}
