extends Button

const CARD_SIZE: Vector2 = Vector2(188, 270)
const FACTION_COLORS: Dictionary = {
	"gods": Color("#667ea0"),
	"nibelungs": Color("#9a704a"),
	"neutral": Color("#77736a"),
	"walsungs": Color("#7d6b91"),
	"valkyries": Color("#719185"),
}

var card_data: CardData
var card_instance: CardInstance
var _selected: bool = false


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("normal", _card_style())
	add_theme_stylebox_override("hover", _card_style(true))
	add_theme_stylebox_override("pressed", _card_style(true))
	add_theme_stylebox_override("focus", _card_style(true))
	add_theme_color_override("font_color", Palette.TEXT)
	add_theme_font_size_override("font_size", 16)
	clip_text = true


## Binds this view to a card definition and optional match instance.
func set_card(data: CardData, instance: CardInstance = null) -> void:
	card_data = data
	card_instance = instance
	_refresh_text()
	if is_inside_tree():
		add_theme_stylebox_override("normal", _card_style())
		add_theme_stylebox_override("hover", _card_style(true))


## Highlights a selected card or target.
func set_selected(value: bool) -> void:
	_selected = value
	if is_inside_tree():
		add_theme_stylebox_override("normal", _card_style())
		add_theme_stylebox_override("hover", _card_style(true))


func _refresh_text() -> void:
	if card_data == null:
		text = ""
		return
	var card_name: String = tr("CARD_%s_NAME" % String(card_data.id).to_upper())
	var cost_text: String = "◆ %d" % card_data.cost
	var type_text: String = CardData.Type.keys()[card_data.type].capitalize()
	var rules: String = tr("CARD_%s_RULES" % String(card_data.id).to_upper())
	if rules.begins_with("CARD_"):
		rules = ""
	var stats: String = ""
	if card_instance != null and card_data.type == CardData.Type.UNIT:
		stats = "\n\n⚔ %d   ♥ %d" % [card_instance.attack, card_instance.health]
	elif card_data.type == CardData.Type.UNIT:
		stats = "\n\n⚔ %d   ♥ %d" % [card_data.attack, card_data.health]
	text = "%s\n%s\n\n%s%s%s" % [
		cost_text,
		card_name,
		type_text,
		("\n" + rules) if not rules.is_empty() else "",
		stats,
	]
	tooltip_text = "%s\n%s" % [card_name, rules]


func _card_style(hovered: bool = false) -> StyleBoxFlat:
	var faction: String = String(card_data.faction) if card_data != null else "neutral"
	var faction_color: Color = FACTION_COLORS.get(faction, FACTION_COLORS["neutral"])
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = faction_color.darkened(0.66) if not hovered else faction_color.darkened(0.52)
	style.border_color = Palette.ACCENT if _selected or hovered else faction_color.lightened(0.15)
	style.set_border_width_all(4 if _selected else 2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	return style
