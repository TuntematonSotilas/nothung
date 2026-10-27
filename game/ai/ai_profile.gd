class_name AIProfile
extends Resource

## How an AI opponent plays: difficulty, search budget, noise and evaluation weights.
## See docs/technical/05-ai-opponent.md.

enum Difficulty { EASY, NORMAL, HARD }
enum Personality { BALANCED, AGGRESSIVE, DEFENSIVE }

@export var difficulty: Difficulty = Difficulty.NORMAL
@export var personality: Personality = Personality.BALANCED
## Random spread added to each action's evaluation (Normal), in evaluation points.
@export var noise: float = 0.0
## Hard: thinking time per action, and a cap on search iterations (0 = time only).
@export var time_budget_msec: int = 700
@export var max_iterations: int = 0
## Hard: UCB1 exploration constant.
@export var exploration: float = 0.7

@export_group("Evaluation weights")
@export var own_life_weight: float = 1.0
@export var enemy_life_weight: float = 1.0
@export var board_weight: float = 1.0
@export var hand_weight: float = 1.5
@export var artifact_weight: float = 1.0
@export var ring_weight: float = 1.0


## The default profile of a difficulty, optionally with a personality.
static func preset(level: Difficulty, style: Personality = Personality.BALANCED) -> AIProfile:
	var profile := AIProfile.new()
	profile.difficulty = level
	profile.personality = style
	match level:
		Difficulty.NORMAL:
			profile.noise = 2.0
		Difficulty.HARD:
			profile.noise = 0.0
	match style:
		Personality.AGGRESSIVE:
			profile.enemy_life_weight = 1.6
			profile.own_life_weight = 0.7
		Personality.DEFENSIVE:
			profile.own_life_weight = 1.5
			profile.board_weight = 1.2
	return profile
