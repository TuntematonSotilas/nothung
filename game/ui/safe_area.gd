class_name SafeArea
extends RefCounted

## Space taken by the notch / camera cutout and the system bars, in the screen's own units (after the
## canvas_items stretch), so a screen can pad its content out of them. Zero on desktop.


## {left, top, right, bottom} insets for the window showing `node`.
static func insets(node: Node) -> Dictionary:
	var result: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile") or not node.is_inside_tree():
		return result
	var window: Window = node.get_window()
	var window_rect: Rect2i = Rect2i(window.position, window.size)
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window_rect.size.x <= 0 or window_rect.size.y <= 0:
		return result
	# Window pixels → viewport units (the 1080 × 1920 reference, expanded).
	var scale: Vector2 = node.get_viewport().get_visible_rect().size / Vector2(window_rect.size)
	result["left"] = maxf(0.0, safe.position.x - window_rect.position.x) * scale.x
	result["top"] = maxf(0.0, safe.position.y - window_rect.position.y) * scale.y
	result["right"] = maxf(0.0, window_rect.end.x - safe.end.x) * scale.x
	result["bottom"] = maxf(0.0, window_rect.end.y - safe.end.y) * scale.y
	return result


## Adds the insets to a MarginContainer's margins (`base` = the screen's own margin on every side).
static func pad(margin: MarginContainer, base: Dictionary) -> void:
	var inset: Dictionary = insets(margin)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(base[side] + inset[side]))
