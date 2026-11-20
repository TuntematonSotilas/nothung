extends GdUnitTestSuite

## Player level: the XP curve, the level reached, its Rhinegold, taking XP back.

var _saved_profile: Dictionary
var _saved_path: String


func before_test() -> void:
	_saved_profile = SaveManager.profile.duplicate(true)
	_saved_path = SaveManager.path
	SaveManager.path = create_temp_dir("player_level_%d" % Time.get_ticks_usec()) + "/profile.json"
	SaveManager.profile = SaveManager.default_profile()


func after_test() -> void:
	SaveManager.path = _saved_path
	SaveManager.profile = _saved_profile


func test_the_curve_is_fast_then_slower_up_to_the_cap() -> void:
	assert_int(PlayerLevel.xp_to_next(1)).is_equal(20)
	assert_int(PlayerLevel.xp_to_next(10)).is_equal(110)
	assert_int(PlayerLevel.xp_to_next(29)).is_equal(300)
	assert_int(PlayerLevel.level_for(0)).is_equal(1)
	assert_int(PlayerLevel.level_for(19)).is_equal(1)
	assert_int(PlayerLevel.level_for(20)).is_equal(2)
	assert_int(PlayerLevel.level_for(50)).is_equal(3)
	assert_int(PlayerLevel.level_for(4640)).is_equal(PlayerLevel.MAX_LEVEL)
	assert_int(PlayerLevel.level_for(4639)).is_equal(PlayerLevel.MAX_LEVEL - 1)
	assert_int(PlayerLevel.level_for(100000)).is_equal(PlayerLevel.MAX_LEVEL)


func test_match_xp_by_result_and_difficulty() -> void:
	assert_int(PlayerLevel.match_xp(false, 2)).is_equal(10)
	assert_int(PlayerLevel.match_xp(true, 0)).is_equal(20)
	assert_int(PlayerLevel.match_xp(true, 1)).is_equal(30)
	assert_int(PlayerLevel.match_xp(true, 2)).is_equal(40)


func test_levels_reached_pay_and_revert_takes_them_back() -> void:
	SaveManager.add_rhinegold(7)
	var change: Dictionary = PlayerLevel.add_xp(55)
	assert_array(change["levels"]).contains_exactly([2, 3])
	assert_int(change["rhinegold"]).is_equal(2 * PlayerLevel.RHINEGOLD_PER_LEVEL)
	assert_int(SaveManager.rhinegold()).is_equal(7 + 80)
	assert_int(PlayerLevel.level()).is_equal(3)
	assert_that(PlayerLevel.progress()).is_equal(Vector2i(5, 40))
	PlayerLevel.revert(change)
	assert_int(PlayerLevel.total_xp()).is_equal(0)
	assert_int(PlayerLevel.level()).is_equal(1)
	assert_int(SaveManager.rhinegold()).is_equal(7)


func test_the_last_level_has_no_progress_and_pays_nothing_more() -> void:
	PlayerLevel.add_xp(4640)
	assert_int(PlayerLevel.level()).is_equal(PlayerLevel.MAX_LEVEL)
	assert_that(PlayerLevel.progress()).is_equal(Vector2i.ZERO)
	var change: Dictionary = PlayerLevel.add_xp(500)
	assert_array(change["levels"]).is_empty()
	assert_int(change["rhinegold"]).is_equal(0)
