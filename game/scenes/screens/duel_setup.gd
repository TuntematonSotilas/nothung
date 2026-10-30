class_name DuelSetup
extends RefCounted

## What the next duel plays. Quick match (later the campaign) sets DuelSetup.next before opening the
## duel screen; the duel keeps it for rematches. Without one, the duel plays the default below.
## Decks are DeckData: a player deck (DeckRules.to_deck_data) or a starter deck from CardDatabase.

static var next: DuelSetup

var player_deck: DeckData
var opponent_deck: DeckData
var difficulty: AIProfile.Difficulty = AIProfile.Difficulty.NORMAL
## An interrupted match to resume (main menu prompt); used once, a rematch starts a new match.
var resume: MatchRecord
## Whether a win pays Rhinegold (Quick match: Progression.quick_match_reward()).
var rewards: bool = false


func _init(deck: DeckData = null, opponent: DeckData = null, level: AIProfile.Difficulty = AIProfile.Difficulty.NORMAL) -> void:
	player_deck = deck if deck != null else CardDatabase.get_deck(&"gods_starter")
	opponent_deck = opponent if opponent != null else CardDatabase.get_deck(&"nibelungs_starter")
	difficulty = level
