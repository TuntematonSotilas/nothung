extends GdUnitTestSuite

const SaveManagerScript: GDScript = preload("res://autoload/save_manager.gd")

var _manager: Node
var _path: String


func before_test() -> void:
	_path = create_temp_dir("save_manager_%d" % Time.get_ticks_usec()) + "/profile.json"
	_manager = auto_free(SaveManagerScript.new())
	_manager.path = _path


func test_missing_file_gives_default_profile() -> void:
	_manager.load_profile()
	assert_dict(_manager.profile).is_equal(SaveManagerScript.default_profile())


func test_save_then_load_round_trip() -> void:
	_manager.load_profile()
	_manager.profile["rhinegold"] = 320
	_manager.profile["collection"] = {"fafner": 1}
	assert_int(_manager.save_profile()).is_equal(OK)

	var reloaded: Node = auto_free(SaveManagerScript.new())
	reloaded.path = _path
	reloaded.load_profile()
	assert_int(int(reloaded.profile["rhinegold"])).is_equal(320)
	assert_dict(reloaded.profile["collection"]).contains_keys(["fafner"])


func test_second_save_keeps_previous_profile_as_backup() -> void:
	_manager.load_profile()
	_manager.profile["rhinegold"] = 10
	_manager.save_profile()
	_manager.profile["rhinegold"] = 20
	_manager.save_profile()

	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path + ".bak"))
	assert_int(int(backup["rhinegold"])).is_equal(10)
	assert_bool(FileAccess.file_exists(_path + ".tmp")).is_false()


func test_corrupted_profile_falls_back_to_backup() -> void:
	_manager.load_profile()
	_manager.profile["rhinegold"] = 10
	_manager.save_profile()
	_manager.save_profile()
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()

	_manager.load_profile()
	assert_int(int(_manager.profile["rhinegold"])).is_equal(10)


func test_corrupted_profile_without_backup_gives_default_profile() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("[1, 2")
	file.close()

	_manager.load_profile()
	assert_dict(_manager.profile).is_equal(SaveManagerScript.default_profile())


func test_saving_after_a_restore_keeps_the_good_backup() -> void:
	_manager.load_profile()
	_manager.profile["rhinegold"] = 10
	_manager.save_profile()
	_manager.save_profile()
	_corrupt_profile()
	_manager.load_profile()
	_manager.profile["rhinegold"] = 15
	assert_int(_manager.save_profile()).is_equal(OK)

	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path + ".bak"))
	assert_int(int(backup["rhinegold"])).is_equal(10)
	_corrupt_profile()
	_manager.load_profile()
	assert_int(int(_manager.profile["rhinegold"])).is_equal(10)


func test_reset_erases_profile_and_backup() -> void:
	_manager.load_profile()
	_manager.profile["rhinegold"] = 10
	_manager.profile["collection"] = {"fafner": 1}
	_manager.save_profile()
	_manager.save_profile()

	assert_int(_manager.reset_profile()).is_equal(OK)
	assert_dict(_manager.profile).is_equal(SaveManagerScript.default_profile())
	assert_bool(FileAccess.file_exists(_path + ".bak")).is_false()
	var reloaded: Node = auto_free(SaveManagerScript.new())
	reloaded.path = _path
	reloaded.load_profile()
	assert_dict(reloaded.profile).is_equal(SaveManagerScript.default_profile())


func test_unknown_cards_become_rhinegold_and_leave_the_decks() -> void:
	var data: Dictionary = SaveManagerScript.migrate({
		"version": 2,
		"rhinegold": 5,
		"collection": {"fafner": 2, "removed_card": 3},
		"decks": [
			{"name": "A", "leader": "wotan", "cards": ["fafner", "removed_card", "fafner"]},
			{"name": "B", "leader": "removed_leader", "cards": ["fafner"]},
		],
	})
	var known: Array[StringName] = [&"fafner", &"wotan"]
	SaveManagerScript.convert_unknown_cards(data, func(id: StringName) -> bool: return id in known)
	assert_int(int(data["rhinegold"])).is_equal(5 + 3 * SaveManagerScript.REMOVED_CARD_VALUE)
	assert_dict(data["collection"]).is_equal({"fafner": 2})
	assert_int((data["decks"] as Array).size()).is_equal(1)
	assert_array(data["decks"][0]["cards"]).is_equal(["fafner", "fafner"])


func test_mistyped_keys_get_their_default() -> void:
	var migrated: Dictionary = SaveManagerScript.migrate({"version": 2, "rhinegold": 5, "collection": [1, 2], "decks": "x"})
	assert_dict(migrated["collection"]).is_empty()
	assert_array(migrated["decks"]).is_empty()
	assert_int(int(migrated["rhinegold"])).is_equal(5)


func test_migration_v2_adds_leaders_and_the_starter_collection_flag() -> void:
	var migrated: Dictionary = SaveManagerScript.migrate({"version": 2, "rhinegold": 5, "collection": {"loge": 1}})
	assert_array(migrated["leaders"]).is_empty()
	assert_bool(migrated["starter_collection_granted"]).is_false()
	assert_dict(migrated["collection"]).is_equal({"loge": 1})


func test_starter_decks_give_what_each_deck_needs_not_the_sum() -> void:
	var data: Dictionary = SaveManagerScript.default_profile()
	data["collection"] = {"loge": 1, "froh": 2}
	var gods: DeckData = CardDatabase.get_deck(&"gods_starter")
	var starters: Array[DeckData] = [gods, gods]
	SaveManagerScript.add_starter_decks(data, starters)
	assert_array(data["leaders"]).is_equal(["wotan"])
	for card: CardData in gods.cards:
		assert_int(int(data["collection"][String(card.id)])).is_equal(maxi(gods.cards.count(card), 2 if card.id == &"froh" else 0))
	assert_bool(data["starter_collection_granted"]).is_true()


func test_migration_v1_renames_hoard_to_rhinegold() -> void:
	var migrated: Dictionary = SaveManagerScript.migrate({"version": 1, "hoard": 320})
	assert_int(int(migrated["rhinegold"])).is_equal(320)
	assert_bool(migrated.has("hoard")).is_false()
	assert_int(int(migrated["version"])).is_equal(SaveManagerScript.CURRENT_VERSION)


func test_migration_fills_missing_keys() -> void:
	var migrated: Dictionary = SaveManagerScript.migrate({"version": 2, "rhinegold": 5})
	assert_dict(migrated).contains_keys(["collection", "decks", "campaign", "achievements"])
	assert_int(int(migrated["rhinegold"])).is_equal(5)


func _corrupt_profile() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
