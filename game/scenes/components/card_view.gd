class_name CardView
extends Button

signal zoom_requested(data: CardData, instance: CardInstance)
signal drop_requested(drag_data: Dictionary, target_uid: int, target_player: int)
signal drag_started(drag_data: Dictionary)
signal drag_moved(drag_data: Dictionary, position: Vector2)
signal drag_released(drag_data: Dictionary, position: Vector2)

const CARD_SIZE: Vector2 = Vector2(216, 310)
const LONG_PRESS_DURATION: float = 0.55
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
var _content: VBoxContainer
var _cost_icon: TextureRect
var _cost_label: Label
var _type_label: Label
var _name_label: Label
var _rules_label: Label
var _stats_row: HBoxContainer
var _attack_icon: TextureRect
var _attack_label: Label
var _health_label: Label
var _health_icon: TextureRect


func _ready() -> void:
	if not _view_scale_configured:
		_apply_view_scale()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("normal", _card_style())
	add_theme_stylebox_override("hover", _card_style(true))
	add_theme_stylebox_override("pressed", _card_style(true))
	add_theme_stylebox_override("focus", _card_style(true))
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
		add_theme_stylebox_override("normal", _card_style())
		add_theme_stylebox_override("hover", _card_style(true))


## Returns whether the last press was consumed by the zoom gesture.
func consume_long_press() -> bool:
	var triggered: bool = _long_press_triggered
	_long_press_triggered = false
	return triggered


func consume_drag() -> bool:
	var triggered: bool = _drag_triggered
	_drag_triggered = false
	return triggered


## Highlights a selected card or target.
func set_selected(value: bool) -> void:
	_selected = value
	if is_inside_tree():
		add_theme_stylebox_override("normal", _card_style())
		add_theme_stylebox_override("hover", _card_style(true))


## Highlights a unit ready to attack (&"ready") or a valid target (&"target"); &"" clears it.
func set_highlight(kind: StringName) -> void:
	_highlight = kind
	if is_inside_tree():
		add_theme_stylebox_override("normal", _card_style())
		add_theme_stylebox_override("hover", _card_style(true))


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
		and (data as Dictionary).get("kind", "") in ["hand", "attacker"]
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
	_type_label.text = CardData.Type.keys()[card_data.type].capitalize()
	_name_label.text = card_name
	_rules_label.text = rules
	var is_unit: bool = card_data.type == CardData.Type.UNIT
	_stats_row.visible = is_unit
	if is_unit:
		_attack_label.text = str(card_instance.attack if card_instance != null else card_data.attack)
		_health_label.text = str(card_instance.health if card_instance != null else card_data.health)
	tooltip_text = "%s\n%s" % [card_name, rules]


## Card face: cost (Energy icon) and type, name, rules text, then attack / health for units.
## Children of a Button do not change its size, so the card keeps its fixed size whatever the text.
func _ensure_content() -> void:
	if _content != null:
		return
	clip_contents = true
	_content = VBoxContainer.new()
	_content.name = "CardFace"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)

	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(top)
	_cost_icon = _make_icon("energy", Palette.ENERGY)
	top.add_child(_cost_icon)
	_cost_label = _make_label("CostLabel", Palette.ENERGY)
	top.add_child(_cost_label)
	_type_label = _make_label("TypeLabel", Palette.TEXT_MUTED)
	_type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_type_label)

	_name_label = _make_label("NameLabel", Palette.TEXT)
	# Left-aligned with the stats, so they stay visible when hand cards overlap.
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_content.add_child(_name_label)

	_rules_label = _make_label("RulesLabel", Palette.TEXT)
	_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rules_label.clip_text = true
	_rules_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_rules_label)

	_stats_row = HBoxContainer.new()
	_stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stats_row)
	_attack_icon = _make_icon("attack", Palette.TEXT)
	# Attack and health side by side at bottom-left: still visible when hand cards overlap.
	_stats_row.add_child(_attack_icon)
	_attack_label = _make_label("AttackLabel", Palette.TEXT)
	_stats_row.add_child(_attack_label)
	var gap: Control = Control.new()
	gap.custom_minimum_size.x = 8
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_row.add_child(gap)
	_health_icon = _make_icon("life", Palette.LIFE)
	_stats_row.add_child(_health_icon)
	_health_label = _make_label("HealthLabel", Palette.LIFE)
	_stats_row.add_child(_health_label)
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


## Fonts, icons and margins follow the card's actual size (board cards are smaller than hand cards).
func _apply_face_scale() -> void:
	if _content == null:
		return
	var card_size: Vector2 = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	# Board cards are squatter than hand cards: width drives the size, height only caps it.
	var k: float = minf(card_size.x / CARD_SIZE.x, card_size.y / CARD_SIZE.y * 1.25)
	if k <= 0.0:
		k = _view_scale
	var margin: float = 10.0 * k
	_content.offset_left = margin
	_content.offset_top = margin
	_content.offset_right = -margin
	_content.offset_bottom = -margin
	_content.add_theme_constant_override("separation", roundi(4 * k))
	_cost_label.add_theme_font_size_override("font_size", roundi(22 * k))
	_type_label.add_theme_font_size_override("font_size", roundi(13 * k))
	_name_label.add_theme_font_size_override("font_size", roundi(18 * k))
	_rules_label.add_theme_font_size_override("font_size", roundi(15 * k))
	_attack_label.add_theme_font_size_override("font_size", roundi(20 * k))
	_health_label.add_theme_font_size_override("font_size", roundi(20 * k))
	for icon: TextureRect in [_cost_icon, _attack_icon, _health_icon]:
		icon.custom_minimum_size = Vector2.ONE * roundi(22 * k)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_face_scale()


func _card_style(hovered: bool = false) -> StyleBoxFlat:
	var faction: String = String(card_data.faction) if card_data != null else "neutral"
	var faction_color: Color = FACTION_COLORS.get(faction, FACTION_COLORS["neutral"])
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = faction_color.darkened(0.66) if not hovered else faction_color.darkened(0.52)
	style.border_color = Palette.ACCENT if _selected or hovered else faction_color.lightened(0.15)
	style.set_border_width_all(4 if _selected else 2)
	if not _selected and _highlight == &"ready":
		style.border_color = Palette.ACCENT
		style.set_border_width_all(3)
	elif _highlight == &"target":
		style.border_color = Palette.LIFE
		style.set_border_width_all(5)
		style.bg_color = style.bg_color.lerp(Palette.LIFE, 0.18)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	return style
