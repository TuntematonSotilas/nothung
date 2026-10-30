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
		"profile_path": SaveManager.path,
		"match_path": SaveManager.match_path,
		"profile": SaveManager.profile.duplicate(true),
	}
	# Screens save the settings and the profile: keep the real files out of the tests.
	var directory: String = create_temp_dir("menus_%d" % Time.get_ticks_usec())
	Settings.path = directory + "/settings.cfg"
	SaveManager.path = directory + "/profile.json"
	SaveManager.match_path = directory + "/current_match.json"
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
	SaveManager.path = _saved["profile_path"]
	SaveManager.match_path = _saved["match_path"]
	SaveManager.profile = _saved["profile"]
	DuelSetup.next = null


func test_main_menu_offers_quick_match_collection_and_settings_and_greys_out_the_campaign() -> void:
	SaveManager.profile["rhinegold"] = 320
	var menu: Control = await _open("res://scenes/screens/main_menu.tscn")
	for button_name: String in ["QuickMatchButton", "CollectionButton", "SettingsButton"]:
		assert_bool((menu.find_child(button_name, true, false) as Button).disabled).is_false()
	assert_bool((menu.find_child("CampaignButton", true, false) as Button).disabled).is_true()
	assert_str((menu.find_child("RhinegoldLabel", true, false) as Label).text).starts_with("320 ")
	menu.queue_free()


func test_collection_shows_every_card_with_the_copies_owned() -> void:
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["collection"] = {"loge": 2, "wotans_spear": 1}
	SaveManager.profile["starter_collection_granted"] = true
	var screen: Control = await _open("res://scenes/screens/collection.tscn")
	var grid: GridContainer = screen.find_child("CardGrid", true, false) as GridContainer
	assert_int(grid.get_child_count()).is_equal(CardDatabase.card_ids().size())
	assert_str((screen.find_child("Card_loge", true, false).find_child("Owned", true, false) as Label).text).is_equal("× 2")
	assert_str((screen.find_child("Card_froh", true, false).find_child("Owned", true, false) as Label).text).is_equal("UI_NOT_OWNED")
	# Gods first, by cost: the first card is the cheapest Gods card.
	var first: CardData = (grid.get_child(0).get_child(0) as CardView).card_data
	assert_str(String(first.faction)).is_equal("gods")

	_press(screen, "faction_nibelungs")
	assert_int(_visible_cards(grid).size()).is_equal(15)
	_press(screen, "faction_all")
	_press(screen, "owned_owned")
	assert_array(_visible_cards(grid)).contains_exactly_in_any_order([&"loge", &"wotans_spear"])
	assert_str((screen.find_child("FiltersButton", true, false) as Button).text).ends_with("(1)")
	_press(screen, "owned_all")
	_press(screen, "trait_invisible")
	# Invisible units, and the Tarnhelm that makes its bearer Invisible.
	assert_array(_visible_cards(grid)).contains([&"alberich_toad", &"tarnhelm"])
	_press(screen, "trait_all")
	_press(screen, "cost_6")
	for card_id: StringName in _visible_cards(grid):
		assert_int(CardDatabase.get_card(card_id).cost).is_greater_equal(6)
	screen.queue_free()


func test_collection_card_opens_large_with_its_copies() -> void:
	SaveManager.profile["collection"] = {"loge": 2}
	var screen: Control = await _open("res://scenes/screens/collection.tscn")
	(screen.find_child("Card_loge", true, false).get_child(0) as CardView).pressed.emit()
	var detail: Control = screen.find_child("CardDetail", true, false) as Control
	assert_object(detail).is_not_null()
	assert_str((detail.find_child("OwnedCopies", true, false) as Label).text).contains("2")
	screen.queue_free()


func test_new_profile_owns_the_four_starter_decks() -> void:
	SaveManager.reset_profile()
	for deck_id: StringName in [&"gods_starter", &"nibelungs_starter", &"walsungs_starter", &"valkyries_starter"]:
		var deck: DeckData = CardDatabase.get_deck(deck_id)
		assert_bool((SaveManager.profile["leaders"] as Array).has(String(deck.leader.id))).is_true()
		for card: CardData in deck.cards:
			assert_int(SaveManager.owned_count(card.id)).is_greater_equal(deck.cards.count(card))
	assert_bool(SaveManager.profile["starter_collection_granted"]).is_true()
	assert_int(SaveManager.rhinegold()).is_equal(0)


func _press(screen: Control, chip_name: String) -> void:
	var chip: Button = screen.find_child(chip_name, true, false) as Button
	chip.button_pressed = true
	chip.pressed.emit()


func _visible_cards(grid: GridContainer) -> Array[StringName]:
	var ids: Array[StringName] = []
	for cell: Node in grid.get_children():
		if (cell as Control).visible:
			ids.append((cell.get_child(0) as CardView).card_data.id)
	return ids


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


func test_duel_saves_the_match_in_progress_and_resumes_it() -> void:
	DuelSetup.next = DuelSetup.new(&"walsungs_starter", &"valkyries_starter", AIProfile.Difficulty.EASY)
	var duel: Control = await _open("res://scenes/screens/duel.tscn")
	assert_bool(SaveManager.has_match()).is_true()
	duel.call("_confirm_redraw")
	var engine: Match = duel.get("_match") as Match
	var record: MatchRecord = MatchRecord.from_dict(SaveManager.load_match())
	assert_int(record.entries.size()).is_greater_equal(1)
	assert_str(record.replay(CardDatabase).state_hash()).is_equal(engine.state_hash())
	duel.queue_free()
	await get_tree().process_frame

	var setup := DuelSetup.new(record.player_deck_id, record.opponent_deck_id, record.difficulty as AIProfile.Difficulty)
	setup.resume = record
	DuelSetup.next = setup
	var resumed: Control = await _open("res://scenes/screens/duel.tscn")
	assert_object(resumed.get("_record")).is_same(record)
	assert_str((resumed.get("_match") as Match).state_hash()).is_equal(record.replay(CardDatabase).state_hash())
	assert_str(String((resumed.get("_match") as Match).get_state().player(0).leader.id)).is_equal("siegfried")
	# Used once: a rematch starts a new match.
	assert_object(setup.resume).is_null()
	resumed.queue_free()
	await get_tree().process_frame


func test_finished_match_is_not_kept() -> void:
	DuelSetup.next = DuelSetup.new(&"walsungs_starter", &"valkyries_starter", AIProfile.Difficulty.EASY)
	var duel: Control = await _open("res://scenes/screens/duel.tscn")
	assert_bool(SaveManager.has_match()).is_true()
	duel.call("_apply_action", ConcedeAction.new(0))
	assert_bool(SaveManager.has_match()).is_false()
	duel.queue_free()
	await get_tree().process_frame


func test_main_menu_offers_to_resume_or_abandon_the_saved_match() -> void:
	SaveManager.save_match(_saved_record().to_dict())
	var menu: Control = await _open("res://scenes/screens/main_menu.tscn")
	assert_object(menu.find_child("ResumeMatchButton", true, false)).is_not_null()
	(menu.find_child("AbandonMatchButton", true, false) as Button).pressed.emit()
	assert_bool(SaveManager.has_match()).is_false()
	await get_tree().process_frame
	assert_object(menu.find_child("ResumePrompt", true, false)).is_null()
	menu.queue_free()


func test_match_that_no_longer_replays_is_set_aside_and_explained() -> void:
	var record: MatchRecord = _saved_record()
	record.content_hash = "from an older version"
	SaveManager.save_match(record.to_dict())
	var menu: Control = await _open("res://scenes/screens/main_menu.tscn")
	assert_object(menu.find_child("ResumeMatchButton", true, false)).is_null()
	assert_object(menu.find_child("CloseResumeFailedButton", true, false)).is_not_null()
	assert_bool(SaveManager.has_match()).is_false()
	assert_bool(FileAccess.file_exists(SaveManager.failed_match_path())).is_true()
	menu.queue_free()


func _saved_record() -> MatchRecord:
	var deck_a: DeckData = CardDatabase.get_deck(&"gods_starter")
	var deck_b: DeckData = CardDatabase.get_deck(&"nibelungs_starter")
	var record: MatchRecord = MatchRecord.create(deck_a, deck_b, 99)
	record.add_action(RedrawAction.new(0, []))
	return record


func test_reset_progress_asks_then_erases_the_profile_only() -> void:
	Settings.music_volume = 0.3
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["rhinegold"] = 320
	SaveManager.save_profile()
	var screen: Control = await _open("res://scenes/screens/settings_menu.tscn")
	(screen.find_child("ResetProgressButton", true, false) as Button).pressed.emit()
	# Cancel leaves the profile alone.
	(screen.find_child("CancelResetButton", true, false) as Button).pressed.emit()
	assert_int(int(SaveManager.profile["rhinegold"])).is_equal(320)
	assert_object(screen.find_child("ResetDone", true, false)).is_null()

	(screen.find_child("ResetProgressButton", true, false) as Button).pressed.emit()
	(screen.find_child("ConfirmResetButton", true, false) as Button).pressed.emit()
	# Back to a new player's profile: no Rhinegold, the starter decks.
	assert_int(SaveManager.rhinegold()).is_equal(0)
	assert_bool(SaveManager.profile["starter_collection_granted"]).is_true()
	assert_object(screen.find_child("ResetDone", true, false)).is_not_null()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.path))
	assert_int(int(saved["rhinegold"])).is_equal(0)
	assert_bool(FileAccess.file_exists(SaveManager.path + ".bak")).is_false()
	# Settings are not progress.
	assert_float(Settings.music_volume).is_equal_approx(0.3, 0.001)
	screen.queue_free()


func _open(scene_path: String) -> Control:
	var screen: Control = (load(scene_path) as PackedScene).instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	return screen


func _tile(screen: Control, tile_name: String) -> Button:
	return screen.find_child(tile_name, true, false) as Button
