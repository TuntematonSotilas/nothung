extends Node
## Player profile persistence: JSON, atomic writes, backup, versioned migrations; and the match in
## progress (current_match.json), kept to resume an interrupted match.
## See docs/technical/07-persistence.md.

signal profile_changed

const CURRENT_VERSION: int = 3
const DEFAULT_PATH: String = "user://profile.json"
const DEFAULT_MATCH_PATH: String = "user://current_match.json"
## Rhinegold refunded per copy of a card that no longer exists (its rarity is unknown): the Common
## crafting price (docs/functional/06-progression.md).
const REMOVED_CARD_VALUE: int = 40

var path: String = DEFAULT_PATH
var match_path: String = DEFAULT_MATCH_PATH
var profile: Dictionary = {}
## The profile file on disk could not be read: the next save must not rotate it into the backup,
## which may be the good copy the profile was restored from.
var _discard_main_file: bool = false


func _ready() -> void:
	load_profile()


static func default_profile() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"rhinegold": 0,
		"collection": {},
		"leaders": [],
		"decks": [],
		"campaign": {},
		"achievements": [],
		# Until the campaign unlocks factions, a new player owns the four starter decks.
		"starter_collection_granted": false,
	}


## Loads the profile, falling back to the backup, then to a fresh profile.
func load_profile() -> void:
	var data: Variant = _read_json(path)
	_discard_main_file = data == null and FileAccess.file_exists(path)
	if data == null:
		data = _read_json(_backup_path())
		if data != null:
			push_warning("SaveManager: profile unreadable, restored from backup")
	if data == null:
		if _discard_main_file:
			push_warning("SaveManager: profile and backup unreadable, starting a fresh profile")
		profile = default_profile()
	else:
		profile = migrate(data)
		if is_inside_tree():
			convert_unknown_cards(profile, func(id: StringName) -> bool:
				return CardDatabase.get_card(id) != null or CardDatabase.get_leader(id) != null)
	if _grant_starter_collection():
		save_profile()
	profile_changed.emit()


## Erases all progress (collection, decks, Rhinegold, campaign, achievements) and its backup.
## Settings are kept (user://settings.cfg).
func reset_profile() -> Error:
	profile = default_profile()
	for file_path: String in [path, _backup_path()]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	_discard_main_file = false
	_grant_starter_collection()
	var error: Error = save_profile()
	profile_changed.emit()
	return error


func owned_count(card_id: StringName) -> int:
	return int(profile.get("collection", {}).get(String(card_id), 0))


func rhinegold() -> int:
	return int(profile.get("rhinegold", 0))


## Gives the starter decks' cards and Leaders once per profile. Returns whether the profile changed.
func _grant_starter_collection() -> bool:
	if profile.get("starter_collection_granted", false) or not is_inside_tree():
		return false
	var starters: Array[DeckData] = []
	for deck_id: StringName in CardDatabase.deck_ids():
		if String(deck_id).ends_with("_starter"):
			starters.append(CardDatabase.get_deck(deck_id))
	add_starter_decks(profile, starters)
	return true


## Owned copies become what the decks need (not the sum: decks share the collection), Leaders are
## unlocked.
static func add_starter_decks(data: Dictionary, starters: Array[DeckData]) -> void:
	var collection: Dictionary = data["collection"]
	var leaders: Array = data["leaders"]
	for deck: DeckData in starters:
		if not leaders.has(String(deck.leader.id)):
			leaders.append(String(deck.leader.id))
		var counts: Dictionary = {}
		for card: CardData in deck.cards:
			counts[String(card.id)] = int(counts.get(String(card.id), 0)) + 1
		for card_id: String in counts:
			collection[card_id] = maxi(int(collection.get(card_id, 0)), int(counts[card_id]))
	data["starter_collection_granted"] = true


## Atomic write: write a temp file, keep the previous profile as backup, then swap.
func save_profile() -> Error:
	profile["version"] = CURRENT_VERSION
	var temp_path: String = path + ".tmp"
	var write_error: Error = _write_text(temp_path, JSON.stringify(profile, "\t"))
	if write_error != OK:
		return write_error
	if FileAccess.file_exists(path):
		if _discard_main_file:
			DirAccess.remove_absolute(path)
		else:
			var backup_error: Error = DirAccess.rename_absolute(path, _backup_path())
			if backup_error != OK:
				return backup_error
	var error: Error = DirAccess.rename_absolute(temp_path, path)
	if error == OK:
		_discard_main_file = false
	return error


func has_match() -> bool:
	return FileAccess.file_exists(match_path)


## The saved match in progress (MatchRecord.to_dict()), or {} when there is none or it is unreadable.
func load_match() -> Dictionary:
	var data: Variant = _read_json(match_path)
	return data if data is Dictionary else {}


## Atomic write, like the profile (no backup: the match is rewritten after every action).
func save_match(data: Dictionary) -> Error:
	var temp_path: String = match_path + ".tmp"
	var error: Error = _write_text(temp_path, JSON.stringify(data))
	if error != OK:
		return error
	return DirAccess.rename_absolute(temp_path, match_path)


func delete_match() -> void:
	if FileAccess.file_exists(match_path):
		DirAccess.remove_absolute(match_path)


## A match that cannot be resumed is kept aside as current_match.failed.json, for bug reports.
func keep_failed_match() -> void:
	if FileAccess.file_exists(match_path):
		DirAccess.rename_absolute(match_path, failed_match_path())


func failed_match_path() -> String:
	return match_path.get_basename() + ".failed.json"


## Brings an old save up to CURRENT_VERSION, then fills any missing key with its default.
static func migrate(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var version: int = int(migrated.get("version", 1))
	while version < CURRENT_VERSION:
		match version:
			1:
				_migrate_v1_to_v2(migrated)
			2:
				_migrate_v2_to_v3(migrated)
		version += 1
	migrated["version"] = CURRENT_VERSION
	# Missing or mistyped keys (a hand-edited or damaged save) get their default.
	var defaults: Dictionary = default_profile()
	for key: String in defaults:
		if not migrated.has(key) or _kind(migrated[key]) != _kind(defaults[key]):
			migrated[key] = defaults[key]
	# JSON reads every number back as a float: counts are ints again.
	migrated["rhinegold"] = int(migrated["rhinegold"])
	var collection: Dictionary = migrated["collection"]
	for card_id: Variant in collection:
		collection[card_id] = int(collection[card_id])
	return migrated


## Value type, with JSON numbers (always read back as floats) counted as one kind.
static func _kind(value: Variant) -> int:
	return TYPE_FLOAT if value is int else typeof(value)


## Cards removed from the game: owned copies become Rhinegold, and they leave the decks (a deck whose
## Leader is gone is dropped). `exists` tells whether a card or Leader ID is still known.
static func convert_unknown_cards(data: Dictionary, exists: Callable) -> void:
	var collection: Dictionary = data["collection"]
	for card_id: Variant in collection.keys():
		if not exists.call(StringName(str(card_id))):
			data["rhinegold"] = int(data["rhinegold"]) + maxi(0, int(collection[card_id])) * REMOVED_CARD_VALUE
			collection.erase(card_id)
			push_warning("SaveManager: unknown card %s converted to Rhinegold" % card_id)
	var decks: Array = []
	for deck: Variant in data["decks"]:
		if not deck is Dictionary or not exists.call(StringName(str(deck.get("leader", "")))):
			push_warning("SaveManager: deck with an unknown Leader dropped")
			continue
		var cards: Array = []
		for card_id: Variant in deck.get("cards", []):
			if exists.call(StringName(str(card_id))):
				cards.append(card_id)
		deck["cards"] = cards
		decks.append(deck)
	data["decks"] = decks


## v1 → v2: the progression currency was renamed from Hoard to Rhinegold (same value).
static func _migrate_v1_to_v2(data: Dictionary) -> void:
	if data.has("hoard"):
		data["rhinegold"] = data["hoard"]
		data.erase("hoard")


## v2 → v3: owned Leaders, and the starter collection, granted on the next load.
static func _migrate_v2_to_v3(data: Dictionary) -> void:
	data["leaders"] = []
	data["starter_collection_granted"] = false


func _backup_path() -> String:
	return path + ".bak"


func _write_text(file_path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


func _read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	return parsed if parsed is Dictionary else null
