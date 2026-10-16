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


func test_migration_v1_renames_hoard_to_rhinegold() -> void:
	var migrated: Dictionary = SaveManagerScript.migrate({"version": 1, "hoard": 320})
	assert_int(int(migrated["rhinegold"])).is_equal(320)
	assert_bool(migrated.has("hoard")).is_false()
	assert_int(int(migrated["version"])).is_equal(SaveManagerScript.CURRENT_VERSION)


func test_migration_fills_missing_keys() -> void:
	var migrated: Dictionary = SaveManagerScript.migrate({"version": 2, "rhinegold": 5})
	assert_dict(migrated).contains_keys(["collection", "decks", "campaign", "achievements"])
	assert_int(int(migrated["rhinegold"])).is_equal(5)
