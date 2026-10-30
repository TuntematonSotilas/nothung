extends Control

## Settings: music and sound-effect volumes, language, reset progress.
## Every change is applied and saved at once (Settings); the screen is rebuilt when the language
## changes, so its own texts follow. Resetting progress asks for confirmation first.

const LANGUAGES: Array[String] = ["", "en", "de", "es", "fr"]
## Language names are written in their own language (not translated).
const LANGUAGE_NAMES: Dictionary = {"en": "English", "de": "Deutsch", "es": "Español", "fr": "Français"}


func _ready() -> void:
	_build()


func _build() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 24)
	column.add_child(MenuUI.header("UI_SETTINGS"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	scroll.add_child(body)

	body.add_child(_section("UI_AUDIO"))
	body.add_child(_volume_row("Music", "UI_MUSIC", Settings.music_volume, Settings.set_music_volume))
	body.add_child(_volume_row("Sfx", "UI_SOUND_EFFECTS", Settings.sfx_volume, Settings.set_sfx_volume))

	body.add_child(_section("UI_LANGUAGE"))
	var languages := GridContainer.new()
	languages.columns = 2
	languages.add_theme_constant_override("h_separation", 16)
	languages.add_theme_constant_override("v_separation", 16)
	for code: String in LANGUAGES:
		var text: String = tr("UI_LANGUAGE_AUTO") if code.is_empty() else LANGUAGE_NAMES[code]
		var tile: Button = _choice(text, "Language_" + (code if not code.is_empty() else "auto"), code == Settings.language)
		tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tile.pressed.connect(_on_language_chosen.bind(code))
		languages.add_child(tile)
	body.add_child(languages)

	body.add_child(_section("UI_PROGRESS"))
	var progress := VBoxContainer.new()
	progress.name = "Progress"
	progress.add_theme_constant_override("separation", 16)
	body.add_child(progress)
	_show_reset_button(progress, false)


func _section(key: String) -> Label:
	return MenuUI.label(key, 26, Palette.TEXT_MUTED)


func _choice(text: String, node_name: String, selected: bool) -> Button:
	var tile: Button = MenuUI.choice_tile(text, Palette.BORDER, 96)
	tile.name = node_name
	tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.button_pressed = selected
	return tile


## Label, slider (0–100 %, steps of 10) and the value; moving the slider applies and saves the volume.
func _volume_row(node_name: String, key: String, volume: float, apply: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var title: Label = MenuUI.label(key, 28)
	title.custom_minimum_size.x = 300
	row.add_child(title)
	var slider: HSlider = MenuUI.slider(roundf(volume * 100.0))
	slider.name = node_name + "Slider"
	row.add_child(slider)
	var value: Label = MenuUI.label("", 28, Palette.TEXT_MUTED)
	value.custom_minimum_size.x = 110
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = "%d %%" % roundi(slider.value)
	row.add_child(value)
	slider.value_changed.connect(func(new_value: float) -> void:
		value.text = "%d %%" % roundi(new_value)
		apply.call(new_value / 100.0))
	return row


func _show_reset_button(box: VBoxContainer, done: bool) -> void:
	_clear(box)
	if done:
		var message: Label = MenuUI.label("UI_PROGRESS_RESET_DONE", 26, Palette.TEXT_MUTED)
		message.name = "ResetDone"
		box.add_child(message)
	var reset: Button = MenuUI.button("UI_RESET_PROGRESS")
	reset.name = "ResetProgressButton"
	reset.pressed.connect(_show_reset_confirmation.bind(box))
	box.add_child(reset)


## Cancel is the highlighted choice: erasing cannot be undone.
func _show_reset_confirmation(box: VBoxContainer) -> void:
	_clear(box)
	var question: Label = MenuUI.label("UI_RESET_PROGRESS_CONFIRM", 26)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(question)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	var cancel: Button = MenuUI.button("UI_CANCEL")
	cancel.name = "CancelResetButton"
	cancel.theme_type_variation = &"ButtonPrimary"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_show_reset_button.bind(box, false))
	buttons.add_child(cancel)
	var erase: Button = MenuUI.button("UI_RESET_PROGRESS_ERASE")
	erase.name = "ConfirmResetButton"
	erase.add_theme_color_override("font_color", Palette.LIFE)
	erase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erase.pressed.connect(func() -> void:
		SaveManager.reset_profile()
		_show_reset_button(box, true))
	buttons.add_child(erase)


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _on_language_chosen(code: String) -> void:
	Settings.set_language(code)
	_rebuild()


## Rebuilt in place, in the new language.
func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_build()
