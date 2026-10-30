class_name CardGrid
extends ScrollContainer

## A scrolling grid of cards, 3 per row, scaled to the given width. Each cell is the CardView and a
## caption under it. A press that scrolled the grid is a scroll, not a tap; with `pick_enabled`, a long
## press picks the card up to drag it (PressPick).

signal card_tapped(data: CardData)
signal card_picked(data: CardData)
signal card_released(data: CardData, position: Vector2)

const COLUMNS: int = 3
const CARD_GAP: int = 20

## Set before adding cards.
var pick_enabled: bool = false
var _grid: GridContainer
var _card_scale: float = 1.0


func _init(width: float) -> void:
	name = "CardScroll"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	add_child(_grid)
	_card_scale = (width - (COLUMNS - 1) * CARD_GAP) / float(COLUMNS) / CardView.CARD_SIZE.x


## Adds a cell; returns it (child 0: the CardView, child 1: the caption Label named "Caption").
func add_card(data: CardData) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.name = "Card_%s" % data.id
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_theme_constant_override("separation", 6)
	var view := CardView.new()
	view.mouse_filter = Control.MOUSE_FILTER_PASS
	view.set_view_scale(_card_scale)
	view.set_card(data, null, false, -1, "hand", false)
	cell.add_child(view)
	var press: PressPick = PressPick.attach(view, self, pick_enabled)
	press.tapped.connect(func() -> void: card_tapped.emit(data))
	press.picked.connect(func() -> void: card_picked.emit(data))
	press.released.connect(func(position: Vector2) -> void: card_released.emit(data, position))
	var caption: Label = MenuUI.label("", 24, Palette.TEXT_MUTED)
	caption.name = "Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(caption)
	_grid.add_child(cell)
	return cell


func cells() -> Array[Node]:
	return _grid.get_children()


## Shows the cells whose card passes `keep(data)`; returns how many are shown.
func show_only(keep: Callable) -> int:
	var shown: int = 0
	for cell: Node in _grid.get_children():
		var visible_now: bool = keep.call((cell.get_child(0) as CardView).card_data)
		(cell as Control).visible = visible_now
		if visible_now:
			shown += 1
	scroll_vertical = 0
	return shown


## Sets a cell's caption and fades the card when it is not available (not owned, maxed out…).
static func set_caption(cell: Node, text: String, available: bool, translate: bool = false) -> void:
	var caption: Label = cell.get_child(1) as Label
	caption.text = text
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.add_theme_color_override("font_color", Palette.ACCENT if available else Palette.TEXT_MUTED)
	(cell.get_child(0) as Control).modulate = Color(1, 1, 1, 1.0 if available else 0.4)


## By faction (in `factions` order), then cost, then name.
static func sorted_cards(card_ids: Array[StringName], factions: Array[StringName]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id: StringName in card_ids:
		cards.append(CardDatabase.get_card(card_id))
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		var faction_a: int = factions.find(a.faction)
		var faction_b: int = factions.find(b.faction)
		if faction_a != faction_b:
			return faction_a < faction_b
		if a.cost != b.cost:
			return a.cost < b.cost
		return TranslationServer.translate("CARD_%s_NAME" % String(a.id).to_upper()) < TranslationServer.translate("CARD_%s_NAME" % String(b.id).to_upper()))
	return cards
