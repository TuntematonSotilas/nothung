class_name EffectData
extends Resource

## Declarative effect and target selector understood by Match.

enum Kind {
	DEAL_DAMAGE,
	DRAW_CARDS,
	GAIN_ENERGY,
	SUMMON,
	HEAL,
	BUFF,
	TRANSFORM,
	CREATE_RING,
	STEAL_RING,
	RETURN_RING,
	RESURRECT,
	FORGE_CARD,
}

enum Target {
	SELF,
	SELECTED_UNIT,
	FRIENDLY_LEADER,
	ENEMY_LEADER,
	ALL_FRIENDLY_UNITS,
	ALL_ENEMY_UNITS,
	ALL_UNITS,
	ALL_LEADERS,
	BEARER,
}

@export var kind: Kind = Kind.DEAL_DAMAGE
@export var target: Target = Target.SELECTED_UNIT
@export var amount: int = 0
@export var health_amount: int = 0
@export var keyword: StringName
@export var card: CardData
