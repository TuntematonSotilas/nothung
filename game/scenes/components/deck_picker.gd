class_name DeckPicker
extends RefCounted

## Full-screen choice of the current deck among the decks ready to play (MenuUI.playable_decks()), the
## current one highlighted. Picking one makes it the current deck (Settings.quick_match_deck, saved),
## closes the picker and calls `on_chosen`; Cancel only closes it. Used by the main menu and Quick match.


static func open(parent: Node, on_chosen: Callable) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "DeckPicker"
	overlay.color = Color(Palette.BG, 0.98)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(margin)
	SafeArea.pad(margin, {"left": MenuUI.SCREEN_MARGIN, "top": MenuUI.SCREEN_MARGIN, "right": MenuUI.SCREEN_MARGIN, "bottom": MenuUI.SCREEN_MARGIN})
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	var title: Label = MenuUI.label("UI_CHOOSE_DECK", 36, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var current: String = str(MenuUI.current_deck().get("id", ""))
	for entry: Dictionary in MenuUI.playable_decks():
		var leader: LeaderData = CardDatabase.get_leader(StringName(str(entry["leader"])))
		var text: String = "%s\n%s" % [MenuUI.deck_name(entry), TranslationServer.translate("LEADER_%s_NAME" % String(leader.id).to_upper())]
		var tile: Button = MenuUI.choice_tile(text, CardPalette.FACTIONS[leader.faction]["frame"], 130, "res://ui/icons/faction_%s.svg" % leader.faction)
		tile.name = "Pick_%s" % entry["id"]
		tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tile.button_pressed = str(entry["id"]) == current
		tile.pressed.connect(func() -> void:
			Settings.quick_match_deck = str(entry["id"])
			Settings.save_settings()
			overlay.queue_free()
			on_chosen.call())
		list.add_child(tile)
	var cancel: Button = MenuUI.button("UI_CANCEL")
	cancel.name = "CancelDeckButton"
	cancel.pressed.connect(overlay.queue_free)
	content.add_child(cancel)
	return overlay
