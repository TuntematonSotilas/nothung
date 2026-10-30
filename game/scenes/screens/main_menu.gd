extends Control

## Main menu: Quick match, Collection and Settings, with the Rhinegold counter; Campaign is shown greyed
## out until it exists.
## The Android back button quits from here (the menu is the root of the history).
## An interrupted match (SaveManager) is offered first: Resume or Abandon.

const QUICK_MATCH_SCENE: String = "res://scenes/screens/quick_match.tscn"
const SETTINGS_SCENE: String = "res://scenes/screens/settings_menu.tscn"
const COLLECTION_SCENE: String = "res://scenes/screens/collection.tscn"
const DUEL_SCENE: String = "res://scenes/screens/duel.tscn"


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 32)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var title: Label = MenuUI.label("UI_APP_NAME", 96, Palette.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle: Label = MenuUI.label("UI_APP_SUBTITLE", 30, Palette.ACCENT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var rhinegold: Label = MenuUI.label("", 30, Palette.ACCENT)
	rhinegold.name = "RhinegoldLabel"
	rhinegold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rhinegold.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rhinegold.text = "%d %s" % [SaveManager.rhinegold(), tr("UI_RHINEGOLD")]
	column.add_child(rhinegold)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 60)
	column.add_child(gap)

	var quick_match: Button = MenuUI.button("UI_QUICK_MATCH", 120, 34)
	quick_match.name = "QuickMatchButton"
	quick_match.theme_type_variation = &"ButtonPrimary"
	quick_match.pressed.connect(func() -> void: SceneRouter.go_to(QUICK_MATCH_SCENE))
	column.add_child(quick_match)
	var campaign: Button = MenuUI.button("UI_CAMPAIGN")
	campaign.name = "CampaignButton"
	campaign.disabled = true
	campaign.tooltip_text = "UI_COMING_SOON"
	column.add_child(campaign)
	var collection: Button = MenuUI.button("UI_COLLECTION")
	collection.name = "CollectionButton"
	collection.pressed.connect(func() -> void: SceneRouter.go_to(COLLECTION_SCENE))
	column.add_child(collection)
	var settings: Button = MenuUI.button("UI_SETTINGS")
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: SceneRouter.go_to(SETTINGS_SCENE))
	column.add_child(settings)
	var soon: Label = MenuUI.label("UI_COMING_SOON_HINT", 24, Palette.TEXT_MUTED)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(soon)
	if SaveManager.has_match():
		_offer_resume()


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
