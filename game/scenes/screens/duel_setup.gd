class_name DuelSetup
extends RefCounted

## What the next duel plays. Quick match (later the campaign) sets DuelSetup.next before opening the
## duel screen; the duel keeps it for rematches. Without one, the duel plays the default below.

static var next: DuelSetup

var player_deck: StringName = &"gods_starter"
var opponent_deck: StringName = &"nibelungs_starter"
var difficulty: AIProfile.Difficulty = AIProfile.Difficulty.NORMAL
## An interrupted match to resume (main menu prompt); used once, a rematch starts a new match.
var resume: MatchRecord


func _init(deck: StringName = &"gods_starter", opponent: StringName = &"nibelungs_starter", level: AIProfile.Difficulty = AIProfile.Difficulty.NORMAL) -> void:
	player_deck = deck
	opponent_deck = opponent
	difficulty = level
