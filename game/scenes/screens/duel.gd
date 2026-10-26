extends Control

const HUMAN_PLAYER: int = 0
const AI_PLAYER: int = 1
const AI_DELAY: float = 0.45
const MAX_UI_SCALE: float = 1.15
const MIN_UI_SCALE: float = 0.8
const UI_SCALE_REFERENCE_HEIGHT: float = 2300.0
const CARD_VIEW_SCRIPT: Script = preload("res://scenes/components/card_view.gd")
## Opacity of Invisible units that have not attacked yet.
const HIDDEN_ALPHA: float = 0.45

## Board art to show behind the duel (campaign duels will set it; see assets/art/boards/).
@export var board_id: String = "default"

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
var _enemy_life_label: Label
var _enemy_energy_label: Label
var _enemy_portrait_frame: Panel
var _enemy_artwork: TextureRect
var _enemy_portrait_initial: Label
var _enemy_ability_button: Button
var _enemy_zone_frame: PanelContainer
var _own_zone_frame: PanelContainer
var _own_life_label: Label
var _own_portrait_initial: Label
var _enemy_board: HFlowContainer
var _enemy_artifacts: HFlowContainer
var _own_board: HFlowContainer
var _own_artifacts: HFlowContainer
var _own_hand: HBoxContainer
var _own_leader_portrait_frame: Panel
var _own_leader_artwork: TextureRect
var _own_leader_button: Button
var _own_leader_label: Label
var _energy_label: Label
var _log_label: Label
var _end_turn_button: Button
var _ability_button: Button
var _undo_play_button: Button
var _results_undo_button: Button
var _overlay: ColorRect
var _zoom_overlay: ColorRect
var _pause_overlay: ColorRect
var _enemy_leader_panel: PanelContainer
var _own_leader_panel: PanelContainer
## Card being dragged ({"kind", "uid"}), so targets can be highlighted during the drag.
var _drag_source: Dictionary = {}
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
## Events of the action being applied, animated once it resolves (see _play_fx).
var _pending_events: Array[GameEvent] = []
var _fx: DuelFx
## The Götterdämmerung explanation pops up once per match.
var _doom_explained: bool = false


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
	# Painted board, if any: res://assets/art/boards/<board_id>.png, dimmed so cards stay readable.
	var board_path: String = "res://assets/art/boards/%s.png" % board_id
	if ResourceLoader.exists(board_path):
		var board_art: TextureRect = TextureRect.new()
		board_art.name = "BoardBackground"
		board_art.texture = load(board_path) as Texture2D
		board_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		board_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		board_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board_art.modulate = Color(0.45, 0.45, 0.45)
		board_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(board_art)

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
	# Animations play above the board but below popups.
	var fx_layer: CanvasLayer = CanvasLayer.new()
	fx_layer.name = "FxLayer"
	fx_layer.layer = 5
	add_child(fx_layer)
	_fx = DuelFx.new()
	_fx.name = "DuelFx"
	_fx.ui_scale = _ui_scale
	fx_layer.add_child(_fx)
	_build_drop_hint()

	# Top bar: match / turn info, pause.
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", roundi(10 * _ui_scale))
	_main_layout.add_child(top_bar)
	var info_panel: PanelContainer = _framed_panel(Palette.SURFACE, Palette.BORDER)
	info_panel.name = "MatchInfoPanel"
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(info_panel)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_panel.add_child(info_box)
	_status_label = _label("", 17, Palette.ACCENT)
	# Long instructions wrap instead of widening the top bar (which pushed Pause off screen).
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.x = 1
	_status_label.max_lines_visible = 2
	info_box.add_child(_status_label)
	_turn_label = _label("UI_TURN", 15, Palette.TEXT_MUTED)
	info_box.add_child(_turn_label)
	var back_button: Button = _button("UI_PAUSE", 120)
	_set_button_icon(back_button, "pause", Palette.TEXT)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(back_button)

	# Opponent: leader panel, then its play area.
	var enemy: Dictionary = _leader_panel(AI_PLAYER)
	_main_layout.add_child(enemy["panel"])
	_enemy_leader_panel = enemy["panel"]
	_enemy_leader_button = enemy["button"]
	_enemy_leader_button.pressed.connect(_on_enemy_leader_pressed)
	_enemy_portrait_frame = enemy["portrait_frame"]
	_enemy_artwork = enemy["artwork"]
	_enemy_portrait_initial = enemy["initial"]
	_enemy_leader_label = enemy["name"]
	_enemy_life_label = enemy["life"]
	_enemy_energy_label = enemy["energy"]
	_enemy_ability_button = enemy["ability"]

	_enemy_zone_frame = _zone_frame("UI_ENEMY_UNITS")
	_main_layout.add_child(_enemy_zone_frame)
	_enemy_artifacts = _board_row(false)
	_enemy_zone_frame.get_child(0).add_child(_enemy_artifacts)
	_enemy_board = _board_row(true)
	_enemy_zone_frame.get_child(0).add_child(_enemy_board)

	# Player: play area, then leader panel.
	_own_zone_frame = _zone_frame("UI_YOUR_UNITS")
	_own_zone_frame.set_drag_forwarding(Callable(), _can_drop_on_own_board, _drop_on_own_board)
	_own_zone_frame.gui_input.connect(_on_own_zone_input)
	_main_layout.add_child(_own_zone_frame)
	_own_artifacts = _board_row(false)
	_own_zone_frame.get_child(0).add_child(_own_artifacts)
	_own_board = _board_row(true)
	_own_board.set_drag_forwarding(Callable(), _can_drop_on_own_board, _drop_on_own_board)
	_own_zone_frame.get_child(0).add_child(_own_board)

	var own: Dictionary = _leader_panel(HUMAN_PLAYER)
	_main_layout.add_child(own["panel"])
	_own_leader_panel = own["panel"]
	_own_leader_button = own["button"]
	_own_leader_button.pressed.connect(_on_own_leader_pressed)
	_own_leader_portrait_frame = own["portrait_frame"]
	_own_leader_artwork = own["artwork"]
	_own_portrait_initial = own["initial"]
	_own_leader_label = own["name"]
	_own_life_label = own["life"]
	_energy_label = own["energy"]
	_ability_button = own["ability"]
	_ability_button.pressed.connect(_on_ability_pressed)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", roundi(10 * _ui_scale))
	_main_layout.add_child(action_row)
	var log_panel: PanelContainer = _framed_panel(Palette.SURFACE, Palette.BORDER)
	log_panel.name = "BattleLogPanel"
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(log_panel)
	var log_box: VBoxContainer = VBoxContainer.new()
	log_panel.add_child(log_box)
	log_box.add_child(_section_label("UI_BATTLE_LOG"))
	_log_label = _label("", 13, Palette.TEXT_MUTED)
	_log_label.custom_minimum_size.y = roundi(54 * _ui_scale)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.max_lines_visible = 3
	log_box.add_child(_log_label)
	_undo_play_button = _button("UI_UNDO_PLAY", 150)
	_set_button_icon(_undo_play_button, "undo", Palette.TEXT)
	_undo_play_button.visible = false
	_undo_play_button.pressed.connect(_on_undo_play_pressed)
	action_row.add_child(_undo_play_button)
	_end_turn_button = _button("UI_END_TURN", 200)
	_set_button_icon(_end_turn_button, "end_turn", Palette.INK)
	_end_turn_button.theme_type_variation = &"ButtonPrimary"
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_undo_play_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_row.add_child(_end_turn_button)

	# The hand always fits the width (cards overlap when needed): no scrollbar to fight with drags.
	# A plain Control (not a container) so the cards' total width never widens the layout.
	var hand_area: Control = Control.new()
	hand_area.name = "HandArea"
	hand_area.custom_minimum_size.y = roundi(350 * _ui_scale)
	hand_area.size_flags_vertical = Control.SIZE_SHRINK_END
	_main_layout.add_child(hand_area)
	_own_hand = HBoxContainer.new()
	_own_hand.alignment = BoxContainer.ALIGNMENT_CENTER
	_own_hand.add_theme_constant_override("separation", roundi(12 * _ui_scale))
	_own_hand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_area.resized.connect(_fit_hand)
	hand_area.add_child(_own_hand)


func _start_match() -> void:
	_results_shown = false
	_doom_explained = false
	_clear_undo()
	_log_lines.clear()
	_pending_events.clear()
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
	_update_leader_panel(
		opponent, _enemy_leader_label, _enemy_life_label, _enemy_energy_label,
		_enemy_artwork, _enemy_portrait_initial, _enemy_ability_button
	)
	_update_leader_panel(
		human, _own_leader_label, _own_life_label, _energy_label,
		_own_leader_artwork, _own_portrait_initial, _ability_button
	)
	_turn_label.text = _turn_text(state)
	# Greyed out when the ability cannot be used now (Energy, already used, no target): no message needed.
	_ability_button.disabled = true
	if state.phase == GameState.Phase.MAIN and state.active_player == HUMAN_PLAYER:
		for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
			if action is UseLeaderAbilityAction:
				_ability_button.disabled = false
				break
	if _ability_button.disabled:
		_selected_ability = false
	# Selected ability (waiting for a target): gold like a primary button; unusable: dimmed.
	_ability_button.theme_type_variation = &"ButtonPrimary" if _selected_ability else &""
	_ability_button.modulate = Color(0.6, 0.6, 0.6) if _ability_button.disabled else Color.WHITE
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
	_update_selection_feedback()
	_apply_highlights()
	_log_label.text = "\n".join(_log_lines.slice(maxi(0, _log_lines.size() - 3)))
	if state.phase == GameState.Phase.REDRAW and state.redraw_player == HUMAN_PLAYER:
		_show_redraw_overlay()
	elif _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	if state.phase == GameState.Phase.GAME_OVER:
		_show_results()


## Turn number of the active player (each player counts their own turns, like the Götterdämmerung rule).
## The countdown appears 3 turns before the Götterdämmerung, then the clock stays shown once it burns.
func _turn_text(state: GameState) -> String:
	var turn: int = maxi(state.player(state.active_player).turns_taken, 1)
	var text: String = "%s %d" % [tr("UI_TURN"), turn]
	var remaining: int = Match.DOOM_START_TURN - turn
	if remaining <= 0:
		text += "  ·  %s" % tr("UI_DOOM_TITLE")
	elif remaining <= 3:
		text += "  ·  %s %d" % [tr("UI_DOOM_IN"), remaining]
	return text


func _status_text(state: GameState) -> String:
	if state.phase == GameState.Phase.REDRAW:
		return tr("UI_CHOOSE_REDRAW") if state.redraw_player == HUMAN_PLAYER else tr("UI_OPPONENT_REDRAW")
	if state.phase == GameState.Phase.GAME_OVER:
		return tr("UI_VICTORY") if state.winner == HUMAN_PLAYER else (tr("UI_DRAW") if state.winner < 0 else tr("UI_DEFEAT"))
	# Turn state only: the borders (gold = can attack, red = target) show what to tap.
	return tr("UI_OPPONENT_TURN") if state.active_player != HUMAN_PLAYER else tr("UI_YOUR_TURN")


## Valid targets of the selected attacker, of the selected or dragged hand card, or of the Leader ability.
func _current_targets() -> Dictionary:
	var targets: Dictionary = {"units": {}, "enemy_leader": false, "own_leader": false}
	var attacker_uid: int = _selected_attacker_uid
	var hand_uid: int = _selected_hand_uid
	if not _drag_source.is_empty():
		attacker_uid = -1
		hand_uid = int(_drag_source["uid"])
	if attacker_uid < 0 and hand_uid < 0 and not _selected_ability:
		return targets
	for action: Action in _match.get_legal_actions(HUMAN_PLAYER):
		var target_uid: int = -1
		var target_player: int = -1
		if action is AttackAction and (action as AttackAction).attacker_uid == attacker_uid:
			target_uid = (action as AttackAction).target_uid
			target_player = (action as AttackAction).target_player
		elif action is PlayCardAction and (action as PlayCardAction).card_uid == hand_uid:
			target_uid = (action as PlayCardAction).target_uid
			target_player = (action as PlayCardAction).target_player
		elif action is UseLeaderAbilityAction and _selected_ability and _drag_source.is_empty():
			target_uid = (action as UseLeaderAbilityAction).target_uid
			target_player = (action as UseLeaderAbilityAction).target_player
		else:
			continue
		if target_uid >= 0:
			(targets["units"] as Dictionary)[target_uid] = true
		elif target_player == AI_PLAYER:
			targets["enemy_leader"] = true
		elif target_player == HUMAN_PLAYER:
			targets["own_leader"] = true
	return targets


## Gold border on units ready to attack, red border on valid targets, dimmed units that cannot attack.
func _apply_highlights() -> void:
	var state: GameState = _match.get_state()
	var my_main_phase: bool = state.phase == GameState.Phase.MAIN and state.active_player == HUMAN_PLAYER
	var targets: Dictionary = _current_targets()
	var choosing: bool = _selected_attacker_uid >= 0 or _selected_hand_uid >= 0 or _selected_ability or not _drag_source.is_empty()
	for row: HFlowContainer in [_own_board, _enemy_board]:
		for child: Node in row.get_children():
			var view: CardView = child as CardView
			if view == null or view.card_instance == null:
				continue
			var uid: int = view.card_instance.uid
			var is_own: bool = row == _own_board
			var ready: bool = is_own and my_main_phase and _match.attack_block_reason(HUMAN_PLAYER, uid) == &""
			if (targets["units"] as Dictionary).has(uid):
				view.set_highlight(&"target")
			elif ready and not choosing:
				view.set_highlight(&"ready")
			else:
				view.set_highlight(&"")
			if is_own:
				view.set_selected(uid == _selected_attacker_uid)
				view.modulate = Color.WHITE if ready or not my_main_phase else Color(0.68, 0.68, 0.68)
			else:
				view.modulate = Color.WHITE
			# Invisible (Tarnhelm) units are drawn see-through on both sides until they attack.
			if view.card_instance.is_hidden():
				view.modulate.a = HIDDEN_ALPHA
	_set_panel_border(_enemy_leader_panel, Palette.LIFE if targets["enemy_leader"] else Palette.BORDER, targets["enemy_leader"])
	_set_panel_border(_own_leader_panel, Palette.LIFE if targets["own_leader"] else Palette.ACCENT, targets["own_leader"])


func _set_panel_border(panel: PanelContainer, color: Color, emphasised: bool) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	style.border_color = color
	style.set_border_width_all(maxi(1, roundi((5 if emphasised else 2) * _ui_scale)))


func _fill_board(row: HFlowContainer, zone: Zone, is_human: bool, zone_name: StringName) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for instance: CardInstance in zone.cards:
		# Board cards are never dragged: attacks are tap-tap only (unit, then target).
		var view: CardView = _card_view(
			instance,
			false,
			HUMAN_PLAYER if is_human else AI_PLAYER,
			"board",
			_match.get_state().phase != GameState.Phase.GAME_OVER
		)
		view.custom_minimum_size = Vector2(170, 200) * _board_card_scale
		view.pressed.connect(_on_board_card_pressed.bind(instance.uid, is_human, zone_name, view))
		row.add_child(view)


func _fill_hand(hand: Zone) -> void:
	# The dragged view is about to be freed and will never report its release: drop the drag.
	if _drag_source.get("kind", "") == "hand":
		_cancel_drag()
	# Detach old views right away: queue_free alone keeps them counted (and laid out) until the end of the frame.
	for child: Node in _own_hand.get_children():
		_own_hand.remove_child(child)
		child.queue_free()
	var state: GameState = _match.get_state()
	var my_main_phase: bool = state.phase == GameState.Phase.MAIN and state.active_player == HUMAN_PLAYER
	for instance: CardInstance in hand.cards:
		var zoom_allowed: bool = state.phase != GameState.Phase.REDRAW and state.phase != GameState.Phase.GAME_OVER
		# Unplayable cards are greyed out and cannot be dragged; the zoom popup tells why.
		# Outside the own turn nothing can be dragged (the AI turn rebuilds the hand mid-drag).
		var blocked: bool = my_main_phase and _match.play_block_reason(HUMAN_PLAYER, instance.uid) != &""
		var view: CardView = _card_view(instance, my_main_phase and not blocked, -1, "hand", zoom_allowed)
		view.set_selected(instance.uid == _selected_hand_uid)
		if blocked:
			view.modulate = Color(0.55, 0.55, 0.55)
		if instance.uid == _selected_hand_uid:
			view.z_index = 1
		view.pressed.connect(_on_hand_card_pressed.bind(instance.uid, view))
		_own_hand.add_child(view)
	if hand.cards.is_empty():
		_own_hand.add_child(_label("UI_NO_CARDS", 16, Palette.TEXT_MUTED))
	_fit_hand()


## Fits the whole hand in the available width: cards overlap instead of scrolling.
func _fit_hand() -> void:
	var count: int = _own_hand.get_child_count()
	var card_width: float = CardView.CARD_SIZE.x * _ui_scale
	# The hand area always spans the layout width; the hand row itself shrinks with its separation.
	var hand_area: Control = _own_hand.get_parent() as Control
	var available: float = hand_area.size.x if hand_area != null and hand_area.size.x > 0.0 else get_viewport().get_visible_rect().size.x - 48.0 * _ui_scale
	var separation: float = 12.0 * _ui_scale
	if count > 1 and count * card_width + (count - 1) * separation > available:
		separation = (available - count * card_width) / float(count - 1)
	_own_hand.add_theme_constant_override("separation", floori(separation))


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
	_icon_stat(title, "energy", Palette.ENERGY, 26).text = str(data.cost)
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
	if instance != null and _match.get_state().player(HUMAN_PLAYER).hand.find(instance.uid) != null:
		var reason: StringName = _match.play_block_reason(HUMAN_PLAYER, instance.uid)
		if reason != &"" and reason != &"not_your_turn":
			var blocked_label: Label = _label(_block_reason_text(reason, instance.uid), 20, Palette.LIFE)
			blocked_label.name = "BlockedReason"
			blocked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(blocked_label)
	var on_own_board: bool = instance != null and _match.get_state().player(HUMAN_PLAYER).board.find(instance.uid) != null
	if on_own_board and _match.get_state().active_player == HUMAN_PLAYER:
		var attack_reason: StringName = _match.attack_block_reason(HUMAN_PLAYER, instance.uid)
		if attack_reason != &"" and attack_reason != &"not_your_turn":
			var attack_label: Label = _label("UI_ATTACK_BLOCKED_%s" % String(attack_reason).to_upper(), 20, Palette.LIFE)
			attack_label.name = "BlockedReason"
			attack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(attack_label)
	if data.type == CardData.Type.UNIT:
		var attack: int = instance.attack if instance != null else data.attack
		var health: int = instance.health if instance != null else data.health
		var stats_row: HBoxContainer = HBoxContainer.new()
		stats_row.add_theme_constant_override("separation", roundi(28 * _ui_scale))
		content.add_child(stats_row)
		_icon_stat(stats_row, "attack", Palette.TEXT, 26).text = str(attack)
		_icon_stat(stats_row, "life", Palette.LIFE, 26).text = str(health)
	var close: Button = _button("UI_CLOSE", 300)
	_set_button_icon(close, "close", Palette.TEXT)
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
	# Near full-screen panel; cards in a grid sized to fit, so the popup never needs scrolling.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel: PanelContainer = _framed_panel(Palette.SURFACE, Palette.ACCENT)
	panel.name = "RedrawPanel"
	panel.custom_minimum_size = Vector2(viewport_size.x - 60.0 * _ui_scale, 0.0)
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(18 * _ui_scale))
	panel.add_child(content)
	var title: Label = _label("UI_REDRAW_TITLE", 28, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var prompt: Label = _label("UI_REDRAW_PROMPT", 18, Palette.TEXT_MUTED)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(prompt)

	# Same card size as in the hand; as many columns as the panel width allows.
	var separation: float = 16.0 * _ui_scale
	var card_width: float = CardView.CARD_SIZE.x * _ui_scale
	var hand: Array[CardInstance] = _match.get_state().player(HUMAN_PLAYER).hand.cards
	var usable_width: float = panel.custom_minimum_size.x - 40.0 * _ui_scale
	var columns: int = clampi(floori((usable_width + separation) / (card_width + separation)), 1, maxi(hand.size(), 1))
	var grid_center: CenterContainer = CenterContainer.new()
	content.add_child(grid_center)
	var cards: GridContainer = GridContainer.new()
	cards.name = "RedrawCards"
	cards.columns = columns
	cards.add_theme_constant_override("h_separation", roundi(separation))
	cards.add_theme_constant_override("v_separation", roundi(separation))
	grid_center.add_child(cards)
	for instance: CardInstance in hand:
		var view: CardView = _card_view(instance)
		var marked: bool = _redraw_selected.has(instance.uid)
		# Marked cards: gold border and dimmed.
		view.set_selected(marked)
		if marked:
			view.modulate = Color(0.75, 0.75, 0.75)
		view.pressed.connect(_toggle_redraw_card.bind(instance.uid, view))
		cards.add_child(view)
	var confirm: Button = _button("UI_REDRAW_CONFIRM", 360)
	confirm.theme_type_variation = &"ButtonPrimary"
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	_pending_events.clear()
	if _match.apply(action):
		_redraw_selected.clear()
		_play_fx(action)
		_continue_ai()


func _on_hand_card_pressed(uid: int, view: CardView) -> void:
	if view.consume_drag():
		return
	if view.consume_long_press():
		return
	if _match.get_state().phase != GameState.Phase.MAIN or _match.get_state().active_player != HUMAN_PLAYER:
		return
	# Unplayable (greyed) cards ignore taps; the zoom popup tells why.
	if _match.play_block_reason(HUMAN_PLAYER, uid) != &"":
		return
	# Tap-tap: the first tap only selects; tapping the same card again cancels.
	if _selected_hand_uid == uid:
		_clear_selection()
		_refresh()
		return
	_selected_hand_uid = uid
	_selected_attacker_uid = -1
	_selected_ability = false
	_refresh()


## Tap on the own play area: plays the selected untargeted card.
func _on_own_zone_input(event: InputEvent) -> void:
	var released: bool = (
		(event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.is_pressed())
		or (event is InputEventScreenTouch and not event.is_pressed())
	)
	if not released or _selected_hand_uid < 0:
		return
	var play: PlayCardAction = _find_play_action(_selected_hand_uid, -1, -1)
	if play != null:
		_apply_action(play)


func _clear_selection() -> void:
	_selected_hand_uid = -1
	_selected_attacker_uid = -1
	_selected_ability = false


## Status text and play-zone highlight for the selected hand card.
func _update_selection_feedback() -> void:
	var state: GameState = _match.get_state()
	var zone_play: bool = false
	if _selected_hand_uid >= 0 and state.player(HUMAN_PLAYER).hand.find(_selected_hand_uid) != null:
		zone_play = _find_play_action(_selected_hand_uid, -1, -1) != null
	elif _selected_hand_uid >= 0:
		_selected_hand_uid = -1
	if _drag_preview != null:
		return
	_drop_hint.visible = zone_play
	if zone_play:
		var target_rect: Rect2 = _own_drop_rect()
		_drop_hint.position = target_rect.position
		_drop_hint.size = target_rect.size


func _block_reason_text(reason: StringName, uid: int) -> String:
	var player: PlayerState = _match.get_state().player(HUMAN_PLAYER)
	var card: CardInstance = player.hand.find(uid)
	return tr("UI_BLOCKED_%s" % String(reason).to_upper()).format({
		"cost": card.data.cost if card != null else 0,
		"energy": player.energy,
	})


func _on_board_card_pressed(uid: int, is_human: bool, zone_name: StringName, view: CardView) -> void:
	if view.consume_drag():
		return
	if view.consume_long_press():
		return
	if _match.get_state().phase != GameState.Phase.MAIN or _match.get_state().active_player != HUMAN_PLAYER:
		return
	if is_human and _selected_hand_uid >= 0 and _find_play_action(_selected_hand_uid, uid) == null:
		# The tap lands inside the own play area: an untargeted card is played there.
		var zone_play: PlayCardAction = _find_play_action(_selected_hand_uid, -1, -1)
		if zone_play != null:
			_apply_action(zone_play)
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
			if _selected_attacker_uid == uid:
				_clear_selection()
				_refresh()
				return
			var reason: StringName = _match.attack_block_reason(HUMAN_PLAYER, uid)
			if reason != &"":
				# Dimmed units cannot be selected; the zoom popup tells why.
				_clear_selection()
				_refresh()
				return
			_selected_attacker_uid = uid
			_selected_hand_uid = -1
			_selected_ability = false
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
	_drag_source = data.duplicate()
	# The "drop here to play" zone only makes sense for a hand card played without a target;
	# targeted cards get their valid targets outlined in red instead.
	var zone_play: bool = (
		data.get("kind", "") == "hand"
		and _find_play_action(int(data.get("uid", -1)), -1, -1) != null
	)
	var target_rect: Rect2 = _own_drop_rect()
	_drop_hint.position = target_rect.position
	_drop_hint.size = target_rect.size
	_drop_hint.visible = zone_play
	_apply_highlights()
	_show_drag_preview(source, get_viewport().get_mouse_position())


func _on_card_drag_moved(_data: Dictionary, position: Vector2) -> void:
	if _drag_preview != null:
		_drag_preview.position = position - _drag_preview.size * 0.5


func _cancel_drag() -> void:
	_drop_hint.visible = false
	_hide_drag_preview()
	_drag_source = {}


func _on_card_drag_released(data: Dictionary, position: Vector2) -> void:
	_drop_hint.visible = false
	_hide_drag_preview()
	_drag_source = {}
	_apply_highlights()
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
	# Only hand cards are dragged; attacks are tap-tap only.
	if String(data.get("kind", "")) != "hand":
		return null
	# A unit target is identified by its uid alone: the engine's actions then have no target player.
	if target_uid >= 0:
		target_player = -1
	return _find_play_action(int(data.get("uid", -1)), target_uid, target_player)


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
		return
	# Tap-tap like cards: a second tap on the selected ability cancels it.
	if _selected_ability:
		_clear_selection()
		_refresh()
		return
	if selected.target_uid >= 0:
		_selected_hand_uid = -1
		_selected_attacker_uid = -1
		_selected_ability = true
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
	_pending_events.clear()
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
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_close_pause()
		return
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(Palette.BG, 0.88)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(_pause_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var panel: PanelContainer = _framed_panel(Palette.SURFACE, Palette.ACCENT)
	panel.name = "PausePanel"
	panel.custom_minimum_size.x = roundi(560 * _ui_scale)
	center.add_child(panel)
	_show_pause_menu(panel)


## Back button: opens or closes the pause panel instead of leaving the match.
func handle_back() -> bool:
	_on_pause_pressed()
	return true


func _show_pause_menu(panel: PanelContainer) -> void:
	for child: Node in panel.get_children():
		child.queue_free()
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(18 * _ui_scale))
	panel.add_child(content)
	var title: Label = _label("UI_PAUSE", 30, Palette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var resume: Button = _button("UI_RESUME", 420)
	resume.name = "ResumeButton"
	resume.theme_type_variation = &"ButtonPrimary"
	resume.pressed.connect(_close_pause)
	content.add_child(resume)
	var leave: Button = _button("UI_LEAVE", 420)
	leave.name = "LeaveButton"
	leave.pressed.connect(_show_leave_confirmation.bind(panel))
	content.add_child(leave)


func _show_leave_confirmation(panel: PanelContainer) -> void:
	for child: Node in panel.get_children():
		child.queue_free()
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(18 * _ui_scale))
	panel.add_child(content)
	var question: Label = _label("UI_LEAVE_MATCH", 24, Palette.TEXT)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(question)
	var confirm: Button = _button("UI_LEAVE", 420)
	confirm.name = "ConfirmLeaveButton"
	confirm.pressed.connect(func() -> void:
		SceneRouter.go_to("res://scenes/screens/splash.tscn", false)
	)
	content.add_child(confirm)
	var cancel: Button = _button("UI_CANCEL", 420)
	cancel.theme_type_variation = &"ButtonPrimary"
	cancel.pressed.connect(_show_pause_menu.bind(panel))
	content.add_child(cancel)


func _close_pause() -> void:
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null


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
	# Taps are blocked by the FX layer, but drags are read in CardView._input: ignore them while animating.
	if _fx.is_busy():
		return
	var snapshot: GameState
	var previous_log_lines: Array[String] = _log_lines.duplicate()
	if action is PlayCardAction:
		snapshot = _match.get_state().duplicate_state()
	_pending_events.clear()
	var applied: bool = _match.apply(action)
	if not applied:
		_pending_events.clear()
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
	_play_fx(action)


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
	await _fx_idle()
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
	_pending_events.clear()
	if action == null or not _match.apply(action):
		push_error("EasyAI returned an invalid redraw action.")
		_ai_busy = false
		return
	await _play_fx(action)
	_ai_busy = false
	_continue_ai()


func _run_ai_turn() -> void:
	await _fx_idle()
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
	var action: Action = Action.from_record(selected)
	_pending_events.clear()
	if action == null or not _match.apply(action):
		_ai_busy = false
		push_error("EasyAI returned an invalid action.")
		return
	# Still busy while animating, so no second AI loop starts meanwhile.
	await _play_fx(action)
	_ai_busy = false
	if _match.get_state().phase == GameState.Phase.MAIN and _match.get_state().active_player == AI_PLAYER:
		_continue_ai()


## Animates the events of the action just applied over the old board, then shows the new state.
## Draws come last: they fly to the new hand slots, which only exist after the refresh.
func _play_fx(action: Action) -> void:
	var events: Array[GameEvent] = _pending_events.duplicate()
	_pending_events.clear()
	if _fx.is_instant() or not is_inside_tree():
		_refresh()
		if _doom_popup_due(events):
			await _show_doom_popup()
		return
	_fx.begin()
	for event: GameEvent in events:
		match event.type:
			&"card_played":
				await _fx_spell(event, action)
			&"attack_declared":
				await _fx_attack(event)
			&"damage_dealt":
				_fx.play_damage(_unit_or_leader_rect(event.target_uid, 1 - event.player), event.amount)
			&"gotterdammerung_damage":
				_fx.play_damage(_unit_or_leader_rect(-1, event.player), event.amount)
			&"unit_destroyed":
				var dead: CardView = _find_view(event.card_uid)
				if dead != null:
					dead.modulate.a = 0.0
					await _fx.play_death(dead.card_data, dead.shown_instance(), dead.get_global_rect())
	_refresh()
	var drawn: Array[GameEvent] = []
	for event: GameEvent in events:
		if event.type == &"card_drawn":
			drawn.append(event)
	if not drawn.is_empty():
		# Let the containers place the new hand cards first.
		await get_tree().process_frame
		for event: GameEvent in drawn:
			await _fx_draw(event)
	# The match waits (input and AI) until the player closes the explanation.
	if _doom_popup_due(events):
		await _show_doom_popup()
	_fx.end()


## The first Götterdämmerung damage of the match opens the explanation, unless that damage ended the match.
func _doom_popup_due(events: Array[GameEvent]) -> bool:
	if _doom_explained or _match.get_state().phase == GameState.Phase.GAME_OVER:
		return false
	for event: GameEvent in events:
		if event.type == &"gotterdammerung_damage":
			return true
	return false


## Explains the end-game clock; closed only with its button.
func _show_doom_popup() -> void:
	_doom_explained = true
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "DoomOverlay"
	overlay.color = Color(Palette.BG, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel: PanelContainer = _framed_panel(Palette.SURFACE, Palette.LIFE)
	panel.name = "DoomPanel"
	panel.custom_minimum_size.x = roundi(760 * _ui_scale)
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(18 * _ui_scale))
	panel.add_child(content)
	var title: Label = _label("UI_DOOM_TITLE", 30, Palette.LIFE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var text: Label = _label("UI_DOOM_TEXT", 20, Palette.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = roundi(700 * _ui_scale)
	content.add_child(text)
	var close: Button = _button("UI_DOOM_CLOSE", 420)
	close.name = "DoomCloseButton"
	close.theme_type_variation = &"ButtonPrimary"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(close)
	# A tap outside the panel closes it too (taps on the panel itself stop there),
	# but not a tap that was already under way when it opened.
	var opened_at: int = Time.get_ticks_msec()
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if Time.get_ticks_msec() - opened_at < 400:
			return
		var released: bool = (
			(event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.is_pressed())
			or (event is InputEventScreenTouch and not event.is_pressed())
		)
		if released:
			close.pressed.emit()
	)
	# Counts as a running animation, so the AI waits for it even at instant speed.
	_fx.begin()
	await close.pressed
	overlay.queue_free()
	_fx.end()


func _fx_spell(event: GameEvent, action: Action) -> void:
	var play: PlayCardAction = action as PlayCardAction
	var card: CardInstance = _match.get_state().player(event.player).graveyard.find(event.card_uid)
	if play == null or card == null or card.data.type != CardData.Type.SPELL:
		return
	var from: Rect2
	var view: CardView = _find_view(event.card_uid)
	if view != null:
		from = view.get_global_rect()
		view.modulate.a = 0.0
	else:
		# Enemy spells come out of the enemy Leader panel (its hand is hidden).
		var card_size: Vector2 = CardView.CARD_SIZE * _ui_scale
		from = Rect2(_enemy_leader_panel.get_global_rect().get_center() - card_size * 0.5, card_size)
	var target: Rect2 = Rect2()
	if play.target_uid >= 0 or play.target_player >= 0:
		target = _unit_or_leader_rect(play.target_uid, play.target_player)
	await _fx.play_spell(card.data, card, from, target)


func _fx_attack(event: GameEvent) -> void:
	var attacker: CardView = _find_view(event.card_uid)
	if attacker == null:
		return
	var target: Rect2 = _unit_or_leader_rect(event.target_uid, 1 - event.player)
	attacker.modulate.a = 0.0
	await _fx.play_attack(attacker.card_data, attacker.shown_instance(), attacker.get_global_rect(), target)
	attacker.modulate.a = 1.0


func _fx_draw(event: GameEvent) -> void:
	if event.player != HUMAN_PLAYER:
		await _fx.play_enemy_draw(_enemy_leader_panel.get_global_rect())
		return
	var view: CardView = _find_view(event.card_uid)
	if view == null:
		return
	var shown: Color = view.modulate
	view.modulate.a = 0.0
	await _fx.play_draw(view.card_data, view.card_instance, view.get_global_rect())
	if is_instance_valid(view):
		view.modulate = shown


func _fx_idle() -> void:
	if _fx.is_busy():
		await _fx.idle


## Card view showing this card uid (hand, boards, artifacts), or null.
func _find_view(uid: int) -> CardView:
	for row: Control in [_own_hand, _own_board, _enemy_board, _own_artifacts, _enemy_artifacts]:
		for child: Node in row.get_children():
			var view: CardView = child as CardView
			if view != null and view.card_instance != null and view.card_instance.uid == uid:
				return view
	return null


## Screen rect of a unit (uid >= 0) or else of a Leader panel; empty when neither exists.
func _unit_or_leader_rect(uid: int, player: int) -> Rect2:
	if uid >= 0:
		var view: CardView = _find_view(uid)
		return view.get_global_rect() if view != null else Rect2()
	if player == AI_PLAYER:
		return _enemy_leader_panel.get_global_rect()
	if player == HUMAN_PLAYER:
		return _own_leader_panel.get_global_rect()
	return Rect2()


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
	_set_button_icon(_results_undo_button, "undo", Palette.TEXT)
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
	# No refresh here: the board keeps its old state until the action is animated (_play_fx).
	_pending_events.append(event)


func _event_message(event: GameEvent) -> String:
	match event.type:
		&"turn_started":
			return tr("UI_LOG_TURN_STARTED").format({
				"turn": event.turn,
				"player": _leader_name(event.player),
			})
		&"card_played":
			return tr("UI_LOG_CARD_PLAYED").format({
				"player": tr("UI_YOU") if event.player == HUMAN_PLAYER else _leader_name(event.player),
			})
		&"damage_dealt":
			return tr("UI_LOG_DAMAGE").format({
				"player": _leader_name(event.player),
				"amount": event.amount,
			})
		&"ring_taken":
			return tr("UI_LOG_RING").format({
				"player": tr("UI_YOU") if event.player == HUMAN_PLAYER else _leader_name(event.player),
			})
		&"match_ended":
			return tr("UI_LOG_MATCH_ENDED")
		_:
			return ""


## Units rows keep a card's height when empty so the layout never jumps; artifact rows only take room when used.
## Flow rows wrap onto a second line instead of growing wider than the screen (which widened the whole layout).
func _board_row(is_units_row: bool) -> HFlowContainer:
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", roundi(8 * _board_card_scale))
	row.add_theme_constant_override("v_separation", roundi(8 * _board_card_scale))
	if is_units_row:
		row.custom_minimum_size.y = roundi(200 * _board_card_scale)
	return row


func _framed_panel(background_color: Color, border_color: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(maxi(1, roundi(2 * _ui_scale)))
	style.set_corner_radius_all(roundi(12 * _ui_scale))
	style.set_content_margin_all(roundi(10 * _ui_scale))
	panel.add_theme_stylebox_override("panel", style)
	return panel


## A framed play area (units + artifacts) replacing separator lines between the two sides.
func _zone_frame(title: String) -> PanelContainer:
	var frame: PanelContainer = _framed_panel(Color(Palette.SURFACE, 0.55), Palette.BORDER)
	frame.name = title.to_pascal_case() + "Zone"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(6 * _ui_scale))
	frame.add_child(box)
	box.add_child(_section_label(title))
	return frame


## Same leader panel for both players: portrait, name, Life, Energy and the named ability.
func _leader_panel(player_id: int) -> Dictionary:
	var is_human: bool = player_id == HUMAN_PLAYER
	var panel: PanelContainer = _framed_panel(Palette.SURFACE, Palette.ACCENT if is_human else Palette.BORDER)
	panel.name = "OwnLeaderPanel" if is_human else "EnemyLeaderPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(10 * _ui_scale))
	panel.add_child(row)

	var button: Button = Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = roundi(90 * _ui_scale)
	button.set_drag_forwarding(Callable(), _can_drop_on_leader.bind(player_id), _drop_on_leader.bind(player_id))
	row.add_child(button)
	var content: HBoxContainer = HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", roundi(12 * _ui_scale))
	button.add_child(content)

	var portrait_frame: Panel = Panel.new()
	portrait_frame.name = "OwnLeaderPortraitFrame" if is_human else "EnemyLeaderPortraitFrame"
	portrait_frame.custom_minimum_size = Vector2(roundi(70 * _ui_scale), roundi(86 * _ui_scale))
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait_style: StyleBoxFlat = StyleBoxFlat.new()
	portrait_style.bg_color = Palette.ACCENT.darkened(0.3) if is_human else Palette.SURFACE_RAISED
	portrait_style.border_color = Palette.ACCENT if is_human else Palette.BORDER
	portrait_style.set_border_width_all(maxi(2, roundi(2 * _ui_scale)))
	portrait_style.set_corner_radius_all(maxi(8, roundi(8 * _ui_scale)))
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait_frame)
	var initial: Label = _label("", 34, Palette.ACCENT)
	initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(initial)
	var artwork: TextureRect = TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.offset_left = roundi(2 * _ui_scale)
	artwork.offset_top = roundi(2 * _ui_scale)
	artwork.offset_right = roundi(-2 * _ui_scale)
	artwork.offset_bottom = roundi(-2 * _ui_scale)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(artwork)

	var info: VBoxContainer = VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info)
	var name_label: Label = _label("", 20, Palette.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)
	var stats: HBoxContainer = HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", roundi(16 * _ui_scale))
	info.add_child(stats)
	var life: Label = _icon_stat(stats, "life", Palette.LIFE, 20)
	var energy: Label = _icon_stat(stats, "energy", Palette.ENERGY, 20)

	var ability: Button = Button.new()
	ability.name = "OwnAbilityButton" if is_human else "EnemyAbilityButton"
	ability.custom_minimum_size = Vector2(roundi(250 * _ui_scale), roundi(90 * _ui_scale))
	ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ability.add_theme_font_size_override("font_size", roundi(15 * _ui_scale))
	_set_button_icon(ability, "energy", Palette.ENERGY)
	if not is_human:
		ability.disabled = true
		ability.focus_mode = Control.FOCUS_NONE
	row.add_child(ability)

	return {
		"panel": panel,
		"button": button,
		"portrait_frame": portrait_frame,
		"artwork": artwork,
		"initial": initial,
		"name": name_label,
		"life": life,
		"energy": energy,
		"ability": ability,
	}


func _update_leader_panel(player: PlayerState, name_label: Label, life_label: Label, energy_label: Label, artwork: TextureRect, initial: Label, ability_button: Button) -> void:
	var key: String = String(player.leader.id).to_upper()
	var leader_name: String = tr("LEADER_%s_NAME" % key)
	name_label.text = leader_name
	life_label.text = str(player.life)
	energy_label.text = "%d / %d" % [player.energy, player.max_energy]
	artwork.texture = player.leader.art
	artwork.visible = player.leader.art != null
	initial.text = leader_name.left(1)
	initial.visible = player.leader.art == null
	if player.leader.ability == null:
		ability_button.text = tr("UI_ABILITY")
		return
	# The Energy icon sits on the button; the text starts with the cost, then the ability name and effect.
	ability_button.text = "%d   %s\n%s" % [
		player.leader.ability.cost,
		tr("LEADER_%s_ABILITY_NAME" % key),
		tr("LEADER_%s_ABILITY_TEXT" % key),
	]


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


## The whole framed play area (units + artifacts) accepts drops.
func _own_drop_rect() -> Rect2:
	return _own_zone_frame.get_global_rect()


func _show_drag_preview(source: CardView, position: Vector2) -> void:
	_hide_drag_preview()
	# A non-interactive copy of the dragged card: same face (cost, name, rules, stats) and size.
	var preview: CardView = CARD_VIEW_SCRIPT.new()
	preview.name = "CardDragPreview"
	preview.set_card(source.card_data, source.card_instance, false, -1, "hand", false)
	preview.set_view_scale(_ui_scale)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.custom_minimum_size = source.custom_minimum_size
	preview.size = source.custom_minimum_size
	_drag_preview = preview
	_modal_layer.add_child(_drag_preview)
	preview.remove_from_group("duel_card_views")
	_drag_preview.position = position - _drag_preview.custom_minimum_size * 0.5


func _hide_drag_preview() -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null


func _leader_name(player_id: int) -> String:
	if _match == null or player_id < 0 or player_id > 1:
		return ""
	return tr("LEADER_%s_NAME" % String(_match.get_state().player(player_id).leader.id).to_upper())


## Standard UI icons: library SVGs (game-icons.net, CC BY 3.0 — see CREDITS.md), tinted with modulate.
func _icon(icon_name: String) -> Texture2D:
	return load("res://ui/icons/%s.svg" % icon_name) as Texture2D


## Icon + value label in a row; returns the label to update.
func _icon_stat(parent: Container, icon_name: String, color: Color, font_size: int) -> Label:
	var box: HBoxContainer = HBoxContainer.new()
	box.name = icon_name.to_pascal_case() + "Stat"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", roundi(5 * _ui_scale))
	box.tooltip_text = tr("UI_%s" % icon_name.to_upper())
	parent.add_child(box)
	var icon: TextureRect = TextureRect.new()
	icon.texture = _icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * roundi(font_size * 1.15 * _ui_scale)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var value: Label = _label("", font_size, color)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(value)
	return value


func _set_button_icon(button: Button, icon_name: String, color: Color) -> void:
	button.icon = _icon(icon_name)
	button.add_theme_constant_override("icon_max_width", roundi(26 * _ui_scale))
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(state, color)
	button.add_theme_color_override("icon_disabled_color", Palette.TEXT_DISABLED)
