class_name BackgroundTile
extends RefCounted

## A selectable background (Cosmetics): its picture filling a framed toggle button, gold border when
## selected, its name (or Default) under it. Used in Settings (home background) and My decks (board).


## `cosmetic_id` "" is the default (plain background). `caption_key` replaces the name when given.
static func create(cosmetic_id: String, picture_size: Vector2, caption_key: String = "") -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = picture_size + Vector2(0, 44)
	for state: String in ["normal", "hover"]:
		tile.add_theme_stylebox_override(state, _frame(Palette.BORDER, 3))
	for state: String in ["pressed", "hover_pressed"]:
		tile.add_theme_stylebox_override(state, _frame(Palette.ACCENT, 6))
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 8
	box.offset_right = -8
	box.offset_bottom = -6
	box.add_theme_constant_override("separation", 4)
	tile.add_child(box)
	var picture: Control
	var texture: Texture2D = Cosmetics.texture(cosmetic_id)
	if texture != null:
		picture = Cosmetics.backdrop(texture)
	else:
		var plain := ColorRect.new()
		plain.color = Palette.BG
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture = plain
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(picture)
	var key: String = caption_key
	if key.is_empty():
		key = Cosmetics.name_key(cosmetic_id) if not cosmetic_id.is_empty() else "UI_DEFAULT"
	var name_label: Label = MenuUI.label(key, 20, Palette.TEXT)
	name_label.name = "Caption"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	return tile


static func _frame(color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	return style
