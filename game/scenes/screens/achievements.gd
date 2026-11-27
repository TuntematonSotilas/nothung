extends Control

## Reached achievements wait here to be claimed manually for Rhinegold and XP.

var _count: Label
var _list: VBoxContainer

func _ready() -> void:
	Achievements.refresh_reached()
	var column: VBoxContainer = MenuUI.screen_column(self, 24)
	column.add_child(MenuUI.header("UI_ACHIEVEMENTS", MenuUI.rhinegold_counter()))
	_count = MenuUI.label("", 26, Palette.TEXT_MUTED)
	_count.name = "AchievementCount"
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "AchievementList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	# Fills the scroll's height, centred vertically (it scrolls once taller than the screen).
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(_list)
	_refresh()


func _refresh() -> void:
	var claimed: int = 0
	for achievement: Dictionary in Achievements.LIST:
		if Achievements.is_unlocked(achievement["id"]):
			claimed += 1
	_count.text = tr("UI_ACHIEVEMENTS_COUNT").format({"done": claimed, "total": Achievements.LIST.size()})
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for achievement: Dictionary in Achievements.LIST:
		_list.add_child(_row(achievement))


func _claim(achievement_id: String) -> void:
	var change: Dictionary = Achievements.claim(achievement_id)
	if change.is_empty():
		return
	var lines: PackedStringArray = [Achievements.claimed_text(achievement_id)]
	lines.append(tr("UI_XP_GAINED").format({"amount": change["level"]["xp"]}))
	for reached: Variant in change["level"]["levels"]:
		lines.append(PlayerLevel.level_up_text(reached))
	MenuUI.toast(self, "\n".join(lines))
	_refresh()


func _row(achievement: Dictionary) -> PanelContainer:
	var achievement_id: String = achievement["id"]
	var unlocked: bool = Achievements.is_unlocked(achievement_id)
	var claimable: bool = Achievements.is_claimable(achievement_id)
	var row := PanelContainer.new()
	row.name = "Achievement_%s" % achievement_id
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, Palette.ACCENT if unlocked or claimable else Palette.BORDER, 3)
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
	icon.modulate = Palette.ACCENT if unlocked or claimable else Color(Palette.TEXT_MUTED, 0.45)
	line.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	line.add_child(texts)
	var title: Label = MenuUI.label("ACHIEVEMENT_%s_NAME" % achievement_id.to_upper(), 28, Palette.ACCENT if unlocked or claimable else Palette.TEXT)
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
	if unlocked:
		state.text = tr("UI_ACHIEVEMENT_DONE")
	elif claimable:
		state.text = tr("UI_ACHIEVEMENT_CLAIMABLE")
	else:
		state.text = "%d / %d" % [Achievements.progress(achievement), Achievements.target(achievement)]
	right.add_child(state)
	var reward: Label = MenuUI.label("", 22, Palette.TEXT_MUTED)
	reward.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.text = "%s · %s" % [tr("UI_REWARD").format({"amount": achievement["reward"]}),
			tr("UI_XP_GAINED").format({"amount": PlayerLevel.XP_ACHIEVEMENT})]
	right.add_child(reward)
	if claimable:
		var claim: Button = MenuUI.button("", 64, 20)
		claim.name = "ClaimButton"
		claim.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		claim.text = tr("UI_ACHIEVEMENT_CLAIM").format({"amount": achievement["reward"]})
		claim.theme_type_variation = &"ButtonPrimary"
		claim.pressed.connect(_claim.bind(achievement_id))
		right.add_child(claim)
	return row
