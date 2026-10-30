extends Control

## Main menu, from top to bottom: Nibelheim (forge icon, with the Rhinegold) on the left and Settings
## (cog) on the right; the title; the current deck (Leader portrait, name, Leader — a tap chooses
## another deck ready to play) with My decks under it; Campaign (greyed out until it exists) and Quick
## match side by side; Collection, smaller, at the bottom.
## The Android back button quits from here (the menu is the root of the history).
## An interrupted match (SaveManager) is offered first: Resume or Abandon.

const QUICK_MATCH_SCENE: String = "res://scenes/screens/quick_match.tscn"
const SETTINGS_SCENE: String = "res://scenes/screens/settings_menu.tscn"
const COLLECTION_SCENE: String = "res://scenes/screens/collection.tscn"
const DECKS_SCENE: String = "res://scenes/screens/deck_list.tscn"
const NIBELHEIM_SCENE: String = "res://scenes/screens/nibelheim.tscn"
const DUEL_SCENE: String = "res://scenes/screens/duel.tscn"
const PORTRAIT_SIZE: Vector2 = Vector2(300, 390)
const PORTRAIT_BORDER: int = 5
const PORTRAIT_RADIUS: int = 18


func _ready() -> void:
	_build()
	if SaveManager.has_match():
		_offer_resume()


func _build() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 28)

	var top := HBoxContainer.new()
	top.name = "TopBar"
	column.add_child(top)
	var forge := VBoxContainer.new()
	forge.add_theme_constant_override("separation", 4)
	top.add_child(forge)
	var nibelheim: Button = _icon_button("UI_NIBELHEIM", "nibelheim", Palette.ACCENT)
	nibelheim.name = "NibelheimButton"
	nibelheim.pressed.connect(func() -> void: SceneRouter.go_to(NIBELHEIM_SCENE))
	forge.add_child(nibelheim)
	var rhinegold: Label = MenuUI.label("", 24, Palette.ACCENT)
	rhinegold.name = "RhinegoldLabel"
	rhinegold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rhinegold.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rhinegold.text = "%d %s" % [SaveManager.rhinegold(), tr("UI_RHINEGOLD")]
	forge.add_child(rhinegold)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var settings: Button = _icon_button("", "settings", Palette.TEXT)
	settings.name = "SettingsButton"
	settings.tooltip_text = "UI_SETTINGS"
	settings.custom_minimum_size = Vector2(96, 96)
	settings.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings.pressed.connect(func() -> void: SceneRouter.go_to(SETTINGS_SCENE))
	top.add_child(settings)

	var title: Label = MenuUI.label("UI_APP_NAME", 80, Palette.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle: Label = MenuUI.label("UI_APP_SUBTITLE", 26, Palette.ACCENT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 20)
	column.add_child(middle)
	middle.add_child(_current_deck())
	var decks: Button = MenuUI.button("UI_MY_DECKS", 88, 28)
	decks.name = "MyDecksButton"
	decks.custom_minimum_size.x = 420
	decks.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	decks.pressed.connect(func() -> void: SceneRouter.go_to(DECKS_SCENE))
	middle.add_child(decks)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 20)
	column.add_child(modes)
	var campaign: Button = MenuUI.button("UI_CAMPAIGN", 120, 32)
	campaign.name = "CampaignButton"
	campaign.disabled = true
	campaign.tooltip_text = "UI_COMING_SOON"
	campaign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(campaign)
	var quick_match: Button = MenuUI.button("UI_QUICK_MATCH", 120, 32)
	quick_match.name = "QuickMatchButton"
	quick_match.theme_type_variation = &"ButtonPrimary"
	quick_match.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_match.pressed.connect(func() -> void: SceneRouter.go_to(QUICK_MATCH_SCENE))
	modes.add_child(quick_match)
	var soon: Label = MenuUI.label("UI_COMING_SOON_HINT", 22, Palette.TEXT_MUTED)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(soon)

	var collection: Button = MenuUI.button("UI_COLLECTION", 72, 24)
	collection.name = "CollectionButton"
	collection.custom_minimum_size.x = 320
	collection.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	collection.pressed.connect(func() -> void: SceneRouter.go_to(COLLECTION_SCENE))
	column.add_child(collection)


## Icon (from ui/icons, tinted) and optional text.
func _icon_button(text_key: String, icon_name: String, tint: Color) -> Button:
	var button: Button = MenuUI.button(text_key, 88, 26)
	button.icon = load("res://ui/icons/%s.svg" % icon_name) as Texture2D
	# Next to a text the icon keeps its own size, capped; alone it fills the button.
	button.expand_icon = text_key.is_empty()
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if not text_key.is_empty() else HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 52)
	button.add_theme_constant_override("h_separation", 14)
	for state: String in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(state, tint)
	return button


## The deck Quick match will play: the Leader portrait framed in the faction colour, then — unframed —
## deck name, Leader and "Tap to change". A tap anywhere on it opens the choice among the decks ready to
## play. Without one, says where to complete a deck.
func _current_deck() -> Control:
	var entry: Dictionary = MenuUI.current_deck()
	var panel := Button.new()
	panel.name = "CurrentDeck"
	panel.custom_minimum_size = PORTRAIT_SIZE + Vector2(0, 130)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.focus_mode = Control.FOCUS_NONE
	var leader: LeaderData = CardDatabase.get_leader(StringName(str(entry.get("leader", ""))))
	var faction: StringName = leader.faction if leader != null else &"neutral"
	var colors: Dictionary = CardPalette.FACTIONS[faction]
	# The button draws nothing itself: only the portrait has a frame.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		panel.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	content.add_child(_portrait(leader, colors))
	if entry.is_empty():
		var none: Label = MenuUI.label("UI_NO_PLAYABLE_DECK", 22, Palette.LIFE)
		none.name = "NoPlayableDeck"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.custom_minimum_size.x = PORTRAIT_SIZE.x - 20
		content.add_child(none)
		panel.pressed.connect(func() -> void: SceneRouter.go_to(DECKS_SCENE))
		return panel
	var deck_name: Label = MenuUI.label(MenuUI.deck_name(entry), 30, Palette.TEXT)
	deck_name.name = "CurrentDeckName"
	deck_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	deck_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_name.clip_text = true
	content.add_child(deck_name)
	var leader_name: Label = MenuUI.label("LEADER_%s_NAME" % String(leader.id).to_upper(), 24, Palette.TEXT_MUTED)
	leader_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(leader_name)
	var change: Label = MenuUI.label("UI_CHANGE_DECK", 20, Palette.ACCENT)
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wraps instead of widening the panel past the portrait (long languages).
	change.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	change.custom_minimum_size.x = PORTRAIT_SIZE.x - 16
	content.add_child(change)
	panel.pressed.connect(_choose_deck)
	return panel


## The Leader's art, or the faction icon on the faction colour until the art exists; framed in the
## faction colour.
func _portrait(leader: LeaderData, colors: Dictionary) -> Control:
	var frame := Control.new()
	frame.name = "PortraitFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = PORTRAIT_SIZE
	# The picture is clipped to a rounded shape, then the rounded border is drawn over it: both follow
	# the same curve.
	var mask := Panel.new()
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fill := StyleBoxFlat.new()
	fill.bg_color = (colors["frame"] as Color).darkened(0.55)
	fill.set_corner_radius_all(PORTRAIT_RADIUS)
	fill.anti_aliasing = true
	mask.add_theme_stylebox_override("panel", fill)
	frame.add_child(mask)
	var picture := TextureRect.new()
	picture.name = "LeaderPortrait"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if leader != null and leader.art != null:
		picture.texture = leader.art
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		var faction: String = String(leader.faction) if leader != null else "neutral"
		picture.texture = load("res://ui/icons/faction_%s.svg" % faction) as Texture2D
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.modulate = (colors["frame"] as Color).lightened(0.35)
		picture.offset_left = 80
		picture.offset_right = -80
		picture.offset_top = 100
		picture.offset_bottom = -100
	mask.add_child(picture)
	var border := Panel.new()
	border.name = "PortraitBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var line := StyleBoxFlat.new()
	line.draw_center = false
	line.border_color = colors["frame"]
	line.set_border_width_all(PORTRAIT_BORDER)
	line.set_corner_radius_all(PORTRAIT_RADIUS)
	line.anti_aliasing = true
	border.add_theme_stylebox_override("panel", line)
	frame.add_child(border)
	return frame


## Modal: one tile per deck ready to play; the choice becomes the current deck (Quick match's).
func _choose_deck() -> void:
	var overlay := ColorRect.new()
	overlay.name = "DeckPicker"
	overlay.color = Color(Palette.BG, 0.98)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(margin)
	SafeArea.pad(margin, {"left": MenuUI.SCREEN_MARGIN, "top": MenuUI.SCREEN_MARGIN, "right": MenuUI.SCREEN_MARGIN, "bottom": MenuUI.SCREEN_MARGIN})
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	var title: Label = MenuUI.label("UI_CHOOSE_DECK", 36, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var current: String = str(MenuUI.current_deck().get("id", ""))
	for entry: Dictionary in MenuUI.playable_decks():
		var leader: LeaderData = CardDatabase.get_leader(StringName(str(entry["leader"])))
		var text: String = "%s\n%s" % [MenuUI.deck_name(entry), tr("LEADER_%s_NAME" % String(leader.id).to_upper())]
		var tile: Button = MenuUI.choice_tile(text, CardPalette.FACTIONS[leader.faction]["frame"], 130, "res://ui/icons/faction_%s.svg" % leader.faction)
		tile.name = "Pick_%s" % entry["id"]
		tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tile.button_pressed = str(entry["id"]) == current
		tile.pressed.connect(func() -> void:
			Settings.quick_match_deck = str(entry["id"])
			Settings.save_settings()
			overlay.queue_free()
			_rebuild())
		list.add_child(tile)
	var cancel: Button = MenuUI.button("UI_CANCEL")
	cancel.name = "CancelDeckButton"
	cancel.pressed.connect(overlay.queue_free)
	content.add_child(cancel)


func _rebuild() -> void:
	for child: Node in get_children():
		if child.name != "ResumePrompt":
			remove_child(child)
			child.queue_free()
	_build()


## Replays the saved match first: one that no longer replays (update, unknown card, rejected action)
## is set aside and explained instead of being offered.
func _offer_resume() -> void:
	var record: MatchRecord = MatchRecord.from_dict(SaveManager.load_match())
	if record == null or record.replay(CardDatabase) == null:
		SaveManager.keep_failed_match()
		_show_prompt("UI_RESUME_FAILED", [["UI_CLOSE", "CloseResumeFailedButton", true, Callable()]])
		return
	_show_prompt("UI_RESUME_MATCH_TEXT", [
		["UI_RESUME", "ResumeMatchButton", true, _resume.bind(record)],
		["UI_ABANDON", "AbandonMatchButton", false, SaveManager.delete_match],
	], "UI_RESUME_MATCH_TITLE")


func _resume(record: MatchRecord) -> void:
	var decks: Array[DeckData] = record.rebuild_decks(CardDatabase)
	var setup := DuelSetup.new(decks[0], decks[1], record.difficulty as AIProfile.Difficulty)
	setup.resume = record
	# Only Quick matches are saved for now.
	setup.rewards = true
	DuelSetup.next = setup
	SceneRouter.go_to(DUEL_SCENE)


## Modal panel over the menu; every button closes it, then runs its action.
## buttons: [text key, node name, primary, action].
func _show_prompt(text_key: String, buttons: Array, title_key: String = "") -> void:
	var overlay := ColorRect.new()
	overlay.name = "ResumePrompt"
	overlay.color = Color(Palette.BG, 0.9)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 820
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, Palette.ACCENT, 3)
	style.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	panel.add_child(content)
	if not title_key.is_empty():
		var title: Label = MenuUI.label(title_key, 40, Palette.ACCENT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(title)
	var text: Label = MenuUI.label(text_key, 28)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text)
	for entry: Array in buttons:
		var button: Button = MenuUI.button(entry[0])
		button.name = entry[1]
		if entry[2]:
			button.theme_type_variation = &"ButtonPrimary"
		var action: Callable = entry[3]
		button.pressed.connect(func() -> void:
			overlay.queue_free()
			if action.is_valid():
				action.call())
		content.add_child(button)
