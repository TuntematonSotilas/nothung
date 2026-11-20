class_name LeaderPowers
extends RefCounted

## Leader powers (docs/functional/06-progression.md#leader-powers): upgraded versions of a Leader's
## ability (LeaderData.powers), unlocked in Nibelheim once the player level is reached, for Rhinegold.
## Unlocked ones are kept per Leader in profile["leader_powers"] ({"wotan": [1, 2]}); a deck plays the
## one saved in its entry ("power", 0 = the base ability).


## Power indices unlocked for this Leader (the base ability, 0, is always available).
static func unlocked(leader_id: StringName) -> Array:
	var all: Dictionary = SaveManager.profile.get("leader_powers", {})
	return all.get(String(leader_id), [])


static func is_unlocked(leader_id: StringName, index: int) -> bool:
	return index == 0 or unlocked(leader_id).has(index)


## What is still missing to unlock it: {"level": level needed (0 when reached), "rhinegold": Rhinegold
## short (0 when enough)}.
static func missing(leader: LeaderData, index: int) -> Dictionary:
	var power: LeaderPowerData = leader.powers[index - 1]
	return {
		"level": power.level if PlayerLevel.level() < power.level else 0,
		"rhinegold": maxi(0, power.price - SaveManager.rhinegold()),
	}


static func can_unlock(leader: LeaderData, index: int) -> bool:
	if index < 1 or index > leader.powers.size() or is_unlocked(leader.id, index):
		return false
	var short: Dictionary = missing(leader, index)
	return int(short["level"]) == 0 and int(short["rhinegold"]) == 0


## Spends its price and keeps it unlocked; false (nothing spent) when it cannot be unlocked yet.
static func unlock(leader: LeaderData, index: int) -> bool:
	if not can_unlock(leader, index):
		return false
	var all: Dictionary = SaveManager.profile["leader_powers"]
	var list: Array = all.get(String(leader.id), [])
	list.append(index)
	list.sort()
	all[String(leader.id)] = list
	# add_rhinegold saves the profile (with the power) and tells the screens.
	SaveManager.add_rhinegold(-leader.powers[index - 1].price)
	return true


## The power a deck entry plays with: its "power" if still unlocked, else the base ability.
static func of_entry(entry: Dictionary) -> int:
	var index: int = int(entry.get("power", 0))
	return index if is_unlocked(StringName(str(entry.get("leader", ""))), index) else 0


## Name and effect of a Leader's power: "Wotans Zorn — Deal 3 damage to a unit."
static func title(leader: LeaderData, index: int) -> String:
	var key: String = leader.with_power(index).ability_key()
	return "%s — %s" % [TranslationServer.translate(key + "_NAME"), TranslationServer.translate(key + "_TEXT")]
