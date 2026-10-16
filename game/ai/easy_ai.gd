class_name EasyAI
extends RefCounted

## Selects a simple legal action without touching the live match state.


## Picks a legal action record on a worker thread.
static func choose_action(records: Array[Dictionary]) -> Dictionary:
	var selected: Dictionary = {}
	var best_score: int = -1
	for record: Dictionary in records:
		var score: int = _score_action(record)
		if score > best_score:
			best_score = score
			selected = record
	return selected


static func _score_action(record: Dictionary) -> int:
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
		_:
			return -1
