extends Node

## Loads generated card, leader and deck Resources and indexes them by stable ID.

var _cards: Dictionary = {}
var _leaders: Dictionary = {}
var _decks: Dictionary = {}


func _ready() -> void:
	reload_database()


## Loads all generated Resources. Returns false and reports an error on invalid data.
func reload_database() -> bool:
	_cards.clear()
	_leaders.clear()
	_decks.clear()
	var ok: bool = true
	ok = _load_directory("res://data/cards") and ok
	ok = _load_directory("res://data/leaders") and ok
	ok = _load_directory("res://data/decks") and ok
	if _cards.is_empty() or _leaders.is_empty() or _decks.is_empty():
		push_error("Card database is incomplete; run the card pipeline generator.")
		return false
	return ok


## Returns a card definition by ID, or null when the ID is unknown.
func get_card(card_id: StringName) -> CardData:
	return _cards.get(card_id, null) as CardData


## Returns a Leader definition by ID, or null when the ID is unknown.
func get_leader(leader_id: StringName) -> LeaderData:
	return _leaders.get(leader_id, null) as LeaderData


## Returns a starter deck by ID, or null when the ID is unknown.
func get_deck(deck_id: StringName) -> DeckData:
	return _decks.get(deck_id, null) as DeckData


## Returns the number of registered card definitions.
func card_count() -> int:
	return _cards.size()


func _load_directory(directory: String) -> bool:
	var entries: PackedStringArray = ResourceLoader.list_directory(directory)
	if entries.is_empty():
		push_error("Generated data directory is missing: %s" % directory)
		return false
	var ok: bool = true
	entries.sort()
	for entry: String in entries:
		if entry.ends_with("/"):
			ok = _load_directory(directory.path_join(entry.trim_suffix("/"))) and ok
			continue
		if not entry.ends_with(".tres"):
			continue
		var path: String = directory.path_join(entry)
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			push_error("Could not load generated Resource: %s" % path)
			ok = false
			continue
		if resource is CardData:
			ok = _register(_cards, (resource as CardData).id, resource, path) and ok
		elif resource is LeaderData:
			ok = _register(_leaders, (resource as LeaderData).id, resource, path) and ok
		elif resource is DeckData:
			ok = _register(_decks, (resource as DeckData).id, resource, path) and ok
		else:
			push_error("Unexpected Resource type in generated data: %s" % path)
			ok = false
	return ok


func _register(index: Dictionary, resource_id: StringName, resource: Resource, path: String) -> bool:
	if resource_id == &"":
		push_error("Generated Resource has an empty ID: %s" % path)
		return false
	if index.has(resource_id):
		push_error("Duplicate generated Resource ID %s at %s" % [resource_id, path])
		return false
	index[resource_id] = resource
	return true
