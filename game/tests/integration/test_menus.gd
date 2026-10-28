extends GdUnitTestSuite

## Title → main menu → Quick match → duel; Settings.

var _saved: Dictionary = {}


func before_test() -> void:
	_saved = {
		"deck": Settings.quick_match_deck,
		"opponent": Settings.quick_match_opponent,
		"difficulty": Settings.quick_match_difficulty,
		"speed": Settings.animation_speed,
		"music": Settings.music_volume,
		"sfx": Settings.sfx_volume,
		"language": Settings.language,
		"path": Settings.path,
	}
	# Screens save the settings: keep the real file out of the tests.
	Settings.path = create_temp_dir("menus_%d" % Time.get_ticks_usec()) + "/settings.cfg"
	Settings.animation_speed = 0.0
	DuelSetup.next = null


func after_test() -> void:
	Settings.quick_match_deck = _saved["deck"]
	Settings.quick_match_opponent = _saved["opponent"]
	Settings.quick_match_difficulty = _saved["difficulty"]
	Settings.animation_speed = _saved["speed"]
	Settings.music_volume = _saved["music"]
	Settings.sfx_volume = _saved["sfx"]
	Settings.apply_audio()
	Settings.language = _saved["language"]
	Settings.apply_language()
	Settings.path = _saved["path"]
	DuelSetup.next = null


func test_main_menu_offers_quick_match_and_settings_and_greys_out_the_rest() -> void:
	var menu: Control = await _open("res://scenes/screens/main_menu.tscn")
	assert_bool((menu.find_child("QuickMatchButton", true, false) as Button).disabled).is_false()
	assert_bool((menu.find_child("SettingsButton", true, false) as Button).disabled).is_false()
	for button_name: String in ["CampaignButton", "CollectionButton"]:
		var entry: Button = menu.find_child(button_name, true, false) as Button
		assert_object(entry).is_not_null()
		assert_bool(entry.disabled).is_true()
	menu.queue_free()


func test_quick_match_starts_from_the_remembered_choices() -> void:
	Settings.quick_match_deck = "valkyries_starter"
	Settings.quick_match_opponent = "walsungs_starter"
	Settings.quick_match_difficulty = AIProfile.Difficulty.HARD
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	assert_bool(_tile(screen, "Player_valkyries_starter").button_pressed).is_true()
	assert_bool(_tile(screen, "Opponent_walsungs_starter").button_pressed).is_true()
	assert_bool(_tile(screen, "Difficulty2").button_pressed).is_true()
	var setup: DuelSetup = screen.call("build_setup")
	assert_str(String(setup.player_deck)).is_equal("valkyries_starter")
	assert_str(String(setup.opponent_deck)).is_equal("walsungs_starter")
	assert_int(setup.difficulty).is_equal(AIProfile.Difficulty.HARD)
	screen.queue_free()


func test_quick_match_choices_stay_single_and_build_the_setup() -> void:
	Settings.quick_match_deck = "gods_starter"
	Settings.quick_match_opponent = "random"
	Settings.quick_match_difficulty = AIProfile.Difficulty.NORMAL
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	_tile(screen, "Player_nibelungs_starter").pressed.emit()
	_tile(screen, "Opponent_valkyries_starter").pressed.emit()
	_tile(screen, "Difficulty0").pressed.emit()

	var pressed_players: int = 0
	for deck_id: String in ["gods_starter", "nibelungs_starter", "walsungs_starter", "valkyries_starter"]:
		if _tile(screen, "Player_" + deck_id).button_pressed:
			pressed_players += 1
	assert_int(pressed_players).is_equal(1)
	assert_bool(_tile(screen, "OpponentRandom").button_pressed).is_false()
	assert_bool(_tile(screen, "Difficulty1").button_pressed).is_false()
	var setup: DuelSetup = screen.call("build_setup")
	assert_str(String(setup.player_deck)).is_equal("nibelungs_starter")
	assert_str(String(setup.opponent_deck)).is_equal("valkyries_starter")
	assert_int(setup.difficulty).is_equal(AIProfile.Difficulty.EASY)
	screen.queue_free()


func test_random_opponent_is_another_faction() -> void:
	Settings.quick_match_deck = "walsungs_starter"
	Settings.quick_match_opponent = "random"
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen: Dictionary = {}
	for attempt: int in 30:
		var setup: DuelSetup = screen.call("build_setup", rng)
		assert_str(String(setup.opponent_deck)).is_not_equal("walsungs_starter")
		seen[setup.opponent_deck] = true
	assert_int(seen.size()).is_equal(3)
	screen.queue_free()


func test_duel_plays_the_quick_match_setup() -> void:
	DuelSetup.next = DuelSetup.new(&"walsungs_starter", &"valkyries_starter", AIProfile.Difficulty.EASY)
	var duel: Control = await _open("res://scenes/screens/duel.tscn")
	var state: GameState = (duel.get("_match") as Match).get_state()
	assert_str(String(state.player(0).leader.id)).is_equal("siegfried")
	assert_str(String(state.player(1).leader.id)).is_equal("brunnhilde")
	assert_int((duel.get("_ai_profile") as AIProfile).difficulty).is_equal(AIProfile.Difficulty.EASY)
	duel.queue_free()
	await get_tree().process_frame


func test_settings_show_the_current_values() -> void:
	Settings.music_volume = 0.3
	Settings.language = "de"
	var screen: Control = await _open("res://scenes/screens/settings_menu.tscn")
	assert_float((screen.find_child("MusicSlider", true, false) as HSlider).value).is_equal(30.0)
	assert_bool(_tile(screen, "Language_de").button_pressed).is_true()
	assert_bool(_tile(screen, "Language_auto").button_pressed).is_false()
	screen.queue_free()


func test_settings_changes_are_applied_and_saved() -> void:
	Settings.language = ""
	var screen: Control = await _open("res://scenes/screens/settings_menu.tscn")
	(screen.find_child("SfxSlider", true, false) as HSlider).value = 40.0
	assert_float(Settings.sfx_volume).is_equal_approx(0.4, 0.001)
	var bus: int = AudioServer.get_bus_index(Settings.SFX_BUS)
	assert_int(bus).is_greater(0)
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(linear_to_db(0.4), 0.01)

	_tile(screen, "Language_fr").pressed.emit()
	assert_str(TranslationServer.get_locale()).is_equal("fr")
	# Rebuilt in the new language.
	assert_bool(_tile(screen, "Language_fr").button_pressed).is_true()
	assert_bool(_tile(screen, "Language_auto").button_pressed).is_false()

	var saved := ConfigFile.new()
	assert_int(saved.load(Settings.path)).is_equal(OK)
	assert_float(saved.get_value("audio", "sfx_volume")).is_equal_approx(0.4, 0.001)
	assert_str(saved.get_value("display", "language")).is_equal("fr")
	screen.queue_free()


func _open(scene_path: String) -> Control:
	var screen: Control = (load(scene_path) as PackedScene).instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	return screen


func _tile(screen: Control, tile_name: String) -> Button:
	return screen.find_child(tile_name, true, false) as Button
