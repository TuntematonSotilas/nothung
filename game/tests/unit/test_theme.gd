extends GdUnitTestSuite
## main_theme.tres can't reference Palette constants, so this keeps the two in sync.

const THEME_PATH: String = "res://ui/theme/main_theme.tres"

var _theme: Theme


func before() -> void:
	_theme = load(THEME_PATH)


func test_project_uses_main_theme() -> void:
	assert_str(ProjectSettings.get_setting("gui/theme/custom")).is_equal(THEME_PATH)


func test_text_colours_match_palette() -> void:
	_assert_same(_theme.get_color("font_color", "Label"), Palette.TEXT)
	_assert_same(_theme.get_color("font_color", "LabelAccent"), Palette.ACCENT)
	_assert_same(_theme.get_color("font_color", "LabelMuted"), Palette.TEXT_MUTED)
	_assert_same(_theme.get_color("font_disabled_color", "Button"), Palette.TEXT_DISABLED)
	_assert_same(_theme.get_color("font_color", "ButtonPrimary"), Palette.INK)


func test_surfaces_match_palette() -> void:
	_assert_same(_stylebox_colour("normal", "Button"), Palette.SURFACE_RAISED)
	_assert_same(_stylebox_colour("pressed", "Button"), Palette.ACCENT_PRESSED)
	_assert_same(_stylebox_colour("normal", "ButtonPrimary"), Palette.ACCENT)
	_assert_same(_stylebox_colour("hover", "ButtonPrimary"), Palette.ACCENT_HOVER)
	_assert_same(_stylebox_colour("panel", "PanelContainer"), Palette.SURFACE)
	_assert_same(_stylebox_colour("panel", "PopupMenu"), Palette.SURFACE)


func _stylebox_colour(style: String, type: String) -> Color:
	var box: StyleBoxFlat = _theme.get_stylebox(style, type) as StyleBoxFlat
	return box.bg_color


func _assert_same(actual: Color, expected: Color) -> void:
	assert_str(actual.to_html(false)).is_equal(expected.to_html(false))
