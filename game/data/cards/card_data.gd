class_name CardData
extends Resource

## Immutable definition for a card used by the rules engine.

enum Type { UNIT, SPELL, ARTIFACT }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName
@export var faction: StringName
@export var type: Type = Type.UNIT
@export var subtypes: Array[StringName] = []
@export var rarity: Rarity = Rarity.COMMON
@export_range(0, 10) var cost: int = 0
@export var attack: int = 0
@export var health: int = 0
@export var bonus_damage_faction: StringName
@export_range(1, 10) var bonus_damage_multiplier: int = 1
@export var keywords: Array[StringName] = []
@export var bearer: Array[StringName] = []
@export var abilities: Array[AbilityData] = []
@export var leitmotifs: Array[StringName] = []
@export var art: Texture2D
@export var is_ring: bool = false
@export var artifact_limit_exempt: bool = false
@export var attachable: bool = true
@export var relic_attack_bonus: int = 0
@export var relic_health_bonus: int = 0
@export var relic_keywords: Array[StringName] = []
@export var shatters_into: CardData


## Returns whether this definition describes a unit.
func is_unit() -> bool:
	return type == Type.UNIT


## Copies allowed in a deck: 1 for Epic and Legendary cards, 2 otherwise
## (docs/functional/04-cards.md#deckbuilding-rules).
func deck_limit() -> int:
	return 1 if rarity in [Rarity.EPIC, Rarity.LEGENDARY] else 2


## Returns whether this artifact is equipment.
func is_relic() -> bool:
	return type == Type.ARTIFACT and attachable and StringName("relic") in subtypes
