class_name PressPick
extends Timer

## Tap or pick up a button that sits in a ScrollContainer. A short tap emits `tapped`. With a finger,
## holding still for DELAY picks it up (moving first is a scroll); with a mouse, which does not scroll by
## dragging, moving picks it up at once. While carried, the button keeps the pointer's moves to itself
## (no scrolling); lifting emits `released` with the pointer position.

signal tapped
signal picked
signal released(position: Vector2)

const DELAY: float = 0.25
const MOVE_TOLERANCE: float = 12.0

## The pointer's last position (viewport coordinates), from the input events themselves.
static var pointer: Vector2 = Vector2.ZERO

## Whether a press picks the button up (otherwise only taps count).
var pick_enabled: bool = true
var _button: Control
var _scroll: ScrollContainer
var _pressing: bool = false
var _picked: bool = false
var _start: Vector2
var _scroll_at_press: int = 0


static func attach(button: BaseButton, scroll: ScrollContainer, can_pick: bool = true) -> PressPick:
	var press := PressPick.new()
	press.one_shot = true
	press.wait_time = DELAY
	press.pick_enabled = can_pick
	press._button = button
	press._scroll = scroll
	button.add_child(press)
	button.button_down.connect(press._on_down)
	button.button_up.connect(press._on_up)
	button.pressed.connect(press._on_pressed)
	press.timeout.connect(press._on_hold)
	return press


func is_carrying() -> bool:
	return _picked


func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer = event.position
	if not _pressing or _picked or not pick_enabled:
		return
	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and event.position.distance_to(_start) > MOVE_TOLERANCE:
		if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
			# A real mouse: dragging is never a scroll.
			_pick()
		else:
			# A finger moving before the hold ends is a scroll.
			stop()


func _on_down() -> void:
	_pressing = true
	_picked = false
	_start = pointer
	_scroll_at_press = _scroll.scroll_vertical if _scroll != null else 0
	if pick_enabled:
		start()


func _on_hold() -> void:
	if _pressing and not _picked:
		_pick()


## Carried: the button stops passing the pointer's moves to the ScrollContainer, so it does not scroll.
func _pick() -> void:
	stop()
	_picked = true
	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	picked.emit()


func _on_up() -> void:
	_pressing = false
	stop()
	if _picked:
		_button.mouse_filter = Control.MOUSE_FILTER_PASS
		released.emit(pointer)


func _on_pressed() -> void:
	if _picked:
		_picked = false
		return
	var scrolled: int = absi((_scroll.scroll_vertical if _scroll != null else 0) - _scroll_at_press)
	if scrolled <= MOVE_TOLERANCE:
		tapped.emit()
