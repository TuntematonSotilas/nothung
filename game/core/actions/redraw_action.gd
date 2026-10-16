class_name RedrawAction
extends Action

var card_uids: Array[int] = []


func _init(player_id: int = 0, uids: Array[int] = []) -> void:
	super(player_id)
	card_uids = uids.duplicate()
