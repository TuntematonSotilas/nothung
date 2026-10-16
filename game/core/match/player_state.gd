class_name PlayerState
extends RefCounted

## Mutable state belonging to one player.

var player_id: int
var leader: LeaderData
var life: int
var energy: int = 0
var max_energy: int = 0
var opening_energy: int = 0
var turns_taken: int = 0
var leader_ability_used: bool = false
var redraw_done: bool = false
var deck: Zone = Zone.new()
var hand: Zone = Zone.new()
var board: Zone = Zone.new()
var artifacts: Zone = Zone.new()
var graveyard: Zone = Zone.new()
var banished: Zone = Zone.new()


func _init(id: int = 0, leader_data: LeaderData = null) -> void:
	player_id = id
	leader = leader_data
	life = leader_data.life if leader_data != null else 20


## Returns a deep copy of all runtime zones and cards.
func duplicate_state() -> PlayerState:
	var copy := PlayerState.new(player_id, leader)
	copy.life = life
	copy.energy = energy
	copy.max_energy = max_energy
	copy.opening_energy = opening_energy
	copy.turns_taken = turns_taken
	copy.leader_ability_used = leader_ability_used
	copy.redraw_done = redraw_done
	copy.deck = _duplicate_zone(deck)
	copy.hand = _duplicate_zone(hand)
	copy.board = _duplicate_zone(board)
	copy.artifacts = _duplicate_zone(artifacts)
	copy.graveyard = _duplicate_zone(graveyard)
	copy.banished = _duplicate_zone(banished)
	return copy


func _duplicate_zone(source: Zone) -> Zone:
	var copy := Zone.new()
	for card: CardInstance in source.cards:
		copy.add(card.duplicate_instance())
	return copy
