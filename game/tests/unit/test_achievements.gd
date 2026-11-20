extends GdUnitTestSuite

## Achievements: statistics, unlocking once with its Rhinegold, taking a match back, MatchStats.

var _saved_profile: Dictionary
var _saved_path: String


func before_test() -> void:
	_saved_profile = SaveManager.profile.duplicate(true)
	_saved_path = SaveManager.path
	SaveManager.path = create_temp_dir("achievements_%d" % Time.get_ticks_usec()) + "/profile.json"
	SaveManager.profile = SaveManager.default_profile()


func after_test() -> void:
	SaveManager.path = _saved_path
	SaveManager.profile = _saved_profile


func _summary(won: bool, overrides: Dictionary = {}) -> Dictionary:
	var summary: Dictionary = {
		"won": won, "difficulty": 1, "leader": "wotan", "life": 12, "holds_ring": false,
		"opponent_held_ring": false, "reforged": false, "artifacts_played": 0, "units_lost": 2,
	}
	summary.merge(overrides, true)
	return summary


func test_a_first_win_unlocks_once_and_pays() -> void:
	var change: Dictionary = Achievements.record_match(_summary(true))
	assert_array(change["unlocked"]).contains_exactly(["first_victory"])
	# The Normal win and the achievement give XP; the levels reached pay their own Rhinegold.
	assert_int(change["level"]["xp"]).is_equal(PlayerLevel.XP_WIN[1] + PlayerLevel.XP_ACHIEVEMENT)
	assert_int(SaveManager.rhinegold()).is_equal(20 + int(change["level"]["rhinegold"]))
	var before: int = SaveManager.rhinegold()
	var again: Dictionary = Achievements.record_match(_summary(true))
	assert_array(again["unlocked"]).is_empty()
	assert_int(again["level"]["xp"]).is_equal(PlayerLevel.XP_WIN[1])
	assert_int(Achievements.stat("wins")).is_equal(2)
	assert_int(Achievements.stat("matches")).is_equal(2)
	assert_int(SaveManager.rhinegold()).is_equal(before + int(again["level"]["rhinegold"]))


func test_a_loss_counts_the_match_only() -> void:
	var change: Dictionary = Achievements.record_match(_summary(false, {"life": 1, "units_lost": 0}))
	assert_array(change["unlocked"]).is_empty()
	assert_int(change["level"]["xp"]).is_equal(PlayerLevel.XP_MATCH)
	assert_int(Achievements.stat("matches")).is_equal(1)
	assert_int(Achievements.stat("wins")).is_equal(0)
	assert_int(Achievements.stat("twilight_wins")).is_equal(0)


func test_special_wins() -> void:
	var change: Dictionary = Achievements.record_match(_summary(true, {
		"difficulty": 2, "life": 1, "holds_ring": true, "units_lost": 0,
	}))
	assert_array(change["unlocked"]).contains_exactly_in_any_order([
		"first_victory", "gotterdammerung", "twilight", "renunciation_of_love", "invulnerable",
	])
	# The Ring once held by the opponent does not count.
	Achievements.revert(change)
	change = Achievements.record_match(_summary(true, {"holds_ring": true, "opponent_held_ring": true}))
	assert_array(change["unlocked"]).not_contains(["renunciation_of_love"])


func test_four_evenings_needs_a_win_with_each_leader() -> void:
	for leader: String in ["wotan", "wotan", "alberich", "siegfried"]:
		Achievements.record_match(_summary(true, {"leader": leader}))
	assert_int(Achievements.stat("leaders_won")).is_equal(3)
	assert_bool(Achievements.is_unlocked("four_evenings")).is_false()
	var change: Dictionary = Achievements.record_match(_summary(true, {"leader": "brunnhilde"}))
	assert_array(change["unlocked"]).contains(["four_evenings"])


func test_revert_takes_the_match_back() -> void:
	SaveManager.add_rhinegold(5)
	var change: Dictionary = Achievements.record_match(_summary(true, {"leader": "alberich", "artifacts_played": 3}))
	Achievements.revert(change)
	assert_int(Achievements.stat("matches")).is_equal(0)
	assert_int(Achievements.stat("artifacts_played")).is_equal(0)
	assert_int(Achievements.stat("leaders_won")).is_equal(0)
	assert_bool(Achievements.is_unlocked("first_victory")).is_false()
	assert_int(PlayerLevel.total_xp()).is_equal(0)
	assert_int(SaveManager.rhinegold()).is_equal(5)


func test_counters_unlock_at_their_target() -> void:
	for index: int in 10:
		Achievements.record_match(_summary(false, {"reforged": true, "artifacts_played": 2}))
	assert_bool(Achievements.is_unlocked("notung")).is_true()
	assert_bool(Achievements.is_unlocked("nibelung_hoard")).is_true()
	assert_int(Achievements.progress(Achievements.find("nibelung_hoard"))).is_equal(20)
	assert_array(Achievements.record_craft()["unlocked"]).contains_exactly(["mimes_apprentice"])


func test_match_stats_count_the_players_artifacts_and_forget_an_undone_play() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 7)
	var player: PlayerState = engine.get_state().player(0)
	player.hand.add(CardInstance.new(CardDatabase.get_card(&"wotans_spear"), 0, 900))
	var stats := MatchStats.new()
	stats.checkpoint()
	stats.before_action(engine, PlayCardAction.new(0, 900))
	stats.on_event(GameEvent.new(&"unit_destroyed", 0, 1))
	stats.on_event(GameEvent.new(&"ring_taken", 1))
	stats.on_event(GameEvent.new(&"card_reforged", 0, 2))
	assert_int(stats.artifacts_played).is_equal(1)
	assert_int(stats.units_lost).is_equal(1)
	assert_bool(stats.opponent_held_ring).is_true()
	assert_bool(stats.reforged).is_true()
	stats.rollback()
	assert_int(stats.artifacts_played).is_equal(0)
	assert_int(stats.units_lost).is_equal(0)
	assert_bool(stats.opponent_held_ring).is_false()
	assert_bool(stats.reforged).is_false()
	# The opponent's artifacts do not count.
	stats.before_action(engine, PlayCardAction.new(1, 900))
	assert_int(stats.artifacts_played).is_equal(0)
