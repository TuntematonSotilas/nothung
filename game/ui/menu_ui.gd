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
	back.pressed.connect(func() -> void: SceneRouter.request_back())
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
	result.add_theme_font_size_override("font_size", 20)
	for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, Palette.TEXT)
	for state: String in ["normal", "hover"]:
		var style: StyleBoxFlat = _tile_style(Palette.SURFACE if state == "normal" else Palette.SURFACE_RAISED, color, 3)
		style.content_margin_left = 4
		style.content_margin_right = 4
		result.add_theme_stylebox_override(state, style)
	for state: String in ["pressed", "hover_pressed"]:
		var style: StyleBoxFlat = _tile_style(Palette.SURFACE_RAISED, Palette.ACCENT, 5)
		style.content_margin_left = 4
		style.content_margin_right = 4
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


## A short message at the top of the screen with an icon (an achievement claimed, a level reward…):
## it slides down, stays a few seconds, then fades. `icon` names a file of res://ui/icons.
static func toast(screen: Control, text: String, icon: String = "achievements") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Toast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = _tile_style(Palette.SURFACE_RAISED, Palette.ACCENT, 3)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var picture := TextureRect.new()
	picture.name = "ToastIcon"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = "res://ui/icons/%s.svg" % icon
	if ResourceLoader.exists(icon_path):
		picture.texture = load(icon_path) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(72, 72)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.modulate = Palette.ACCENT
	row.add_child(picture)
	var message: Label = label(text, 28, Palette.ACCENT)
	message.name = "ToastText"
	message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A wrapping label needs its width up front, or its first layout makes the toast very tall.
	message.custom_minimum_size.x = maxf(200.0, screen.get_viewport_rect().size.x - 2 * SCREEN_MARGIN - 72 - 20 - 48 - 6)
	row.add_child(message)
	screen.add_child(panel)
	# Full width within the margins, at the top; as tall as its text (offset_bottom = offset_top lets the
	# container grow to its minimum height).
	var top: float = SCREEN_MARGIN + float(SafeArea.insets(screen)["top"])
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = SCREEN_MARGIN
	panel.offset_right = -SCREEN_MARGIN
	panel.offset_top = top
	panel.offset_bottom = top
	var speed: float = maxf(Settings.animation_speed, 0.0)
	var tween: Tween = panel.create_tween()
	if speed > 0.0:
		# Slides down from above the screen.
		panel.modulate.a = 0.0
		panel.position.y = top - 160.0
		tween.set_parallel()
		tween.tween_property(panel, "position:y", top, 0.3 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "modulate:a", 1.0, 0.2 / speed)
		tween.set_parallel(false)
	tween.tween_interval(3.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)
	return panel


## The player level: "Level 7", a gold XP bar and "45 / 80 XP" ("Max level" at the last one).
## `leading` (optional, e.g. the XP rune of the main menu) sits on the left of the bar, centred on it.
static func level_bar(width: int = 300, leading: Control = null) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "LevelBar"
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size.x = width
	var current: int = PlayerLevel.level()
	var progress: Vector2i = PlayerLevel.progress()
	var title: Label = label("", 26, Palette.ACCENT)
	title.name = "LevelLabel"
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = TranslationServer.translate("UI_LEVEL").format({"level": current})
	box.add_child(title)
	var bar := ProgressBar.new()
	bar.name = "XpBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 14)
	bar.max_value = maxi(1, progress.y)
	bar.value = bar.max_value if progress.y == 0 else progress.x
	for part: String in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.SURFACE_RAISED if part == "background" else Palette.ACCENT
		style.set_corner_radius_all(7)
		bar.add_theme_stylebox_override(part, style)
	if leading == null:
		box.add_child(bar)
	else:
		var row := HBoxContainer.new()
		row.name = "XpRow"
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		leading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(leading)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
	var amount: Label = label("", 20, Palette.TEXT_MUTED)
	amount.name = "XpAmount"
	amount.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if progress.y == 0:
		amount.text = TranslationServer.translate("UI_LEVEL_MAX")
	else:
		amount.text = TranslationServer.translate("UI_XP_PROGRESS").format({"xp": progress.x, "needed": progress.y})
	box.add_child(amount)
	return box


## Calls for attention with an icon that wiggles (rotates left and right a few times), then rests,
## in a loop; the rest of the button stays still. Nothing at animation speed 0. Returns the tween.
static func wiggle(icon: Control) -> Tween:
	if Settings.animation_speed <= 0.0:
		return null
	# Turn around the centre, whatever the size the container gives it.
	icon.resized.connect(func() -> void: icon.pivot_offset = icon.size / 2.0)
	var tween: Tween = icon.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for angle: float in [-14.0, 12.0, -9.0, 6.0, -3.0, 0.0]:
		tween.tween_property(icon, "rotation_degrees", angle, 0.09)
	tween.tween_interval(1.4)
	return tween


## A centred icon over a button (instead of Button.icon), so it can move on its own (wiggle()).
static func button_icon(button: Button, icon_name: String, tint: Color, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = load("res://ui/icons/%s.svg" % icon_name) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -icon_size / 2.0
	icon.offset_top = -icon_size / 2.0
	icon.offset_right = icon_size / 2.0
	icon.offset_bottom = icon_size / 2.0
	button.add_child(icon)
	return icon


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


## The player's Rhinegold: value in gold, caption under it (right of a screen header).
static func rhinegold_counter() -> Control:
	var box := VBoxContainer.new()
	box.name = "RhinegoldCounter"
	box.add_theme_constant_override("separation", 0)
	var value: Label = label(str(SaveManager.rhinegold()), 34, Palette.ACCENT)
	value.name = "RhinegoldValue"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(value)
	var caption: Label = label("UI_RHINEGOLD", 18, Palette.TEXT_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(caption)
	return box


## The player's decks that can be played (no DeckRules problem), in slot order.
static func playable_decks() -> Array[Dictionary]:
	var playable: Array[Dictionary] = []
	for entry: Dictionary in SaveManager.decks():
		if DeckRules.problems(entry, CardDatabase, SaveManager.owned_count).is_empty():
			playable.append(entry)
	return playable


## The current deck: the last one chosen (Settings.quick_match_deck) if it can be played, else the first
## deck ready to play; {} when there is none.
static func current_deck() -> Dictionary:
	var playable: Array[Dictionary] = playable_decks()
	for entry: Dictionary in playable:
		if str(entry["id"]) == Settings.quick_match_deck:
			return entry
	return playable[0] if not playable.is_empty() else {}


## A player deck's own name, or its faction's when it has none (the Leader is shown next to it).
static func deck_name(entry: Dictionary) -> String:
	var custom: String = str(entry.get("name", "")).strip_edges()
	if not custom.is_empty():
		return custom
	var leader: LeaderData = CardDatabase.get_leader(StringName(str(entry.get("leader", ""))))
	return faction_name(leader.faction) if leader != null else "?"


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
