extends Control

## Collection: every card with the copies the player owns, filtered by faction (always shown) and by
## cost, type, rarity, trait and owned / missing (behind the Filters button). Tap a card to see it
## large. See docs/functional/05-game-modes.md#deck-builder.

const COLUMNS: int = 3
const CARD_GAP: int = 20
const FACTIONS: Array[StringName] = [&"gods", &"nibelungs", &"walsungs", &"valkyries", &"neutral"]
## The last cost chip groups every card costing this much or more.
const MAX_COST_CHIP: int = 6
const TYPES: Array[String] = ["unit", "spell", "artifact", "relic"]
const RARITIES: Array[CardData.Rarity] = [CardData.Rarity.COMMON, CardData.Rarity.RARE, CardData.Rarity.EPIC, CardData.Rarity.LEGENDARY]
const TRAITS: Array[StringName] = [&"flying", &"guard", &"charge", &"valhalla", &"invisible"]
const OWNERSHIP: Array[String] = ["owned", "missing"]
## A press that scrolled the grid is a scroll, not a tap.
const TAP_SCROLL_TOLERANCE: int = 12

## Active filter per group; null = all.
var _filters: Dictionary = {"faction": null, "cost": null, "type": null, "rarity": null, "trait": null, "owned": null}
## [{data, cell}] in display order.
var _cells: Array[Dictionary] = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _filter_panel: VBoxContainer
var _filters_button: Button
var _count_label: Label
var _scroll_at_press: int = 0


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 20)
	column.add_child(MenuUI.header("UI_COLLECTION", _rhinegold_counter()))
	column.add_child(_chip_row("faction", [null] + FACTIONS, func(faction: Variant) -> Dictionary:
		if faction == null:
			return {"text": "UI_ALL"}
		return {"icon": "res://ui/icons/faction_%s.svg" % faction, "color": CardPalette.FACTIONS[faction]["frame"], "tooltip": MenuUI.faction_name(faction)}))

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 20)
	column.add_child(tools)
	_filters_button = MenuUI.button("UI_FILTERS", 72, 26)
	_filters_button.name = "FiltersButton"
	_filters_button.toggle_mode = true
	_filters_button.custom_minimum_size.x = 260
	_filters_button.toggled.connect(func(shown: bool) -> void: _filter_panel.visible = shown)
	tools.add_child(_filters_button)
	_count_label = MenuUI.label("", 24, Palette.TEXT_MUTED)
	_count_label.name = "CountLabel"
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tools.add_child(_count_label)

	_filter_panel = VBoxContainer.new()
	_filter_panel.name = "FilterPanel"
	_filter_panel.visible = false
	_filter_panel.add_theme_constant_override("separation", 12)
	column.add_child(_filter_panel)
	var costs: Array = [null]
	for cost: int in MAX_COST_CHIP + 1:
		costs.append(cost)
	_filter_panel.add_child(_chip_row("cost", costs, func(cost: Variant) -> Dictionary:
		if cost == null:
			return {"text": "UI_ALL"}
		return {"text": "%d+" % cost if cost == MAX_COST_CHIP else str(cost), "raw": true}))
	_filter_panel.add_child(_chip_row("type", [null] + TYPES, func(type_id: Variant) -> Dictionary:
		return {"text": "UI_ALL" if type_id == null else "UI_TYPE_%s" % String(type_id).to_upper()}))
	_filter_panel.add_child(_chip_row("rarity", [null] + RARITIES, func(rarity: Variant) -> Dictionary:
		if rarity == null:
			return {"text": "UI_ALL"}
		return {"text": "UI_RARITY_%s" % String(CardData.Rarity.keys()[rarity]), "color": CardPalette.rarity_color(rarity)}))
	_filter_panel.add_child(_chip_row("trait", [null] + TRAITS, func(trait_id: Variant) -> Dictionary:
		return {"text": "UI_ALL" if trait_id == null else "UI_TRAIT_%s" % String(trait_id).to_upper()}))
	_filter_panel.add_child(_chip_row("owned", [null] + OWNERSHIP, func(owned: Variant) -> Dictionary:
		return {"text": "UI_ALL" if owned == null else "UI_%s" % String(owned).to_upper()}))

	_scroll = ScrollContainer.new()
	_scroll.name = "CardScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	_scroll.add_child(_grid)
	_build_cells()
	_apply_filters()


## Every card, by faction, then cost, then name.
func _build_cells() -> void:
	var cards: Array[CardData] = []
	for card_id: StringName in CardDatabase.card_ids():
		cards.append(CardDatabase.get_card(card_id))
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		var faction_a: int = FACTIONS.find(a.faction)
		var faction_b: int = FACTIONS.find(b.faction)
		if faction_a != faction_b:
			return faction_a < faction_b
		if a.cost != b.cost:
			return a.cost < b.cost
		return _card_name(a) < _card_name(b))
	var width: float = (get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN - (COLUMNS - 1) * CARD_GAP) / float(COLUMNS)
	var card_scale: float = width / CardView.CARD_SIZE.x
	for data: CardData in cards:
		var cell := VBoxContainer.new()
		cell.name = "Card_%s" % data.id
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_theme_constant_override("separation", 6)
		var view := CardView.new()
		view.mouse_filter = Control.MOUSE_FILTER_PASS
		view.set_view_scale(card_scale)
		view.set_card(data, null, false, -1, "hand", false)
		view.button_down.connect(func() -> void: _scroll_at_press = _scroll.scroll_vertical)
		view.pressed.connect(func() -> void:
			if absi(_scroll.scroll_vertical - _scroll_at_press) <= TAP_SCROLL_TOLERANCE:
				_show_detail(data))
		cell.add_child(view)
		var owned: int = SaveManager.owned_count(data.id)
		var count: Label = MenuUI.label("UI_NOT_OWNED" if owned == 0 else "× %d" % owned, 24, Palette.TEXT_MUTED if owned == 0 else Palette.ACCENT)
		count.name = "Owned"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if owned > 0:
			count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		cell.add_child(count)
		# Cards not owned are shown faded.
		view.modulate = Color(1, 1, 1, 1.0 if owned > 0 else 0.4)
		_grid.add_child(cell)
		_cells.append({"data": data, "cell": cell})


func _apply_filters() -> void:
	var shown: int = 0
	var owned_shown: int = 0
	for entry: Dictionary in _cells:
		var data: CardData = entry["data"]
		var visible_now: bool = matches(data, _filters, SaveManager.owned_count(data.id))
		(entry["cell"] as Control).visible = visible_now
		if visible_now:
			shown += 1
			if SaveManager.owned_count(data.id) > 0:
				owned_shown += 1
	_count_label.text = tr("UI_COLLECTION_COUNT").format({"owned": owned_shown, "total": shown})
	var active: int = 0
	for group: String in _filters:
		if group != "faction" and _filters[group] != null:
			active += 1
	_filters_button.text = tr("UI_FILTERS") + (" (%d)" % active if active > 0 else "")
	_scroll.scroll_vertical = 0


## Whether a card passes every active filter (null = no filter for that group).
static func matches(data: CardData, filters: Dictionary, owned: int) -> bool:
	if filters["faction"] != null and data.faction != filters["faction"]:
		return false
	if filters["cost"] != null:
		var cost: int = filters["cost"]
		if (cost == MAX_COST_CHIP and data.cost < cost) or (cost < MAX_COST_CHIP and data.cost != cost):
			return false
	if filters["type"] != null and CardView.type_id_of(data) != filters["type"]:
		return false
	if filters["rarity"] != null and data.rarity != filters["rarity"]:
		return false
	if filters["trait"] != null and not (data.keywords.has(filters["trait"]) or data.relic_keywords.has(filters["trait"])):
		return false
	if filters["owned"] == "owned" and owned == 0:
		return false
	if filters["owned"] == "missing" and owned > 0:
		return false
	return true


## One chip per value, exactly one pressed (the first: "All").
## `describe(value)` gives {text, raw (not a translation key), icon, color, tooltip}.
func _chip_row(group: String, values: Array, describe: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sChips" % group.capitalize()
	row.add_theme_constant_override("separation", 10)
	var buttons := ButtonGroup.new()
	for value: Variant in values:
		var look: Dictionary = describe.call(value)
		var chip: Button = MenuUI.chip(look.get("text", ""), look.get("color", Palette.BORDER), look.get("icon", ""))
		chip.name = "%s_%s" % [group, "all" if value == null else str(value)]
		chip.button_group = buttons
		chip.button_pressed = value == null
		chip.tooltip_text = look.get("tooltip", "")
		if look.get("raw", false):
			chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.pressed.connect(func() -> void:
			_filters[group] = value
			_apply_filters())
		row.add_child(chip)
	return row


func _rhinegold_counter() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var value: Label = MenuUI.label(str(SaveManager.rhinegold()), 34, Palette.ACCENT)
	value.name = "RhinegoldValue"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(value)
	var caption: Label = MenuUI.label("UI_RHINEGOLD", 18, Palette.TEXT_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(caption)
	return box


## The card large, its flavour and the copies owned; closed by tapping anywhere.
func _show_detail(data: CardData) -> void:
	var overlay := ColorRect.new()
	overlay.name = "CardDetail"
	overlay.color = Color(Palette.BG, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.is_pressed():
			overlay.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 24)
	center.add_child(content)
	var view := CardView.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_view_scale(2.6)
	view.set_card(data, null, false, -1, "hand", false)
	content.add_child(view)
	var flavour_key: String = "CARD_%s_FLAVOUR" % String(data.id).to_upper()
	if tr(flavour_key) != flavour_key:
		var flavour: Label = MenuUI.label(flavour_key, 26, Palette.TEXT_MUTED)
		flavour.custom_minimum_size.x = view.custom_minimum_size.x
		flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(flavour)
	var owned: Label = MenuUI.label("", 28, Palette.ACCENT)
	owned.name = "OwnedCopies"
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.text = tr("UI_OWNED_COPIES").format({"count": SaveManager.owned_count(data.id), "max": data.deck_limit()})
	content.add_child(owned)


func _card_name(data: CardData) -> String:
	return tr("CARD_%s_NAME" % String(data.id).to_upper())
