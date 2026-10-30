extends Control

## Nibelheim: forge cards with Rhinegold. Shows the cards the player can still add copies of (up to the
## copies a deck can hold), each with its price; a tap shows the card large with Forge (greyed with what
## is missing when the Rhinegold is short). See docs/functional/06-progression.md#meta-currency.

const FACTIONS: Array[StringName] = [&"gods", &"nibelungs", &"walsungs", &"valkyries", &"neutral"]

var _filter_bar: CardFilterBar
var _grid: CardGrid
var _header: HBoxContainer


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 20)
	_header = MenuUI.header("UI_NIBELHEIM", MenuUI.rhinegold_counter())
	column.add_child(_header)
	var intro: Label = MenuUI.label("UI_NIBELHEIM_INTRO", 24, Palette.TEXT_MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	_filter_bar = CardFilterBar.new(FACTIONS)
	_filter_bar.changed.connect(_apply_filters)
	column.add_child(_filter_bar)
	_grid = CardGrid.new(get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN)
	_grid.card_tapped.connect(_show_forge)
	column.add_child(_grid)
	for data: CardData in CardGrid.sorted_cards(CardDatabase.card_ids(), FACTIONS):
		_grid.add_card(data)
	_refresh()


## Captions (price, or "Complete" when a deck's worth is owned) and the Rhinegold counter.
func _refresh() -> void:
	(_header.find_child("RhinegoldValue", true, false) as Label).text = str(SaveManager.rhinegold())
	for cell: Node in _grid.cells():
		var data: CardData = (cell.get_child(0) as CardView).card_data
		var owned: int = SaveManager.owned_count(data.id)
		if Progression.can_craft(data, owned):
			var price: int = Progression.craft_price(data)
			CardGrid.set_caption(cell, "%d / %d · %s" % [owned, data.deck_limit(), tr("UI_PRICE").format({"price": price})], SaveManager.rhinegold() >= price)
		else:
			CardGrid.set_caption(cell, "UI_COMPLETE", false, true)
	_apply_filters()


## Hides the cards already complete: there is nothing to forge.
func _apply_filters() -> void:
	var shown: int = _grid.show_only(func(data: CardData) -> bool:
		var owned: int = SaveManager.owned_count(data.id)
		return Progression.can_craft(data, owned) and _filter_bar.accepts(data, owned))
	_filter_bar.count_label.text = tr("UI_SHOWN_COUNT").format({"count": shown})


func _show_forge(data: CardData) -> void:
	var owned: int = SaveManager.owned_count(data.id)
	var price: int = Progression.craft_price(data)
	var lines: Array[String] = [tr("UI_OWNED_COPIES").format({"count": owned, "max": data.deck_limit()})]
	var short: int = price - SaveManager.rhinegold()
	if short > 0:
		lines.append(tr("UI_FORGE_SHORT").format({"missing": short}))
	CardDetail.open(self, data, lines, [{
		"text": tr("UI_FORGE").format({"price": price}),
		"name": "ForgeButton",
		"primary": true,
		"disabled": short > 0 or not Progression.can_craft(data, owned),
		"action": func() -> void: forge(data),
	}])


func forge(data: CardData) -> bool:
	if not SaveManager.craft(data):
		return false
	_refresh()
	return true
