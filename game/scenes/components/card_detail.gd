class_name CardDetail
extends ColorRect

## A card shown large over the screen, with its flavour and lines given by the screen (copies owned…),
## and optional buttons under it. Tapping outside the buttons closes it.


## `lines`: already translated texts. `buttons`: [{text, name, action, disabled}] — a button runs its
## action, then closes the detail.
static func open(parent: Node, data: CardData, lines: Array[String], buttons: Array[Dictionary] = []) -> CardDetail:
	var overlay := CardDetail.new()
	overlay.name = "CardDetail"
	overlay.color = Color(Palette.BG, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.is_pressed():
			overlay.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 24)
	center.add_child(content)
	var view := CardView.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_view_scale(2.6)
	view.set_card(data, null, false, -1, "hand", false)
	content.add_child(view)
	var flavour_key: String = "CARD_%s_FLAVOUR" % String(data.id).to_upper()
	if TranslationServer.translate(flavour_key) != flavour_key:
		var flavour: Label = MenuUI.label(flavour_key, 26, Palette.TEXT_MUTED)
		flavour.custom_minimum_size.x = view.custom_minimum_size.x
		flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(flavour)
	for index: int in lines.size():
		var line: Label = MenuUI.label(lines[index], 28, Palette.ACCENT)
		line.name = "Line%d" % index
		line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.custom_minimum_size.x = view.custom_minimum_size.x
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(line)
	for spec: Dictionary in buttons:
		var button: Button = MenuUI.button(spec["text"])
		button.name = spec["name"]
		button.disabled = spec.get("disabled", false)
		if spec.get("primary", false):
			button.theme_type_variation = &"ButtonPrimary"
		var action: Callable = spec["action"]
		button.pressed.connect(func() -> void:
			overlay.queue_free()
			action.call())
		content.add_child(button)
	return overlay
