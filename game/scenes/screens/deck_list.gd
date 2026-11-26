extends Control

## My decks: one tile per player deck — one per faction, the starter decks' copies — with its faction,
## name, Leader and whether it can be played. Tapping a deck opens the editor; decks are not created,
## duplicated or deleted (the board, like the Leader's power, is chosen in the editor). See
## docs/functional/07-ui-ux.md.

const EDITOR_SCENE: String = "res://scenes/screens/deck_editor.tscn"


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 24)
	column.add_child(MenuUI.header("UI_MY_DECKS"))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "DeckTiles"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	# Fills the scroll's height, its content centred vertically (it scrolls once taller than the screen).
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(list)
	for entry: Dictionary in SaveManager.decks():
		list.add_child(_deck_tile(entry))


## Faction icon and colour, the deck's name, its Leader and "Ready" or what is missing.
func _deck_tile(entry: Dictionary) -> Button:
	var leader: LeaderData = CardDatabase.get_leader(StringName(str(entry["leader"])))
	var faction: StringName = leader.faction if leader != null else &"neutral"
	var problems: Array[Dictionary] = DeckRules.problems(entry, CardDatabase, SaveManager.owned_count)
	var status: String = tr("UI_DECK_READY") if problems.is_empty() else DeckRules.problem_text(problems[0])
	var leader_name: String = tr("LEADER_%s_NAME" % String(leader.id).to_upper()) if leader != null else "?"
	var tile: Button = MenuUI.choice_tile("%s\n%s · %s" % [MenuUI.deck_name(entry), leader_name, status], CardPalette.FACTIONS[faction]["frame"], 150, "res://ui/icons/faction_%s.svg" % faction)
	tile.name = "Deck_%s" % entry["id"]
	tile.toggle_mode = false
	tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tile.clip_text = true
	tile.pressed.connect(open_editor.bind(str(entry["id"])))
	return tile


func open_editor(deck_id: String) -> void:
	DeckEditor.deck_id = deck_id
	SceneRouter.go_to(EDITOR_SCENE)
