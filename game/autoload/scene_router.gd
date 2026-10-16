extends CanvasLayer
## Screen transitions with a fade, history for the Android back button.
## See docs/technical/06-ui-implementation.md#scene-composition.

signal screen_changed(scene_path: String)

const FADE_DURATION: float = 0.2

var _history: PackedStringArray = []
var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(Palette.BG, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not go_back():
		get_tree().quit()


## Opens a screen; the current one is kept in the history unless `remember` is false.
func go_to(scene_path: String, remember: bool = true) -> void:
	if _busy:
		return
	_busy = true
	var current: Node = get_tree().current_scene
	if remember and current != null and not current.scene_file_path.is_empty():
		_history.append(current.scene_file_path)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _tween_fade(1.0)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _tween_fade(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	screen_changed.emit(scene_path)


## Returns to the previous screen. False when there is none (the caller may quit).
func go_back() -> bool:
	if _history.is_empty():
		return false
	var previous: String = _history[_history.size() - 1]
	_history.remove_at(_history.size() - 1)
	go_to(previous, false)
	return true


func clear_history() -> void:
	_history.clear()


func history_size() -> int:
	return _history.size()


func _tween_fade(alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_DURATION)
	await tween.finished
