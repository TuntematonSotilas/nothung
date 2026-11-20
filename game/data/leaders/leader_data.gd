class_name LeaderData
extends Resource

## Immutable leader definition.

@export var id: StringName
@export var faction: StringName
@export_range(1, 99) var life: int = 20
@export var ability: AbilityData
## Upgraded versions of the ability (powers 1 and 2; 0 is the ability above). See with_power().
@export var powers: Array[LeaderPowerData] = []
@export var art: Texture2D
## The power this copy plays with: 0 for the base ability, else an index in powers + 1.
var power: int = 0


## This Leader playing with `index` (0 = base ability): a copy whose ability is that power's. An
## unknown index gives the base Leader. The engine only reads `ability`.
func with_power(index: int) -> LeaderData:
	if index <= 0 or index > powers.size():
		return self
	var copy: LeaderData = duplicate(false)
	copy.ability = powers[index - 1].ability
	copy.power = index
	return copy


## Translation key prefix of the ability in use: LEADER_<ID>_ABILITY or LEADER_<ID>_POWER<n>
## (+ "_NAME" / "_TEXT").
func ability_key() -> String:
	if power == 0:
		return "LEADER_%s_ABILITY" % String(id).to_upper()
	return "LEADER_%s_POWER%d" % [String(id).to_upper(), power]
