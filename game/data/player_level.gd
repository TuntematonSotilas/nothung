class_name PlayerLevel
extends RefCounted

## Player level (docs/functional/06-progression.md#player-level): XP from every finished Quick match
## (more for a win, by difficulty) and from each achievement unlocked. The profile keeps the total
## (profile["xp"]); the level is derived from it. Each level reached pays Rhinegold; levels lock nothing.

## Loss or draw.
const XP_MATCH: int = 10
## Win, by AI difficulty (Easy, Normal, Hard).
const XP_WIN: Array[int] = [20, 30, 40]
const XP_ACHIEVEMENT: int = 25
const MAX_LEVEL: int = 30
const RHINEGOLD_PER_LEVEL: int = 40


## XP to go from `level` to the next one: 20, 30, 40… (300 for the last one).
static func xp_to_next(level: int) -> int:
	return 20 + 10 * (level - 1)


## Level reached with a total of `total_xp`.
static func level_for(total_xp: int) -> int:
	var level: int = 1
	var left: int = total_xp
	while level < MAX_LEVEL and left >= xp_to_next(level):
		left -= xp_to_next(level)
		level += 1
	return level


static func total_xp() -> int:
	return int(SaveManager.profile.get("xp", 0))


static func level() -> int:
	return level_for(total_xp())


## XP earned inside the current level and the XP it needs: (45, 80). (0, 0) at the last level.
static func progress() -> Vector2i:
	var current: int = level()
	if current >= MAX_LEVEL:
		return Vector2i.ZERO
	var before: int = 0
	for step: int in range(1, current):
		before += xp_to_next(step)
	return Vector2i(total_xp() - before, xp_to_next(current))


## XP of a finished Quick match.
static func match_xp(won: bool, difficulty: int) -> int:
	if not won:
		return XP_MATCH
	return XP_WIN[clampi(difficulty, 0, XP_WIN.size() - 1)]


## Adds XP, pays the levels reached and saves. Returns what changed, for revert() and the screens:
## {"xp", "levels" (each level reached), "rhinegold"}.
static func add_xp(amount: int) -> Dictionary:
	var before: int = level()
	SaveManager.profile["xp"] = total_xp() + maxi(0, amount)
	var levels: Array = range(before + 1, level() + 1)
	var rhinegold: int = RHINEGOLD_PER_LEVEL * levels.size()
	# add_rhinegold saves the profile (with the new XP) and tells the screens.
	SaveManager.add_rhinegold(rhinegold)
	return {"xp": maxi(0, amount), "levels": levels, "rhinegold": rhinegold}


## Takes back XP added by add_xp(), with the Rhinegold of its levels.
static func revert(change: Dictionary) -> void:
	SaveManager.profile["xp"] = maxi(0, total_xp() - int(change.get("xp", 0)))
	SaveManager.add_rhinegold(-int(change.get("rhinegold", 0)))


## "Level 8! (+40 Rhinegold)", for the results screen and Nibelheim.
static func level_up_text(reached: int) -> String:
	return TranslationServer.translate("UI_LEVEL_UP").format({"level": reached, "amount": RHINEGOLD_PER_LEVEL})
