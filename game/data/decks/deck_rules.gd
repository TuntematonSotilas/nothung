class_name DeckRules
extends RefCounted

## Deckbuilding rules for the player's decks (docs/functional/04-cards.md#deckbuilding-rules): 20 cards,
## the Leader's faction + Neutral, copy limits by rarity, and no more copies than the player owns.
## A player deck is stored in the profile as {id, name, leader, cards: [card IDs]}.

const DECK_SIZE: int = 20
## Deck slots (docs/functional/05-game-modes.md#deck-builder).
const MAX_DECKS: int = 12


static func eligible(card: CardData, leader: LeaderData) -> bool:
	return card.faction == leader.faction or card.faction == &"neutral"


static func count_of(entry: Dictionary, card_id: StringName) -> int:
	return (entry.get("cards", []) as Array).count(String(card_id))


## Whether one more copy of `card` fits: eligible, under the copy limit and the copies owned, deck not full.
static func can_add(entry: Dictionary, card: CardData, leader: LeaderData, owned: int) -> bool:
	var copies: int = count_of(entry, card.id)
	return (
		eligible(card, leader)
		and (entry.get("cards", []) as Array).size() < DECK_SIZE
		and copies < card.deck_limit()
		and copies < owned
	)


## What keeps the deck from being played, as {key, args} for tr(key).format(args); empty = valid.
## `owned` gives the copies owned of a card ID.
static func problems(entry: Dictionary, database: Object, owned: Callable) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var leader: LeaderData = database.call("get_leader", StringName(str(entry.get("leader", "")))) as LeaderData
	if leader == null:
		found.append({"key": "UI_DECK_PROBLEM_LEADER", "args": {}})
		return found
	var cards: Array = entry.get("cards", [])
	if cards.size() != DECK_SIZE:
		found.append({"key": "UI_DECK_PROBLEM_SIZE", "args": {"count": cards.size(), "size": DECK_SIZE}})
	var seen: Dictionary = {}
	for card_id: Variant in cards:
		if seen.has(card_id):
			continue
		seen[card_id] = true
		var card: CardData = database.call("get_card", StringName(str(card_id))) as CardData
		if card == null or not eligible(card, leader):
			found.append({"key": "UI_DECK_PROBLEM_CARD", "args": {"card": str(card_id)}})
			continue
		var copies: int = cards.count(card_id)
		var name: String = TranslationServer.translate("CARD_%s_NAME" % String(card.id).to_upper())
		if copies > card.deck_limit():
			found.append({"key": "UI_DECK_PROBLEM_COPIES", "args": {"card": name, "max": card.deck_limit()}})
		elif copies > int(owned.call(card.id)):
			found.append({"key": "UI_DECK_PROBLEM_OWNED", "args": {"card": name, "owned": int(owned.call(card.id))}})
	return found


## A problem from problems(), translated.
static func problem_text(problem: Dictionary) -> String:
	return TranslationServer.translate(problem["key"]).format(problem["args"])


## The DeckData the engine plays, or null when the Leader or a card is unknown.
static func to_deck_data(entry: Dictionary, database: Object) -> DeckData:
	var deck := DeckData.new()
	deck.id = StringName(str(entry.get("id", "")))
	deck.leader = database.call("get_leader", StringName(str(entry.get("leader", "")))) as LeaderData
	if deck.leader == null:
		return null
	for card_id: Variant in entry.get("cards", []):
		var card: CardData = database.call("get_card", StringName(str(card_id))) as CardData
		if card == null:
			return null
		deck.cards.append(card)
	return deck


## Copies per cost (0 … 6+), and cards per type ("unit", "spell", "artifact" with relics).
static func curve(cards: Array[CardData]) -> Array[int]:
	var bars: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for card: CardData in cards:
		bars[mini(card.cost, bars.size() - 1)] += 1
	return bars


static func type_counts(cards: Array[CardData]) -> Dictionary:
	var counts: Dictionary = {"unit": 0, "spell": 0, "artifact": 0}
	for card: CardData in cards:
		counts[String(CardData.Type.keys()[card.type]).to_lower()] += 1
	return counts
