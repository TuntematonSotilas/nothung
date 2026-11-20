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
	# A new player's profile: the starter decks as deck_1 (Gods) … deck_4 (Valkyries).
	SaveManager.reset_profile()
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
	for button_name: String in ["NibelheimButton", "SettingsButton", "ChangeDeckButton", "MyDecksButton", "QuickMatchButton", "CollectionButton"]:
		assert_bool((menu.find_child(button_name, true, false) as Button).disabled).is_false()
	assert_int((menu.find_child("TopBar", true, false) as HBoxContainer).get_theme_constant("separation")).is_equal(20)
	assert_bool((menu.find_child("CampaignButton", true, false) as Button).disabled).is_true()
	assert_str((menu.find_child("RhinegoldLabel", true, false) as Label).text).starts_with("320 ")
	menu.queue_free()


func test_main_menu_shows_the_current_deck_and_lets_choose_another() -> void:
	Settings.quick_match_deck = "deck_1"
	var menu: Control = await _open("res://scenes/screens/main_menu.tscn")
	assert_str((menu.find_child("CurrentDeckName", true, false) as Label).text).is_equal(MenuUI.deck_name(SaveManager.find_deck("deck_1")))
	# Wotan has his art; the others show their faction icon until theirs exists.
	assert_object((menu.find_child("LeaderPortrait", true, false) as TextureRect).texture).is_same(CardDatabase.get_leader(&"wotan").art)
	# The portrait is not a button: Change deck picks another one.
	assert_bool(menu.find_child("CurrentDeck", true, false) is BaseButton).is_false()
	(menu.find_child("ChangeDeckButton", true, false) as Button).pressed.emit()
	(menu.find_child("Pick_deck_3", true, false) as Button).pressed.emit()
	assert_str(Settings.quick_match_deck).is_equal("deck_3")
	await get_tree().process_frame
	assert_str((menu.find_child("CurrentDeckName", true, false) as Label).text).is_equal(MenuUI.deck_name(SaveManager.find_deck("deck_3")))
	assert_object(menu.find_child("DeckPicker", true, false)).is_null()
	menu.queue_free()


func test_main_menu_without_a_playable_deck_points_to_my_decks() -> void:
	for entry: Dictionary in SaveManager.decks():
		(entry["cards"] as Array).pop_back()
	var menu: Control = await _open("res://scenes/screens/main_menu.tscn")
	assert_object(menu.find_child("NoPlayableDeck", true, false)).is_not_null()
	menu.queue_free()


func test_collection_shows_every_card_with_the_copies_owned() -> void:
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["collection"] = {"loge": 2, "wotans_spear": 1}
	SaveManager.profile["starter_collection_granted"] = true
	var screen: Control = await _open("res://scenes/screens/collection.tscn")
	var grid: GridContainer = screen.find_child("CardGrid", true, false) as GridContainer
	assert_int(grid.get_child_count()).is_equal(CardDatabase.card_ids().size())
	assert_str((screen.find_child("Card_loge", true, false).find_child("Caption", true, false) as Label).text).is_equal("× 2")
	assert_str((screen.find_child("Card_froh", true, false).find_child("Caption", true, false) as Label).text).is_equal("UI_NOT_OWNED")
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
	# My decks and Nibelheim are reached from the main menu only.
	assert_object(screen.find_child("MyDecksButton", true, false)).is_null()
	assert_object(screen.find_child("NibelheimButton", true, false)).is_null()
	(screen.find_child("Card_loge", true, false).get_child(0) as CardView).pressed.emit()
	var detail: Control = screen.find_child("CardDetail", true, false) as Control
	assert_object(detail).is_not_null()
	assert_str((detail.find_child("Line0", true, false) as Label).text).contains("2")
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


func test_my_decks_lists_one_deck_per_faction_and_creates_none() -> void:
	var screen: Control = await _open("res://scenes/screens/deck_list.tscn")
	for index: int in range(1, 5):
		assert_object(screen.find_child("Deck_deck_%d" % index, true, false)).is_not_null()
	assert_object(screen.find_child("NewDeckButton", true, false)).is_null()
	screen.queue_free()


func test_deck_editor_adds_and_removes_cards_and_saves() -> void:
	SaveManager.profile["collection"]["loge"] = 2
	var entry: Dictionary = SaveManager.create_deck("wotan")
	DeckEditor.deck_id = str(entry["id"])
	var editor: DeckEditor = await _open("res://scenes/screens/deck_editor.tscn") as DeckEditor
	assert_str((editor.find_child("DeckStatus", true, false) as Label).text).contains("0 / 20")
	# Only Gods and Neutral cards.
	assert_object(editor.find_child("Card_loge", true, false)).is_not_null()
	assert_object(editor.find_child("Card_mime", true, false)).is_null()

	# No drag and drop: a tap on a card adds a copy.
	var loge_view: CardView = editor.find_child("Card_loge", true, false).get_child(0) as CardView
	loge_view.pressed.emit()
	assert_int(DeckRules.count_of(entry, &"loge")).is_equal(1)
	assert_object(editor.find_child("CardDetail", true, false)).is_null()
	loge_view.pressed.emit()
	assert_int(DeckRules.count_of(entry, &"loge")).is_equal(2)
	# Rare: at most 2 copies; a third tap shows the card with why instead.
	loge_view.pressed.emit()
	assert_int(DeckRules.count_of(entry, &"loge")).is_equal(2)
	assert_object(editor.find_child("CardDetail", true, false)).is_not_null()
	# Saved at once.
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.path))
	var saved_deck: Dictionary = (saved["decks"] as Array).filter(func(d: Dictionary) -> bool: return d["id"] == entry["id"])[0]
	assert_int((saved_deck["cards"] as Array).count("loge")).is_equal(2)
	assert_str((editor.find_child("DeckCount", true, false) as Label).text).contains("2")

	assert_float((editor.find_child("DeckGauge", true, false) as ProgressBar).value).is_equal(2.0)

	# A tap on its chip takes a copy out.
	(editor.find_child("Chip_loge", true, false) as Button).pressed.emit()
	assert_int(DeckRules.count_of(entry, &"loge")).is_equal(1)
	# The name is the faction's, fixed; no Duplicate or Delete.
	var deck_name: Node = editor.find_child("DeckName", true, false)
	assert_bool(deck_name is Label).is_true()
	assert_str((deck_name as Label).text).is_equal(MenuUI.faction_name(&"gods"))
	assert_object(editor.find_child("DuplicateButton", true, false)).is_null()
	assert_object(editor.find_child("DeleteButton", true, false)).is_null()
	editor.queue_free()


func test_deck_editor_shows_ready_for_a_full_valid_deck() -> void:
	DeckEditor.deck_id = "deck_1"
	var editor: Control = await _open("res://scenes/screens/deck_editor.tscn")
	assert_str((editor.find_child("DeckStatus", true, false) as Label).text).is_equal(tr("UI_DECK_READY"))
	assert_float((editor.find_child("DeckGauge", true, false) as ProgressBar).value).is_equal(20.0)
	editor.queue_free()


func test_deck_editor_auto_fills_and_restores_the_starter_deck() -> void:
	var entry: Dictionary = SaveManager.create_deck("wotan")
	DeckEditor.deck_id = str(entry["id"])
	var editor: DeckEditor = await _open("res://scenes/screens/deck_editor.tscn") as DeckEditor
	# Empty deck: no question asked.
	(editor.find_child("AutoFillButton", true, false) as Button).pressed.emit()
	assert_int((entry["cards"] as Array).size()).is_equal(20)
	assert_array(DeckRules.problems(entry, CardDatabase, SaveManager.owned_count)).is_empty()
	# Not empty: asks first; Cancel keeps the deck.
	var before: Array = (entry["cards"] as Array).duplicate()
	(editor.find_child("StarterDeckButton", true, false) as Button).pressed.emit()
	(editor.find_child("CancelButton", true, false) as Button).pressed.emit()
	assert_array(entry["cards"]).is_equal(before)
	(editor.find_child("StarterDeckButton", true, false) as Button).pressed.emit()
	(editor.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	var starter: Array[String] = []
	for card: CardData in CardDatabase.get_deck(&"gods_starter").cards:
		starter.append(String(card.id))
	assert_array(entry["cards"]).contains_exactly_in_any_order(starter)
	editor.queue_free()


func test_deck_editor_empties_the_deck_and_asks_before_leaving_it_incomplete() -> void:
	DeckEditor.deck_id = "deck_1"
	var entry: Dictionary = SaveManager.find_deck("deck_1")
	var editor: DeckEditor = await _open("res://scenes/screens/deck_editor.tscn") as DeckEditor
	# A complete deck leaves without a question.
	assert_bool(editor.handle_back()).is_false()
	# Empty the deck: asks first (Cancel keeps it), then the deck is empty and the button goes.
	var clear: Button = editor.find_child("ClearDeckButton", true, false) as Button
	assert_str(clear.get_theme_color("font_color").to_html(false)).is_equal(Palette.LIFE.to_html(false))
	clear.pressed.emit()
	(editor.find_child("CancelButton", true, false) as Button).pressed.emit()
	assert_int((entry["cards"] as Array).size()).is_equal(20)
	(editor.find_child("ClearDeckButton", true, false) as Button).pressed.emit()
	(editor.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	assert_int((entry["cards"] as Array).size()).is_equal(0)
	assert_object(editor.find_child("ClearDeckButton", true, false)).is_null()
	# Incomplete: Back opens a popup naming the problem; Keep editing closes it.
	assert_bool(editor.handle_back()).is_true()
	var prompt: Control = editor.find_child("LeavePrompt", true, false) as Control
	assert_object(prompt).is_not_null()
	assert_str((prompt.find_child("LeaveProblems", true, false) as Label).text).contains("0 / 20")
	assert_object(prompt.find_child("LeaveAnywayButton", true, false)).is_not_null()
	(prompt.find_child("KeepEditingButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_object(editor.find_child("LeavePrompt", true, false)).is_null()
	editor.queue_free()


func test_nibelheim_forges_the_missing_copies() -> void:
	SaveManager.profile["rhinegold"] = 150
	SaveManager.profile["collection"].erase("loge")
	# Already a forger: no achievement reward mixes with the prices here.
	SaveManager.profile["achievements"] = ["mimes_apprentice"]
	var screen: Control = await _open("res://scenes/screens/nibelheim.tscn")
	# Complete cards are hidden: nothing to forge.
	var complete: CardData = CardDatabase.get_card(&"wotans_ravens")
	assert_int(SaveManager.owned_count(complete.id)).is_equal(complete.deck_limit())
	assert_bool((screen.find_child("Card_wotans_ravens", true, false) as Control).visible).is_false()
	assert_bool((screen.find_child("Card_loge", true, false) as Control).visible).is_true()

	(screen.find_child("Card_loge", true, false).get_child(0) as CardView).pressed.emit()
	var forge: Button = screen.find_child("ForgeButton", true, false) as Button
	assert_bool(forge.disabled).is_false()
	forge.pressed.emit()
	assert_int(SaveManager.owned_count(&"loge")).is_equal(1)
	assert_int(SaveManager.rhinegold()).is_equal(50)
	assert_str((screen.find_child("RhinegoldValue", true, false) as Label).text).is_equal("50")
	# The second copy costs 100: greyed, with what is missing.
	await get_tree().process_frame
	(screen.find_child("Card_loge", true, false).get_child(0) as CardView).pressed.emit()
	assert_bool((screen.find_child("ForgeButton", true, false) as Button).disabled).is_true()
	assert_str((screen.find_child("Line1", true, false) as Label).text).contains("50")
	screen.queue_free()


func test_quick_match_win_pays_rhinegold_once() -> void:
	var setup := DuelSetup.new(CardDatabase.get_deck(&"walsungs_starter"), CardDatabase.get_deck(&"valkyries_starter"), AIProfile.Difficulty.HARD)
	setup.rewards = true
	DuelSetup.next = setup
	var duel: Control = await _open("res://scenes/screens/duel.tscn")
	var state: GameState = (duel.get("_match") as Match).get_state()
	state.phase = GameState.Phase.GAME_OVER
	state.winner = 0
	duel.call("_save_progress")
	duel.call("_save_progress")
	# The win reaches achievements, but their rewards wait for a manual claim.
	var change: Dictionary = duel.get("_achievements_change")
	assert_array(change["reached"]).contains(["first_victory", "gotterdammerung"])
	assert_bool(Achievements.is_claimable("first_victory")).is_true()
	assert_bool(Achievements.is_unlocked("first_victory")).is_false()
	assert_int(Achievements.stat("wins")).is_equal(1)
	# XP: only the Hard win; the level reached pays Rhinegold.
	var level: Dictionary = change["level"]
	assert_int(level["xp"]).is_equal(PlayerLevel.XP_WIN[AIProfile.Difficulty.HARD])
	var ability_button: Button = duel.find_child("OwnAbilityButton", true, false) as Button
	var ability_cost: Label = ability_button.find_child("AbilityCost", true, false) as Label
	var ability_title: Label = ability_button.find_child("AbilityTitle", true, false) as Label
	var ability_action: Label = ability_button.find_child("AbilityAction", true, false) as Label
	var ability_content: HBoxContainer = ability_button.find_child("AbilityContent", true, false) as HBoxContainer
	var ability_icon: TextureRect = ability_button.find_child("EnergyIcon", true, false) as TextureRect
	assert_int(ability_cost.get_index()).is_equal(0)
	assert_int(ability_icon.get_index()).is_equal(1)
	assert_int(ability_content.get_theme_constant("separation")).is_equal(roundi(2 * float(duel.get("_ui_scale"))))
	assert_str(ability_cost.text).is_equal("2")
	assert_that(ability_cost.get_theme_color("font_color")).is_equal(Palette.ENERGY)
	assert_str(ability_title.text).is_equal(tr("LEADER_SIEGFRIED_ABILITY_NAME"))
	assert_that(ability_title.get_theme_color("font_color")).is_equal(
		(CardPalette.FACTIONS[&"walsungs"]["frame"] as Color).lightened(0.55)
	)
	assert_str(ability_action.text).is_equal(tr("LEADER_SIEGFRIED_ABILITY_TEXT"))
	assert_that(ability_action.get_theme_color("font_color")).is_equal(Palette.TEXT_MUTED)
	assert_int(PlayerLevel.total_xp()).is_equal(level["xp"])
	assert_array(level["levels"]).contains([2])
	assert_int(SaveManager.rhinegold()).is_equal(Progression.quick_match_reward(AIProfile.Difficulty.HARD) + int(level["rhinegold"]))
	# The results list claimable achievements, match XP and the levels reached.
	duel.call("_show_results")
	assert_object(duel.find_child("Achievement_first_victory", true, false)).is_not_null()
	assert_object(duel.find_child("VictoryPanel", true, false)).is_not_null()
	assert_str((duel.find_child("XpLabel", true, false) as Label).text).is_equal(tr("UI_XP_GAINED").format({"amount": level["xp"]}))
	assert_object(duel.find_child("LevelBar", true, false)).is_not_null()
	assert_object(duel.find_child("LevelUp_2", true, false)).is_not_null()
	# Undoing the winning play takes it all back.
	state.phase = GameState.Phase.MAIN
	state.winner = -1
	duel.call("_save_progress")
	assert_int(SaveManager.rhinegold()).is_equal(0)
	assert_bool(Achievements.is_unlocked("first_victory")).is_false()
	assert_int(Achievements.stat("matches")).is_equal(0)
	assert_int(PlayerLevel.total_xp()).is_equal(0)
	duel.queue_free()
	await get_tree().process_frame


func test_achievements_screen_lists_progress_and_the_main_menu_opens_it() -> void:
	var menu: Control = await _open("res://scenes/screens/main_menu.tscn")
	assert_object(menu.find_child("AchievementsButton", true, false)).is_not_null()
	assert_str((menu.find_child("LevelLabel", true, false) as Label).text).is_equal(tr("UI_LEVEL").format({"level": 1}))
	assert_str((menu.find_child("XpAmount", true, false) as Label).text).is_equal(tr("UI_XP_PROGRESS").format({"xp": 0, "needed": 20}))
	menu.queue_free()
	SaveManager.profile["stats"] = {"wins": 3}
	SaveManager.profile["achievements"] = ["first_victory"]
	SaveManager.profile["claimed_achievements"] = []
	var screen: Control = await _open("res://scenes/screens/achievements.tscn")
	assert_int(screen.find_child("AchievementList", true, false).get_child_count()).is_equal(Achievements.LIST.size())
	var pending: Node = screen.find_child("Achievement_first_victory", true, false)
	assert_str((pending.find_child("Progress", true, false) as Label).text).is_equal(tr("UI_ACHIEVEMENT_CLAIMABLE"))
	var claim: Button = pending.find_child("ClaimButton", true, false) as Button
	assert_bool(claim.disabled).is_false()
	claim.pressed.emit()
	assert_bool(Achievements.is_unlocked("first_victory")).is_true()
	assert_int(PlayerLevel.total_xp()).is_equal(PlayerLevel.XP_ACHIEVEMENT)
	assert_int(SaveManager.rhinegold()).is_equal(20 + PlayerLevel.RHINEGOLD_PER_LEVEL)
	assert_object(screen.find_child("Achievement_first_victory", true, false).find_child("ClaimButton", true, false)).is_null()
	var done: Node = screen.find_child("Achievement_first_victory", true, false)
	assert_str((done.find_child("Progress", true, false) as Label).text).is_equal(tr("UI_ACHIEVEMENT_DONE"))
	var counting: Node = screen.find_child("Achievement_einherjar", true, false)
	assert_str((counting.find_child("Progress", true, false) as Label).text).is_equal("3 / 10")
	screen.queue_free()


func test_forging_in_nibelheim_makes_mimes_apprentice_claimable() -> void:
	SaveManager.add_rhinegold(1000)
	var screen: Control = await _open("res://scenes/screens/nibelheim.tscn")
	var data: CardData = null
	for card_id: StringName in CardDatabase.card_ids():
		var card: CardData = CardDatabase.get_card(card_id)
		if card.rarity == CardData.Rarity.COMMON and Progression.can_craft(card, SaveManager.owned_count(card_id)):
			data = card
			break
	assert_bool(screen.call("forge", data)).is_true()
	assert_bool(Achievements.is_claimable("mimes_apprentice")).is_true()
	# Crafting reaches the achievement but awards no XP or Rhinegold for it yet.
	assert_int(PlayerLevel.level()).is_equal(1)
	assert_int(SaveManager.rhinegold()).is_equal(1000 - Progression.craft_price(data))
	assert_str((screen.find_child("ToastText", true, false) as Label).text).contains(tr("UI_ACHIEVEMENT_READY").format({
		"name": tr("ACHIEVEMENT_MIMES_APPRENTICE_NAME"),
	}))
	screen.queue_free()


func test_nibelheim_unlocks_a_leader_power_from_its_level() -> void:
	SaveManager.add_rhinegold(400)
	var screen: Control = await _open("res://scenes/screens/nibelheim.tscn")
	(screen.find_child("LeadersTab", true, false) as Button).pressed.emit()
	assert_bool((screen.find_child("LeaderPowers", true, false) as Control).visible).is_true()
	var wotan: Node = screen.find_child("Leader_wotan", true, false)
	assert_str((wotan.find_child("Power0", true, false).find_child("State", true, false) as Label).text).is_equal("UI_POWER_BASE")
	# Level 1: greyed, with the level needed.
	var power: Node = wotan.find_child("Power1", true, false)
	var power_title: Label = power.find_child("PowerTitle", true, false) as Label
	var power_action: Label = power.find_child("PowerAction", true, false) as Label
	assert_str(power_title.text).contains(tr("LEADER_WOTAN_POWER1_NAME"))
	assert_str(power_title.text).contains(tr("UI_POWER_COST").format({"cost": 3}))
	assert_str(power_action.text).is_equal(tr("LEADER_WOTAN_POWER1_TEXT"))
	assert_that(power_title.get_theme_color("font_color")).is_equal(
		(CardPalette.FACTIONS[&"gods"]["frame"] as Color).lightened(0.55)
	)
	assert_that(power_title.get_theme_color("font_color")).is_not_equal(power_action.get_theme_color("font_color"))
	assert_bool((power.find_child("UnlockButton", true, false) as Button).disabled).is_true()
	assert_str((power.find_child("Reason", true, false) as Label).text).is_equal(tr("UI_POWER_LEVEL_NEEDED").format({"level": 5}))
	# Level 5: it can be unlocked for its price.
	SaveManager.profile["xp"] = 140
	screen.call("_refresh")
	power = screen.find_child("Leader_wotan", true, false).find_child("Power1", true, false)
	(power.find_child("UnlockButton", true, false) as Button).pressed.emit()
	assert_bool(LeaderPowers.is_unlocked(&"wotan", 1)).is_true()
	assert_int(SaveManager.rhinegold()).is_equal(100)
	power = screen.find_child("Leader_wotan", true, false).find_child("Power1", true, false)
	assert_object(power.find_child("UnlockButton", true, false)).is_null()
	assert_object(screen.find_child("Toast", true, false)).is_not_null()
	screen.queue_free()


func test_deck_editor_changes_the_leader_power_among_those_unlocked() -> void:
	SaveManager.profile["leader_powers"] = {"wotan": [1]}
	var entry: Dictionary = SaveManager.create_deck("wotan")
	DeckEditor.deck_id = str(entry["id"])
	var editor: DeckEditor = await _open("res://scenes/screens/deck_editor.tscn") as DeckEditor
	var wotan: LeaderData = CardDatabase.get_leader(&"wotan")
	var label: Label = editor.find_child("LeaderPower", true, false) as Label
	assert_str(label.text).contains(LeaderPowers.title(wotan, 0))
	(editor.find_child("ChangePowerButton", true, false) as Button).pressed.emit()
	var picker: Node = editor.find_child("PowerPicker", true, false)
	assert_bool((picker.find_child("Power_0", true, false) as Button).button_pressed).is_true()
	assert_bool((picker.find_child("Power_2", true, false) as Button).disabled).is_true()
	(picker.find_child("Power_1", true, false) as Button).pressed.emit()
	assert_int(int(entry["power"])).is_equal(1)
	assert_str(label.text).contains(LeaderPowers.title(wotan, 1))
	assert_int(DeckRules.to_deck_data(entry, CardDatabase).leader.power).is_equal(1)
	# A power not unlocked cannot be chosen.
	assert_bool(editor.choose_power(2)).is_false()
	editor.queue_free()


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
	Settings.quick_match_deck = "deck_4"
	Settings.quick_match_opponent = "walsungs_starter"
	Settings.quick_match_difficulty = AIProfile.Difficulty.HARD
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	# Only the current deck, and a button to change it.
	assert_str((screen.find_child("CurrentDeckTile", true, false) as Button).text).contains(MenuUI.deck_name(SaveManager.find_deck("deck_4")))
	assert_object(screen.find_child("ChangeDeckButton", true, false)).is_not_null()
	assert_object(_tile(screen, "Player_deck_1")).is_null()
	assert_bool(_tile(screen, "Opponent_walsungs_starter").button_pressed).is_true()
	assert_bool(_tile(screen, "Difficulty2").button_pressed).is_true()
	var setup: DuelSetup = screen.call("build_setup")
	assert_str(String(setup.player_deck.id)).is_equal("deck_4")
	assert_str(String(setup.player_deck.leader.id)).is_equal("brunnhilde")
	assert_str(String(setup.opponent_deck.id)).is_equal("walsungs_starter")
	assert_int(setup.difficulty).is_equal(AIProfile.Difficulty.HARD)
	screen.queue_free()


func test_quick_match_changes_the_current_deck_among_those_ready_to_play() -> void:
	Settings.quick_match_deck = "deck_1"
	(SaveManager.find_deck("deck_2")["cards"] as Array).pop_back()
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	(screen.find_child("ChangeDeckButton", true, false) as Button).pressed.emit()
	# Not ready: not offered.
	assert_object(screen.find_child("Pick_deck_2", true, false)).is_null()
	(screen.find_child("Pick_deck_3", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_str(Settings.quick_match_deck).is_equal("deck_3")
	assert_str((screen.find_child("CurrentDeckTile", true, false) as Button).text).contains(MenuUI.deck_name(SaveManager.find_deck("deck_3")))
	assert_str(String((screen.call("build_setup") as DuelSetup).player_deck.leader.id)).is_equal("siegfried")
	screen.queue_free()


func test_quick_match_without_a_playable_deck_cannot_start() -> void:
	for entry: Dictionary in SaveManager.decks():
		(entry["cards"] as Array).pop_back()
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	assert_object(screen.find_child("NoPlayableDeck", true, false)).is_not_null()
	assert_bool((screen.find_child("PlayButton", true, false) as Button).disabled).is_true()
	screen.queue_free()


func test_quick_match_choices_stay_single_and_build_the_setup() -> void:
	Settings.quick_match_deck = "deck_2"
	Settings.quick_match_opponent = "random"
	Settings.quick_match_difficulty = AIProfile.Difficulty.NORMAL
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	_tile(screen, "Opponent_valkyries_starter").pressed.emit()
	_tile(screen, "Difficulty0").pressed.emit()

	assert_bool(_tile(screen, "OpponentRandom").button_pressed).is_false()
	assert_bool(_tile(screen, "Difficulty1").button_pressed).is_false()
	var setup: DuelSetup = screen.call("build_setup")
	assert_str(String(setup.player_deck.leader.id)).is_equal("alberich")
	assert_str(String(setup.opponent_deck.id)).is_equal("valkyries_starter")
	assert_int(setup.difficulty).is_equal(AIProfile.Difficulty.EASY)
	screen.queue_free()


func test_random_opponent_is_another_faction() -> void:
	Settings.quick_match_deck = "deck_3"
	Settings.quick_match_opponent = "random"
	var screen: Control = await _open("res://scenes/screens/quick_match.tscn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen: Dictionary = {}
	for attempt: int in 30:
		var setup: DuelSetup = screen.call("build_setup", rng)
		assert_str(String(setup.opponent_deck.id)).is_not_equal("walsungs_starter")
		seen[setup.opponent_deck.id] = true
	assert_int(seen.size()).is_equal(3)
	screen.queue_free()


func test_duel_plays_the_quick_match_setup() -> void:
	DuelSetup.next = DuelSetup.new(CardDatabase.get_deck(&"walsungs_starter"), CardDatabase.get_deck(&"valkyries_starter"), AIProfile.Difficulty.EASY)
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
	DuelSetup.next = DuelSetup.new(CardDatabase.get_deck(&"walsungs_starter"), CardDatabase.get_deck(&"valkyries_starter"), AIProfile.Difficulty.EASY)
	var duel: Control = await _open("res://scenes/screens/duel.tscn")
	assert_bool(SaveManager.has_match()).is_true()
	duel.call("_confirm_redraw")
	var engine: Match = duel.get("_match") as Match
	var record: MatchRecord = MatchRecord.from_dict(SaveManager.load_match())
	assert_int(record.entries.size()).is_greater_equal(1)
	assert_str(record.replay(CardDatabase).state_hash()).is_equal(engine.state_hash())
	duel.queue_free()
	await get_tree().process_frame

	var decks: Array[DeckData] = record.rebuild_decks(CardDatabase)
	var setup := DuelSetup.new(decks[0], decks[1], record.difficulty as AIProfile.Difficulty)
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
	DuelSetup.next = DuelSetup.new(CardDatabase.get_deck(&"walsungs_starter"), CardDatabase.get_deck(&"valkyries_starter"), AIProfile.Difficulty.EASY)
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
