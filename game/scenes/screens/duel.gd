extends Control

const HUMAN_PLAYER: int = 0
const AI_PLAYER: int = 1
const AI_DELAY: float = 0.45
const CARD_VIEW_SCRIPT: Script = preload("res://scenes/components/card_view.gd")

var _match: Match
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
var _own_leader_button: Button
var _own_leader_label: Label
var _energy_label: Label
var _deck_label: Label
var _log_label: Label
var _end_turn_button: Button
var _ability_button: Button
var _overlay: ColorRect
var _main_layout: VBoxContainer
var _results_shown: bool = false


func _ready() -> void:
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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	_main_layout = VBoxContainer.new()
	_main_layout.add_theme_constant_override("separation", 12)
	margin.add_child(_main_layout)

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
	_enemy_leader_button.custom_minimum_size.y = 92
	_enemy_leader_button.pressed.connect(_on_enemy_leader_pressed)
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
	_main_layout.add_child(_own_board)
	_main_layout.add_child(_section_label("UI_YOUR_UNITS"))

	var own_leader_row: HBoxContainer = HBoxContainer.new()
	_main_layout.add_child(own_leader_row)
	_own_leader_button = _button("", 100)
	_own_leader_button.custom_minimum_size.y = 86
	_own_leader_button.pressed.connect(_on_own_leader_pressed)
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
	_end_turn_button = _button("UI_END_TURN", 200)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	action_row.add_child(_end_turn_button)

	var log_title: Label = _section_label("UI_BATTLE_LOG")
	_main_layout.add_child(log_title)
	_log_label = _label("", 14, Palette.TEXT_MUTED)
	_log_label.custom_minimum_size.y = 50
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_layout.add_child(_log_label)

	var hand_scroll: ScrollContainer = ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 286
	hand_scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_layout.add_child(hand_scroll)
	_own_hand = HBoxContainer.new()
	_own_hand.add_theme_constant_override("separation", 12)
	hand_scroll.add_child(_own_hand)


func _start_match() -> void:
	_results_shown = false
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
		var view: Button = _card_view(instance)
		view.custom_minimum_size = Vector2(148, 174)
		view.pressed.connect(_on_board_card_pressed.bind(instance.uid, is_human, zone_name))
		if is_human and instance.can_attack and not instance.exhausted:
			view.modulate = Color.WHITE
		elif is_human and instance.exhausted:
			view.modulate = Color(0.68, 0.68, 0.68)
		row.add_child(view)
	if zone.cards.is_empty():
		var empty: Label = _label("—", 18, Palette.TEXT_DISABLED)
		empty.custom_minimum_size = Vector2(108, 56)
		row.add_child(empty)


func _fill_hand(hand: Zone) -> void:
	for child: Node in _own_hand.get_children():
		child.queue_free()
	for instance: CardInstance in hand.cards:
		var view: Button = _card_view(instance)
		view.set_selected(instance.uid == _selected_hand_uid)
		view.pressed.connect(_on_hand_card_pressed.bind(instance.uid))
		_own_hand.add_child(view)
	if hand.cards.is_empty():
		_own_hand.add_child(_label("UI_NO_CARDS", 16, Palette.TEXT_MUTED))


func _card_view(instance: CardInstance) -> Button:
	var view: Button = CARD_VIEW_SCRIPT.new()
	view.set_card(instance.data, instance)
	return view


func _show_redraw_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = ColorRect.new()
	_overlay.color = Color(Palette.BG, 0.96)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 20
	add_child(_overlay)
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
		var view: Button = _card_view(instance)
		view.custom_minimum_size = Vector2(154, 250)
		view.set_selected(_redraw_selected.has(instance.uid))
		view.pressed.connect(_toggle_redraw_card.bind(instance.uid))
		cards.add_child(view)
	var confirm: Button = _button("UI_REDRAW_CONFIRM", 300)
	confirm.pressed.connect(_confirm_redraw)
	content.add_child(confirm)


func _toggle_redraw_card(uid: int) -> void:
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


func _on_hand_card_pressed(uid: int) -> void:
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


func _on_board_card_pressed(uid: int, is_human: bool, zone_name: StringName) -> void:
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
	if not _match.apply(action):
		_set_status("UI_INVALID_ACTION")
		return
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
	_match.apply(RedrawAction.new(AI_PLAYER))
	_ai_busy = false
	_refresh()
	_continue_ai()


func _run_ai_turn() -> void:
	await get_tree().create_timer(AI_DELAY).timeout
	var state: GameState = _match.get_state()
	if state.phase != GameState.Phase.MAIN or state.active_player != AI_PLAYER:
		_ai_busy = false
		return
	var records: Array[Dictionary] = []
	for action: Action in _match.get_legal_actions(AI_PLAYER):
		records.append(action.to_record())
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
	_overlay.color = Color(Palette.BG, 0.94)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 30
	add_child(_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	center.add_child(content)
	content.add_child(_label(_status_text(_match.get_state()), 42, Palette.ACCENT))
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
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 180
	return row


func _section_label(value: String) -> Label:
	return _label(tr(value), 13, Palette.TEXT_MUTED)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = tr(value)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, width: float) -> Button:
	var button: Button = Button.new()
	button.text = tr(value)
	button.custom_minimum_size = Vector2(width, 62)
	button.add_theme_font_size_override("font_size", 17)
	return button
