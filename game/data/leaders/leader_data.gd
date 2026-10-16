class_name LeaderData
extends Resource

## Immutable leader definition.

@export var id: StringName
@export var faction: StringName
@export_range(1, 99) var life: int = 20
@export var ability: AbilityData
