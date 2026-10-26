class_name CardInstance
extends RefCounted

## Mutable state for one card in a match.

var uid: int
var data: CardData
var owner: int
var attack: int
var health: int
var statuses: Array[StringName] = []
var exhausted: bool = false
var can_attack: bool = false
var relic: CardInstance


func _init(card_data: CardData = null, card_owner: int = 0, card_uid: int = 0) -> void:
	data = card_data
	owner = card_owner
	uid = card_uid
	if data != null:
		attack = data.attack
		health = data.health
		statuses = data.keywords.duplicate()


## Copies mutable runtime fields while preserving the immutable card resource.
func duplicate_instance() -> CardInstance:
	var copy := CardInstance.new(data, owner, uid)
	copy.attack = attack
	copy.health = health
	copy.statuses = statuses.duplicate()
	copy.exhausted = exhausted
	copy.can_attack = can_attack
	if relic != null:
		copy.relic = relic.duplicate_instance()
	return copy


## Invisible and not yet revealed by an attack: the opponent cannot attack or target it.
func is_hidden() -> bool:
	return has_keyword(&"invisible") and not statuses.has(&"revealed")


## Returns whether this card currently has the given keyword.
func has_keyword(keyword: StringName) -> bool:
	if statuses.has(keyword):
		return true
	return relic != null and relic.data.relic_keywords.has(keyword)
