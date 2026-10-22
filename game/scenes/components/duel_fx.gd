class_name DuelFx
extends Control
## Duel animations: ghost copies of cards tweened above the board.
## The duel hides the real view while its ghost plays, then rebuilds the board with the new state.

## Emitted when the last running animation sequence ends.
signal idle

const CARD_VIEW_SCRIPT: Script = preload("res://scenes/components/card_view.gd")

var ui_scale: float = 1.0
var _running: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Settings "instant": no animation at all, the duel refreshes right away.
func is_instant() -> bool:
	return Settings.animation_speed <= 0.0


func is_busy() -> bool:
	return _running > 0


## Starts a sequence: input is blocked until the matching end().
func begin() -> void:
	_running += 1
	mouse_filter = Control.MOUSE_FILTER_STOP


func end() -> void:
	_running = maxi(0, _running - 1)
	if _running == 0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		idle.emit()


## Spell cast: the card rises to the centre, glows, then strikes its target (or fades when it has none).
func play_spell(data: CardData, instance: CardInstance, from: Rect2, target: Rect2) -> void:
	var ghost: CardView = _ghost_card(data, instance, from)
	var centre: Vector2 = get_viewport_rect().size * 0.5 - from.size * 0.5
	var tween: Tween = _tween()
	tween.tween_property(ghost, "position", centre, _d(0.25))
	tween.parallel().tween_property(ghost, "scale", Vector2.ONE * 1.3, _d(0.25))
	tween.tween_property(ghost, "modulate", Color(1.6, 1.45, 1.0), _d(0.1))
	tween.tween_property(ghost, "modulate", Color.WHITE, _d(0.1))
	if target.has_area():
		tween.tween_property(ghost, "position", target.get_center() - from.size * 0.5, _d(0.25)).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(ghost, "scale", Vector2.ONE * 0.2, _d(0.25)).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(ghost, "scale", Vector2.ONE * 1.6, _d(0.25))
		tween.parallel().tween_property(ghost, "modulate:a", 0.0, _d(0.25))
	await tween.finished
	ghost.queue_free()
	if target.has_area():
		_burst(target, Palette.ACCENT)


## Attack: the attacker lunges at the target and comes back; the target flashes red on impact.
func play_attack(data: CardData, instance: CardInstance, from: Rect2, target: Rect2) -> void:
	var ghost: CardView = _ghost_card(data, instance, from)
	ghost.z_index = 1
	var hit: Vector2 = from.position + (target.get_center() - from.get_center()) * 0.8
	var tween: Tween = _tween()
	# Wind-up (lift), strike, short hold on impact, then back to its place.
	tween.tween_property(ghost, "scale", Vector2.ONE * 1.12, _d(0.12))
	tween.tween_property(ghost, "position", hit, _d(0.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_flash(target, Palette.LIFE)
	tween = _tween()
	tween.tween_interval(_d(0.08))
	tween.tween_property(ghost, "position", from.position, _d(0.25))
	tween.parallel().tween_property(ghost, "scale", Vector2.ONE, _d(0.25))
	await tween.finished
	ghost.queue_free()


## Floating "-N" over a damaged unit or Leader; not awaited, it fades on its own.
func play_damage(target: Rect2, amount: int) -> void:
	if amount <= 0 or not target.has_area():
		return
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(48 * ui_scale))
	label.add_theme_color_override("font_color", Palette.LIFE)
	label.add_theme_color_override("font_outline_color", Palette.BG)
	label.add_theme_constant_override("outline_size", roundi(10 * ui_scale))
	add_child(label)
	label.position = target.get_center() - label.get_combined_minimum_size() * 0.5
	var tween: Tween = _tween()
	tween.tween_property(label, "position:y", label.position.y - 70.0 * ui_scale, _d(0.7))
	tween.parallel().tween_property(label, "modulate:a", 0.0, _d(0.7)).set_delay(_d(0.3))
	tween.finished.connect(label.queue_free)


## Destroyed unit: red tint and shake, then it shrinks, sinks and fades.
func play_death(data: CardData, instance: CardInstance, rect: Rect2) -> void:
	var ghost: CardView = _ghost_card(data, instance, rect)
	var shake: float = 8.0 * ui_scale
	var tween: Tween = _tween()
	tween.tween_property(ghost, "modulate", Color(1.5, 0.45, 0.4), _d(0.12))
	for offset: float in [shake, -shake, shake * 0.5, 0.0]:
		tween.tween_property(ghost, "position:x", rect.position.x + offset, _d(0.04))
	tween.tween_property(ghost, "scale", Vector2.ONE * 0.6, _d(0.35)).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "position:y", rect.position.y + 30.0 * ui_scale, _d(0.35))
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, _d(0.35))
	await tween.finished
	ghost.queue_free()


## Own draw: a card back flies in from the right edge and turns into the card at its hand slot.
func play_draw(data: CardData, instance: CardInstance, target: Rect2) -> void:
	var start: Rect2 = Rect2(Vector2(get_viewport_rect().size.x + 10.0, target.position.y), target.size)
	var middle: Vector2 = start.position.lerp(target.position, 0.5)
	var back: Control = _card_back(start)
	var tween: Tween = _tween()
	tween.tween_property(back, "position", middle, _d(0.16))
	tween.parallel().tween_property(back, "scale:x", 0.0, _d(0.16)).set_ease(Tween.EASE_IN)
	await tween.finished
	back.queue_free()
	var ghost: CardView = _ghost_card(data, instance, Rect2(middle, target.size))
	ghost.scale.x = 0.0
	tween = _tween()
	tween.tween_property(ghost, "position", target.position, _d(0.16))
	tween.parallel().tween_property(ghost, "scale:x", 1.0, _d(0.16))
	await tween.finished
	ghost.queue_free()


## Enemy draw: a small card back slides from the top-right corner into the enemy Leader panel.
func play_enemy_draw(target: Rect2) -> void:
	var card_size: Vector2 = CardView.CARD_SIZE * 0.45 * ui_scale
	var back: Control = _card_back(Rect2(Vector2(get_viewport_rect().size.x + 10.0, target.position.y), card_size))
	var tween: Tween = _tween()
	tween.tween_property(back, "position", target.get_center() - card_size * 0.5, _d(0.3))
	tween.tween_property(back, "modulate:a", 0.0, _d(0.12))
	await tween.finished
	back.queue_free()


func _ghost_card(data: CardData, instance: CardInstance, rect: Rect2) -> CardView:
	var ghost: CardView = CARD_VIEW_SCRIPT.new()
	ghost.name = "FxCard"
	ghost.set_card(data, instance, false, -1, "hand", false)
	ghost.set_view_scale(rect.size.x / CardView.CARD_SIZE.x)
	ghost.custom_minimum_size = rect.size
	ghost.size = rect.size
	ghost.position = rect.position
	ghost.pivot_offset = rect.size * 0.5
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	ghost.remove_from_group("duel_card_views")
	return ghost


## Placeholder card back until the painted one exists.
func _card_back(rect: Rect2) -> Control:
	var back: Panel = Panel.new()
	back.name = "FxCardBack"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE_RAISED
	style.border_color = Palette.ACCENT
	style.set_border_width_all(maxi(2, roundi(3 * ui_scale)))
	style.set_corner_radius_all(roundi(14 * ui_scale))
	back.add_theme_stylebox_override("panel", style)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = rect.size
	back.position = rect.position
	back.pivot_offset = rect.size * 0.5
	add_child(back)
	return back


## Translucent coloured card-shaped flash over a rect.
func _flash(rect: Rect2, color: Color) -> void:
	var flash: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color, 0.55)
	style.set_corner_radius_all(roundi(14 * ui_scale))
	flash.add_theme_stylebox_override("panel", style)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = rect.position
	flash.size = rect.size
	add_child(flash)
	var tween: Tween = _tween()
	tween.tween_property(flash, "modulate:a", 0.0, _d(0.3))
	tween.finished.connect(flash.queue_free)


## Expanding ring where a spell lands.
func _burst(rect: Rect2, color: Color) -> void:
	var diameter: float = minf(rect.size.x, rect.size.y)
	var burst: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color, 0.25)
	style.border_color = color
	style.set_border_width_all(maxi(2, roundi(6 * ui_scale)))
	style.set_corner_radius_all(roundi(diameter))
	burst.add_theme_stylebox_override("panel", style)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.size = Vector2.ONE * diameter
	burst.position = rect.get_center() - burst.size * 0.5
	burst.pivot_offset = burst.size * 0.5
	burst.scale = Vector2.ONE * 0.2
	add_child(burst)
	var tween: Tween = _tween()
	tween.tween_property(burst, "scale", Vector2.ONE * 1.3, _d(0.3))
	tween.parallel().tween_property(burst, "modulate:a", 0.0, _d(0.3))
	tween.finished.connect(burst.queue_free)


func _tween() -> Tween:
	return create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Duration scaled by the animation speed setting (1x, 2x).
func _d(seconds: float) -> float:
	return seconds / maxf(Settings.animation_speed, 0.01)
