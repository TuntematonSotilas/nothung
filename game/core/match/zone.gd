class_name Zone
extends RefCounted

## Ordered collection of cards in one player zone.

var cards: Array[CardInstance] = []


## Returns the number of cards in the zone.
func size() -> int:
	return cards.size()


## Returns whether the zone contains no cards.
func is_empty() -> bool:
	return cards.is_empty()


## Finds a card by match-unique id, or returns null.
func find(uid: int) -> CardInstance:
	for card: CardInstance in cards:
		if card.uid == uid:
			return card
	return null


## Removes and returns a card by id, or null if it is absent.
func remove_uid(uid: int) -> CardInstance:
	for index: int in cards.size():
		if cards[index].uid == uid:
			return cards.pop_at(index)
	return null


## Adds a card at the end of the zone.
func add(card: CardInstance) -> void:
	cards.append(card)
