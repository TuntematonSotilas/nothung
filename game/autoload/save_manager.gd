extends Node
## Player profile persistence: JSON, atomic writes, backup, versioned migrations.
## See docs/technical/07-persistence.md.

const CURRENT_VERSION: int = 2
const DEFAULT_PATH: String = "user://profile.json"

var path: String = DEFAULT_PATH
var profile: Dictionary = {}


func _ready() -> void:
	load_profile()


static func default_profile() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"rhinegold": 0,
		"collection": {},
		"decks": [],
		"campaign": {},
		"achievements": [],
	}


## Loads the profile, falling back to the backup, then to a fresh profile.
func load_profile() -> void:
	var data: Variant = _read_json(path)
	if data == null:
		data = _read_json(_backup_path())
		if data != null:
			push_warning("SaveManager: profile unreadable, restored from backup")
	if data == null:
		profile = default_profile()
		return
	profile = migrate(data)


## Atomic write: write a temp file, keep the previous profile as backup, then swap.
func save_profile() -> Error:
	profile["version"] = CURRENT_VERSION
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		var backup_error: Error = DirAccess.rename_absolute(path, _backup_path())
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(temp_path, path)


## Brings an old save up to CURRENT_VERSION, then fills any missing key with its default.
static func migrate(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var version: int = int(migrated.get("version", 1))
	while version < CURRENT_VERSION:
		match version:
			1:
				_migrate_v1_to_v2(migrated)
		version += 1
	migrated["version"] = CURRENT_VERSION
	var defaults: Dictionary = default_profile()
	for key: String in defaults:
		if not migrated.has(key):
			migrated[key] = defaults[key]
	return migrated


## v1 → v2: the progression currency was renamed from Hoard to Rhinegold (same value).
static func _migrate_v1_to_v2(data: Dictionary) -> void:
	if data.has("hoard"):
		data["rhinegold"] = data["hoard"]
		data.erase("hoard")


func _backup_path() -> String:
	return path + ".bak"


func _read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	return parsed if parsed is Dictionary else null
