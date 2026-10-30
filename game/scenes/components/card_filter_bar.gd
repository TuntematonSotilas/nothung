class_name CardFilterBar
extends VBoxContainer

## Card filters shared by the Collection and the deck editor: faction chips (always shown), then a
## Filters button with the number of active filters and a count label, unfolding captioned chip rows
## for cost, type, rarity, trait and owned / missing. One chip per row is pressed, "All" first.

signal changed

## The last cost chip groups every card costing this much or more.
const MAX_COST_CHIP: int = 6
const TYPES: Array[String] = ["unit", "spell", "artifact", "relic"]
const RARITIES: Array[CardData.Rarity] = [CardData.Rarity.COMMON, CardData.Rarity.RARE, CardData.Rarity.EPIC, CardData.Rarity.LEGENDARY]
const TRAITS: Array[StringName] = [&"flying", &"guard", &"charge", &"valhalla", &"invisible"]
const OWNERSHIP: Array[String] = ["owned", "missing"]
## Width of the caption on the left of each filter row, so the chips line up.
const CAPTION_WIDTH: int = 160

## Active filter per group; null = all.
var filters: Dictionary = {"faction": null, "cost": null, "type": null, "rarity": null, "trait": null, "owned": null}
## Right of the Filters button; the screen writes what it counts.
var count_label: Label
var _filter_panel: VBoxContainer
var _filters_button: Button


## `factions` are the faction chips after "All"; `initial` presets filters (e.g. {"owned": "owned"}).
func _init(factions: Array[StringName], initial: Dictionary = {}) -> void:
	name = "CardFilterBar"
	add_theme_constant_override("separation", 20)
	filters.merge(initial, true)
	add_child(_chip_row("faction", [null] + factions, func(faction: Variant) -> Dictionary:
		if faction == null:
			return {"text": "UI_ALL"}
		return {"icon": "res://ui/icons/faction_%s.svg" % faction, "color": CardPalette.FACTIONS[faction]["frame"], "tooltip": MenuUI.faction_name(faction)}))

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 20)
	add_child(tools)
	_filters_button = MenuUI.button("UI_FILTERS", 72, 26)
	_filters_button.name = "FiltersButton"
	_filters_button.toggle_mode = true
	_filters_button.custom_minimum_size.x = 260
	_filters_button.toggled.connect(func(shown: bool) -> void: _filter_panel.visible = shown)
	tools.add_child(_filters_button)
	count_label = MenuUI.label("", 24, Palette.TEXT_MUTED)
	count_label.name = "CountLabel"
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tools.add_child(count_label)

	_filter_panel = VBoxContainer.new()
	_filter_panel.name = "FilterPanel"
	_filter_panel.visible = false
	_filter_panel.add_theme_constant_override("separation", 12)
	add_child(_filter_panel)
	var costs: Array = [null]
	for cost: int in MAX_COST_CHIP + 1:
		costs.append(cost)
	_filter_panel.add_child(_captioned("UI_FILTER_COST", "energy", _chip_row("cost", costs, func(cost: Variant) -> Dictionary:
		if cost == null:
			return {"text": "UI_ALL"}
		return {"text": "%d+" % cost if cost == MAX_COST_CHIP else str(cost), "raw": true})))
	_filter_panel.add_child(_captioned("UI_FILTER_TYPE", "", _chip_row("type", [null] + TYPES, func(type_id: Variant) -> Dictionary:
		return {"text": "UI_ALL" if type_id == null else "UI_TYPE_%s" % String(type_id).to_upper()})))
	_filter_panel.add_child(_captioned("UI_FILTER_RARITY", "", _chip_row("rarity", [null] + RARITIES, func(rarity: Variant) -> Dictionary:
		if rarity == null:
			return {"text": "UI_ALL"}
		return {"text": "UI_RARITY_%s" % String(CardData.Rarity.keys()[rarity]), "color": CardPalette.rarity_color(rarity)})))
	_filter_panel.add_child(_captioned("UI_FILTER_TRAIT", "", _chip_row("trait", [null] + TRAITS, func(trait_id: Variant) -> Dictionary:
		return {"text": "UI_ALL" if trait_id == null else "UI_TRAIT_%s" % String(trait_id).to_upper()})))
	_filter_panel.add_child(_captioned("UI_FILTER_OWNED", "", _chip_row("owned", [null] + OWNERSHIP, func(owned: Variant) -> Dictionary:
		return {"text": "UI_ALL" if owned == null else "UI_%s" % String(owned).to_upper()})))
	_update_filters_button()


## Whether a card passes every active filter (null = no filter for that group).
static func matches(data: CardData, active: Dictionary, owned: int) -> bool:
	if active["faction"] != null and data.faction != active["faction"]:
		return false
	if active["cost"] != null:
		var cost: int = active["cost"]
		if (cost == MAX_COST_CHIP and data.cost < cost) or (cost < MAX_COST_CHIP and data.cost != cost):
			return false
	if active["type"] != null and CardView.type_id_of(data) != active["type"]:
		return false
	if active["rarity"] != null and data.rarity != active["rarity"]:
		return false
	if active["trait"] != null and not (data.keywords.has(active["trait"]) or data.relic_keywords.has(active["trait"])):
		return false
	if active["owned"] == "owned" and owned == 0:
		return false
	if active["owned"] == "missing" and owned > 0:
		return false
	return true


func accepts(data: CardData, owned: int) -> bool:
	return matches(data, filters, owned)


## One chip per value, the one of the current filter pressed.
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
		chip.button_pressed = value == filters[group]
		chip.tooltip_text = look.get("tooltip", "")
		if look.get("raw", false):
			chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.pressed.connect(func() -> void:
			filters[group] = value
			_update_filters_button()
			changed.emit())
		row.add_child(chip)
	return row


## A filter row with its caption on the left (and an icon from ui/icons, e.g. Energy for the cost).
func _captioned(caption_key: String, icon_name: String, row: HBoxContainer) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var caption := HBoxContainer.new()
	caption.custom_minimum_size.x = CAPTION_WIDTH
	caption.add_theme_constant_override("separation", 6)
	line.add_child(caption)
	if not icon_name.is_empty():
		var icon := TextureRect.new()
		icon.texture = load("res://ui/icons/%s.svg" % icon_name) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.modulate = Palette.ENERGY
		caption.add_child(icon)
	var label: Label = MenuUI.label(caption_key, 22, Palette.TEXT_MUTED)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	caption.add_child(label)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(row)
	return line


## "FILTERS (n)": the faction is not counted, it is always in sight.
func _update_filters_button() -> void:
	var active: int = 0
	for group: String in filters:
		if group != "faction" and filters[group] != null:
			active += 1
	_filters_button.text = tr("UI_FILTERS") + (" (%d)" % active if active > 0 else "")
