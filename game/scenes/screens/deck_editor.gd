class_name DeckEditor
extends Control

## Deck editor, one screen. Top: the name (editable), the Leader and the deck's state (Ready, or what is
## missing). Then the deck zone: "Deck n / 20", a small Energy curve, the types and one chip per card.
## Below: the Leader's faction and Neutral cards, filtered. Pick a card up (hold it with a finger, or just
## drag it with a mouse) and drop it on the deck zone to add it; drag a chip out of the zone (or tap it) to take a copy out; tap a card to see it with
## Add (or why it cannot be added). Duplicate and Delete at the bottom. Every change is saved at once.
## See docs/functional/05-game-modes.md#deck-builder.

## The deck to edit (a player deck ID), set before opening the screen.
static var deck_id: String = ""

const CURVE_HEIGHT: int = 44
const CHIPS_HEIGHT: int = 250
const GHOST_SCALE: float = 1.2

var _entry: Dictionary
var _leader: LeaderData
var _name_edit: LineEdit
var _status: Label
var _zone: PanelContainer
var _zone_title: Label
var _curve: HBoxContainer
var _types: Label
var _chips_scroll: ScrollContainer
var _chips: HFlowContainer
var _filter_bar: CardFilterBar
var _grid: CardGrid
var _actions: VBoxContainer
## The card being carried: {data, from_deck}, and its picture under the finger.
var _carried: Dictionary = {}
var _ghost: Control
var _ghost_layer: CanvasLayer


func _ready() -> void:
	_entry = SaveManager.find_deck(deck_id)
	_leader = CardDatabase.get_leader(StringName(str(_entry.get("leader", ""))))
	var column: VBoxContainer = MenuUI.screen_column(self, 16)
	column.add_child(MenuUI.header("UI_DECK_EDITOR"))
	if _entry.is_empty() or _leader == null:
		return
	column.add_child(_identity_row())
	_status = MenuUI.label("", 24)
	_status.name = "DeckStatus"
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	column.add_child(_deck_zone())

	var factions: Array[StringName] = [_leader.faction, &"neutral"]
	_filter_bar = CardFilterBar.new(factions, {"owned": "owned"})
	_filter_bar.changed.connect(_apply_filters)
	column.add_child(_filter_bar)
	_grid = CardGrid.new(get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN)
	_grid.pick_enabled = true
	_grid.card_tapped.connect(_show_card)
	_grid.card_picked.connect(func(data: CardData) -> void: _begin_drag(data, false))
	_grid.card_released.connect(func(_data: CardData, position: Vector2) -> void: drop_at(position))
	column.add_child(_grid)
	var eligible: Array[StringName] = []
	for card_id: StringName in CardDatabase.card_ids():
		if DeckRules.eligible(CardDatabase.get_card(card_id), _leader):
			eligible.append(card_id)
	for data: CardData in CardGrid.sorted_cards(eligible, factions):
		_grid.add_card(data)

	_actions = VBoxContainer.new()
	_actions.name = "DeckActions"
	_actions.add_theme_constant_override("separation", 12)
	column.add_child(_actions)
	_show_actions()
	_ghost_layer = CanvasLayer.new()
	_ghost_layer.layer = 20
	add_child(_ghost_layer)
	_refresh()


func _identity_row() -> HBoxContainer:
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 16)
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
	_name_edit.custom_minimum_size.y = 76
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 30)
	# Framed, so it reads as a field to type in.
	_name_edit.add_theme_stylebox_override("normal", MenuUI._tile_style(Palette.SURFACE, Palette.BORDER, 3))
	_name_edit.add_theme_stylebox_override("focus", MenuUI._tile_style(Palette.SURFACE_RAISED, Palette.ACCENT, 3))
	_name_edit.text_changed.connect(func(text: String) -> void:
		_entry["name"] = text.strip_edges()
		SaveManager.update_deck(_entry))
	identity.add_child(_name_edit)
	var leader_name: Label = MenuUI.label("LEADER_%s_NAME" % String(_leader.id).to_upper(), 28, Palette.TEXT_MUTED)
	leader_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(leader_name)
	return identity


## "Deck n / 20" and the small curve, the types, then the chips (or how to add cards).
func _deck_zone() -> PanelContainer:
	_zone = PanelContainer.new()
	_zone.name = "DeckZone"
	_set_zone_highlight(false)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_zone.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	_zone_title = MenuUI.label("", 30, Palette.ACCENT)
	_zone_title.name = "DeckCount"
	_zone_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_zone_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_title.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_zone_title)
	_curve = HBoxContainer.new()
	_curve.name = "EnergyCurve"
	_curve.add_theme_constant_override("separation", 6)
	top.add_child(_curve)
	_types = MenuUI.label("", 22, Palette.TEXT_MUTED)
	_types.name = "TypeCounts"
	_types.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_types)
	_chips_scroll = ScrollContainer.new()
	_chips_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chips_scroll.custom_minimum_size.y = CHIPS_HEIGHT
	content.add_child(_chips_scroll)
	_chips = HFlowContainer.new()
	_chips.name = "DeckCards"
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chips.add_theme_constant_override("h_separation", 8)
	_chips.add_theme_constant_override("v_separation", 8)
	_chips_scroll.add_child(_chips)
	return _zone


## Gold border while a card from the grid is carried over the zone.
func _set_zone_highlight(on: bool) -> void:
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE_RAISED if on else Palette.SURFACE, Palette.ACCENT if on else Palette.BORDER, 4 if on else 3)
	style.set_content_margin_all(16)
	_zone.add_theme_stylebox_override("panel", style)


func _cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id: Variant in _entry["cards"]:
		var card: CardData = CardDatabase.get_card(StringName(str(card_id)))
		if card != null:
			cards.append(card)
	return cards


## Status, deck zone (count, curve, types, chips) and the cards' captions.
func _refresh() -> void:
	var count: int = (_entry["cards"] as Array).size()
	var problems: Array[Dictionary] = DeckRules.problems(_entry, CardDatabase, SaveManager.owned_count)
	var ready: bool = problems.is_empty()
	var lines: PackedStringArray = []
	for problem: Dictionary in problems:
		lines.append(DeckRules.problem_text(problem))
	_status.text = tr("UI_DECK_READY") if ready else " · ".join(lines)
	_status.add_theme_color_override("font_color", Palette.ACCENT if ready else Palette.LIFE)
	_zone_title.text = tr("UI_DECK_COUNT").format({"count": count, "size": DeckRules.DECK_SIZE})
	for cell: Node in _grid.cells():
		var data: CardData = (cell.get_child(0) as CardView).card_data
		var owned: int = SaveManager.owned_count(data.id)
		var in_deck: int = DeckRules.count_of(_entry, data.id)
		CardGrid.set_caption(cell, "%d / %d" % [in_deck, mini(owned, data.deck_limit())], DeckRules.can_add(_entry, data, _leader, owned) or in_deck > 0)
	_apply_filters()

	var cards: Array[CardData] = _cards()
	_draw_curve(DeckRules.curve(cards))
	var types: Dictionary = DeckRules.type_counts(cards)
	_types.text = tr("UI_DECK_TYPES").format({"units": types["unit"], "spells": types["spell"], "artifacts": types["artifact"]})
	for child: Node in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	if cards.is_empty():
		var hint: Label = MenuUI.label("UI_DECK_DROP_HINT", 24, Palette.TEXT_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_chips.add_child(hint)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.cost < b.cost if a.cost != b.cost else tr("CARD_%s_NAME" % String(a.id).to_upper()) < tr("CARD_%s_NAME" % String(b.id).to_upper()))
	var listed: Dictionary = {}
	for card: CardData in cards:
		if not listed.has(card.id):
			listed[card.id] = true
			_chips.add_child(_chip(card, DeckRules.count_of(_entry, card.id)))


## Seven small bars (0 … 6+), labelled by cost.
func _draw_curve(bars: Array[int]) -> void:
	for child: Node in _curve.get_children():
		child.queue_free()
	var tallest: int = maxi(1, bars.max())
	for cost: int in bars.size():
		var bar_column := VBoxContainer.new()
		bar_column.alignment = BoxContainer.ALIGNMENT_END
		bar_column.custom_minimum_size = Vector2(30, CURVE_HEIGHT + 24)
		bar_column.add_theme_constant_override("separation", 2)
		var bar := ColorRect.new()
		bar.color = Palette.ENERGY
		bar.custom_minimum_size.y = maxf(3.0, CURVE_HEIGHT * bars[cost] / float(tallest))
		bar.tooltip_text = str(bars[cost])
		bar_column.add_child(bar)
		var cost_label: Label = MenuUI.label("%d+" % cost if cost == bars.size() - 1 else str(cost), 16, Palette.TEXT_MUTED)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		bar_column.add_child(cost_label)
		_curve.add_child(bar_column)


## Cost, name, copies, framed in the card's colour. Tap: one copy out; long press: carry it out.
func _chip(card: CardData, copies: int) -> Button:
	var chip: Button = MenuUI.button("", 64, 22)
	chip.name = "Chip_%s" % card.id
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	chip.text = "%d · %s%s" % [card.cost, tr("CARD_%s_NAME" % String(card.id).to_upper()), "  × %d" % copies if copies > 1 else ""]
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE_RAISED, CardPalette.colors_for(card)["frame"], 3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	for state: String in ["normal", "hover", "pressed"]:
		chip.add_theme_stylebox_override(state, style)
	var press: PressPick = PressPick.attach(chip, _chips_scroll)
	press.tapped.connect(remove_card.bind(card.id))
	press.picked.connect(_begin_drag.bind(card, true))
	press.released.connect(drop_at)
	return chip


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


## Picks a card up: its picture follows the finger until drop_at().
func _begin_drag(data: CardData, from_deck: bool) -> void:
	_carried = {"data": data, "from_deck": from_deck}
	var view := CardView.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_view_scale(GHOST_SCALE)
	view.set_card(data, null, false, -1, "hand", false)
	view.modulate = Color(1, 1, 1, 0.9)
	_ghost = view
	_ghost_layer.add_child(view)
	_move_ghost(PressPick.pointer)


func _input(event: InputEvent) -> void:
	if _ghost != null and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		_move_ghost(event.position)


func _move_ghost(position: Vector2) -> void:
	if _ghost == null:
		return
	_ghost.position = position - CardView.CARD_SIZE * GHOST_SCALE * Vector2(0.5, 0.9)
	_set_zone_highlight(not _carried["from_deck"] and _zone.get_global_rect().has_point(position))


## Ends a carry: a grid card dropped on the deck zone is added (or says why not); a deck card dropped
## outside the zone is taken out.
func drop_at(position: Vector2) -> void:
	if _carried.is_empty():
		return
	var data: CardData = _carried["data"]
	var on_zone: bool = _zone.get_global_rect().has_point(position)
	var from_deck: bool = _carried["from_deck"]
	_carried = {}
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_set_zone_highlight(false)
	if from_deck and not on_zone:
		remove_card(data.id)
	elif not from_deck and on_zone and not add_card(data.id):
		CardDetail.open(self, data, [why_not(data)])


## The card large: Add when it can be added, otherwise why not.
func _show_card(data: CardData) -> void:
	var can_add: bool = DeckRules.can_add(_entry, data, _leader, SaveManager.owned_count(data.id))
	var lines: Array[String] = [tr("UI_IN_DECK").format({"count": DeckRules.count_of(_entry, data.id)})]
	if not can_add:
		lines.append(why_not(data))
	CardDetail.open(self, data, lines, [{
		"text": "UI_ADD", "name": "AddButton", "primary": true, "disabled": not can_add,
		"action": func() -> void: add_card(data.id),
	}])


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
	_clear(_actions)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_actions.add_child(row)
	var duplicate: Button = MenuUI.button("UI_DUPLICATE", 72, 26)
	duplicate.name = "DuplicateButton"
	duplicate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duplicate.disabled = SaveManager.decks().size() >= DeckRules.MAX_DECKS
	duplicate.pressed.connect(_duplicate)
	row.add_child(duplicate)
	var delete: Button = MenuUI.button("UI_DELETE", 72, 26)
	delete.name = "DeleteButton"
	delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete.add_theme_color_override("font_color", Palette.LIFE)
	delete.pressed.connect(_confirm_delete)
	row.add_child(delete)


func _confirm_delete() -> void:
	_clear(_actions)
	var question: Label = MenuUI.label("UI_DELETE_DECK_CONFIRM", 26)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions.add_child(question)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_actions.add_child(row)
	var cancel: Button = MenuUI.button("UI_CANCEL", 72, 26)
	cancel.name = "CancelDeleteButton"
	cancel.theme_type_variation = &"ButtonPrimary"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_show_actions)
	row.add_child(cancel)
	var confirm: Button = MenuUI.button("UI_DELETE", 72, 26)
	confirm.name = "ConfirmDeleteButton"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.add_theme_color_override("font_color", Palette.LIFE)
	confirm.pressed.connect(func() -> void:
		SaveManager.delete_deck(str(_entry["id"]))
		SceneRouter.go_back())
	row.add_child(confirm)


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


## The copy opens in place of this deck (Back still returns to the deck list).
func _duplicate() -> void:
	var copy: Dictionary = SaveManager.duplicate_deck(str(_entry["id"]), tr("UI_DECK_COPY_NAME").format({"name": MenuUI.deck_name(_entry)}))
	if copy.is_empty():
		return
	deck_id = str(copy["id"])
	SceneRouter.go_to("res://scenes/screens/deck_editor.tscn", false)
