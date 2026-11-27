extends Control

## Nibelheim, two tabs. Cards: forge cards with Rhinegold — the cards the player can still add copies of
## (up to the copies a deck can hold), each with its price; a tap shows the card large with Forge (greyed
## with what is missing when the Rhinegold is short). Leaders: each Leader's ability and its two powers,
## unlocked from a player level for Rhinegold. Backgrounds: home backgrounds and boards, bought the same
## way. See docs/functional/06-progression.md#meta-currency, #leader-powers and #cosmetics.

const FACTIONS: Array[StringName] = [&"gods", &"nibelungs", &"walsungs", &"valkyries", &"neutral"]

var _filter_bar: CardFilterBar
var _grid: CardGrid
var _header: HBoxContainer
var _cards_tab: VBoxContainer
var _leaders_tab: ScrollContainer
var _leader_list: VBoxContainer
var _backgrounds_tab: ScrollContainer
var _background_list: GridContainer


func _ready() -> void:
	var column: VBoxContainer = MenuUI.screen_column(self, 20)
	_header = MenuUI.header("UI_NIBELHEIM", MenuUI.rhinegold_counter())
	column.add_child(_header)
	var intro: Label = MenuUI.label("UI_NIBELHEIM_INTRO", 24, Palette.TEXT_MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for tab: Array in [["CardsTab", "UI_TAB_CARDS"], ["LeadersTab", "UI_TAB_LEADERS"], ["BackgroundsTab", "UI_TAB_BACKGROUNDS"]]:
		var chip: Button = MenuUI.chip(tab[1])
		chip.name = tab[0]
		chip.button_group = group
		chip.add_theme_font_size_override("font_size", 26)
		chip.pressed.connect(show_tab.bind(tabs.get_child_count()))
		tabs.add_child(chip)
	(tabs.get_child(0) as Button).button_pressed = true

	_cards_tab = VBoxContainer.new()
	_cards_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_tab.add_theme_constant_override("separation", 20)
	column.add_child(_cards_tab)
	_filter_bar = CardFilterBar.new(FACTIONS)
	_filter_bar.changed.connect(_apply_filters)
	_cards_tab.add_child(_filter_bar)
	_grid = CardGrid.new(get_viewport_rect().size.x - 2 * MenuUI.SCREEN_MARGIN)
	_grid.card_tapped.connect(_show_forge)
	_cards_tab.add_child(_grid)
	for data: CardData in CardGrid.sorted_cards(CardDatabase.card_ids(), FACTIONS):
		_grid.add_card(data)

	_leaders_tab = ScrollContainer.new()
	_leaders_tab.name = "LeaderPowers"
	_leaders_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_leaders_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_leaders_tab.visible = false
	column.add_child(_leaders_tab)
	_leader_list = VBoxContainer.new()
	_leader_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leader_list.add_theme_constant_override("separation", 28)
	_leaders_tab.add_child(_leader_list)

	_backgrounds_tab = ScrollContainer.new()
	_backgrounds_tab.name = "Backgrounds"
	_backgrounds_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_backgrounds_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backgrounds_tab.visible = false
	column.add_child(_backgrounds_tab)
	_background_list = GridContainer.new()
	_background_list.columns = 2
	_background_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_background_list.add_theme_constant_override("h_separation", 24)
	_background_list.add_theme_constant_override("v_separation", 28)
	_backgrounds_tab.add_child(_background_list)
	_refresh()


## Cards (0), Leaders (1) or Backgrounds (2).
func show_tab(tab: int) -> void:
	_cards_tab.visible = tab == 0
	_leaders_tab.visible = tab == 1
	_backgrounds_tab.visible = tab == 2


## Captions (price, or "Complete" when a deck's worth is owned), the Leaders tab and the Rhinegold counter.
func _refresh() -> void:
	(_header.find_child("RhinegoldValue", true, false) as Label).text = str(SaveManager.rhinegold())
	_build_leaders()
	_build_backgrounds()
	for cell: Node in _grid.cells():
		var data: CardData = (cell.get_child(0) as CardView).card_data
		var owned: int = SaveManager.owned_count(data.id)
		if Progression.can_craft(data, owned):
			var price: int = Progression.craft_price(data)
			CardGrid.set_caption(cell, "%d / %d · %s" % [owned, data.deck_limit(), tr("UI_PRICE").format({"price": price})], SaveManager.rhinegold() >= price)
		else:
			CardGrid.set_caption(cell, "UI_COMPLETE", false, true)
	_apply_filters()


## Hides the cards already complete: there is nothing to forge.
func _apply_filters() -> void:
	var shown: int = _grid.show_only(func(data: CardData) -> bool:
		var owned: int = SaveManager.owned_count(data.id)
		return Progression.can_craft(data, owned) and _filter_bar.accepts(data, owned))
	_filter_bar.count_label.text = tr("UI_SHOWN_COUNT").format({"count": shown})


func _show_forge(data: CardData) -> void:
	var owned: int = SaveManager.owned_count(data.id)
	var price: int = Progression.craft_price(data)
	var lines: Array[String] = [tr("UI_OWNED_COPIES").format({"count": owned, "max": data.deck_limit()})]
	var short: int = price - SaveManager.rhinegold()
	if short > 0:
		lines.append(tr("UI_FORGE_SHORT").format({"missing": short}))
	CardDetail.open(self, data, lines, [{
		"text": tr("UI_FORGE").format({"price": price}),
		"name": "ForgeButton",
		"primary": true,
		"disabled": short > 0 or not Progression.can_craft(data, owned),
		"action": func() -> void: forge(data),
	}])


func forge(data: CardData) -> bool:
	if not SaveManager.craft(data):
		return false
	var lines: PackedStringArray = []
	var change: Dictionary = Achievements.record_craft()
	for achievement_id: Variant in change["reached"]:
		lines.append(Achievements.ready_text(achievement_id))
	_refresh()
	if not lines.is_empty():
		MenuUI.toast(self, "\n".join(lines))
	return true


## Unlocks a Leader's power (LeaderPowers.unlock()); false when it cannot be unlocked yet.
func unlock_power(leader: LeaderData, index: int) -> bool:
	if not LeaderPowers.unlock(leader, index):
		return false
	_refresh()
	var lines: PackedStringArray = [
		tr("UI_POWER_UNLOCKED").format({"name": tr(leader.with_power(index).ability_key() + "_NAME")}),
	]
	for achievement_id: Variant in Achievements.refresh_reached()["reached"]:
		lines.append(Achievements.ready_text(achievement_id))
	MenuUI.toast(self, "\n".join(lines), "nibelheim")
	return true


## One panel per Leader, in faction order: its name, then the base ability and each power.
func _build_leaders() -> void:
	for child: Node in _leader_list.get_children():
		_leader_list.remove_child(child)
		child.queue_free()
	for faction: StringName in MenuUI.FACTION_ORDER:
		for leader_id: StringName in CardDatabase.leader_ids():
			var leader: LeaderData = CardDatabase.get_leader(leader_id)
			if leader.faction == faction and leader.ability != null:
				_leader_list.add_child(_leader_panel(leader))


func _leader_panel(leader: LeaderData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Leader_%s" % leader.id
	var color: Color = (CardPalette.FACTIONS[leader.faction]["frame"] as Color).lightened(0.3)
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, color, 3)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(MenuUI.label("LEADER_%s_NAME" % String(leader.id).to_upper(), 32, Palette.ACCENT))
	for index: int in range(leader.powers.size() + 1):
		box.add_child(_power_row(leader, index))
	return panel


## A version of the ability: name, effect and cost; then Base, Unlocked, or the price to unlock it
## (greyed with the level needed or the Rhinegold missing).
func _power_row(leader: LeaderData, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Power%d" % index
	row.add_theme_constant_override("separation", 16)
	var text := VBoxContainer.new()
	text.name = "PowerText"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var ability_key: String = leader.with_power(index).ability_key()
	var title_color: Color = (CardPalette.FACTIONS[leader.faction]["frame"] as Color).lightened(0.55)
	var title: Label = MenuUI.label("", 24, title_color)
	title.name = "PowerTitle"
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.text = "%s (%s)" % [
		tr(ability_key + "_NAME"),
		tr("UI_POWER_COST").format({"cost": leader.with_power(index).ability.cost}),
	]
	text.add_child(title)
	var action: Label = MenuUI.label("", 20, Palette.TEXT_MUTED)
	action.name = "PowerAction"
	action.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	action.text = tr(ability_key + "_TEXT")
	action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(action)
	if LeaderPowers.is_unlocked(leader.id, index):
		var state: Label = MenuUI.label("UI_POWER_BASE" if index == 0 else "UI_ACHIEVEMENT_DONE", 22, Palette.TEXT_MUTED if index == 0 else Palette.ACCENT)
		state.name = "State"
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(state)
		return row
	var power: LeaderPowerData = leader.powers[index - 1]
	var side := VBoxContainer.new()
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var unlock: Button = MenuUI.button("", 72, 22)
	unlock.name = "UnlockButton"
	unlock.custom_minimum_size.x = 240
	unlock.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	unlock.text = tr("UI_PRICE").format({"price": power.price})
	unlock.disabled = not LeaderPowers.can_unlock(leader, index)
	if not unlock.disabled:
		unlock.theme_type_variation = &"ButtonPrimary"
	unlock.pressed.connect(func() -> void: unlock_power(leader, index))
	side.add_child(unlock)
	var short: Dictionary = LeaderPowers.missing(leader, index)
	if int(short["level"]) > 0 or int(short["rhinegold"]) > 0:
		var reason: Label = MenuUI.label("", 18, Palette.TEXT_MUTED)
		reason.name = "Reason"
		reason.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.custom_minimum_size.x = 240
		if int(short["level"]) > 0:
			reason.text = tr("UI_POWER_LEVEL_NEEDED").format({"level": short["level"]})
		else:
			reason.text = tr("UI_FORGE_SHORT").format({"missing": short["rhinegold"]})
		side.add_child(reason)
	return row


## Buys a background (Cosmetics.buy()); false when it cannot be bought yet.
func buy_background(cosmetic_id: String) -> bool:
	if not Cosmetics.buy(cosmetic_id):
		return false
	_refresh()
	var lines: PackedStringArray = [
		tr("UI_BACKGROUND_BOUGHT").format({"name": tr(Cosmetics.name_key(cosmetic_id))}),
	]
	for achievement_id: Variant in Achievements.refresh_reached()["reached"]:
		lines.append(Achievements.ready_text(achievement_id))
	MenuUI.toast(self, "\n".join(lines), "nibelheim")
	return true


## One card per background: its picture, name and kind, then Owned or its price (greyed with the level
## needed or the Rhinegold missing).
func _build_backgrounds() -> void:
	for child: Node in _background_list.get_children():
		_background_list.remove_child(child)
		child.queue_free()
	for cosmetic: Dictionary in Cosmetics.LIST:
		_background_list.add_child(_background_card(cosmetic))


func _background_card(cosmetic: Dictionary) -> VBoxContainer:
	var cosmetic_id: String = cosmetic["id"]
	var home: bool = cosmetic["kind"] == Cosmetics.HOME
	var card := VBoxContainer.new()
	card.name = "Background_%s" % cosmetic_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 8)
	var frame := PanelContainer.new()
	var style: StyleBoxFlat = MenuUI._tile_style(Palette.SURFACE, Palette.ACCENT if Cosmetics.is_owned(cosmetic_id) else Palette.BORDER, 3)
	style.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", style)
	card.add_child(frame)
	var picture: TextureRect = Cosmetics.backdrop(Cosmetics.texture(cosmetic_id))
	picture.custom_minimum_size = Vector2(0, 420 if home else 240)
	frame.add_child(picture)
	var title: Label = MenuUI.label(Cosmetics.name_key(cosmetic_id), 26, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var kind: Label = MenuUI.label("UI_HOME_BACKGROUND" if home else "UI_BOARD", 20, Palette.TEXT_MUTED)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(kind)
	if Cosmetics.is_owned(cosmetic_id):
		var owned: Label = MenuUI.label("UI_BACKGROUND_OWNED", 22, Palette.ACCENT)
		owned.name = "State"
		owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(owned)
		return card
	var buy: Button = MenuUI.button("", 72, 22)
	buy.name = "BuyButton"
	buy.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	buy.text = tr("UI_PRICE").format({"price": cosmetic["price"]})
	buy.disabled = not Cosmetics.can_buy(cosmetic_id)
	if not buy.disabled:
		buy.theme_type_variation = &"ButtonPrimary"
	buy.pressed.connect(func() -> void: buy_background(cosmetic_id))
	card.add_child(buy)
	var short: Dictionary = Cosmetics.missing(cosmetic_id)
	if int(short["level"]) > 0 or int(short["rhinegold"]) > 0:
		var reason: Label = MenuUI.label("", 18, Palette.TEXT_MUTED)
		reason.name = "Reason"
		reason.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if int(short["level"]) > 0:
			reason.text = tr("UI_POWER_LEVEL_NEEDED").format({"level": short["level"]})
		else:
			reason.text = tr("UI_FORGE_SHORT").format({"missing": short["rhinegold"]})
		card.add_child(reason)
	return card
