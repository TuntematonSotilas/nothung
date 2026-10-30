extends Control

## Collection: every card with the copies the player owns, filtered (CardFilterBar). Tap a card to see
## it large. My decks opens the deck list, Nibelheim the forge. See docs/functional/07-ui-ux.md.

const FACTIONS: Array[StringName] = [&"gods", &"nibelungs", &"walsungs", &"valkyries", &"neutral"]
const DECKS_SCENE: String = "res://scenes/screens/deck_list.tscn"
const NIBELHEIM_SCENE: String = "res://scenes/screens/nibelheim.tscn"

var _filter_bar: CardFilterBar
var _grid: CardGrid


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 20)
	column.add_child(MenuUI.header("UI_COLLECTION", MenuUI.rhinegold_counter()))
	var decks: Button = MenuUI.button("UI_MY_DECKS", 88, 28)
	decks.name = "MyDecksButton"
	decks.theme_type_variation = &"ButtonPrimary"
	decks.pressed.connect(func() -> void: SceneRouter.go_to(DECKS_SCENE))
	decks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 16)
	links.add_child(decks)
	var nibelheim: Button = MenuUI.button("UI_NIBELHEIM", 88, 28)
	nibelheim.name = "NibelheimButton"
	nibelheim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nibelheim.pressed.connect(func() -> void: SceneRouter.go_to(NIBELHEIM_SCENE))
	links.add_child(nibelheim)
	column.add_child(links)
	_filter_bar = CardFilterBar.new(FACTIONS)
	_filter_bar.changed.connect(_apply_filters)
	column.add_child(_filter_bar)
	_grid = CardGrid.new(get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN)
	_grid.card_tapped.connect(_show_detail)
	column.add_child(_grid)
	for data: CardData in CardGrid.sorted_cards(CardDatabase.card_ids(), FACTIONS):
		var owned: int = SaveManager.owned_count(data.id)
		CardGrid.set_caption(_grid.add_card(data), "× %d" % owned if owned > 0 else "UI_NOT_OWNED", owned > 0, owned == 0)
	_apply_filters()


func _apply_filters() -> void:
	# Lambdas capture locals by value: count in an array.
	var owned_shown: Array[int] = [0]
	var shown: int = _grid.show_only(func(data: CardData) -> bool:
		var owned: int = SaveManager.owned_count(data.id)
		var keep: bool = _filter_bar.accepts(data, owned)
		if keep and owned > 0:
			owned_shown[0] += 1
		return keep)
	_filter_bar.count_label.text = tr("UI_COLLECTION_COUNT").format({"owned": owned_shown[0], "total": shown})


func _show_detail(data: CardData) -> void:
	var owned: String = tr("UI_OWNED_COPIES").format({"count": SaveManager.owned_count(data.id), "max": data.deck_limit()})
	CardDetail.open(self, data, [owned])
