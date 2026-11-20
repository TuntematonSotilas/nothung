class_name Achievements
extends RefCounted

## Achievements (docs/functional/06-progression.md#achievements): each one counts a statistic of the
## profile (SaveManager.profile["stats"]) up to a target, and pays Rhinegold once when reached. Unlocked
## IDs are kept in profile["achievements"]. Only Quick matches count (DuelSetup.rewards), plus crafting
## in Nibelheim. Names and descriptions: ACHIEVEMENT_<ID>_NAME / _DESC.

## id, statistic counted, target, Rhinegold reward. Order = order on the Achievements screen.
const LIST: Array[Dictionary] = [
	{"id": "first_victory", "stat": "wins", "target": 1, "reward": 20},
	{"id": "einherjar", "stat": "wins", "target": 10, "reward": 50},
	{"id": "valhalla", "stat": "wins", "target": 50, "reward": 150},
	{"id": "ring_cycle", "stat": "matches", "target": 100, "reward": 100},
	{"id": "four_evenings", "stat": "leaders_won", "target": 4, "reward": 100},
	{"id": "gotterdammerung", "stat": "hard_wins", "target": 1, "reward": 60},
	{"id": "twilight", "stat": "twilight_wins", "target": 1, "reward": 40},
	{"id": "renunciation_of_love", "stat": "ring_wins", "target": 1, "reward": 40},
	{"id": "notung", "stat": "reforge_matches", "target": 10, "reward": 80},
	{"id": "nibelung_hoard", "stat": "artifacts_played", "target": 20, "reward": 40},
	{"id": "invulnerable", "stat": "flawless_wins", "target": 1, "reward": 60},
	{"id": "mimes_apprentice", "stat": "cards_crafted", "target": 1, "reward": 20},
	{"id": "forging_song", "stat": "cards_crafted", "target": 10, "reward": 60},
]
const HARD: int = 2


## The facts of a finished match that achievements count. `stats` comes from replaying its record.
static func summarize(state: GameState, stats: MatchStats, difficulty: int) -> Dictionary:
	var me: PlayerState = state.player(MatchStats.PLAYER)
	return {
		"won": state.winner == MatchStats.PLAYER,
		"difficulty": difficulty,
		"leader": String(me.leader.id),
		"life": me.life,
		"holds_ring": state.ring_holder == MatchStats.PLAYER,
		"opponent_held_ring": stats.opponent_held_ring,
		"reforged": stats.reforged,
		"artifacts_played": stats.artifacts_played,
		"units_lost": stats.units_lost,
	}


## Adds a finished match to the statistics, unlocks what it reaches and gives the XP of the match and
## of its achievements (PlayerLevel). Returns what changed, for revert() (undoing the winning play from
## the results) and the results screen: {"counts", "leader", "unlocked", "rhinegold", "level"}.
static func record_match(summary: Dictionary) -> Dictionary:
	var won: bool = summary["won"]
	var counts: Dictionary = {
		"matches": 1,
		"wins": 1 if won else 0,
		"hard_wins": 1 if won and int(summary["difficulty"]) == HARD else 0,
		"twilight_wins": 1 if won and int(summary["life"]) == 1 else 0,
		"ring_wins": 1 if won and summary["holds_ring"] and not summary["opponent_held_ring"] else 0,
		"flawless_wins": 1 if won and int(summary["units_lost"]) == 0 else 0,
		"reforge_matches": 1 if summary["reforged"] else 0,
		"artifacts_played": int(summary["artifacts_played"]),
	}
	var leader: String = ""
	var leaders: Array = _leaders_won()
	if won and not leaders.has(summary["leader"]):
		leader = summary["leader"]
		leaders.append(leader)
	_add_counts(counts, 1)
	var change: Dictionary = {"counts": counts, "leader": leader}
	change.merge(_unlock_reached())
	var xp: int = PlayerLevel.match_xp(won, int(summary["difficulty"])) + PlayerLevel.XP_ACHIEVEMENT * (change["unlocked"] as Array).size()
	change["level"] = PlayerLevel.add_xp(xp)
	return change


## A card forged in Nibelheim: {"unlocked" (IDs), "level" (PlayerLevel.add_xp() of their XP)}.
static func record_craft() -> Dictionary:
	_add_counts({"cards_crafted": 1}, 1)
	var change: Dictionary = _unlock_reached()
	change["level"] = PlayerLevel.add_xp(PlayerLevel.XP_ACHIEVEMENT * (change["unlocked"] as Array).size())
	return change


## Takes back a match recorded by record_match(): counts, Leader, achievements and their Rhinegold, XP.
static func revert(change: Dictionary) -> void:
	PlayerLevel.revert(change.get("level", {}))
	_add_counts(change.get("counts", {}), -1)
	var leader: String = change.get("leader", "")
	if not leader.is_empty():
		_leaders_won().erase(leader)
	for achievement_id: Variant in change.get("unlocked", []):
		(SaveManager.profile["achievements"] as Array).erase(achievement_id)
	SaveManager.add_rhinegold(-int(change.get("rhinegold", 0)))


## Current value of an achievement's statistic, capped at its target.
static func progress(achievement: Dictionary) -> int:
	return mini(stat(achievement["stat"]), int(achievement["target"]))


static func stat(stat_id: String) -> int:
	if stat_id == "leaders_won":
		return _leaders_won().size()
	return int(_stats().get(stat_id, 0))


static func is_unlocked(achievement_id: String) -> bool:
	return (SaveManager.profile["achievements"] as Array).has(achievement_id)


## "Achievement unlocked: Name (+40 Rhinegold)", for the results screen and Nibelheim.
static func unlocked_text(achievement_id: String) -> String:
	return TranslationServer.translate("UI_ACHIEVEMENT_UNLOCKED").format({
		"name": TranslationServer.translate("ACHIEVEMENT_%s_NAME" % achievement_id.to_upper()),
		"amount": find(achievement_id).get("reward", 0),
	})


static func find(achievement_id: String) -> Dictionary:
	for achievement: Dictionary in LIST:
		if achievement["id"] == achievement_id:
			return achievement
	return {}


static func _stats() -> Dictionary:
	var profile: Dictionary = SaveManager.profile
	if not profile.get("stats") is Dictionary:
		profile["stats"] = {}
	return profile["stats"]


static func _leaders_won() -> Array:
	var stats: Dictionary = _stats()
	if not stats.get("leaders_won") is Array:
		stats["leaders_won"] = []
	return stats["leaders_won"]


static func _add_counts(counts: Dictionary, direction: int) -> void:
	var stats: Dictionary = _stats()
	for key: String in counts:
		stats[key] = maxi(0, int(stats.get(key, 0)) + direction * int(counts[key]))
	SaveManager.save_profile()


## Unlocks every achievement whose target is reached and pays its reward: {"unlocked", "rhinegold"}.
static func _unlock_reached() -> Dictionary:
	var unlocked: Array = []
	var total: int = 0
	for achievement: Dictionary in LIST:
		var achievement_id: String = achievement["id"]
		if is_unlocked(achievement_id) or stat(achievement["stat"]) < int(achievement["target"]):
			continue
		(SaveManager.profile["achievements"] as Array).append(achievement_id)
		unlocked.append(achievement_id)
		total += int(achievement["reward"])
	# add_rhinegold saves the profile (with the new achievements) and tells the screens.
	SaveManager.add_rhinegold(total)
	return {"unlocked": unlocked, "rhinegold": total}
