extends Node
## User settings (volumes, language, last Quick match choices), stored in a ConfigFile.
## See docs/technical/07-persistence.md and docs/technical/06-ui-implementation.md#localisation.

signal changed(key: StringName)

const DEFAULT_PATH: String = "user://settings.cfg"
const SUPPORTED_LANGUAGES: PackedStringArray = ["en", "de", "es", "fr"]
const FALLBACK_LANGUAGE: String = "en"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

var path: String = DEFAULT_PATH
var music_volume: float = 0.8
var sfx_volume: float = 1.0
## Empty = follow the device language.
var language: String = ""
## Duel animation speed: not a user setting (not saved); tests set 0 (instant) or 2 to run faster.
var animation_speed: float = 1.0
## Last Quick match choices, offered again next time (opponent "random" = a random deck).
var quick_match_deck: String = "gods_starter"
var quick_match_opponent: String = "random"
var quick_match_difficulty: int = 1


func _ready() -> void:
	load_settings()
	apply_language()
	apply_audio()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return
	music_volume = clampf(config.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	var saved_language: String = config.get_value("display", "language", language)
	language = saved_language if saved_language in SUPPORTED_LANGUAGES else ""
	quick_match_deck = str(config.get_value("quick_match", "deck", quick_match_deck))
	quick_match_opponent = str(config.get_value("quick_match", "opponent", quick_match_opponent))
	quick_match_difficulty = clampi(int(config.get_value("quick_match", "difficulty", quick_match_difficulty)), 0, 2)


func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "language", language)
	config.set_value("quick_match", "deck", quick_match_deck)
	config.set_value("quick_match", "opponent", quick_match_opponent)
	config.set_value("quick_match", "difficulty", quick_match_difficulty)
	return config.save(path)


func set_language(code: String) -> void:
	language = code if code in SUPPORTED_LANGUAGES else ""
	apply_language()
	_save_and_notify(&"language")


func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	apply_audio()
	_save_and_notify(&"music_volume")


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	apply_audio()
	_save_and_notify(&"sfx_volume")




## The locale actually used: the chosen language, else the device language if supported, else English.
func resolved_language() -> String:
	if language in SUPPORTED_LANGUAGES:
		return language
	var device_language: String = OS.get_locale_language()
	return device_language if device_language in SUPPORTED_LANGUAGES else FALLBACK_LANGUAGE


func apply_language() -> void:
	TranslationServer.set_locale(resolved_language())


## Volumes go to the Music and SFX buses (default_bus_layout.tres); 0 mutes the bus.
func apply_audio() -> void:
	for entry: Array in [[MUSIC_BUS, music_volume], [SFX_BUS, sfx_volume]]:
		var bus: int = AudioServer.get_bus_index(entry[0])
		if bus < 0:
			continue
		AudioServer.set_bus_volume_db(bus, linear_to_db(entry[1]))
		AudioServer.set_bus_mute(bus, entry[1] <= 0.0)


func _save_and_notify(key: StringName) -> void:
	save_settings()
	changed.emit(key)
