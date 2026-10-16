class_name PlayCardAction
extends Action

var card_uid: int
var target_uid: int = -1
var target_player: int = -1


func _init(player_id: int = 0, uid: int = -1, selected_uid: int = -1, selected_player: int = -1) -> void:
	super(player_id)
	card_uid = uid
	target_uid = selected_uid
	target_player = selected_player
