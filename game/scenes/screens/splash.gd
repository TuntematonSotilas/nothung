extends Control

const EMBLEM_COLOR: Color = Color(Palette.ACCENT, 0.9)
const EMBLEM_GLOW: Color = Color(Palette.ACCENT, 0.12)

@onready var background: ColorRect = %Background
@onready var content: VBoxContainer = %Content
@onready var start_button: Button = %StartButton


func _ready() -> void:
	background.color = Palette.BG
	content.modulate.a = 0.0
	start_button.pressed.connect(_on_start_pressed)
	var fade_in: Tween = create_tween()
	fade_in.tween_property(content, "modulate:a", 1.0, 1.0)


## The title screen opens the main menu, which becomes the root of the back history.
func _on_start_pressed() -> void:
	SceneRouter.go_to("res://scenes/screens/main_menu.tscn", false)


func _draw() -> void:
	var center: Vector2 = size * Vector2(0.5, 0.36)
	var radius: float = minf(size.x, size.y) * 0.105

	draw_arc(center, radius, 0.0, TAU, 96, EMBLEM_GLOW, 2.0, true)
	draw_arc(center, radius * 0.86, 0.0, TAU, 96, EMBLEM_COLOR, 1.0, true)
	draw_circle(center, radius * 0.045, EMBLEM_COLOR)

	var blade_top: Vector2 = center + Vector2(0.0, -radius * 0.57)
	var blade_base: Vector2 = center + Vector2(0.0, radius * 0.34)
	draw_colored_polygon(
		PackedVector2Array(
			[
				blade_top,
				blade_base + Vector2(-radius * 0.06, 0.0),
				blade_base,
				blade_base + Vector2(radius * 0.06, 0.0),
			]
		),
		EMBLEM_COLOR
	)
	draw_line(
		center + Vector2(-radius * 0.32, radius * 0.34),
		center + Vector2(radius * 0.32, radius * 0.34),
		EMBLEM_COLOR,
		radius * 0.045,
		true
	)
	draw_line(
		center + Vector2(0.0, radius * 0.34),
		center + Vector2(0.0, radius * 0.58),
		EMBLEM_COLOR,
		radius * 0.055,
		true
	)
