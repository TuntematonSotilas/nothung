class_name Action
extends RefCounted

## Base value object for a player command.

var player: int


func _init(player_id: int = 0) -> void:
	player = player_id


## Encodes this action as a JSON-compatible replay record.
func to_record() -> Dictionary:
	var record: Dictionary = {"player": player}
	if self is RedrawAction:
		record["type"] = "redraw"
		record["card_uids"] = (self as RedrawAction).card_uids
	elif self is PlayCardAction:
		var play := self as PlayCardAction
		record["type"] = "play_card"
		record["card_uid"] = play.card_uid
		record["target_uid"] = play.target_uid
		record["target_player"] = play.target_player
	elif self is AttackAction:
		var attack := self as AttackAction
		record["type"] = "attack"
		record["attacker_uid"] = attack.attacker_uid
		record["target_uid"] = attack.target_uid
		record["target_player"] = attack.target_player
	elif self is UseLeaderAbilityAction:
		var ability := self as UseLeaderAbilityAction
		record["type"] = "leader_ability"
		record["target_uid"] = ability.target_uid
		record["target_player"] = ability.target_player
	elif self is EndTurnAction:
		record["type"] = "end_turn"
	elif self is ConcedeAction:
		record["type"] = "concede"
	else:
		push_error("Cannot serialize unsupported action type: %s" % get_class())
	return record


## Rebuilds a recorded action, or returns null and reports malformed replay data.
static func from_record(record: Dictionary) -> Action:
	if not record.has("type") or not record.has("player"):
		push_error("Replay action is missing its type or player.")
		return null
	var player_id: int = int(record["player"])
	match String(record["type"]):
		"redraw":
			var uids: Array[int] = []
			for uid: Variant in record.get("card_uids", []):
				uids.append(int(uid))
			return RedrawAction.new(player_id, uids)
		"play_card":
			return PlayCardAction.new(player_id, int(record.get("card_uid", -1)), int(record.get("target_uid", -1)), int(record.get("target_player", -1)))
		"attack":
			return AttackAction.new(player_id, int(record.get("attacker_uid", -1)), int(record.get("target_uid", -1)), int(record.get("target_player", -1)))
		"leader_ability":
			return UseLeaderAbilityAction.new(player_id, int(record.get("target_uid", -1)), int(record.get("target_player", -1)))
		"end_turn":
			return EndTurnAction.new(player_id)
		"concede":
			return ConcedeAction.new(player_id)
		_:
			push_error("Replay contains an unknown action type: %s" % String(record["type"]))
			return null
