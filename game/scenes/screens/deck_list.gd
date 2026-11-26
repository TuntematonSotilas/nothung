extends Control

## My decks: one tile per player deck — one per faction, the starter decks' copies — with its faction,
## name, Leader and whether it can be played. Tapping a deck opens the editor; decks are not created,
## duplicated or deleted. Next to each deck, its board (the background of the player's play area in a
## match, bought in Nibelheim): a tap chooses it. See docs/functional/07-ui-ux.md.

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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var tile: Button = _deck_tile(entry)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)
		row.add_child(_board_button(entry))
		list.add_child(row)


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


## The deck's board as a thumbnail ("Board" over it); a tap opens the choice.
func _board_button(entry: Dictionary) -> Button:
	var button: Button = BackgroundTile.create(Cosmetics.board_of(entry), Vector2(200, 150), "UI_BOARD")
	button.name = "Board_%s" % entry["id"]
	button.toggle_mode = false
	button.pressed.connect(open_board_picker.bind(entry))
	return button


## Default and each board owned; choosing one saves it with the deck. Without any, a line says where
## to buy them.
func open_board_picker(entry: Dictionary) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "BoardPicker"
	overlay.color = Color(Palette.BG, 0.96)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.custom_minimum_size.x = get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN
	center.add_child(content)
	var title: Label = MenuUI.label("UI_CHOOSE_BOARD", 36, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var owned: Array[String] = Cosmetics.owned(Cosmetics.BOARD)
	if owned.is_empty():
		var hint: Label = MenuUI.label("UI_BACKGROUNDS_HINT", 26, Palette.TEXT_MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	content.add_child(grid)
	var current: String = Cosmetics.board_of(entry)
	for cosmetic_id: String in [""] + owned:
		var tile: Button = BackgroundTile.create(cosmetic_id, Vector2(470, 280))
		tile.name = "Board_%s" % (cosmetic_id if not cosmetic_id.is_empty() else "default")
		tile.button_pressed = cosmetic_id == current
		tile.pressed.connect(func() -> void:
			Cosmetics.set_board(entry, cosmetic_id)
			overlay.queue_free()
			_rebuild())
		grid.add_child(tile)
	var cancel: Button = MenuUI.button("UI_CANCEL")
	cancel.name = "CancelBoardButton"
	cancel.pressed.connect(overlay.queue_free)
	content.add_child(cancel)
	return overlay


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_ready()
