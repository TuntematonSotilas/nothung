class_name DeckData
extends Resource

## A leader and its ordered card definitions.

@export var id: StringName
@export var leader: LeaderData
@export var cards: Array[CardData] = []
