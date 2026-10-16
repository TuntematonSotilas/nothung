class_name AttackAction
extends Action

var attacker_uid: int
var target_uid: int = -1
var target_player: int = -1


func _init(player_id: int = 0, attacker: int = -1, target: int = -1, leader_target: int = -1) -> void:
	super(player_id)
	attacker_uid = attacker
	target_uid = target
	target_player = leader_target
