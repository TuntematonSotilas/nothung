extends GdUnitTestSuite

## Achievements: statistics, manual claims, taking a match back, MatchStats.

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
		"opponent_held_ring": false, "reforged": false, "artifacts_played": 0,
		"spells_played": 0, "leader_abilities_used": 0, "units_lost": 2,
	}
	summary.merge(overrides, true)
	return summary


func test_a_first_win_makes_an_achievement_claimable_without_paying_it() -> void:
	var change: Dictionary = Achievements.record_match(_summary(true))
	assert_array(change["reached"]).contains_exactly(["first_victory", "normal_victory"])
	assert_bool(Achievements.is_claimable("first_victory")).is_true()
	assert_bool(Achievements.is_unlocked("first_victory")).is_false()
	assert_int(change["level"]["xp"]).is_equal(PlayerLevel.XP_WIN[1])
	# Nothing is paid until claimed (level rewards too).
	assert_int(SaveManager.rhinegold()).is_equal(0)
	var again: Dictionary = Achievements.record_match(_summary(true))
	assert_array(again["reached"]).is_empty()
	assert_int(again["level"]["xp"]).is_equal(PlayerLevel.XP_WIN[1])
	assert_int(Achievements.stat("wins")).is_equal(2)
	assert_int(Achievements.stat("matches")).is_equal(2)
	assert_int(SaveManager.rhinegold()).is_equal(0)
	var claim: Dictionary = Achievements.claim("first_victory")
	assert_int(claim["reward"]).is_equal(20)
	assert_int(claim["level"]["xp"]).is_equal(PlayerLevel.XP_ACHIEVEMENT)
	assert_int(SaveManager.rhinegold()).is_equal(20)
	assert_bool(Achievements.is_unlocked("first_victory")).is_true()
	assert_bool(Achievements.claim("first_victory").is_empty()).is_true()


func test_a_loss_counts_the_match_only() -> void:
	var change: Dictionary = Achievements.record_match(_summary(false, {"life": 1, "units_lost": 0}))
	assert_array(change["reached"]).is_empty()
	assert_int(change["level"]["xp"]).is_equal(PlayerLevel.XP_MATCH)
	assert_int(Achievements.stat("matches")).is_equal(1)
	assert_int(Achievements.stat("wins")).is_equal(0)
	assert_int(Achievements.stat("twilight_wins")).is_equal(0)


func test_winning_match_tiers_reach_at_five_ten_twenty_and_fifty() -> void:
	var reached: Array = []
	for index: int in 50:
		var change: Dictionary = Achievements.record_match(_summary(true, {"difficulty": AIProfile.Difficulty.EASY}))
		reached.append_array(change["reached"])
	assert_array(reached).contains_exactly_in_any_order([
		"first_victory", "five_wins", "einherjar", "twenty_wins", "valhalla",
	])
	assert_bool(Achievements.is_claimable("normal_victory")).is_false()
	assert_int(Achievements.stat("wins")).is_equal(50)


func test_special_wins() -> void:
	var change: Dictionary = Achievements.record_match(_summary(true, {
		"difficulty": 2, "life": 1, "holds_ring": true, "units_lost": 0,
	}))
	assert_array(change["reached"]).contains_exactly_in_any_order([
		"first_victory", "gotterdammerung", "twilight", "renunciation_of_love", "invulnerable",
	])
	# The Ring once held by the opponent does not count.
	Achievements.revert(change)
	change = Achievements.record_match(_summary(true, {"holds_ring": true, "opponent_held_ring": true}))
	assert_array(change["reached"]).not_contains(["renunciation_of_love"])


func test_four_evenings_needs_a_win_with_each_leader() -> void:
	for leader: String in ["wotan", "wotan", "alberich", "siegfried"]:
		Achievements.record_match(_summary(true, {"leader": leader}))
	assert_int(Achievements.stat("leaders_won")).is_equal(3)
	assert_bool(Achievements.is_unlocked("four_evenings")).is_false()
	var change: Dictionary = Achievements.record_match(_summary(true, {"leader": "brunnhilde"}))
	assert_array(change["reached"]).contains(["four_evenings"])


func test_revert_takes_the_match_back() -> void:
	SaveManager.add_rhinegold(5)
	var change: Dictionary = Achievements.record_match(_summary(true, {"leader": "alberich", "artifacts_played": 3}))
	Achievements.revert(change)
	assert_int(Achievements.stat("matches")).is_equal(0)
	assert_int(Achievements.stat("artifacts_played")).is_equal(0)
	assert_int(Achievements.stat("leaders_won")).is_equal(0)
	assert_bool(Achievements.is_unlocked("first_victory")).is_false()
	assert_bool(Achievements.is_claimable("first_victory")).is_false()
	assert_int(PlayerLevel.total_xp()).is_equal(0)
	assert_int(SaveManager.rhinegold()).is_equal(5)


func test_counters_unlock_at_their_target() -> void:
	for index: int in 10:
		Achievements.record_match(_summary(false, {"reforged": true, "artifacts_played": 2}))
	assert_bool(Achievements.is_claimable("notung")).is_true()
	assert_bool(Achievements.is_claimable("nibelung_hoard")).is_true()
	assert_int(Achievements.progress(Achievements.find("nibelung_hoard"))).is_equal(20)
	var xp_before_craft: int = PlayerLevel.total_xp()
	assert_array(Achievements.record_craft()["reached"]).contains_exactly(["mimes_apprentice"])
	assert_bool(Achievements.is_claimable("mimes_apprentice")).is_true()
	assert_int(PlayerLevel.total_xp()).is_equal(xp_before_craft)


func test_match_activity_reaches_artifact_spell_and_ability_milestones() -> void:
	var change: Dictionary = Achievements.record_match(_summary(false, {
		"artifacts_played": 50,
		"spells_played": 50,
		"leader_abilities_used": 50,
	}))
	assert_array(change["reached"]).contains_exactly_in_any_order([
		"artifacts_10", "nibelung_hoard", "artifacts_50",
		"spells_10", "spells_20", "spells_50",
		"leader_ability_10", "leader_ability_20", "leader_ability_50",
	])
	assert_int(Achievements.stat("artifacts_played")).is_equal(50)
	assert_int(Achievements.stat("spells_played")).is_equal(50)
	assert_int(Achievements.stat("leader_abilities_used")).is_equal(50)


func test_crafting_reaches_each_requested_tier() -> void:
	var reached: Array = []
	for index: int in 10:
		reached.append_array(Achievements.record_craft()["reached"])
	assert_array(reached).contains_exactly_in_any_order([
		"mimes_apprentice", "craft_two", "craft_five", "forging_song",
	])
	assert_int(Achievements.stat("cards_crafted")).is_equal(10)


func test_unlock_achievements_track_powers_and_backgrounds_in_the_profile() -> void:
	var change: Dictionary
	SaveManager.profile["leader_powers"] = {"wotan": [1]}
	change = Achievements.refresh_reached()
	assert_array(change["reached"]).contains_exactly(["power_unlock_1"])
	SaveManager.profile["leader_powers"]["wotan"].append(2)
	change = Achievements.refresh_reached()
	assert_array(change["reached"]).contains_exactly(["power_unlock_2"])
	SaveManager.profile["leader_powers"]["alberich"] = [1, 2]
	change = Achievements.refresh_reached()
	assert_array(change["reached"]).contains_exactly(["power_unlock_4"])
	for leader_id: StringName in CardDatabase.leader_ids():
		var leader: LeaderData = CardDatabase.get_leader(leader_id)
		var unlocked: Array = []
		for index: int in leader.powers.size():
			unlocked.append(index + 1)
		SaveManager.profile["leader_powers"][String(leader_id)] = unlocked
	change = Achievements.refresh_reached()
	assert_array(change["reached"]).contains(["all_powers"])
	assert_int(Achievements.target(Achievements.find("all_powers"))).is_equal(Achievements.stat("powers_unlocked"))

	SaveManager.profile["cosmetics"] = ["home_rhine_depths"]
	change = Achievements.refresh_reached()
	assert_array(change["reached"]).contains_exactly(["background_unlock_1"])
	SaveManager.profile["cosmetics"].append("board_valhalla")
	change = Achievements.refresh_reached()
	assert_array(change["reached"]).contains_exactly(["background_unlock_2"])
	for cosmetic: Dictionary in Cosmetics.LIST:
		if not SaveManager.profile["cosmetics"].has(cosmetic["id"]):
			SaveManager.profile["cosmetics"].append(cosmetic["id"])
	change = Achievements.refresh_reached()
	assert_array(change["reached"]).contains(["all_backgrounds"])
	assert_int(Achievements.target(Achievements.find("all_backgrounds"))).is_equal(Cosmetics.LIST.size())


func test_match_stats_count_the_players_artifacts_and_forget_an_undone_play() -> void:
	var engine := Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), 7)
	var player: PlayerState = engine.get_state().player(0)
	player.hand.add(CardInstance.new(CardDatabase.get_card(&"wotans_spear"), 0, 900))
	player.hand.add(CardInstance.new(CardDatabase.get_card(&"donners_hammer"), 0, 901))
	var stats := MatchStats.new()
	stats.checkpoint()
	stats.before_action(engine, PlayCardAction.new(0, 900))
	stats.before_action(engine, PlayCardAction.new(0, 901))
	stats.before_action(engine, UseLeaderAbilityAction.new(0))
	stats.on_event(GameEvent.new(&"unit_destroyed", 0, 1))
	stats.on_event(GameEvent.new(&"ring_taken", 1))
	stats.on_event(GameEvent.new(&"card_reforged", 0, 2))
	assert_int(stats.artifacts_played).is_equal(1)
	assert_int(stats.spells_played).is_equal(1)
	assert_int(stats.leader_abilities_used).is_equal(1)
	assert_int(stats.units_lost).is_equal(1)
	assert_bool(stats.opponent_held_ring).is_true()
	assert_bool(stats.reforged).is_true()
	stats.rollback()
	assert_int(stats.artifacts_played).is_equal(0)
	assert_int(stats.spells_played).is_equal(0)
	assert_int(stats.leader_abilities_used).is_equal(0)
	assert_int(stats.units_lost).is_equal(0)
	assert_bool(stats.opponent_held_ring).is_false()
	assert_bool(stats.reforged).is_false()
	# The opponent's artifacts do not count.
	stats.before_action(engine, PlayCardAction.new(1, 900))
	assert_int(stats.artifacts_played).is_equal(0)
	stats.before_action(engine, UseLeaderAbilityAction.new(1))
	assert_int(stats.leader_abilities_used).is_equal(0)
