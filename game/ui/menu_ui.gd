class_name MenuUI
extends RefCounted

## Builders shared by the menu screens (main menu, Quick match, Settings…), sized for the 1080 × 1920 reference.

const SCREEN_MARGIN: int = 48
## Faction display order everywhere a deck or faction list is shown.
const FACTION_ORDER: Array[StringName] = [&"gods", &"nibelungs", &"walsungs", &"valkyries"]


static func label(key: String, font_size: int, color: Color = Palette.TEXT) -> Label:
	var result := Label.new()
	result.text = key
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(key: String, height: int = 104, font_size: int = 30) -> Button:
	var result := Button.new()
	result.text = key
	result.custom_minimum_size = Vector2(0, height)
	result.add_theme_font_size_override("font_size", font_size)
	return result


## Back button, centred title, and on the right `right` (e.g. a counter) or a spacer, as wide as the
## button so the title stays centred.
static func header(title_key: String, right: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	var back: Button = button("UI_BACK", 88, 26)
	back.name = "BackButton"
	back.custom_minimum_size.x = 200
	back.pressed.connect(func() -> void: SceneRouter.go_back())
	row.add_child(back)
	var title: Label = label(title_key, 44, Palette.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)
	var balance: Control = right if right != null else Control.new()
	balance.custom_minimum_size.x = 200
	row.add_child(balance)
	return row


## A filter chip: toggle button, one of a ButtonGroup row; gold border when pressed. An icon chip
## shows the icon only, tinted with `color`.
static func chip(text: String, color: Color = Palette.BORDER, icon_path: String = "") -> Button:
	var result := Button.new()
	result.toggle_mode = true
	result.text = text
	result.custom_minimum_size = Vector2(0, 72)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.clip_text = true
	result.add_theme_font_size_override("font_size", 22)
	for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, Palette.TEXT)
	for state: String in ["normal", "hover"]:
		var style: StyleBoxFlat = _tile_style(Palette.SURFACE if state == "normal" else Palette.SURFACE_RAISED, color, 3)
		style.content_margin_left = 8
		style.content_margin_right = 8
		result.add_theme_stylebox_override(state, style)
	for state: String in ["pressed", "hover_pressed"]:
		var style: StyleBoxFlat = _tile_style(Palette.SURFACE_RAISED, Palette.ACCENT, 5)
		style.content_margin_left = 8
		style.content_margin_right = 8
		result.add_theme_stylebox_override(state, style)
	result.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_path != "" and ResourceLoader.exists(icon_path):
		result.icon = load(icon_path) as Texture2D
		result.expand_icon = true
		result.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.add_theme_constant_override("icon_max_width", 44)
		for state: String in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color", "icon_focus_color"]:
			result.add_theme_color_override(state, color.lightened(0.3))
	return result


## A 0–100 slider sized for touch: thick track, gold fill and a large round grabber.
static func slider(value: float, step: float = 10.0) -> HSlider:
	var result := HSlider.new()
	result.min_value = 0.0
	result.max_value = 100.0
	result.step = step
	result.value = value
	result.custom_minimum_size = Vector2(0, 72)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.SURFACE_RAISED
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	result.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.ACCENT
	fill.set_corner_radius_all(6)
	result.add_theme_stylebox_override("grabber_area", fill)
	result.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob: Texture2D = _disc(44, Palette.ACCENT)
	result.add_theme_icon_override("grabber", knob)
	result.add_theme_icon_override("grabber_highlight", _disc(44, Palette.ACCENT_HOVER))
	return result


## Full-screen background plus a margin container holding the screen's column, kept out of the notch
## and system bars (SafeArea).
static func screen_column(screen: Control, separation: int = 28) -> VBoxContainer:
	var background := ColorRect.new()
	background.color = Palette.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(margin)
	SafeArea.pad(margin, {"left": SCREEN_MARGIN, "top": SCREEN_MARGIN, "right": SCREEN_MARGIN, "bottom": SCREEN_MARGIN})
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	margin.add_child(column)
	return column


## A selectable tile (toggle button): border in `color`, gold and thicker when selected.
static func choice_tile(text: String, color: Color, height: int, icon_path: String = "") -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.text = text
	tile.custom_minimum_size = Vector2(0, height)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tile.add_theme_font_size_override("font_size", 28)
	for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		tile.add_theme_color_override(state, Palette.TEXT)
	tile.add_theme_stylebox_override("normal", _tile_style(Palette.SURFACE, color, 3))
	tile.add_theme_stylebox_override("hover", _tile_style(Palette.SURFACE_RAISED, color, 3))
	tile.add_theme_stylebox_override("pressed", _tile_style(Palette.SURFACE_RAISED, Palette.ACCENT, 6))
	tile.add_theme_stylebox_override("hover_pressed", _tile_style(Palette.SURFACE_RAISED, Palette.ACCENT, 6))
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tile.icon = load(icon_path) as Texture2D
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 64)
		tile.add_theme_constant_override("h_separation", 20)
		for state: String in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color", "icon_focus_color"]:
			# Faction colours are dark (made for card frames): lighten the icon so it reads on the tile.
			tile.add_theme_color_override(state, color.lightened(0.3))
	return tile


## Display name of a faction (localised).
static func faction_name(faction: StringName) -> String:
	return TranslationServer.translate("UI_FACTION_%s" % String(faction).to_upper())


## Starter deck IDs in faction order.
static func ordered_decks(deck_ids: Array[StringName]) -> Array[StringName]:
	var ordered: Array[StringName] = []
	for faction: StringName in FACTION_ORDER:
		var deck_id := StringName("%s_starter" % faction)
		if deck_ids.has(deck_id):
			ordered.append(deck_id)
	for deck_id: StringName in deck_ids:
		if not ordered.has(deck_id):
			ordered.append(deck_id)
	return ordered


static func _tile_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


## A filled, anti-aliased disc (slider grabber).
static func _disc(diameter: int, color: Color) -> ImageTexture:
	var image: Image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var radius: float = diameter / 2.0
	for y: int in diameter:
		for x: int in diameter:
			var distance: float = Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			image.set_pixel(x, y, Color(color, clampf(radius - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
