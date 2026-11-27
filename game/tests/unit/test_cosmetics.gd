extends GdUnitTestSuite

## Backgrounds: catalogue, buying (level then Rhinegold, once), the home background and a deck's board.

var _saved_profile: Dictionary
var _saved_path: String


func before_test() -> void:
	_saved_profile = SaveManager.profile.duplicate(true)
	_saved_path = SaveManager.path
	SaveManager.path = create_temp_dir("cosmetics_%d" % Time.get_ticks_usec()) + "/profile.json"
	SaveManager.profile = SaveManager.default_profile()


func after_test() -> void:
	SaveManager.path = _saved_path
	SaveManager.profile = _saved_profile


func test_three_home_backgrounds_and_three_boards_each_with_its_picture_and_name() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var kinds: Dictionary = {Cosmetics.HOME: 0, Cosmetics.BOARD: 0}
	var levels: Array[int] = []
	for cosmetic: Dictionary in Cosmetics.LIST:
		kinds[cosmetic["kind"]] += 1
		levels.append(int(cosmetic["level"]))
		assert_object(Cosmetics.texture(cosmetic["id"])).is_not_null()
		assert_str(tr(Cosmetics.name_key(cosmetic["id"]))).is_not_equal(Cosmetics.name_key(cosmetic["id"]))
	assert_dict(kinds).is_equal({Cosmetics.HOME: 3, Cosmetics.BOARD: 3})
	assert_array(levels).contains_exactly([5, 10, 15, 20, 25, 30])
	assert_str(tr(Cosmetics.name_key("board_valhalla"))).is_equal("The Gibichung Hall")
	assert_str(tr(Cosmetics.name_key("board_valkyrie_rock"))).is_equal("Fafnir's Forest")
	assert_object(Cosmetics.texture("")).is_null()
	TranslationServer.set_locale(previous_locale)


func test_buying_needs_the_level_then_the_rhinegold_and_happens_once() -> void:
	SaveManager.add_rhinegold(1000)
	assert_dict(Cosmetics.missing("home_rhine_depths")).is_equal({"level": 5, "rhinegold": 0})
	assert_bool(Cosmetics.buy("home_rhine_depths")).is_false()
	# Level 5: 20 + 30 + 40 + 50 XP.
	SaveManager.profile["xp"] = 140
	assert_bool(Cosmetics.buy("home_rhine_depths")).is_true()
	assert_bool(Cosmetics.is_owned("home_rhine_depths")).is_true()
	assert_int(SaveManager.rhinegold()).is_equal(850)
	assert_bool(Cosmetics.buy("home_rhine_depths")).is_false()
	assert_array(Cosmetics.owned(Cosmetics.HOME)).contains_exactly(["home_rhine_depths"])
	assert_array(Cosmetics.owned(Cosmetics.BOARD)).is_empty()
	SaveManager.profile["xp"] = 10000
	SaveManager.profile["rhinegold"] = 599
	assert_dict(Cosmetics.missing("board_ring")).is_equal({"level": 0, "rhinegold": 1})
	assert_bool(Cosmetics.buy("board_ring")).is_false()


func test_only_an_owned_background_of_the_right_kind_can_be_used() -> void:
	assert_bool(Cosmetics.set_home_background("home_nibelheim")).is_false()
	SaveManager.profile["cosmetics"] = ["home_nibelheim", "board_valhalla"]
	assert_bool(Cosmetics.set_home_background("board_valhalla")).is_false()
	assert_bool(Cosmetics.set_home_background("home_nibelheim")).is_true()
	assert_str(Cosmetics.home_background()).is_equal("home_nibelheim")
	var entry: Dictionary = {"id": "deck_1", "leader": "wotan", "cards": []}
	assert_bool(Cosmetics.set_board(entry, "home_nibelheim")).is_false()
	assert_bool(Cosmetics.set_board(entry, "board_valhalla")).is_true()
	assert_str(Cosmetics.board_of(entry)).is_equal("board_valhalla")
	# A background no longer owned falls back to the default.
	SaveManager.profile["cosmetics"] = []
	assert_str(Cosmetics.home_background()).is_empty()
	assert_str(Cosmetics.board_of(entry)).is_empty()
