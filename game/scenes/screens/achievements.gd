extends Control

## Achievements: one row per achievement (Achievements.LIST) — the trophy icon (gold once unlocked),
## name, what to do, progress ("3 / 10") or Unlocked, and the Rhinegold it pays. Opened from the main
## menu's trophy. See docs/functional/06-progression.md#achievements.


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 24)
	column.add_child(MenuUI.header("UI_ACHIEVEMENTS", MenuUI.rhinegold_counter()))
	var done: int = 0
	for achievement: Dictionary in Achievements.LIST:
		if Achievements.is_unlocked(achievement["id"]):
			done += 1
	var count: Label = MenuUI.label("", 26, Palette.TEXT_MUTED)
	count.name = "AchievementCount"
	count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.text = tr("UI_ACHIEVEMENTS_COUNT").format({"done": done, "total": Achievements.LIST.size()})
	column.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "AchievementList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	# Fills the scroll's height, centred vertically (it scrolls once taller than the screen).
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(list)
	for achievement: Dictionary in Achievements.LIST:
		list.add_child(_row(achievement))


func _row(achievement: Dictionary) -> PanelContainer:
	var achievement_id: String = achievement["id"]
	var unlocked: bool = Achievements.is_unlocked(achievement_id)
	var row := PanelContainer.new()
	row.name = "Achievement_%s" % achievement_id
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, Palette.ACCENT if unlocked else Palette.BORDER, 3)
	style.set_content_margin_all(18)
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	row.add_child(line)

	var icon := TextureRect.new()
	icon.texture = load("res://ui/icons/achievements.svg") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = Palette.ACCENT if unlocked else Color(Palette.TEXT_MUTED, 0.45)
	line.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	line.add_child(texts)
	var title: Label = MenuUI.label("ACHIEVEMENT_%s_NAME" % achievement_id.to_upper(), 28, Palette.ACCENT if unlocked else Palette.TEXT)
	texts.add_child(title)
	var description: Label = MenuUI.label("ACHIEVEMENT_%s_DESC" % achievement_id.to_upper(), 22, Palette.TEXT_MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(description)

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(right)
	var state: Label = MenuUI.label("", 24, Palette.ACCENT if unlocked else Palette.TEXT)
	state.name = "Progress"
	state.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.text = tr("UI_ACHIEVEMENT_DONE") if unlocked else "%d / %d" % [Achievements.progress(achievement), int(achievement["target"])]
	right.add_child(state)
	var reward: Label = MenuUI.label("", 22, Palette.TEXT_MUTED)
	reward.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.text = tr("UI_REWARD").format({"amount": achievement["reward"]})
	right.add_child(reward)
	return row
