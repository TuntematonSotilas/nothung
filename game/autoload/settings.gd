extends Node
## User settings (volumes, language, animation speed), stored in a ConfigFile.
## See docs/technical/07-persistence.md and docs/technical/06-ui-implementation.md#localisation.

signal changed(key: StringName)

const DEFAULT_PATH: String = "user://settings.cfg"
const SUPPORTED_LANGUAGES: PackedStringArray = ["en", "de", "es", "fr"]
const FALLBACK_LANGUAGE: String = "en"
const ANIMATION_SPEEDS: PackedFloat32Array = [1.0, 2.0, 0.0] # 0.0 = instant

var path: String = DEFAULT_PATH
var music_volume: float = 0.8
var sfx_volume: float = 1.0
## Empty = follow the device language.
var language: String = ""
var animation_speed: float = 1.0


func _ready() -> void:
	load_settings()
	apply_language()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return
	music_volume = clampf(config.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	var saved_language: String = config.get_value("display", "language", language)
	language = saved_language if saved_language in SUPPORTED_LANGUAGES else ""
	var saved_speed: float = config.get_value("gameplay", "animation_speed", animation_speed)
	animation_speed = saved_speed if saved_speed in ANIMATION_SPEEDS else 1.0


func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "language", language)
	config.set_value("gameplay", "animation_speed", animation_speed)
	return config.save(path)


func set_language(code: String) -> void:
	language = code if code in SUPPORTED_LANGUAGES else ""
	apply_language()
	save_settings()
	changed.emit(&"language")


## The locale actually used: the chosen language, else the device language if supported, else English.
func resolved_language() -> String:
	if language in SUPPORTED_LANGUAGES:
		return language
	var device_language: String = OS.get_locale_language()
	return device_language if device_language in SUPPORTED_LANGUAGES else FALLBACK_LANGUAGE


func apply_language() -> void:
	TranslationServer.set_locale(resolved_language())
