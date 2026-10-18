extends Control

const HUMAN_PLAYER: int = 0
const AI_PLAYER: int = 1
const AI_DELAY: float = 0.45
const MAX_UI_SCALE: float = 1.15
const MIN_UI_SCALE: float = 0.8
const UI_SCALE_REFERENCE_HEIGHT: float = 2300.0
const CARD_VIEW_SCRIPT: Script = preload("res://scenes/components/card_view.gd")

var _match: Match
var _ui_scale: float = 1.0
var _board_card_scale: float = 1.0
var _ai_busy: bool = false
var _selected_hand_uid: int = -1
var _selected_attacker_uid: int = -1
var _selected_ability: bool = false
var _redraw_selected: Array[int] = []
var _log_lines: Array[String] = []
var _turn_label: Label
var _status_label: Label
var _enemy_leader_button: Button
var _enemy_leader_label: Label
var _enemy_board: HBoxContainer
var _enemy_artifacts: HBoxContainer
var _own_board: HBoxContainer
var _own_artifacts: HBoxContainer
var _own_hand: HBoxContainer
var _own_leader_portrait_frame: Panel
var _own_leader_artwork: TextureRect
var _own_leader_button: Button
var _own_leader_label: Label
var _energy_label: Label
var _deck_label: Label
var _log_label: Label
var _end_turn_button: Button
var _ability_button: Button
var _undo_play_button: Button
var _results_undo_button: Button
var _overlay: ColorRect
var _zoom_overlay: ColorRect
var _zoom_source: CardView
var _drop_hint: PanelContainer
var _drop_hint_label: Label
var _drag_preview: Control
var _modal_layer: CanvasLayer
var _main_layout: VBoxContainer
var _results_shown: bool = false
var _undo_snapshot: GameState
var _undo_card_uid: int = -1
var _undo_state_hash: String
var _undo_log_lines: Array[String] = []


func _ready() -> void:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	_board_card_scale = clampf(
		MAX_UI_SCALE * viewport_height / 2050.0,
		1.0,
		MAX_UI_SCALE
	)
	_ui_scale = clampf(
		MAX_UI_SCALE * viewport_height / UI_SCALE_REFERENCE_HEIGHT,
		MIN_UI_SCALE,
		MAX_UI_SCALE
	)
	_build_ui()
	_start_match()


func _exit_tree() -> void:
	if _ai_busy:
		_ai_busy = false


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Palette.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", roundi(24 * _ui_scale))
	margin.add_theme_constant_override("margin_top", roundi(28 * _ui_scale))
	margin.add_theme_constant_override("margin_right", roundi(24 * _ui_scale))
	margin.add_theme_constant_override("margin_bottom", roundi(26 * _ui_scale))
	add_child(margin)
	_main_layout = VBoxContainer.new()
	_main_layout.add_theme_constant_override("separation", roundi(12 * _ui_scale))
	margin.add_child(_main_layout)
	_modal_layer = CanvasLayer.new()
	_modal_layer.name = "ModalLayer"
	_modal_layer.layer = 10
	add_child(_modal_layer)
	_build_drop_hint()

	var header: HBoxContainer = HBoxContainer.new()
	_main_layout.add_child(header)
	_turn_label = _label("UI_DUEL", 24, Palette.ACCENT)
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_turn_label)
	var back_button: Button = _button("UI_PAUSE", 140)
	back_button.pressed.connect(_on_pause_pressed)
	header.add_child(back_button)

	_status_label = _label("", 18, Palette.TEXT_MUTED)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_layout.add_child(_status_label)

	_enemy_leader_button = _button("", 100)
	_enemy_leader_button.custom_minimum_size.y = roundi(92 * _ui_scale)
	_enemy_leader_button.pressed.connect(_on_enemy_leader_pressed)
	_enemy_leader_button.set_drag_forwarding(
		Callable(),
		_can_drop_on_leader.bind(AI_PLAYER),
		_drop_on_leader.bind(AI_PLAYER)
	)
	_main_layout.add_child(_enemy_leader_button)
	_enemy_leader_label = _label("", 20, Palette.LIFE)
	_enemy_leader_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_layout.add_child(_enemy_leader_label)
	_deck_label = _label("", 16, Palette.TEXT_MUTED)
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_layout.add_child(_deck_label)

	_main_layout.add_child(_section_label("UI_ENEMY_UNITS"))
	_enemy_board = _board_row()
	_main_layout.add_child(_enemy_board)
	_enemy_artifacts = _board_row()
	_main_layout.add_child(_enemy_artifacts)

	_turn_label = _label("UI_TURN", 18, Palette.ACCENT)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_layout.add_child(_turn_label)

	_own_artifacts = _board_row()
	_main_layout.add_child(_own_artifacts)
	_own_board = _board_row()
	_own_board.set_drag_forwarding(Callable(), _can_drop_on_own_board, _drop_on_own_board)
	_main_layout.add_child(_own_board)
	_main_layout.add_child(_section_label("UI_YOUR_UNITS"))

	var own_leader_row: HBoxContainer = HBoxContainer.new()
	_main_layout.add_child(own_leader_row)
	_own_leader_portrait_frame = Panel.new()
	_own_leader_portrait_frame.name = "OwnLeaderPortraitFrame"
	_own_leader_portrait_frame.custom_minimum_size = Vector2(
		roundi(70 * _ui_scale),
		roundi(86 * _ui_scale)
	)
	var portrait_frame_style: StyleBoxFlat = StyleBoxFlat.new()
	portrait_frame_style.bg_color = Palette.ACCENT.darkened(0.3)
	portrait_frame_style.border_color = Palette.ACCENT
	portrait_frame_style.set_border_width_all(roundi(2 * _ui_scale))
	portrait_frame_style.set_corner_radius_all(roundi(8 * _ui_scale))
	_own_leader_portrait_frame.add_theme_stylebox_override("panel", portrait_frame_style)
	_own_leader_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own_leader_row.add_child(_own_leader_portrait_frame)
	_own_leader_artwork = TextureRect.new()
	_own_leader_artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_own_leader_artwork.offset_left = roundi(2 * _ui_scale)
	_own_leader_artwork.offset_top = roundi(2 * _ui_scale)
	_own_leader_artwork.offset_right = roundi(-2 * _ui_scale)
	_own_leader_artwork.offset_bottom = roundi(-2 * _ui_scale)
	_own_leader_artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_own_leader_artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_own_leader_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own_leader_portrait_frame.add_child(_own_leader_artwork)
	_own_leader_button = _button("", 100)
	_own_leader_button.custom_minimum_size.y = roundi(86 * _ui_scale)
	_own_leader_button.pressed.connect(_on_own_leader_pressed)
	_own_leader_button.set_drag_forwarding(
		Callable(),
		_can_drop_on_leader.bind(HUMAN_PLAYER),
		_drop_on_leader.bind(HUMAN_PLAYER)
	)
	own_leader_row.add_child(_own_leader_button)
	_own_leader_label = _label("", 19, Palette.LIFE)
	_own_leader_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own_leader_row.add_child(_own_leader_label)
	_ability_button = _button("UI_ABILITY", 168)
	_ability_button.pressed.connect(_on_ability_pressed)
	own_leader_row.add_child(_ability_button)

	var action_row: HBoxContainer = HBoxContainer.new()
	_main_layout.add_child(action_row)
	_energy_label = _label("", 21, Palette.ENERGY)
	_energy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(_energy_label)
	_undo_play_button = _button("UI_UNDO_PLAY", 150)
	_undo_play_button.visible = false
	_undo_play_button.pressed.connect(_on_undo_play_pressed)
	action_row.add_child(_undo_play_button)
	_end_turn_button = _button("UI_END_TURN", 200)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	action_row.add_child(_end_turn_button)

	var log_title: Label = _section_label("UI_BATTLE_LOG")
	_main_layout.add_child(log_title)
	_log_label = _label("", 14, Palette.TEXT_MUTED)
	_log_label.custom_minimum_size.y = roundi(50 * _ui_scale)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_layout.add_child(_log_label)

	var hand_scroll: ScrollContainer = ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = roundi(350 * _ui_scale)
	hand_scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_layout.add_child(hand_scroll)
	_own_hand = HBoxContainer.new()
	_own_hand.add_theme_constant_override("separation", roundi(12 * _ui_scale))
	hand_scroll.add_child(_own_hand)


func _start_match() -> void:
	_results_shown = false
	_clear_undo()
	_log_lines.clear()
	_match = Match.new(CardDatabase.get_deck(&"gods_starter"), CardDatabase.get_deck(&"nibelungs_starter"), int(Time.get_unix_time_from_system()))
	_match.event_emitted.connect(_on_match_event)
	_refresh()
	_continue_ai()


func _refresh() -> void:
	if _match == null:
		return
	var state: GameState = _match.get_state()
	var human: PlayerState = state.player(HUMAN_PLAYER)
	var opponent: PlayerState = state.player(AI_PLAYER)
	_enemy_leader_button.text = "♥ %d" % opponent.life
	_enemy_leader_label.text = tr("LEADER_ALBERICH_NAME")
	_own_leader_artwork.texture = human.leader.art
	_own_leader_artwork.visible = human.leader.art != null
	_own_leader_button.text = "♥ %d" % human.life
	_own_leader_label.text = tr("LEADER_WOTAN_NAME")
	_energy_label.text = "%s  %d / %d" % [tr("UI_ENERGY"), human.energy, human.max_energy]
	_deck_label.text = "%s %d     %s %d     %s %d" % [
		tr("UI_DECK"),
		opponent.deck.size(),
		tr("UI_GRAVEYARD"),
		opponent.graveyard.size(),
		tr("UI_HAND"),
		opponent.hand.size(),
	]
	_turn_label.text = "%s %d  ·  %s %d" % [
		tr("UI_TURN"),
		state.turn,
		tr("UI_DOOM_IN"),
		maxi(10 - state.turn, 0),
	]
	_ability_button.text = "%s · %d" % [tr("UI_ABILITY"), human.leader.ability.cost if human.leader.ability != null else 0]
	_ability_button.disabled = state.phase != GameState.Phase.MAIN or state.active_player != HUMAN_PLAYER
	_end_turn_button.disabled = state.phase != GameState.Phase.MAIN or state.active_player != HUMAN_PLAYER
	_undo_play_button.visible = _undo_snapshot != null
	if _results_undo_button != null and is_instance_valid(_results_undo_button):
		_results_undo_button.visible = _undo_snapshot != null
	_status_label.text = _status_text(state)
	_fill_board(_enemy_board, opponent.board, false, &"board")
	_fill_board(_own_board, human.board, true, &"board")
	_fill_board(_enemy_artifacts, opponent.artifacts, false, &"artifact")
	_fill_board(_own_artifacts, human.artifacts, true, &"artifact")
	_fill_hand(human.hand)
	_log_label.text = "\n".join(_log_lines.slice(maxi(0, _log_lines.size() - 3)))
	if state.phase == GameState.Phase.REDRAW and state.redraw_player == HUMAN_PLAYER:
		_show_redraw_overlay()
	elif _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	if state.phase == GameState.Phase.GAME_OVER:
		_show_results()


func _status_text(state: GameState) -> String:
	if state.phase == GameState.Phase.REDRAW:
		return tr("UI_CHOOSE_REDRAW") if state.redraw_player == HUMAN_PLAYER else tr("UI_OPPONENT_REDRAW")
	if state.phase == GameState.Phase.GAME_OVER:
		return tr("UI_VICTORY") if state.winner == HUMAN_PLAYER else (tr("UI_DRAW") if state.winner < 0 else tr("UI_DEFEAT"))
	return tr("UI_YOUR_TURN") if state.active_player == HUMAN_PLAYER else tr("UI_OPPONENT_TURN")


func _fill_board(row: HBoxContainer, zone: Zone, is_human: bool, zone_name: StringName) -> void:
	for child: Node in row.get_children():
		child.queue_free()
	for instance: CardInstance in zone.cards:
		var can_attack: bool = is_human and zone_name == &"board"
		var view: CardView = _card_view(
			instance,
			can_attack,
			HUMAN_PLAYER if is_human else AI_PLAYER,
			"attacker",
			_match.get_state().phase != GameState.Phase.GAME_OVER
		)
		view.custom_minimum_size = Vector2(170, 200) * _board_card_scale
		view.pressed.connect(_on_board_card_pressed.bind(instance.uid, is_human, zone_name, view))
		if is_human and instance.can_attack and not instance.exhausted:
			view.modulate = Color.WHITE
		elif is_human and instance.exhausted:
			view.modulate = Color(0.68, 0.68, 0.68)
		row.add_child(view)
	if zone.cards.is_empty():
		var empty: Label = _label("—", 18, Palette.TEXT_DISABLED)
		empty.custom_minimum_size = Vector2(108, 56)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(empty)


func _fill_hand(hand: Zone) -> void:
	for child: Node in _own_hand.get_children():
		child.queue_free()
	for instance: CardInstance in hand.cards:
		var phase: GameState.Phase = _match.get_state().phase
		var zoom_allowed: bool = phase != GameState.Phase.REDRAW and phase != GameState.Phase.GAME_OVER
		var view: CardView = _card_view(instance, true, -1, "hand", zoom_allowed)
		view.set_selected(instance.uid == _selected_hand_uid)
		view.pressed.connect(_on_hand_card_pressed.bind(instance.uid, view))
		_own_hand.add_child(view)
	if hand.cards.is_empty():
		_own_hand.add_child(_label("UI_NO_CARDS", 16, Palette.TEXT_MUTED))


func _card_view(
	instance: CardInstance,
	draggable: bool = false,
	drop_player: int = -1,
	drag_kind: String = "hand",
	zoom_allowed: bool = true
) -> CardView:
	var view: CardView = CARD_VIEW_SCRIPT.new()
	view.set_card(instance.data, instance, draggable, drop_player, drag_kind, zoom_allowed)
	view.set_view_scale(_ui_scale)
	view.zoom_requested.connect(_show_card_zoom.bind(view))
	view.drop_requested.connect(_on_card_drop)
	view.drag_started.connect(_on_card_drag_started)
	view.drag_moved.connect(_on_card_drag_moved)
	view.drag_released.connect(_on_card_drag_released)
	return view


func _show_card_zoom(data: CardData, instance: CardInstance, source: CardView) -> void:
	if _zoom_overlay != null and is_instance_valid(_zoom_overlay):
		return
	_zoom_source = source
	for node: Node in get_tree().get_nodes_in_group("duel_card_views"):
		if node is CardView:
			(node as CardView).set_zoom_blocked(true)
	_zoom_overlay = ColorRect.new()
	_zoom_overlay.name = "CardZoomOverlay"
	_zoom_overlay.color = Color(Palette.BG, 0.88)
	_zoom_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zoom_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_zoom_overlay.gui_input.connect(_on_zoom_overlay_input)
	_modal_layer.add_child(_zoom_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zoom_overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 980)
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	var title: HBoxContainer = HBoxContainer.new()
	var name_label: Label = _label("CARD_%s_NAME" % String(data.id).to_upper(), 28, Palette.ACCENT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	title.add_child(_label("◆ %d" % data.cost, 24, Palette.ENERGY))
	content.add_child(title)

	var artwork: Control
	if data.art != null:
		var texture: TextureRect = TextureRect.new()
		texture.texture = data.art
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		artwork = texture
	else:
		var placeholder: ColorRect = ColorRect.new()
		placeholder.color = Color("#20242d")
		artwork = placeholder
		var emblem: Label = _label(String(data.faction).to_upper(), 25, Palette.ACCENT)
		emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emblem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		placeholder.add_child(emblem)
	artwork.custom_minimum_size = Vector2(500, 360)
	content.add_child(artwork)

	var type_label: Label = _label("%s · %s" % [
		String(data.faction).capitalize(),
		CardData.Type.keys()[data.type].capitalize(),
	], 18, Palette.TEXT_MUTED)
	content.add_child(type_label)
	var rules: String = tr("CARD_%s_RULES" % String(data.id).to_upper())
	if rules.begins_with("CARD_"):
		rules = ""
	var rules_label: Label = _label(rules, 22, Palette.TEXT)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(rules_label)
	if data.type == CardData.Type.UNIT:
		var attack: int = instance.attack if instance != null else data.attack
		var health: int = instance.health if instance != null else data.health
		content.add_child(_label("⚔ %d   ♥ %d" % [attack, health], 24, Palette.LIFE))
	var close: Button = _button("UI_CLOSE", 300)
	close.pressed.connect(_close_card_zoom)
	content.add_child(close)


func _on_zoom_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_card_zoom()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_close_card_zoom()


func _close_card_zoom() -> void:
	if _zoom_overlay == null or not is_instance_valid(_zoom_overlay):
		return
	_zoom_overlay.queue_free()
	_zoom_overlay = null
	if is_instance_valid(_zoom_source):
		_zoom_source.consume_long_press()
	_zoom_source = null
	for node: Node in get_tree().get_nodes_in_group("duel_card_views"):
		if node is CardView:
			(node as CardView).set_zoom_blocked(false)


func _show_redraw_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = ColorRect.new()
	_overlay.name = "ModalOverlay"
	_overlay.color = Color(Palette.BG, 0.96)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(840, 560)
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	content.add_child(_label("UI_REDRAW_TITLE", 26, Palette.ACCENT))
	content.add_child(_label("UI_REDRAW_PROMPT", 17, Palette.TEXT_MUTED))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 310
	content.add_child(scroll)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	scroll.add_child(cards)
	for instance: CardInstance in _match.get_state().player(HUMAN_PLAYER).hand.cards:
		var view: CardView = _card_view(instance)
		view.custom_minimum_size = Vector2(154, 250) * _ui_scale
		view.set_selected(_redraw_selected.has(instance.uid))
		view.pressed.connect(_toggle_redraw_card.bind(instance.uid, view))
		cards.add_child(view)
	var confirm: Button = _button("UI_REDRAW_CONFIRM", 300)
	confirm.pressed.connect(_confirm_redraw)
	content.add_child(confirm)


func _toggle_redraw_card(uid: int, view: CardView) -> void:
	if view.consume_drag():
		return
	if view.consume_long_press():
		return
	if _redraw_selected.has(uid):
		_redraw_selected.erase(uid)
	else:
		_redraw_selected.append(uid)
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	call_deferred("_show_redraw_overlay")


func _confirm_redraw() -> void:
	var action: RedrawAction = RedrawAction.new(HUMAN_PLAYER, _redraw_selected)
	if _match.apply(action):
		_redraw_selected.clear()
		_refresh()
		_continue_ai()


func _on_hand_card_pressed(uid: int, view: CardView) -> void:
	if view.consume_drag():
		return
	if view.consume_long_press():
		return
	if _match.get_state().phase != GameState.Phase.MAIN or _match.get_state().active_player != HUMAN_PLAYER:
		return
	var matching: PlayCardAction
	for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
		if action is PlayCardAction and (action as PlayCardAction).card_uid == uid:
			matching = action as PlayCardAction
			break
	if matching == null:
		_set_status("UI_CANNOT_PLAY")
		return
	_selected_hand_uid = uid
	if matching.target_uid >= 0:
		_selected_attacker_uid = -1
		_selected_ability = false
		_set_status("UI_CHOOSE_CARD_TARGET")
	else:
		_apply_action(matching)
		return
	_refresh()


func _on_board_card_pressed(uid: int, is_human: bool, zone_name: StringName, view: CardView) -> void:
	if view.consume_drag():
		return
	if view.consume_long_press():
		return
	if _match.get_state().phase != GameState.Phase.MAIN or _match.get_state().active_player != HUMAN_PLAYER:
		return
	if zone_name == &"board":
		if _selected_hand_uid >= 0:
			var play: PlayCardAction = _find_play_action(_selected_hand_uid, uid)
			if play != null:
				_apply_action(play)
				return
		if _selected_ability:
			var ability: UseLeaderAbilityAction = _find_ability_action(uid)
			if ability != null:
				_apply_action(ability)
				return
		if not is_human and _selected_attacker_uid >= 0:
			var attack: AttackAction = _find_attack_action(_selected_attacker_uid, uid, -1)
			if attack != null:
				_apply_action(attack)
				return
		if is_human:
			_selected_attacker_uid = uid
			_selected_hand_uid = -1
			_selected_ability = false
			_set_status("UI_CHOOSE_ATTACK_TARGET")
			_refresh()


func _on_enemy_leader_pressed() -> void:
	if _selected_hand_uid >= 0:
		var play: PlayCardAction = _find_play_action(_selected_hand_uid, -1, AI_PLAYER)
		if play != null:
			_apply_action(play)
			return
	if _selected_ability:
		var ability: UseLeaderAbilityAction = _find_ability_action(-1, AI_PLAYER)
		if ability != null:
			_apply_action(ability)
			return
	if _selected_attacker_uid >= 0:
		var attack: AttackAction = _find_attack_action(_selected_attacker_uid, -1, AI_PLAYER)
		if attack != null:
			_apply_action(attack)


func _on_card_drop(data: Dictionary, target_uid: int, target_player: int) -> void:
	var action: Action = _find_drop_action(data, target_uid, target_player)
	if action != null:
			_apply_action(action)


func _on_card_drag_started(data: Dictionary) -> void:
	var source: CardView
	for node: Node in get_tree().get_nodes_in_group("duel_card_views"):
		if node is CardView:
			var view: CardView = node as CardView
			if view.card_instance != null and view.card_instance.uid == int(data.get("uid", -1)):
				source = view
				break
	if source == null:
		push_error("Cannot display a drag preview: the source card view was not found.")
		return
	var target_rect: Rect2 = _own_drop_rect()
	_drop_hint.position = target_rect.position
	_drop_hint.size = target_rect.size
	_drop_hint.visible = true
	_show_drag_preview(source, get_viewport().get_mouse_position())


func _on_card_drag_moved(_data: Dictionary, position: Vector2) -> void:
	if _drag_preview != null:
		_drag_preview.position = position - _drag_preview.size * 0.5


func _on_card_drag_released(data: Dictionary, position: Vector2) -> void:
	_drop_hint.visible = false
	_hide_drag_preview()
	if _enemy_leader_button.get_global_rect().has_point(position):
		_on_card_drop(data, -1, AI_PLAYER)
		return
	if _own_leader_button.get_global_rect().has_point(position):
		_on_card_drop(data, -1, HUMAN_PLAYER)
		return
	for node: Node in get_tree().get_nodes_in_group("duel_card_views"):
		if not node is CardView:
			continue
		var target: CardView = node as CardView
		if (
			target.card_instance != null
			and target._drop_player >= 0
			and target.get_global_rect().has_point(position)
		):
			var action: Action = _find_drop_action(
				data,
				target.card_instance.uid,
				target._drop_player
			)
			if action != null:
				_apply_action(action)
				return
	if _own_drop_rect().has_point(position):
		var action: Action = _find_drop_action(data, -1, -1)
		if action != null:
			_apply_action(action)


func _can_drop_on_leader(_at_position: Vector2, data: Variant, player_id: int) -> bool:
	return data is Dictionary and _find_drop_action(data as Dictionary, -1, player_id) != null


func _drop_on_leader(_at_position: Vector2, data: Variant, player_id: int) -> void:
	if data is Dictionary:
			_on_card_drop(data as Dictionary, -1, player_id)


func _can_drop_on_own_board(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or (data as Dictionary).get("kind", "") != "hand":
			return false
	return _find_drop_action(data as Dictionary, -1, -1) != null


func _drop_on_own_board(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_on_own_board(_at_position, data):
			_on_card_drop(data as Dictionary, -1, -1)


func _find_drop_action(data: Dictionary, target_uid: int, target_player: int) -> Action:
	if _match == null or _match.get_state().phase != GameState.Phase.MAIN:
			return null
	if _match.get_state().active_player != HUMAN_PLAYER:
			return null
	var uid: int = int(data.get("uid", -1))
	match String(data.get("kind", "")):
			"hand":
				for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
					if action is PlayCardAction:
						var play: PlayCardAction = action as PlayCardAction
						if (
							play.card_uid == uid
							and play.target_uid == target_uid
							and play.target_player == target_player
						):
							return play
			"attacker":
				for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
					if action is AttackAction:
						var attack: AttackAction = action as AttackAction
						if (
							attack.attacker_uid == uid
							and attack.target_uid == target_uid
							and attack.target_player == target_player
						):
							return attack
	return null


func _on_own_leader_pressed() -> void:
	if _selected_hand_uid >= 0:
		var play: PlayCardAction = _find_play_action(_selected_hand_uid, -1, HUMAN_PLAYER)
		if play != null:
			_apply_action(play)
			return
	if _selected_ability:
		var ability: UseLeaderAbilityAction = _find_ability_action(-1, HUMAN_PLAYER)
		if ability != null:
			_apply_action(ability)


func _on_ability_pressed() -> void:
	var selected: UseLeaderAbilityAction
	for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
		if action is UseLeaderAbilityAction:
			selected = action as UseLeaderAbilityAction
			break
	if selected == null:
		_set_status("UI_ABILITY_UNAVAILABLE")
	elif selected.target_uid >= 0:
		_selected_hand_uid = -1
		_selected_attacker_uid = -1
		_selected_ability = true
		_set_status("UI_CHOOSE_ABILITY_TARGET")
		_refresh()
	else:
		_apply_action(selected)


func _on_end_turn_pressed() -> void:
	_apply_action(EndTurnAction.new(HUMAN_PLAYER))
	_continue_ai()


func _on_undo_play_pressed() -> void:
	if _undo_snapshot == null:
		return
	if _match.state_hash() != _undo_state_hash:
		_clear_undo()
		_refresh()
		return
	if not _match.restore_snapshot(_undo_snapshot):
		_clear_undo()
		_refresh()
		return
	var player: PlayerState = _match.get_state().player(HUMAN_PLAYER)
	var card: CardInstance = player.hand.remove_uid(_undo_card_uid)
	if card == null:
		push_error("Cannot undo the card play because the card is missing from the restored hand.")
		_clear_undo()
		_refresh()
		return
	player.deck.add(card)
	_log_lines = _undo_log_lines.duplicate()
	_clear_undo()
	_results_shown = false
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_refresh()


func _clear_undo() -> void:
	_undo_snapshot = null
	_undo_card_uid = -1
	_undo_state_hash = ""
	_undo_log_lines.clear()
	if _undo_play_button != null:
		_undo_play_button.visible = false


func _on_pause_pressed() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = tr("UI_PAUSE")
	dialog.dialog_text = tr("UI_LEAVE_MATCH")
	dialog.ok_button_text = tr("UI_LEAVE")
	dialog.confirmed.connect(func() -> void:
		SceneRouter.go_to("res://scenes/screens/splash.tscn", false)
	)
	add_child(dialog)
	dialog.popup_centered()


func _find_play_action(card_uid: int, target_uid: int, target_player: int = -1) -> PlayCardAction:
	for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
		if action is PlayCardAction:
			var play: PlayCardAction = action as PlayCardAction
			if play.card_uid == card_uid and play.target_uid == target_uid and play.target_player == target_player:
				return play
	return null


func _find_ability_action(target_uid: int, target_player: int = -1) -> UseLeaderAbilityAction:
	for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
		if action is UseLeaderAbilityAction:
			var ability: UseLeaderAbilityAction = action as UseLeaderAbilityAction
			if ability.target_uid == target_uid and ability.target_player == target_player:
				return ability
	return null


func _find_attack_action(attacker_uid: int, target_uid: int, target_player: int) -> AttackAction:
	for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
		if action is AttackAction:
			var attack: AttackAction = action as AttackAction
			if attack.attacker_uid == attacker_uid and attack.target_uid == target_uid and attack.target_player == target_player:
				return attack
	return null


func _apply_action(action: Action) -> void:
	var snapshot: GameState
	var previous_log_lines: Array[String] = _log_lines.duplicate()
	if action is PlayCardAction:
		snapshot = _match.get_state().duplicate_state()
	var applied: bool = _match.apply(action)
	if not applied:
		_set_status("UI_INVALID_ACTION")
		return
	if action is PlayCardAction:
		_undo_snapshot = snapshot
		_undo_card_uid = (action as PlayCardAction).card_uid
		_undo_state_hash = _match.state_hash()
		_undo_log_lines = previous_log_lines
	else:
		_clear_undo()
	_selected_hand_uid = -1
	_selected_attacker_uid = -1
	_selected_ability = false
	_refresh()


func _continue_ai() -> void:
	if _ai_busy or _match == null or _match.get_state().phase == GameState.Phase.GAME_OVER:
		return
	var state: GameState = _match.get_state()
	if state.phase == GameState.Phase.REDRAW and state.redraw_player == AI_PLAYER:
		_ai_busy = true
		_finish_ai_redraw.call_deferred()
	elif state.phase == GameState.Phase.MAIN and state.active_player == AI_PLAYER:
		_ai_busy = true
		_run_ai_turn.call_deferred()


func _finish_ai_redraw() -> void:
	await get_tree().create_timer(AI_DELAY).timeout
	var state: GameState = _match.get_state()
	if state.phase != GameState.Phase.REDRAW or state.redraw_player != AI_PLAYER:
		_ai_busy = false
		return
	var records: Array[Dictionary] = EasyAI.prepare_actions(state, _match.get_legal_actions(AI_PLAYER))
	var worker: Thread = Thread.new()
	var error: Error = worker.start(EasyAI.choose_action.bind(records))
	if error != OK:
		push_error("Could not start EasyAI redraw worker: %s" % error_string(error))
		_ai_busy = false
		return
	var selected: Dictionary = worker.wait_to_finish()
	var action: Action = Action.from_record(selected)
	if action == null or not _match.apply(action):
		push_error("EasyAI returned an invalid redraw action.")
		_ai_busy = false
		return
	_ai_busy = false
	_refresh()
	_continue_ai()


func _run_ai_turn() -> void:
	await get_tree().create_timer(AI_DELAY).timeout
	var state: GameState = _match.get_state()
	if state.phase != GameState.Phase.MAIN or state.active_player != AI_PLAYER:
		_ai_busy = false
		return
	var records: Array[Dictionary] = EasyAI.prepare_actions(state, _match.get_legal_actions(AI_PLAYER))
	var worker: Thread = Thread.new()
	var error: Error = worker.start(EasyAI.choose_action.bind(records))
	if error != OK:
		push_error("Could not start EasyAI worker: %s" % error_string(error))
		_ai_busy = false
		return
	var selected: Dictionary = worker.wait_to_finish()
	_ai_busy = false
	var action: Action = Action.from_record(selected)
	if action == null or not _match.apply(action):
		push_error("EasyAI returned an invalid action.")
		return
	_refresh()
	if _match.get_state().phase == GameState.Phase.MAIN and _match.get_state().active_player == AI_PLAYER:
		_continue_ai()


func _show_results() -> void:
	if _results_shown:
		return
	_results_shown = true
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = ColorRect.new()
	_overlay.name = "ModalOverlay"
	_overlay.color = Color(Palette.BG, 0.94)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	center.add_child(content)
	content.add_child(_label(_status_text(_match.get_state()), 42, Palette.ACCENT))
	_results_undo_button = _button("UI_UNDO_PLAY", 250)
	_results_undo_button.visible = false
	_results_undo_button.pressed.connect(_on_undo_play_pressed)
	content.add_child(_results_undo_button)
	var rematch: Button = _button("UI_REMATCH", 250)
	rematch.pressed.connect(func() -> void:
		_overlay.queue_free()
		_overlay = null
		_start_match()
	)
	content.add_child(rematch)
	var home: Button = _button("UI_HOME", 250)
	home.pressed.connect(func() -> void:
		SceneRouter.go_to("res://scenes/screens/splash.tscn", false)
	)
	content.add_child(home)


func _on_match_event(event: GameEvent) -> void:
	var message: String = _event_message(event)
	if not message.is_empty():
		_log_lines.append(message)
		_log_lines = _log_lines.slice(maxi(0, _log_lines.size() - 8))
	_refresh()


func _event_message(event: GameEvent) -> String:
	match event.type:
		&"turn_started":
			return tr("UI_LOG_TURN_STARTED").format({
				"turn": event.turn,
				"player": tr("LEADER_WOTAN_NAME") if event.player == HUMAN_PLAYER else tr("LEADER_ALBERICH_NAME"),
			})
		&"card_played":
			return tr("UI_LOG_CARD_PLAYED").format({
				"player": tr("UI_YOU") if event.player == HUMAN_PLAYER else tr("LEADER_ALBERICH_NAME"),
			})
		&"damage_dealt":
			return tr("UI_LOG_DAMAGE").format({
				"player": tr("LEADER_WOTAN_NAME") if event.player == HUMAN_PLAYER else tr("LEADER_ALBERICH_NAME"),
				"amount": event.amount,
			})
		&"ring_taken":
			return tr("UI_LOG_RING").format({
				"player": tr("UI_YOU") if event.player == HUMAN_PLAYER else tr("LEADER_ALBERICH_NAME"),
			})
		&"match_ended":
			return tr("UI_LOG_MATCH_ENDED")
		_:
			return ""


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = tr(message)


func _board_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", roundi(8 * _board_card_scale))
	row.custom_minimum_size.y = roundi(200 * _board_card_scale)
	return row


func _section_label(value: String) -> Label:
	return _label(tr(value), 13, Palette.TEXT_MUTED)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = tr(value)
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, width: float) -> Button:
	var button: Button = Button.new()
	button.text = tr(value)
	button.custom_minimum_size = Vector2(width * _ui_scale, 72 * _ui_scale)
	button.add_theme_font_size_override("font_size", roundi(17 * _ui_scale))
	return button


func _build_drop_hint() -> void:
	_drop_hint = PanelContainer.new()
	_drop_hint.name = "DropTargetHint"
	_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_hint.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(Palette.ACCENT, 0.22)
	style.border_color = Palette.ACCENT
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	_drop_hint.add_theme_stylebox_override("panel", style)
	_drop_hint_label = _label("UI_DROP_TO_PLAY", 22, Palette.ACCENT)
	_drop_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drop_hint.add_child(_drop_hint_label)
	_modal_layer.add_child(_drop_hint)


func _own_drop_rect() -> Rect2:
	var artifacts_rect: Rect2 = _own_artifacts.get_global_rect()
	var board_rect: Rect2 = _own_board.get_global_rect()
	var left: float = minf(artifacts_rect.position.x, board_rect.position.x)
	var top: float = minf(artifacts_rect.position.y, board_rect.position.y)
	var right: float = maxf(artifacts_rect.end.x, board_rect.end.x)
	var bottom: float = maxf(artifacts_rect.end.y, board_rect.end.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _show_drag_preview(source: CardView, position: Vector2) -> void:
	_hide_drag_preview()
	_drag_preview = Control.new()
	_drag_preview.name = "CardDragPreview"
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.modulate = Color(1, 1, 1, 0.9)
	_drag_preview.custom_minimum_size = source.custom_minimum_size
	_drag_preview.size = source.custom_minimum_size
	var faction: String = String(source.card_data.faction)
	var faction_color: Color = CardView.FACTION_COLORS.get(faction, CardView.FACTION_COLORS["neutral"])
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = faction_color.darkened(0.66)
	style.border_color = faction_color.lightened(0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", style)
	_drag_preview.add_child(panel)
	var label: Label = _label(source.text, 18, Palette.TEXT)
	label.name = "CardText"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 12
	label.offset_top = 12
	label.offset_right = -12
	label.offset_bottom = -12
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drag_preview.add_child(label)
	_modal_layer.add_child(_drag_preview)
	_drag_preview.reset_size()
	_drag_preview.position = position - _drag_preview.custom_minimum_size * 0.5


func _hide_drag_preview() -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null
