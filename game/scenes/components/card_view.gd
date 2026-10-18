class_name CardView
extends Button

signal zoom_requested(data: CardData, instance: CardInstance)
signal drop_requested(drag_data: Dictionary, target_uid: int, target_player: int)
signal drag_started(drag_data: Dictionary)
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


func _ready() -> void:
	_apply_view_scale()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("normal", _card_style())
	add_theme_stylebox_override("hover", _card_style(true))
	add_theme_stylebox_override("pressed", _card_style(true))
	add_theme_stylebox_override("focus", _card_style(true))
	add_theme_color_override("font_color", Palette.TEXT)
	clip_text = true
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


func set_zoom_blocked(value: bool) -> void:
	_zoom_blocked = value


func set_view_scale(value: float) -> void:
	_view_scale = value
	_apply_view_scale()


func _apply_view_scale() -> void:
	custom_minimum_size = CARD_SIZE * _view_scale
	add_theme_font_size_override("font_size", roundi(18 * _view_scale))


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
	elif event is InputEventScreenDrag and _press_active:
		_cancel_moved_press((event as InputEventScreenDrag).position)
	elif event is InputEventMouseMotion and _press_active:
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
		drag_released.emit(_drag_data(), position)
		get_viewport().set_input_as_handled()
	if _press_active:
		_press_active = false
		_stop_long_press()


func _cancel_moved_press(position: Vector2) -> void:
	if position.distance_to(_press_position) > 18.0:
		_press_active = false
		_stop_long_press()
		_drag_active = _draggable and card_instance != null
		if _drag_active:
			drag_started.emit(_drag_data())


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _draggable or card_instance == null:
		return null
	_long_press_timer.stop()
	var preview: Label = Label.new()
	preview.text = tr("CARD_%s_NAME" % String(card_data.id).to_upper())
	preview.custom_minimum_size = Vector2(220, 56)
	preview.add_theme_color_override("font_color", Palette.TEXT)
	preview.add_theme_font_size_override("font_size", 20)
	set_drag_preview(preview)
	return _drag_data()


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
