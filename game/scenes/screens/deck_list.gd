extends Control

## My decks: one tile per player deck (faction, name, Leader, whether it can be played), and New deck,
## which asks for the Leader first. Tapping a deck opens the editor. See docs/functional/07-ui-ux.md.

const EDITOR_SCENE: String = "res://scenes/screens/deck_editor.tscn"


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 24)
	var slots: Label = MenuUI.label("", 26, Palette.TEXT_MUTED)
	slots.name = "SlotsLabel"
	slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slots.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	slots.text = tr("UI_DECK_SLOTS").format({"count": SaveManager.decks().size(), "max": DeckRules.MAX_DECKS})
	column.add_child(MenuUI.header("UI_MY_DECKS", slots))

	var new_deck: Button = MenuUI.button("UI_NEW_DECK", 104, 30)
	new_deck.name = "NewDeckButton"
	new_deck.theme_type_variation = &"ButtonPrimary"
	new_deck.disabled = SaveManager.decks().size() >= DeckRules.MAX_DECKS
	new_deck.pressed.connect(_choose_leader)
	column.add_child(new_deck)
	if new_deck.disabled:
		var full: Label = MenuUI.label("UI_DECKS_FULL", 24, Palette.TEXT_MUTED)
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(full)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "DeckTiles"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
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


## Modal: one tile per owned Leader; choosing one creates the empty deck and opens it.
func _choose_leader() -> void:
	var overlay := ColorRect.new()
	overlay.name = "LeaderPicker"
	overlay.color = Color(Palette.BG, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 860
	content.add_theme_constant_override("separation", 20)
	center.add_child(content)
	var title: Label = MenuUI.label("UI_CHOOSE_LEADER", 36, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	for leader_id: Variant in SaveManager.profile["leaders"]:
		var leader: LeaderData = CardDatabase.get_leader(StringName(str(leader_id)))
		if leader == null:
			continue
		var text: String = "%s\n%s" % [tr("LEADER_%s_NAME" % String(leader.id).to_upper()), MenuUI.faction_name(leader.faction)]
		var tile: Button = MenuUI.choice_tile(text, CardPalette.FACTIONS[leader.faction]["frame"], 130, "res://ui/icons/faction_%s.svg" % leader.faction)
		tile.name = "Leader_%s" % leader.id
		tile.toggle_mode = false
		tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tile.pressed.connect(func() -> void:
			var entry: Dictionary = SaveManager.create_deck(String(leader.id))
			overlay.queue_free()
			if not entry.is_empty():
				open_editor(str(entry["id"])))
		content.add_child(tile)
	var cancel: Button = MenuUI.button("UI_CANCEL")
	cancel.name = "CancelLeaderButton"
	cancel.pressed.connect(overlay.queue_free)
	content.add_child(cancel)
