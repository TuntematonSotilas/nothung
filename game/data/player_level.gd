class_name PlayerLevel
extends RefCounted

## Player level (docs/functional/06-progression.md#player-level): XP from every finished Quick match
## (more for a win, by difficulty) and from each achievement claimed. The profile keeps the total
## (profile["xp"]); the level is derived from it. Each level reached gives Rhinegold, claimed by hand from
## the main menu (profile["level_rewards_claimed"]: the highest level whose reward was taken).

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
	return progress_of(total_xp())


## progress() for a total of `xp`.
static func progress_of(xp: int) -> Vector2i:
	var current: int = level_for(xp)
	if current >= MAX_LEVEL:
		return Vector2i.ZERO
	var before: int = 0
	for step: int in range(1, current):
		before += xp_to_next(step)
	return Vector2i(xp - before, xp_to_next(current))


## XP of a finished Quick match.
static func match_xp(won: bool, difficulty: int) -> int:
	if not won:
		return XP_MATCH
	return XP_WIN[clampi(difficulty, 0, XP_WIN.size() - 1)]


## Adds XP and saves; the rewards of the levels reached wait to be claimed. Returns what changed, for
## revert() and the screens: {"xp", "levels" (each level reached), "before" (total XP before)}.
static func add_xp(amount: int) -> Dictionary:
	var before: int = level()
	var before_xp: int = total_xp()
	SaveManager.profile["xp"] = before_xp + maxi(0, amount)
	var levels: Array = range(before + 1, level() + 1)
	SaveManager.save_profile()
	SaveManager.profile_changed.emit()
	return {"xp": maxi(0, amount), "levels": levels, "before": before_xp}


## Takes back XP added by add_xp(); a level it reached is no longer there to claim.
static func revert(change: Dictionary) -> void:
	SaveManager.profile["xp"] = maxi(0, total_xp() - int(change.get("xp", 0)))
	SaveManager.save_profile()
	SaveManager.profile_changed.emit()


## Levels reached whose reward has not been claimed yet.
static func pending_rewards() -> Array:
	var claimed: int = int(SaveManager.profile.get("level_rewards_claimed", 1))
	return range(maxi(claimed, 1) + 1, level() + 1)


## Claims every pending level reward: {"levels", "rhinegold"} (empty levels when none was waiting).
static func claim_rewards() -> Dictionary:
	var levels: Array = pending_rewards()
	if levels.is_empty():
		return {"levels": [], "rhinegold": 0}
	SaveManager.profile["level_rewards_claimed"] = level()
	var rhinegold: int = RHINEGOLD_PER_LEVEL * levels.size()
	# add_rhinegold saves the profile and tells the screens.
	SaveManager.add_rhinegold(rhinegold)
	return {"levels": levels, "rhinegold": rhinegold}


## "Level 8 reached! Reward to claim in the main menu.", for the results screen and Nibelheim.
static func level_up_text(reached: int) -> String:
	return TranslationServer.translate("UI_LEVEL_UP").format({"level": reached, "amount": RHINEGOLD_PER_LEVEL})


## "Level 8: +40 Rhinegold" (several levels: "Levels 7–8: +80 Rhinegold"), once claimed.
static func claimed_text(claim: Dictionary) -> String:
	var levels: Array = claim["levels"]
	var key: String = "UI_LEVEL_REWARD_CLAIMED" if levels.size() == 1 else "UI_LEVEL_REWARDS_CLAIMED"
	return TranslationServer.translate(key).format({"level": levels.back(), "first": levels.front(), "amount": claim["rhinegold"]})
