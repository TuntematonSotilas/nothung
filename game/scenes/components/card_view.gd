class_name CardView
extends Button

signal zoom_requested(data: CardData, instance: CardInstance)
signal drop_requested(drag_data: Dictionary, target_uid: int, target_player: int)
signal drag_started(drag_data: Dictionary)
signal drag_moved(drag_data: Dictionary, position: Vector2)
signal drag_released(drag_data: Dictionary, position: Vector2)

const CARD_SIZE: Vector2 = Vector2(216, 310)
const LONG_PRESS_DURATION: float = 0.55
## Space between the frame and the card face (at hand size).
const FACE_MARGIN: float = 14.0
## Corner radius (at hand size) giving each type its frame shape; artifacts cut their corners (octagon).
const SHAPE_RADIUS: Dictionary = {
	CardData.Type.UNIT: 8.0,
	CardData.Type.SPELL: 30.0,
	CardData.Type.ARTIFACT: 26.0,
}

var card_data: CardData
var card_instance: CardInstance
var _selected: bool = false
## &"ready" (can attack now), &"target" (valid target of the current selection) or &"".
var _highlight: StringName = &""
var _draggable: bool = false
var _drop_player: int = -1
var _drag_kind: String = "hand"
var _zoom_allowed: bool = true
var _zoom_blocked: bool = false
var _long_press_triggered: bool = false
var _drag_triggered: bool = false
var _drag_active: bool = false
var _long_press_timer: Timer
var _press_position: Vector2
var _press_active: bool = false
var _view_scale: float = 1.0
var _view_scale_configured: bool = false
var _face_k: float = 1.0
var _content: VBoxContainer
var _name_banner: PanelContainer
var _cost_stone: PanelContainer
var _cost_icon: TextureRect
var _cost_label: Label
var _faction_icon: TextureRect
var _type_label: Label
var _type_icon: TextureRect
var _gem: Control
var _gem_shape: Panel
var _name_label: Label
var _art: TextureRect
var _rules_label: Label
var _ribbon: PanelContainer
var _ribbon_label: Label
var _stats_row: HBoxContainer
var _attack_stone: PanelContainer
var _attack_icon: TextureRect
var _attack_label: Label
var _health_stone: PanelContainer
var _health_label: Label
var _health_icon: TextureRect


func _ready() -> void:
	if not _view_scale_configured:
		_apply_view_scale()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_styles()
	add_theme_color_override("font_color", Palette.TEXT)
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = LONG_PRESS_DURATION
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
	add_to_group("duel_card_views")
	set_process_input(true)


## Binds this view to a card definition and optional match instance.
func set_card(
	data: CardData,
	instance: CardInstance = null,
	draggable: bool = false,
	drop_player: int = -1,
	drag_kind: String = "hand",
	zoom_allowed: bool = true
) -> void:
	card_data = data
	card_instance = instance
	_draggable = draggable
	_drop_player = drop_player
	_drag_kind = drag_kind
	_zoom_allowed = zoom_allowed
	_refresh_text()
	if is_inside_tree():
		_apply_styles()


## Returns whether the last press was consumed by the zoom gesture.
func consume_long_press() -> bool:
	var triggered: bool = _long_press_triggered
	_long_press_triggered = false
	return triggered


## Copy of the card as currently drawn: the match may already have changed its stats (animations replay the old ones).
func shown_instance() -> CardInstance:
	if card_instance == null:
		return null
	var copy: CardInstance = card_instance.duplicate_instance()
	if _attack_stone != null and _attack_stone.visible:
		copy.attack = int(_attack_label.text)
		copy.health = int(_health_label.text)
	return copy


func consume_drag() -> bool:
	var triggered: bool = _drag_triggered
	_drag_triggered = false
	return triggered


## Highlights a selected card or target.
func set_selected(value: bool) -> void:
	_selected = value
	if is_inside_tree():
		_apply_styles()


## Highlights a unit ready to attack (&"ready") or a valid target (&"target"); &"" clears it.
func set_highlight(kind: StringName) -> void:
	_highlight = kind
	if is_inside_tree():
		_apply_styles()


func set_zoom_blocked(value: bool) -> void:
	_zoom_blocked = value


func set_view_scale(value: float) -> void:
	_view_scale = value
	_view_scale_configured = true
	_apply_view_scale()


func _apply_view_scale() -> void:
	custom_minimum_size = CARD_SIZE * _view_scale
	_apply_face_scale()


func _input(event: InputEvent) -> void:
	if not _zoom_allowed or _zoom_blocked:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and get_global_rect().has_point(touch.position):
			_begin_press(touch.position)
		elif not touch.pressed:
			_end_press(touch.position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and get_global_rect().has_point(mouse.position):
			_begin_press(mouse.position)
		elif not mouse.pressed:
			_end_press(mouse.position)
	elif event is InputEventScreenDrag and (_press_active or _drag_active):
		_cancel_moved_press((event as InputEventScreenDrag).position)
	elif event is InputEventMouseMotion and (_press_active or _drag_active):
		_cancel_moved_press((event as InputEventMouseMotion).position)


func _begin_press(position: Vector2) -> void:
	_press_position = position
	_press_active = true
	_drag_triggered = false
	_start_long_press()


func _end_press(position: Vector2) -> void:
	if _drag_active:
		_drag_active = false
		_drag_triggered = true
		# Handle the input before emitting: the listener may play the card and remove this view from the tree.
		get_viewport().set_input_as_handled()
		drag_released.emit(_drag_data(), position)
		if not is_inside_tree():
			return
	if _press_active:
		_press_active = false
		_stop_long_press()


func _cancel_moved_press(position: Vector2) -> void:
	if _drag_active:
		drag_moved.emit(_drag_data(), position)
	elif _press_active and position.distance_to(_press_position) > 18.0:
		_press_active = false
		_stop_long_press()
		_drag_active = _draggable and card_instance != null
		if _drag_active:
			drag_started.emit(_drag_data())
			drag_moved.emit(_drag_data(), position)


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Touch drags use the custom preview and release path for consistent Android rendering.
	return null


func _drag_data() -> Dictionary:
	return {"kind": _drag_kind, "uid": card_instance.uid}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and (data as Dictionary).get("kind", "") == "hand"
		and card_instance != null
		and _drop_player >= 0
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		drop_requested.emit(data as Dictionary, card_instance.uid, _drop_player)


func _start_long_press() -> void:
	_long_press_triggered = false
	_long_press_timer.start()


func _stop_long_press() -> void:
	_long_press_timer.stop()


func _on_long_press_timeout() -> void:
	if card_data == null:
		return
	_long_press_triggered = true
	zoom_requested.emit(card_data, card_instance)


func _refresh_text() -> void:
	text = ""
	_ensure_content()
	if card_data == null:
		_content.visible = false
		tooltip_text = ""
		return
	_content.visible = true
	var card_name: String = tr("CARD_%s_NAME" % String(card_data.id).to_upper())
	var rules: String = tr("CARD_%s_RULES" % String(card_data.id).to_upper())
	if rules.begins_with("CARD_"):
		rules = ""
	_cost_label.text = str(card_data.cost)
	var type_id: String = "relic" if card_data.is_relic() else String(CardData.Type.keys()[card_data.type]).to_lower()
	_type_label.text = type_id.capitalize()
	_set_icon(_type_icon, "res://ui/icons/type_%s.svg" % type_id)
	_name_label.text = card_name
	_rules_label.text = rules
	var is_unit: bool = card_data.type == CardData.Type.UNIT
	_attack_stone.visible = is_unit
	_health_stone.visible = is_unit
	if is_unit:
		_attack_label.text = str(card_instance.attack if card_instance != null else card_data.attack)
		_health_label.text = str(card_instance.health if card_instance != null else card_data.health)
	_ribbon.visible = card_data.is_relic()
	_art.texture = card_data.art
	_art.visible = card_data.art != null
	_set_icon(_faction_icon, "res://ui/icons/faction_%s.svg" % card_data.faction)
	_apply_face_colors()
	_apply_styles()
	tooltip_text = "%s\n%s" % [card_name, rules]


## Card face: cost, faction icon and rarity gem; name banner; illustration (when drawn); rules text;
## "Bearer" ribbon for relics; attack / health (units) and the card type at the bottom.
## Children of a Button do not change its size, so the card keeps its fixed size whatever the text.
func _ensure_content() -> void:
	if _content != null:
		return
	# No clipping: the highlight glow and the name banner draw outside the face (texts clip themselves).
	clip_contents = false
	_content = VBoxContainer.new()
	_content.name = "CardFace"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)

	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(top)
	_cost_stone = _make_stone("CostStone")
	top.add_child(_cost_stone)
	var cost_row: HBoxContainer = _stone_row(_cost_stone)
	_cost_icon = _make_icon("energy", Palette.ENERGY)
	cost_row.add_child(_cost_icon)
	_cost_label = _make_label("CostLabel", Palette.ENERGY)
	cost_row.add_child(_cost_label)
	var top_gap: Control = Control.new()
	top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_gap)
	# Faction icon top right, in the faction colour, next to the gem.
	_faction_icon = _make_icon_slot("FactionIcon")
	top.add_child(_faction_icon)
	# Rarity gem: a small diamond (a square turned by 45 degrees) in the top-right corner.
	_gem = Control.new()
	_gem.name = "Gem"
	_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_gem)
	_gem_shape = Panel.new()
	_gem_shape.name = "GemShape"
	_gem_shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem_shape.rotation_degrees = 45.0
	_gem.add_child(_gem_shape)

	_name_label = _make_label("NameLabel", Palette.TEXT)
	# Left-aligned with the stats, so they stay visible when hand cards overlap.
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	# The name sits on a banner in the faction colour.
	_name_banner = PanelContainer.new()
	_name_banner.name = "NameBanner"
	_name_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_banner.add_child(_name_label)
	_content.add_child(_name_banner)

	_art = TextureRect.new()
	_art.name = "Artwork"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.clip_contents = true
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.visible = false
	_content.add_child(_art)

	_rules_label = _make_label("RulesLabel", Palette.TEXT)
	_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rules_label.clip_text = true
	_rules_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_rules_label)

	_ribbon = PanelContainer.new()
	_ribbon.name = "BearerRibbon"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.visible = false
	_content.add_child(_ribbon)
	_ribbon_label = _make_label("BearerLabel", Palette.TEXT)
	_ribbon_label.text = "UI_BEARER"
	_ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ribbon.add_child(_ribbon_label)

	# Attack and health side by side at bottom-left (still visible when hand cards overlap), type at bottom-right.
	_stats_row = HBoxContainer.new()
	_stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stats_row)
	_attack_stone = _make_stone("AttackStone")
	_stats_row.add_child(_attack_stone)
	var attack_row: HBoxContainer = _stone_row(_attack_stone)
	_attack_icon = _make_icon("attack", Palette.TEXT)
	attack_row.add_child(_attack_icon)
	_attack_label = _make_label("AttackLabel", Palette.TEXT)
	attack_row.add_child(_attack_label)
	_health_stone = _make_stone("HealthStone")
	_stats_row.add_child(_health_stone)
	var health_row: HBoxContainer = _stone_row(_health_stone)
	_health_icon = _make_icon("life", Palette.LIFE)
	health_row.add_child(_health_icon)
	_health_label = _make_label("HealthLabel", Palette.LIFE)
	health_row.add_child(_health_label)
	# Card type at the bottom right: its name, then its icon once drawn (ui/icons/type_<type>.svg).
	var stats_gap: Control = Control.new()
	stats_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_row.add_child(stats_gap)
	_type_label = _make_label("TypeLabel", Palette.TEXT_MUTED)
	_type_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stats_row.add_child(_type_label)
	_type_icon = _make_icon_slot("TypeIcon")
	_stats_row.add_child(_type_icon)
	_apply_face_scale()


func _make_label(node_name: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	return label


func _make_icon(icon_name: String, color: Color) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = icon_name.to_pascal_case() + "Icon"
	icon.texture = load("res://ui/icons/%s.svg" % icon_name) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Icon loaded from a file that may not exist yet (faction and type icons); hidden until it does.
func _make_icon_slot(node_name: String) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = node_name
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _set_icon(icon: TextureRect, path: String) -> void:
	icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	icon.visible = icon.texture != null


## Holder of an icon + number (cost, attack, health); drawn bare, without a pill.
func _make_stone(node_name: String) -> PanelContainer:
	var stone: PanelContainer = PanelContainer.new()
	stone.name = node_name
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return stone


func _stone_row(stone: PanelContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	stone.add_child(row)
	return row


## Light text on the dark card background; the name takes the faction's text colour (dark on the
## light Valkyries / Neutral banners); the relic ribbon picks the ink that reads on its trim.
func _apply_face_colors() -> void:
	var colors: Dictionary = CardPalette.colors_for(card_data)
	var ink: Color = CardPalette.TEXT_LIGHT
	_rules_label.add_theme_color_override("font_color", ink)
	_name_label.add_theme_color_override("font_color", colors["text"])
	_type_label.add_theme_color_override("font_color", Color(ink, 0.75))
	_faction_icon.modulate = colors["frame"]
	_type_icon.modulate = Color(ink, 0.75)
	_ribbon_label.add_theme_color_override("font_color", CardPalette.ink_on(colors["trim"]))


## Fonts, icons and margins follow the card's actual size (board cards are smaller than hand cards).
func _apply_face_scale() -> void:
	if _content == null:
		return
	var card_size: Vector2 = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	# Board cards are squatter than hand cards: width drives the size, height only caps it.
	var k: float = minf(card_size.x / CARD_SIZE.x, card_size.y / CARD_SIZE.y * 1.25)
	if k <= 0.0:
		k = _view_scale
	_face_k = k
	var margin: float = FACE_MARGIN * k
	_content.offset_left = margin
	_content.offset_top = margin
	_content.offset_right = -margin
	_content.offset_bottom = -margin
	_content.add_theme_constant_override("separation", roundi(4 * k))
	_cost_label.add_theme_font_size_override("font_size", roundi(20 * k))
	_type_label.add_theme_font_size_override("font_size", roundi(13 * k))
	_name_label.add_theme_font_size_override("font_size", roundi(18 * k))
	_rules_label.add_theme_font_size_override("font_size", roundi(15 * k))
	_ribbon_label.add_theme_font_size_override("font_size", roundi(12 * k))
	_attack_label.add_theme_font_size_override("font_size", roundi(18 * k))
	_health_label.add_theme_font_size_override("font_size", roundi(18 * k))
	_stats_row.add_theme_constant_override("separation", roundi(6 * k))
	for icon: TextureRect in [_cost_icon, _attack_icon, _health_icon]:
		icon.custom_minimum_size = Vector2.ONE * roundi(18 * k)
	_faction_icon.custom_minimum_size = Vector2.ONE * roundi(26 * k)
	_type_icon.custom_minimum_size = Vector2.ONE * roundi(18 * k)
	var gem_size: float = roundf(16 * k)
	_gem.custom_minimum_size = Vector2.ONE * gem_size
	_gem_shape.size = Vector2.ONE * gem_size * 0.72
	_gem_shape.pivot_offset = _gem_shape.size * 0.5
	_gem_shape.position = (Vector2.ONE * gem_size - _gem_shape.size) * 0.5
	_apply_styles()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_face_scale()


## Frame, name banner, gem, stones and ribbon styles; called when the card, its state or its size changes.
func _apply_styles() -> void:
	add_theme_stylebox_override("normal", _card_style())
	add_theme_stylebox_override("hover", _card_style(true))
	add_theme_stylebox_override("pressed", _card_style(true))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _content == null:
		return
	var colors: Dictionary = CardPalette.colors_for(card_data)
	var trim: Color = colors["trim"]
	var k: float = _face_k
	# Full-width band: drawn out to the frame on both sides, the name stays aligned with the face.
	var banner: StyleBoxFlat = StyleBoxFlat.new()
	banner.bg_color = colors["frame"]
	var to_frame: float = FACE_MARGIN * k - float(_frame_width())
	banner.expand_margin_left = to_frame
	banner.expand_margin_right = to_frame
	banner.content_margin_left = 0.0
	banner.content_margin_right = 0.0
	banner.content_margin_top = 3.0 * k
	banner.content_margin_bottom = 3.0 * k
	_name_banner.add_theme_stylebox_override("panel", banner)
	var gem: StyleBoxFlat = StyleBoxFlat.new()
	gem.bg_color = CardPalette.gem_for(card_data.rarity if card_data != null else CardData.Rarity.COMMON)
	gem.border_color = CardPalette.TEXT_DARK
	gem.set_border_width_all(maxi(1, roundi(1.5 * k)))
	_gem_shape.add_theme_stylebox_override("panel", gem)
	# Cost, attack and health are bare icon + number (no pill around them).
	for stone: PanelContainer in [_cost_stone, _attack_stone, _health_stone]:
		stone.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var ribbon: StyleBoxFlat = StyleBoxFlat.new()
	ribbon.bg_color = trim
	ribbon.set_corner_radius_all(roundi(3 * k))
	ribbon.content_margin_top = 1.0 * k
	ribbon.content_margin_bottom = 1.0 * k
	_ribbon.add_theme_stylebox_override("panel", ribbon)


## Thickness of the faction-coloured frame.
func _frame_width() -> int:
	return maxi(2, roundi(3 * _face_k))


func _shape_radius() -> float:
	var card_type: CardData.Type = card_data.type if card_data != null else CardData.Type.UNIT
	return float(SHAPE_RADIUS.get(card_type, 8.0)) * _face_k


## Frame shape by type: unit = rectangle with small corners, spell = very rounded, artifact = octagon.
func _shaped_box(radius: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(roundi(radius))
	if card_data != null and card_data.type == CardData.Type.ARTIFACT:
		# One segment per corner: straight cut corners, i.e. an octagon.
		box.corner_detail = 1
	box.anti_aliasing = true
	return box


## Frame (border) in the faction colour (dark gold for the Ring) on a dark background, which the
## illustrations will cover. Selection, "ready" and "target" add an outer glow instead of
## recolouring the frame, so the faction stays readable.
func _card_style(hovered: bool = false) -> StyleBoxFlat:
	var colors: Dictionary = CardPalette.colors_for(card_data)
	var style: StyleBoxFlat = _shaped_box(_shape_radius())
	style.bg_color = CardPalette.BACKGROUND.lightened(0.06) if hovered else CardPalette.BACKGROUND
	style.border_color = colors["frame"]
	style.set_border_width_all(_frame_width())
	var glow: Color = Color.TRANSPARENT
	if _highlight == &"target":
		glow = Palette.LIFE
		style.bg_color = style.bg_color.lerp(Palette.LIFE, 0.15)
	elif _selected:
		glow = Palette.ACCENT
	elif _highlight == &"ready":
		glow = Color(Palette.ACCENT, 0.75)
	if glow.a > 0.0:
		style.shadow_color = glow
		style.shadow_size = roundi((12 if _selected or _highlight == &"target" else 7) * _face_k)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 12.0)
	return style
