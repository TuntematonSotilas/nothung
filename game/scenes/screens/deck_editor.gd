class_name DeckEditor
extends Control

## Deck editor, one screen. Top: the deck's name (its faction's, fixed), the Leader and the deck's state
## (Ready, or what is missing). Then the deck zone: "Deck n / 20" with a gauge, the types and one chip
## per card. Below: the Leader's faction and Neutral cards, filtered. No drag and drop: a tap on a card
## adds a copy (or shows the card with why it cannot be added); a tap on a chip takes a copy out. At the
## bottom: Auto-fill and Starter deck (both replace the deck, asking first when it is not empty), and
## Empty the deck (asks first). Every change is saved at once; leaving a deck that cannot be played
## (Back, or the Android back button) asks first in a popup. Under the name, the Leader's power in use
## and Change the Leader's power (the versions unlocked in Nibelheim).
## See docs/functional/05-game-modes.md#deck-builder.

## The deck to edit (a player deck ID), set before opening the screen.
static var deck_id: String = ""

const CHIPS_HEIGHT: int = 250

var _entry: Dictionary
var _leader: LeaderData
var _status: Label
var _zone: PanelContainer
var _zone_title: Label
var _gauge: ProgressBar
var _types: Label
var _chips_scroll: ScrollContainer
var _chips: HFlowContainer
var _filter_bar: CardFilterBar
var _grid: CardGrid
var _actions: VBoxContainer
var _power_label: Label


func _ready() -> void:
	_entry = SaveManager.find_deck(deck_id)
	_leader = CardDatabase.get_leader(StringName(str(_entry.get("leader", ""))))
	var column: VBoxContainer = MenuUI.screen_column(self, 16)
	column.add_child(MenuUI.header("UI_DECK_EDITOR"))
	if _entry.is_empty() or _leader == null:
		return
	column.add_child(_identity_row())
	if not _leader.powers.is_empty():
		column.add_child(_power_row())
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
	_grid.card_tapped.connect(_on_card_tapped)
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
	var deck_name: Label = MenuUI.label(MenuUI.deck_name(_entry), 32, Palette.TEXT)
	deck_name.name = "DeckName"
	deck_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	deck_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deck_name.clip_text = true
	identity.add_child(deck_name)
	var leader_name: Label = MenuUI.label("LEADER_%s_NAME" % String(_leader.id).to_upper(), 28, Palette.TEXT_MUTED)
	leader_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(leader_name)
	return identity


## The Leader's power in use ("Power: Wotans Zorn — Deal 3 damage to a unit. (3 Energy)") and the
## button that changes it.
func _power_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_power_label = MenuUI.label("", 22, Palette.TEXT_MUTED)
	_power_label.name = "LeaderPower"
	_power_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_power_label)
	var change: Button = MenuUI.button("UI_CHANGE_POWER", 72, 22)
	change.name = "ChangePowerButton"
	change.custom_minimum_size.x = 300
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	change.pressed.connect(open_power_picker)
	row.add_child(change)
	_update_power_label()
	return row


func _update_power_label() -> void:
	var index: int = LeaderPowers.of_entry(_entry)
	_power_label.text = tr("UI_LEADER_POWER").format({
		"power": LeaderPowers.title(_leader, index),
		"cost": _leader.with_power(index).ability.cost,
	})


## A popup listing the base ability and each power: the unlocked ones can be chosen, the others say
## where and from which level they are unlocked.
func open_power_picker() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "PowerPicker"
	overlay.color = Color(Palette.BG, 0.98)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN
	content.add_theme_constant_override("separation", 20)
	center.add_child(content)
	var title: Label = MenuUI.label("UI_CHANGE_POWER", 36, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var current: int = LeaderPowers.of_entry(_entry)
	for index: int in range(_leader.powers.size() + 1):
		var text: String = "%s\n%s" % [LeaderPowers.title(_leader, index), tr("UI_POWER_COST").format({"cost": _leader.with_power(index).ability.cost})]
		var unlocked: bool = LeaderPowers.is_unlocked(_leader.id, index)
		if not unlocked:
			text += " · " + tr("UI_POWER_LOCKED").format({"level": _leader.powers[index - 1].level})
		var tile: Button = MenuUI.choice_tile(text, CardPalette.FACTIONS[_leader.faction]["frame"], 130)
		tile.name = "Power_%d" % index
		tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tile.add_theme_font_size_override("font_size", 24)
		tile.button_pressed = index == current
		tile.disabled = not unlocked
		tile.pressed.connect(func() -> void:
			choose_power(index)
			overlay.queue_free())
		content.add_child(tile)
	var cancel: Button = MenuUI.button("UI_CANCEL")
	cancel.name = "CancelPowerButton"
	cancel.pressed.connect(overlay.queue_free)
	content.add_child(cancel)
	return overlay


## Saves the Leader's power this deck plays with; an index not unlocked is refused.
func choose_power(index: int) -> bool:
	if not LeaderPowers.is_unlocked(_leader.id, index) or index > _leader.powers.size():
		return false
	_entry["power"] = index
	SaveManager.update_deck(_entry)
	_update_power_label()
	return true


## "Deck n / 20" and its gauge, the types, then the chips (or how to add cards).
func _deck_zone() -> PanelContainer:
	_zone = PanelContainer.new()
	_zone.name = "DeckZone"
	var frame: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, Palette.BORDER, 3)
	frame.set_content_margin_all(16)
	_zone.add_theme_stylebox_override("panel", frame)
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
	_gauge = ProgressBar.new()
	_gauge.name = "DeckGauge"
	_gauge.max_value = DeckRules.DECK_SIZE
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(360, 22)
	_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.SURFACE_RAISED
	track.set_corner_radius_all(11)
	_gauge.add_theme_stylebox_override("background", track)
	top.add_child(_gauge)
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


func _cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id: Variant in _entry["cards"]:
		var card: CardData = CardDatabase.get_card(StringName(str(card_id)))
		if card != null:
			cards.append(card)
	return cards


## Status, deck zone (count, gauge, types, chips) and the cards' captions.
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
	_gauge.value = count
	# Energy blue while filling, gold once complete.
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.ACCENT if count == DeckRules.DECK_SIZE else Palette.ENERGY
	fill.set_corner_radius_all(11)
	_gauge.add_theme_stylebox_override("fill", fill)
	for cell: Node in _grid.cells():
		var data: CardData = (cell.get_child(0) as CardView).card_data
		var owned: int = SaveManager.owned_count(data.id)
		var in_deck: int = DeckRules.count_of(_entry, data.id)
		CardGrid.set_caption(cell, "%d / %d" % [in_deck, mini(owned, data.deck_limit())], DeckRules.can_add(_entry, data, _leader, owned) or in_deck > 0)
	_apply_filters()

	var cards: Array[CardData] = _cards()
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


## Cost, name, copies, framed in the card's colour. A long press shows the card, a sideways swipe
## takes one copy out; a tap does nothing (the chips still scroll).
func _chip(card: CardData, copies: int) -> Button:
	var chip: Button = MenuUI.button("", 64, 22)
	chip.name = "Chip_%s" % card.id
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.focus_mode = Control.FOCUS_NONE
	chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	chip.text = "%d · %s%s" % [card.cost, tr("CARD_%s_NAME" % String(card.id).to_upper()), "  × %d" % copies if copies > 1 else ""]
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE_RAISED, CardPalette.colors_for(card)["frame"], 3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	for state: String in ["normal", "hover", "pressed"]:
		chip.add_theme_stylebox_override(state, style)
	var gesture: SwipeChip = SwipeChip.attach(chip)
	gesture.name = "Gesture"
	gesture.long_pressed.connect(show_chip_card.bind(card))
	gesture.swiped.connect(_swipe_out.bind(chip, card.id))
	return chip


## Long press on a chip: the card, large, with the copies in the deck and how to take one out.
func show_chip_card(card: CardData) -> void:
	var owned: int = SaveManager.owned_count(card.id)
	CardDetail.open(self, card, [
		tr("UI_IN_DECK_COPIES").format({"count": DeckRules.count_of(_entry, card.id), "max": mini(owned, card.deck_limit())}),
		tr("UI_SWIPE_TO_REMOVE"),
	])


## Swipe on a chip: it slides out and fades, then a copy leaves the deck.
func _swipe_out(chip: Button, card_id: StringName) -> void:
	if Settings.animation_speed <= 0.0:
		remove_card(card_id)
		return
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = chip.create_tween().set_parallel()
	tween.tween_property(chip, "position:x", chip.position.x + 240.0, 0.18 / Settings.animation_speed)
	tween.tween_property(chip, "modulate:a", 0.0, 0.18 / Settings.animation_speed)
	tween.chain().tween_callback(remove_card.bind(card_id))


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


## A tap adds a copy; when it cannot, the card shows why.
func _on_card_tapped(data: CardData) -> void:
	if not add_card(data.id):
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


## The filters, and no card whose available copies are all in the deck already (nothing to add).
func _apply_filters() -> void:
	var shown: int = _grid.show_only(func(data: CardData) -> bool:
		var owned: int = SaveManager.owned_count(data.id)
		if owned > 0 and DeckRules.count_of(_entry, data.id) >= mini(owned, data.deck_limit()):
			return false
		return _filter_bar.accepts(data, owned))
	_filter_bar.count_label.text = tr("UI_SHOWN_COUNT").format({"count": shown})


## Auto-fill and Starter deck; replacing a non-empty deck asks first.
func _show_actions() -> void:
	_clear(_actions)
	var fill_row := HBoxContainer.new()
	fill_row.add_theme_constant_override("separation", 16)
	_actions.add_child(fill_row)
	var auto_fill: Button = MenuUI.button("UI_AUTO_FILL", 72, 26)
	auto_fill.name = "AutoFillButton"
	auto_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_fill.pressed.connect(_replace_cards.bind(func() -> Array[String]:
		return DeckRules.auto_fill(_leader, CardDatabase, SaveManager.owned_count)))
	fill_row.add_child(auto_fill)
	if starter_cards().size() > 0:
		var starter: Button = MenuUI.button("UI_STARTER_DECK", 72, 26)
		starter.name = "StarterDeckButton"
		starter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		starter.pressed.connect(_replace_cards.bind(starter_cards))
		fill_row.add_child(starter)
	if not (_entry["cards"] as Array).is_empty():
		var clear: Button = MenuUI.button("UI_CLEAR_DECK", 72, 26)
		clear.name = "ClearDeckButton"
		clear.add_theme_color_override("font_color", Palette.LIFE)
		clear.pressed.connect(_confirm.bind("UI_CLEAR_DECK_CONFIRM", "UI_CLEAR", clear_deck))
		_actions.add_child(clear)


## Takes every card out of the deck.
func clear_deck() -> void:
	(_entry["cards"] as Array).clear()
	SaveManager.update_deck(_entry)
	_show_actions()
	_refresh()


## Back (header button or Android): a deck that cannot be played asks first; true when handled here.
func handle_back() -> bool:
	if _entry.is_empty() or has_node("LeavePrompt"):
		return has_node("LeavePrompt")
	if DeckRules.problems(_entry, CardDatabase, SaveManager.owned_count).is_empty():
		return false
	_show_leave_prompt()
	return true


## Popup: the deck is not complete. Keep editing (highlighted) or leave anyway (red).
func _show_leave_prompt() -> void:
	var overlay := ColorRect.new()
	overlay.name = "LeavePrompt"
	overlay.color = Color(Palette.BG, 0.9)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 820
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, Palette.ACCENT, 3)
	style.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	panel.add_child(content)
	var title: Label = MenuUI.label("UI_DECK_INCOMPLETE_TITLE", 40, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var problems: Label = MenuUI.label(_status.text, 28, Palette.LIFE)
	problems.name = "LeaveProblems"
	problems.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	problems.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(problems)
	var text: Label = MenuUI.label("UI_DECK_INCOMPLETE_TEXT", 28)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text)
	var keep: Button = MenuUI.button("UI_KEEP_EDITING")
	keep.name = "KeepEditingButton"
	keep.theme_type_variation = &"ButtonPrimary"
	keep.pressed.connect(overlay.queue_free)
	content.add_child(keep)
	var leave: Button = MenuUI.button("UI_LEAVE")
	leave.name = "LeaveAnywayButton"
	leave.add_theme_color_override("font_color", Palette.LIFE)
	leave.pressed.connect(func() -> void:
		overlay.queue_free()
		SceneRouter.go_back())
	content.add_child(leave)


## Replaces the deck with `cards_source.call()`; asks first when the deck already has cards.
func _replace_cards(cards_source: Callable) -> void:
	var replace: Callable = func() -> void:
		_entry["cards"] = cards_source.call()
		SaveManager.update_deck(_entry)
		_show_actions()
		_refresh()
	if (_entry["cards"] as Array).is_empty():
		replace.call()
	else:
		_confirm("UI_REPLACE_DECK_CONFIRM", "UI_REPLACE", replace)


## The starter deck of this deck's Leader, as card IDs (only the copies owned); empty when none.
func starter_cards() -> Array[String]:
	var cards: Array[String] = []
	for deck_id: StringName in CardDatabase.deck_ids():
		var deck: DeckData = CardDatabase.get_deck(deck_id)
		if not String(deck_id).ends_with("_starter") or deck.leader.id != _leader.id:
			continue
		for card: CardData in deck.cards:
			if cards.count(String(card.id)) < SaveManager.owned_count(card.id):
				cards.append(String(card.id))
		break
	return cards


## Inline question in place of the actions: Cancel (highlighted) or the confirming button.
func _confirm(question_key: String, confirm_key: String, action: Callable) -> void:
	_clear(_actions)
	var question: Label = MenuUI.label(question_key, 26)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_actions.add_child(question)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_actions.add_child(row)
	var cancel: Button = MenuUI.button("UI_CANCEL", 72, 26)
	cancel.name = "CancelButton"
	cancel.theme_type_variation = &"ButtonPrimary"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_show_actions)
	row.add_child(cancel)
	var confirm: Button = MenuUI.button(confirm_key, 72, 26)
	confirm.name = "ConfirmButton"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.add_theme_color_override("font_color", Palette.LIFE)
	confirm.pressed.connect(action)
	row.add_child(confirm)


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
