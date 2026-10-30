class_name DeckEditor
extends Control

## Deck editor. Always in sight: the name (editable), the Leader and the deck's state (Ready, or what is
## missing). Two tabs: Cards (the Leader's faction and Neutral cards, filtered; a tap adds a copy, or
## says why it cannot) and Deck (Energy curve, types, the list — a tap removes a copy — then Duplicate
## and Delete). Every change is saved at once. See docs/functional/05-game-modes.md#deck-builder.

## The deck to edit (a player deck ID), set before opening the screen.
static var deck_id: String = ""

const CURVE_HEIGHT: int = 120

var _entry: Dictionary
var _leader: LeaderData
var _name_edit: LineEdit
var _status: Label
var _cards_tab: Button
var _deck_tab: Button
var _cards_page: VBoxContainer
var _deck_page: VBoxContainer
var _filter_bar: CardFilterBar
var _grid: CardGrid
var _curve: HBoxContainer
var _types: Label
var _list: VBoxContainer
var _actions: VBoxContainer


func _ready() -> void:
	_entry = SaveManager.find_deck(deck_id)
	_leader = CardDatabase.get_leader(StringName(str(_entry.get("leader", ""))))
	var column: VBoxContainer = MenuUI.screen_column(self, 18)
	column.add_child(MenuUI.header("UI_DECK_EDITOR"))
	if _entry.is_empty() or _leader == null:
		return

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 16)
	column.add_child(identity)
	var icon := TextureRect.new()
	icon.texture = load("res://ui/icons/faction_%s.svg" % _leader.faction) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = (CardPalette.FACTIONS[_leader.faction]["frame"] as Color).lightened(0.3)
	identity.add_child(icon)
	_name_edit = LineEdit.new()
	_name_edit.name = "DeckName"
	_name_edit.text = str(_entry.get("name", ""))
	_name_edit.placeholder_text = MenuUI.deck_name({"leader": _entry["leader"]})
	_name_edit.max_length = 32
	_name_edit.custom_minimum_size.y = 80
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 30)
	# Framed, so it reads as a field to type in.
	var field: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, Palette.BORDER, 3)
	_name_edit.add_theme_stylebox_override("normal", field)
	_name_edit.add_theme_stylebox_override("focus", MenuUI._tile_style(Palette.SURFACE_RAISED, Palette.ACCENT, 3))
	_name_edit.text_changed.connect(func(text: String) -> void:
		_entry["name"] = text.strip_edges()
		SaveManager.update_deck(_entry))
	identity.add_child(_name_edit)
	var leader_name: Label = MenuUI.label("LEADER_%s_NAME" % String(_leader.id).to_upper(), 28, Palette.TEXT_MUTED)
	leader_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(leader_name)

	_status = MenuUI.label("", 26)
	_status.name = "DeckStatus"
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	column.add_child(tabs)
	var tab_group := ButtonGroup.new()
	_cards_tab = _tab("CardsTab", tab_group, true)
	_cards_tab.text = tr("UI_TAB_CARDS")
	tabs.add_child(_cards_tab)
	_deck_tab = _tab("DeckTab", tab_group, false)
	tabs.add_child(_deck_tab)

	_cards_page = VBoxContainer.new()
	_cards_page.name = "CardsPage"
	_cards_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_page.add_theme_constant_override("separation", 18)
	column.add_child(_cards_page)
	var factions: Array[StringName] = [_leader.faction, &"neutral"]
	_filter_bar = CardFilterBar.new(factions, {"owned": "owned"})
	_filter_bar.changed.connect(_apply_filters)
	_cards_page.add_child(_filter_bar)
	_grid = CardGrid.new(get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN)
	_grid.card_tapped.connect(_on_card_tapped)
	_cards_page.add_child(_grid)
	var eligible: Array[StringName] = []
	for card_id: StringName in CardDatabase.card_ids():
		if DeckRules.eligible(CardDatabase.get_card(card_id), _leader):
			eligible.append(card_id)
	for data: CardData in CardGrid.sorted_cards(eligible, factions):
		_grid.add_card(data)

	_deck_page = VBoxContainer.new()
	_deck_page.name = "DeckPage"
	_deck_page.visible = false
	_deck_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_deck_page)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck_page.add_child(scroll)
	var deck_column := VBoxContainer.new()
	deck_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_column.add_theme_constant_override("separation", 18)
	scroll.add_child(deck_column)
	deck_column.add_child(MenuUI.label("UI_ENERGY_CURVE", 24, Palette.TEXT_MUTED))
	_curve = HBoxContainer.new()
	_curve.name = "EnergyCurve"
	_curve.add_theme_constant_override("separation", 12)
	deck_column.add_child(_curve)
	_types = MenuUI.label("", 24, Palette.TEXT_MUTED)
	_types.name = "TypeCounts"
	_types.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	deck_column.add_child(_types)
	var remove_hint: Label = MenuUI.label("UI_DECK_REMOVE_HINT", 22, Palette.TEXT_MUTED)
	remove_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deck_column.add_child(remove_hint)
	_list = VBoxContainer.new()
	_list.name = "DeckCards"
	_list.add_theme_constant_override("separation", 8)
	deck_column.add_child(_list)
	_actions = VBoxContainer.new()
	_actions.name = "DeckActions"
	_actions.add_theme_constant_override("separation", 16)
	deck_column.add_child(_actions)
	_show_actions()
	_refresh()


func _tab(node_name: String, group: ButtonGroup, pressed: bool) -> Button:
	var tab: Button = MenuUI.chip("", Palette.BORDER)
	tab.name = node_name
	tab.custom_minimum_size.y = 84
	tab.add_theme_font_size_override("font_size", 28)
	tab.button_group = group
	tab.button_pressed = pressed
	tab.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tab.pressed.connect(func() -> void:
		_cards_page.visible = _cards_tab.button_pressed
		_deck_page.visible = _deck_tab.button_pressed)
	return tab


func _cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id: Variant in _entry["cards"]:
		var card: CardData = CardDatabase.get_card(StringName(str(card_id)))
		if card != null:
			cards.append(card)
	return cards


## Status, tab count, the cards' captions, the curve, the types and the list.
func _refresh() -> void:
	var count: int = (_entry["cards"] as Array).size()
	var problems: Array[Dictionary] = DeckRules.problems(_entry, CardDatabase, SaveManager.owned_count)
	var ready: bool = problems.is_empty()
	var lines: PackedStringArray = []
	for problem: Dictionary in problems:
		lines.append(DeckRules.problem_text(problem))
	_status.text = tr("UI_DECK_READY") if ready else " · ".join(lines)
	_status.add_theme_color_override("font_color", Palette.ACCENT if ready else Palette.LIFE)
	_deck_tab.text = tr("UI_TAB_DECK").format({"count": count, "size": DeckRules.DECK_SIZE})
	for cell: Node in _grid.cells():
		var data: CardData = (cell.get_child(0) as CardView).card_data
		var owned: int = SaveManager.owned_count(data.id)
		var in_deck: int = DeckRules.count_of(_entry, data.id)
		var available: int = mini(owned, data.deck_limit())
		CardGrid.set_caption(cell, "%d / %d" % [in_deck, available], DeckRules.can_add(_entry, data, _leader, owned) or in_deck > 0)
	_apply_filters()

	var cards: Array[CardData] = _cards()
	var bars: Array[int] = DeckRules.curve(cards)
	var tallest: int = maxi(1, bars.max())
	for child: Node in _curve.get_children():
		child.queue_free()
	for cost: int in bars.size():
		var bar_column := VBoxContainer.new()
		bar_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_column.alignment = BoxContainer.ALIGNMENT_END
		bar_column.custom_minimum_size.y = CURVE_HEIGHT + 70
		var value: Label = MenuUI.label(str(bars[cost]), 22, Palette.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		bar_column.add_child(value)
		var bar := ColorRect.new()
		bar.color = Palette.ENERGY
		bar.custom_minimum_size.y = maxf(4.0, CURVE_HEIGHT * bars[cost] / float(tallest))
		bar_column.add_child(bar)
		var cost_label: Label = MenuUI.label("%d+" % cost if cost == bars.size() - 1 else str(cost), 22, Palette.TEXT_MUTED)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		bar_column.add_child(cost_label)
		_curve.add_child(bar_column)
	var types: Dictionary = DeckRules.type_counts(cards)
	_types.text = tr("UI_DECK_TYPES").format({"units": types["unit"], "spells": types["spell"], "artifacts": types["artifact"]})

	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if cards.is_empty():
		var hint: Label = MenuUI.label("UI_DECK_EMPTY", 24, Palette.TEXT_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(hint)
	var listed: Dictionary = {}
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.cost < b.cost if a.cost != b.cost else tr("CARD_%s_NAME" % String(a.id).to_upper()) < tr("CARD_%s_NAME" % String(b.id).to_upper()))
	for card: CardData in cards:
		if listed.has(card.id):
			continue
		listed[card.id] = true
		_list.add_child(_deck_row(card, DeckRules.count_of(_entry, card.id)))


## Cost, name, copies; a tap takes one copy out.
func _deck_row(card: CardData, copies: int) -> Button:
	var row: Button = MenuUI.button("", 76, 26)
	row.name = "Row_%s" % card.id
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.text = "%d   %s%s" % [card.cost, tr("CARD_%s_NAME" % String(card.id).to_upper()), "   × %d" % copies if copies > 1 else ""]
	row.icon = load("res://ui/icons/energy.svg") as Texture2D
	row.expand_icon = false
	row.add_theme_constant_override("icon_max_width", 28)
	row.add_theme_color_override("icon_normal_color", Palette.ENERGY)
	var colors: Dictionary = CardPalette.colors_for(card)
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, colors["frame"], 3)
	row.add_theme_stylebox_override("normal", style)
	row.pressed.connect(func() -> void: remove_card(card.id))
	return row


func add_card(card_id: StringName) -> bool:
	var data: CardData = CardDatabase.get_card(card_id)
	if data == null or not DeckRules.can_add(_entry, data, _leader, SaveManager.owned_count(card_id)):
		return false
	(_entry["cards"] as Array).append(String(card_id))
	SaveManager.update_deck(_entry)
	_refresh()
	return true


func remove_card(card_id: StringName) -> void:
	var cards: Array = _entry["cards"]
	var index: int = cards.rfind(String(card_id))
	if index < 0:
		return
	cards.remove_at(index)
	SaveManager.update_deck(_entry)
	_refresh()


## Adds a copy; when it cannot, shows the card large with the reason.
func _on_card_tapped(data: CardData) -> void:
	if add_card(data.id):
		return
	CardDetail.open(self, data, [why_not(data)])


func why_not(data: CardData) -> String:
	var owned: int = SaveManager.owned_count(data.id)
	var in_deck: int = DeckRules.count_of(_entry, data.id)
	if owned == 0:
		return tr("UI_CANNOT_ADD_NOT_OWNED")
	if in_deck >= data.deck_limit():
		return tr("UI_CANNOT_ADD_LIMIT").format({"max": data.deck_limit()})
	if in_deck >= owned:
		return tr("UI_CANNOT_ADD_OWNED").format({"owned": owned})
	return tr("UI_CANNOT_ADD_FULL").format({"size": DeckRules.DECK_SIZE})


func _apply_filters() -> void:
	var shown: int = _grid.show_only(func(data: CardData) -> bool:
		return _filter_bar.accepts(data, SaveManager.owned_count(data.id)))
	_filter_bar.count_label.text = tr("UI_SHOWN_COUNT").format({"count": shown})


## Duplicate and Delete; Delete asks first (Cancel highlighted).
func _show_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_actions.add_child(row)
	var duplicate: Button = MenuUI.button("UI_DUPLICATE")
	duplicate.name = "DuplicateButton"
	duplicate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duplicate.disabled = SaveManager.decks().size() >= DeckRules.MAX_DECKS
	duplicate.pressed.connect(_duplicate)
	row.add_child(duplicate)
	var delete: Button = MenuUI.button("UI_DELETE")
	delete.name = "DeleteButton"
	delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete.add_theme_color_override("font_color", Palette.LIFE)
	delete.pressed.connect(_confirm_delete)
	row.add_child(delete)


func _confirm_delete() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var question: Label = MenuUI.label("UI_DELETE_DECK_CONFIRM", 26)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions.add_child(question)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_actions.add_child(row)
	var cancel: Button = MenuUI.button("UI_CANCEL")
	cancel.name = "CancelDeleteButton"
	cancel.theme_type_variation = &"ButtonPrimary"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_show_actions)
	row.add_child(cancel)
	var confirm: Button = MenuUI.button("UI_DELETE")
	confirm.name = "ConfirmDeleteButton"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.add_theme_color_override("font_color", Palette.LIFE)
	confirm.pressed.connect(func() -> void:
		SaveManager.delete_deck(str(_entry["id"]))
		SceneRouter.go_back())
	row.add_child(confirm)


## The copy opens in place of this deck (Back still returns to the deck list).
func _duplicate() -> void:
	var copy: Dictionary = SaveManager.duplicate_deck(str(_entry["id"]), tr("UI_DECK_COPY_NAME").format({"name": MenuUI.deck_name(_entry)}))
	if copy.is_empty():
		return
	deck_id = str(copy["id"])
	SceneRouter.go_to("res://scenes/screens/deck_editor.tscn", false)
