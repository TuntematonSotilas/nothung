class_name MatchRecord
extends RefCounted

## A match as seed + deck snapshots + the list of what happened (actions and undone plays), saved to
## resume an interrupted match. Replaying it rebuilds the exact state: the engine is deterministic and
## AI moves are recorded like the player's. See docs/technical/07-persistence.md#resume-an-interrupted-match.

const VERSION: int = 1

## Where the decks came from (a player deck ID or a starter deck ID), for bug reports.
var player_deck_id: StringName
var opponent_deck_id: StringName
var difficulty: int = 0
var seed: int = 0
## [{leader, cards}] for players 0 and 1: card IDs, not deck references.
var decks: Array[Dictionary] = []
## Hash of the card data at match start; replaying on changed data could diverge.
var content_hash: String = ""
## Action records (Action.to_record()) and {"type": "undo_play", "card_uid"} entries, in order.
var entries: Array[Dictionary] = []


static func create(deck_a: DeckData, deck_b: DeckData, match_seed: int) -> MatchRecord:
	var record := MatchRecord.new()
	record.player_deck_id = deck_a.id
	record.opponent_deck_id = deck_b.id
	record.seed = match_seed
	record.decks = [deck_snapshot(deck_a), deck_snapshot(deck_b)]
	record.content_hash = content_hash_of([deck_a, deck_b])
	return record


static func deck_snapshot(deck: DeckData) -> Dictionary:
	var cards: Array[String] = []
	for card: CardData in deck.cards:
		cards.append(String(card.id))
	return {"leader": String(deck.leader.id), "cards": cards}


func add_action(action: Action) -> void:
	entries.append(action.to_record())


func add_undo_play(card_uid: int) -> void:
	entries.append({"type": "undo_play", "card_uid": card_uid})


## Undoes the last card play: back to the state before it, with the card on top of the deck
## (docs/functional/07-ui-ux.md). Shared by the duel screen and the replay.
static func undo_play(engine: Match, snapshot: GameState, card_uid: int) -> bool:
	if not engine.restore_snapshot(snapshot):
		return false
	var player: PlayerState = engine.get_state().player(snapshot.active_player)
	var card: CardInstance = player.hand.remove_uid(card_uid)
	if card == null:
		push_error("Cannot undo the card play because the card is missing from the restored hand.")
		return false
	player.deck.add(card)
	return true


## Rebuilds the match, or returns null when it cannot be resumed: unknown card, card data changed
## since the match started, or an entry the engine rejects. `database` resolves IDs (CardDatabase).
func replay(database: Object) -> Match:
	var rebuilt: Array[DeckData] = rebuild_decks(database)
	if rebuilt.size() != 2 or content_hash_of(rebuilt) != content_hash:
		return null
	var engine := Match.new(rebuilt[0], rebuilt[1], seed)
	if engine.get_state().phase == GameState.Phase.GAME_OVER:
		return null
	var before_play: GameState
	for entry: Dictionary in entries:
		if String(entry.get("type", "")) == "undo_play":
			if before_play == null or not undo_play(engine, before_play, int(entry.get("card_uid", -1))):
				return null
			before_play = null
			continue
		var action: Action = Action.from_record(entry)
		var snapshot: GameState = engine.get_state().duplicate_state() if action is PlayCardAction else null
		if action == null or not engine.apply(action):
			return null
		before_play = snapshot
	return engine


## The two decks from their snapshots (a rematch after resuming plays them again); empty when a card
## or Leader is unknown.
func rebuild_decks(database: Object) -> Array[DeckData]:
	var rebuilt: Array[DeckData] = []
	for snapshot: Dictionary in decks:
		var deck: DeckData = _rebuild_deck(snapshot, database)
		if deck == null:
			return []
		rebuilt.append(deck)
	return rebuilt


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"content_hash": content_hash,
		"mode": "quick_match",
		"player_deck": String(player_deck_id),
		"opponent_deck": String(opponent_deck_id),
		"difficulty": difficulty,
		"seed": seed,
		"decks": decks,
		"actions": entries,
	}


## Reads a saved record, or returns null when it is malformed or from another format version.
static func from_dict(data: Dictionary) -> MatchRecord:
	if int(data.get("version", 0)) != VERSION or not data.get("decks") is Array or not data.get("actions") is Array:
		return null
	var record := MatchRecord.new()
	record.content_hash = str(data.get("content_hash", ""))
	record.player_deck_id = StringName(str(data.get("player_deck", "")))
	record.opponent_deck_id = StringName(str(data.get("opponent_deck", "")))
	record.difficulty = int(data.get("difficulty", 0))
	record.seed = int(data.get("seed", 0))
	for deck: Variant in data["decks"]:
		if not deck is Dictionary:
			return null
		record.decks.append(deck)
	for entry: Variant in data["actions"]:
		if not entry is Dictionary:
			return null
		record.entries.append(entry)
	return record


## SHA-256 of everything that drives the rules in these decks (art excluded).
static func content_hash_of(deck_list: Array[DeckData]) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for deck: DeckData in deck_list:
		var record: Array = [_resource_record(deck.leader, true)]
		for card: CardData in deck.cards:
			record.append(_resource_record(card, true))
		context.update(JSON.stringify(record).to_utf8_buffer())
	return context.finish().hex_encode()


## Stored properties of a resource, sub-resources included; textures are left out. A card or Leader
## met inside another one (shatters_into, reforge…) is named by its ID: Nothung and Nothung (broken)
## refer to each other.
static func _resource_record(value: Variant, top_level: bool = false) -> Variant:
	if value is Texture2D:
		return null
	if not top_level and (value is CardData or value is LeaderData):
		return String(value.get("id"))
	if value is Resource:
		var resource: Resource = value
		var record: Dictionary = {}
		for property: Dictionary in resource.get_property_list():
			var name: String = property["name"]
			if int(property["usage"]) & PROPERTY_USAGE_STORAGE == 0 or name.begins_with("resource_") or name == "script":
				continue
			record[name] = _resource_record(resource.get(name))
		return record
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_resource_record(item))
		return items
	if value is StringName:
		return String(value)
	return value


static func _rebuild_deck(snapshot: Dictionary, database: Object) -> DeckData:
	var deck := DeckData.new()
	deck.leader = database.call("get_leader", StringName(str(snapshot.get("leader", "")))) as LeaderData
	if deck.leader == null or not snapshot.get("cards") is Array:
		return null
	for card_id: Variant in snapshot["cards"]:
		var card: CardData = database.call("get_card", StringName(str(card_id))) as CardData
		if card == null:
			return null
		deck.cards.append(card)
	return deck
