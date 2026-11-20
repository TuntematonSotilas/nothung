class_name LeaderPowerData
extends Resource

## An upgraded version of a Leader's ability (docs/functional/06-progression.md#leader-powers),
## unlocked in Nibelheim from a player level for Rhinegold. Source: cards/leader_powers.md.

@export var ability: AbilityData
## Player level needed to unlock it.
@export_range(1, 99) var level: int = 1
## Rhinegold it costs.
@export_range(0, 99999) var price: int = 0
