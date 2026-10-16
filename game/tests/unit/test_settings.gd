extends GdUnitTestSuite

const SettingsScript: GDScript = preload("res://autoload/settings.gd")

var _settings: Node
var _path: String
var _previous_locale: String


func before_test() -> void:
	_previous_locale = TranslationServer.get_locale()
	_path = create_temp_dir("settings_%d" % Time.get_ticks_usec()) + "/settings.cfg"
	_settings = auto_free(SettingsScript.new())
	_settings.path = _path


func after_test() -> void:
	TranslationServer.set_locale(_previous_locale)


func test_missing_file_keeps_defaults() -> void:
	_settings.load_settings()
	assert_float(_settings.music_volume).is_equal(0.8)
	assert_str(_settings.language).is_empty()
	assert_float(_settings.animation_speed).is_equal(1.0)


func test_save_then_load_round_trip() -> void:
	_settings.music_volume = 0.3
	_settings.language = "fr"
	_settings.animation_speed = 2.0
	assert_int(_settings.save_settings()).is_equal(OK)

	var reloaded: Node = auto_free(SettingsScript.new())
	reloaded.path = _path
	reloaded.load_settings()
	assert_float(reloaded.music_volume).is_equal_approx(0.3, 0.001)
	assert_str(reloaded.language).is_equal("fr")
	assert_float(reloaded.animation_speed).is_equal(2.0)


func test_invalid_values_are_rejected_on_load() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "music_volume", 5.0)
	config.set_value("display", "language", "xx")
	config.set_value("gameplay", "animation_speed", 7.0)
	config.save(_path)

	_settings.load_settings()
	assert_float(_settings.music_volume).is_equal(1.0)
	assert_str(_settings.language).is_empty()
	assert_float(_settings.animation_speed).is_equal(1.0)


func test_set_language_changes_locale() -> void:
	_settings.set_language("de")
	assert_str(TranslationServer.get_locale()).is_equal("de")
	assert_str(_settings.resolved_language()).is_equal("de")


func test_unsupported_language_falls_back_to_a_supported_one() -> void:
	_settings.set_language("ja")
	assert_str(_settings.language).is_empty()
	assert_array(Array(SettingsScript.SUPPORTED_LANGUAGES)).contains([_settings.resolved_language()])
