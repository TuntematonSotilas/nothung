extends Control

## Quick match: your current deck (Change deck picks another one ready to play), the opponent's deck (a
## starter deck, or Random) and the AI difficulty, then Play, right under them. The choices are
## remembered in Settings for next time.

const DUEL_SCENE: String = "res://scenes/screens/duel.tscn"
const RANDOM: StringName = &"random"
const DIFFICULTY_KEYS: Array[String] = ["UI_DIFFICULTY_EASY", "UI_DIFFICULTY_NORMAL", "UI_DIFFICULTY_HARD"]

## Starter decks: the AI's decks.
var _deck_ids: Array[StringName] = []
## The current deck (MenuUI.current_deck()); {} when no deck is ready to play.
var _player_entry: Dictionary = {}
var _player_deck: StringName
var _opponent_deck: StringName
var _difficulty: AIProfile.Difficulty
var _opponent_tiles: Dictionary = {}
var _difficulty_buttons: Array[Button] = []
var _difficulty_hint: Label


func _ready() -> void:
	_deck_ids = MenuUI.ordered_decks(CardDatabase.deck_ids())
	_player_entry = MenuUI.current_deck()
	_player_deck = StringName(str(_player_entry.get("id", "")))
	_opponent_deck = StringName(Settings.quick_match_opponent)
	if _opponent_deck != RANDOM and not _deck_ids.has(_opponent_deck):
		_opponent_deck = RANDOM
	_difficulty = clampi(Settings.quick_match_difficulty, 0, 2) as AIProfile.Difficulty
	_build()


func _build() -> void:
	var screen_column: VBoxContainer = MenuUI.screen_column(self, 24)
	screen_column.add_child(MenuUI.header("UI_QUICK_MATCH"))
	# The choices and Play sit in the middle of the height left under the title.
	var column := VBoxContainer.new()
	column.name = "QuickMatchBody"
	column.add_theme_constant_override("separation", 24)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_column.add_child(column)

	column.add_child(_section("UI_YOUR_DECK"))
	if _player_entry.is_empty():
		var none: Label = MenuUI.label("UI_NO_PLAYABLE_DECK", 26, Palette.LIFE)
		none.name = "NoPlayableDeck"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(none)
	else:
		column.add_child(_current_deck_row())

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

	# Play right under the choices, not at the bottom of the screen.
	var play: Button = MenuUI.button("UI_PLAY", 128, 38)
	play.name = "PlayButton"
	play.theme_type_variation = &"ButtonPrimary"
	play.pressed.connect(_on_play_pressed)
	play.disabled = _player_entry.is_empty()
	column.add_child(play)


## The setup the Play button would start; Random is resolved here, among the other factions' decks.
func build_setup(rng: RandomNumberGenerator = null) -> DuelSetup:
	var player: DeckData = DeckRules.to_deck_data(_player_entry, CardDatabase)
	var opponent: StringName = _opponent_deck
	if opponent == RANDOM:
		var candidates: Array[StringName] = []
		for deck_id: StringName in _deck_ids:
			if CardDatabase.get_deck(deck_id).leader.faction != player.leader.faction:
				candidates.append(deck_id)
		if candidates.is_empty():
			candidates = _deck_ids
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.randomize()
		opponent = candidates[rng.randi_range(0, candidates.size() - 1)]
	return DuelSetup.new(player, CardDatabase.get_deck(opponent), _difficulty)


func _on_play_pressed() -> void:
	Settings.quick_match_deck = String(_player_deck)
	Settings.quick_match_opponent = String(_opponent_deck)
	Settings.quick_match_difficulty = _difficulty
	Settings.save_settings()
	DuelSetup.next = build_setup()
	DuelSetup.next.rewards = true
	SceneRouter.go_to(DUEL_SCENE, false)


func _section(key: String) -> Label:
	return MenuUI.label(key, 26, Palette.TEXT_MUTED)


## The current deck (faction icon, name, Leader) and Change deck, which opens the DeckPicker.
func _current_deck_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var leader: LeaderData = CardDatabase.get_leader(StringName(str(_player_entry["leader"])))
	var colors: Dictionary = CardPalette.FACTIONS.get(leader.faction, CardPalette.FACTIONS[&"neutral"])
	var text: String = "%s\n%s" % [MenuUI.deck_name(_player_entry), tr("LEADER_%s_NAME" % String(leader.id).to_upper())]
	var tile: Button = MenuUI.choice_tile(text, colors["frame"], 150, "res://ui/icons/faction_%s.svg" % leader.faction)
	tile.name = "CurrentDeckTile"
	tile.toggle_mode = false
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tile.clip_text = true
	row.add_child(tile)
	var change: Button = MenuUI.button("UI_CHANGE_DECK", 150, 26)
	change.name = "ChangeDeckButton"
	change.custom_minimum_size.x = 300
	change.pressed.connect(func() -> void: DeckPicker.open(self, _rebuild))
	row.add_child(change)
	return row


## Rebuilt with the new current deck; the opponent and difficulty chosen stay.
func _rebuild() -> void:
	for child: Node in get_children():
		if child.name != "DeckPicker":
			remove_child(child)
			child.queue_free()
	_opponent_tiles.clear()
	_difficulty_buttons.clear()
	_player_entry = MenuUI.current_deck()
	_player_deck = StringName(str(_player_entry.get("id", "")))
	_build()


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
		tile.name = "Opponent_%s" % deck_id
		tile.button_pressed = deck_id == selected
		tile.pressed.connect(on_chosen.bind(deck_id))
		tiles[deck_id] = tile
		grid.add_child(tile)
	return grid


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
