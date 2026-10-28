extends Control

## Quick match: choose your deck, the opponent's deck (or Random) and the AI difficulty, then play.
## The choices are remembered in Settings for next time.

const DUEL_SCENE: String = "res://scenes/screens/duel.tscn"
const RANDOM: StringName = &"random"
const DIFFICULTY_KEYS: Array[String] = ["UI_DIFFICULTY_EASY", "UI_DIFFICULTY_NORMAL", "UI_DIFFICULTY_HARD"]

var _deck_ids: Array[StringName] = []
var _player_deck: StringName
var _opponent_deck: StringName
var _difficulty: AIProfile.Difficulty
var _player_tiles: Dictionary = {}
var _opponent_tiles: Dictionary = {}
var _difficulty_buttons: Array[Button] = []
var _difficulty_hint: Label


func _ready() -> void:
	_deck_ids = MenuUI.ordered_decks(CardDatabase.deck_ids())
	_player_deck = StringName(Settings.quick_match_deck)
	if not _deck_ids.has(_player_deck):
		_player_deck = _deck_ids[0]
	_opponent_deck = StringName(Settings.quick_match_opponent)
	if _opponent_deck != RANDOM and not _deck_ids.has(_opponent_deck):
		_opponent_deck = RANDOM
	_difficulty = clampi(Settings.quick_match_difficulty, 0, 2) as AIProfile.Difficulty
	_build()


func _build() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 24)

	column.add_child(MenuUI.header("UI_QUICK_MATCH"))

	column.add_child(_section("UI_YOUR_DECK"))
	column.add_child(_deck_grid(_player_tiles, _on_player_deck_chosen, _player_deck))

	column.add_child(_section("UI_OPPONENT"))
	var random_tile: Button = MenuUI.choice_tile(tr("UI_RANDOM"), Palette.BORDER, 96)
	random_tile.name = "OpponentRandom"
	random_tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	random_tile.button_pressed = _opponent_deck == RANDOM
	random_tile.pressed.connect(_on_opponent_chosen.bind(RANDOM))
	_opponent_tiles[RANDOM] = random_tile
	column.add_child(random_tile)
	column.add_child(_deck_grid(_opponent_tiles, _on_opponent_chosen, _opponent_deck))

	column.add_child(_section("UI_DIFFICULTY"))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 16)
	for level: int in DIFFICULTY_KEYS.size():
		var level_button: Button = MenuUI.choice_tile(tr(DIFFICULTY_KEYS[level]), Palette.BORDER, 96)
		level_button.name = "Difficulty%d" % level
		level_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_button.button_pressed = level == _difficulty
		level_button.pressed.connect(_on_difficulty_chosen.bind(level))
		_difficulty_buttons.append(level_button)
		levels.add_child(level_button)
	column.add_child(levels)
	_difficulty_hint = MenuUI.label("", 24, Palette.TEXT_MUTED)
	_difficulty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_hint.custom_minimum_size.y = 64
	column.add_child(_difficulty_hint)
	_update_difficulty_hint()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var play: Button = MenuUI.button("UI_PLAY", 128, 38)
	play.name = "PlayButton"
	play.theme_type_variation = &"ButtonPrimary"
	play.pressed.connect(_on_play_pressed)
	column.add_child(play)


## The setup the Play button would start; Random is resolved here, among the other factions' decks.
func build_setup(rng: RandomNumberGenerator = null) -> DuelSetup:
	var opponent: StringName = _opponent_deck
	if opponent == RANDOM:
		var candidates: Array[StringName] = []
		for deck_id: StringName in _deck_ids:
			if deck_id != _player_deck:
				candidates.append(deck_id)
		if candidates.is_empty():
			candidates = _deck_ids
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.randomize()
		opponent = candidates[rng.randi_range(0, candidates.size() - 1)]
	return DuelSetup.new(_player_deck, opponent, _difficulty)


func _on_play_pressed() -> void:
	Settings.quick_match_deck = String(_player_deck)
	Settings.quick_match_opponent = String(_opponent_deck)
	Settings.quick_match_difficulty = _difficulty
	Settings.save_settings()
	DuelSetup.next = build_setup()
	SceneRouter.go_to(DUEL_SCENE, false)


func _section(key: String) -> Label:
	return MenuUI.label(key, 26, Palette.TEXT_MUTED)


## Two columns of deck tiles: faction icon, faction and Leader, border in the faction colour.
func _deck_grid(tiles: Dictionary, on_chosen: Callable, selected: StringName) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for deck_id: StringName in _deck_ids:
		var deck: DeckData = CardDatabase.get_deck(deck_id)
		var faction: StringName = deck.leader.faction
		var colors: Dictionary = CardPalette.FACTIONS.get(faction, CardPalette.FACTIONS[&"neutral"])
		var text: String = "%s\n%s" % [MenuUI.faction_name(faction), tr("LEADER_%s_NAME" % String(deck.leader.id).to_upper())]
		var tile: Button = MenuUI.choice_tile(text, colors["frame"], 150, "res://ui/icons/faction_%s.svg" % faction)
		tile.name = "%s_%s" % ["Player" if tiles == _player_tiles else "Opponent", deck_id]
		tile.button_pressed = deck_id == selected
		tile.pressed.connect(on_chosen.bind(deck_id))
		tiles[deck_id] = tile
		grid.add_child(tile)
	return grid


func _on_player_deck_chosen(deck_id: StringName) -> void:
	_player_deck = deck_id
	_select(_player_tiles, deck_id)


func _on_opponent_chosen(deck_id: StringName) -> void:
	_opponent_deck = deck_id
	_select(_opponent_tiles, deck_id)


func _on_difficulty_chosen(level: int) -> void:
	_difficulty = level as AIProfile.Difficulty
	for index: int in _difficulty_buttons.size():
		_difficulty_buttons[index].set_pressed_no_signal(index == level)
	_update_difficulty_hint()


## Exactly one tile of a group stays selected (tapping the selected one keeps it).
func _select(tiles: Dictionary, chosen: StringName) -> void:
	for deck_id: StringName in tiles:
		(tiles[deck_id] as Button).set_pressed_no_signal(deck_id == chosen)


func _update_difficulty_hint() -> void:
	_difficulty_hint.text = tr(DIFFICULTY_KEYS[_difficulty] + "_HINT")
