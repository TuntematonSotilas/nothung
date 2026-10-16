class_name ConditionData
extends Resource

## Predicate required for an ability to resolve.

enum Kind { NONE, CONTROLS_CARD, HOLDS_RING }

@export var kind: Kind = Kind.NONE
@export var card_id: StringName
