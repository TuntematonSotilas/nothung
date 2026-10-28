extends Control

## Main menu: Quick match and Settings; Campaign and Collection are shown greyed out until they exist.
## The Android back button quits from here (the menu is the root of the history).

const QUICK_MATCH_SCENE: String = "res://scenes/screens/quick_match.tscn"
const SETTINGS_SCENE: String = "res://scenes/screens/settings_menu.tscn"


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 32)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var title: Label = MenuUI.label("UI_APP_NAME", 96, Palette.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle: Label = MenuUI.label("UI_APP_SUBTITLE", 30, Palette.ACCENT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 80)
	column.add_child(gap)

	var quick_match: Button = MenuUI.button("UI_QUICK_MATCH", 120, 34)
	quick_match.name = "QuickMatchButton"
	quick_match.theme_type_variation = &"ButtonPrimary"
	quick_match.pressed.connect(func() -> void: SceneRouter.go_to(QUICK_MATCH_SCENE))
	column.add_child(quick_match)
	for key: String in ["UI_CAMPAIGN", "UI_COLLECTION"]:
		var entry: Button = MenuUI.button(key)
		entry.name = key.trim_prefix("UI_").to_pascal_case() + "Button"
		entry.disabled = true
		entry.tooltip_text = "UI_COMING_SOON"
		column.add_child(entry)
	var settings: Button = MenuUI.button("UI_SETTINGS")
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: SceneRouter.go_to(SETTINGS_SCENE))
	column.add_child(settings)
	var soon: Label = MenuUI.label("UI_COMING_SOON_HINT", 24, Palette.TEXT_MUTED)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(soon)
