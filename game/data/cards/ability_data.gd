class_name AbilityData
extends Resource

## An ordered set of effects invoked by a game trigger.

@export var trigger: StringName = &"on_play"
@export_range(0, 10) var cost: int = 0
@export var condition: ConditionData
@export var effects: Array[EffectData] = []
