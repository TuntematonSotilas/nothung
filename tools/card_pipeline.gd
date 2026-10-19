extends SceneTree

const CARD_TYPES: Dictionary = {
	"unit": CardData.Type.UNIT,
	"spell": CardData.Type.SPELL,
	"artifact": CardData.Type.ARTIFACT,
}
const RARITIES: Dictionary = {
	"common": CardData.Rarity.COMMON,
	"rare": CardData.Rarity.RARE,
	"epic": CardData.Rarity.EPIC,
	"legendary": CardData.Rarity.LEGENDARY,
}
const KEYWORDS: Array[String] = ["guard", "charge", "flying", "valhalla"]
const TRIGGERS: Array[String] = [
	"on_play",
	"on_death",
	"on_bearer_death",
	"start_of_turn",
	"end_of_turn",
	"on_attack",
	"on_damage",
]
const TARGETS: Dictionary = {
	"self": EffectData.Target.SELF,
	"selected_unit": EffectData.Target.SELECTED_UNIT,
	"friendly_leader": EffectData.Target.FRIENDLY_LEADER,
	"enemy_leader": EffectData.Target.ENEMY_LEADER,
	"all_friendly_units": EffectData.Target.ALL_FRIENDLY_UNITS,
	"all_enemy_units": EffectData.Target.ALL_ENEMY_UNITS,
	"all_units": EffectData.Target.ALL_UNITS,
	"all_leaders": EffectData.Target.ALL_LEADERS,
	"bearer": EffectData.Target.BEARER,
}
const CARD_HEADER: PackedStringArray = [
	"id",
	"name",
	"type",
	"subtypes",
	"rarity",
	"cost",
	"atk",
	"hp",
	"keywords",
	"bearer",
	"abilities",
	"leitmotifs",
	"flavour",
]
const LEADER_HEADER: PackedStringArray = ["id", "name", "faction", "life", "ability_cost", "ability", "flavour"]
const DECK_HEADER: PackedStringArray = ["id", "leader", "cards"]
const ART_DIRECTORY: String = "res://assets/art/cards"

var _repo_root: String
var _errors: Array[String] = []
var _resources: Dictionary = {}
var _cards: Dictionary = {}
var _leaders: Dictionary = {}
var _decks: Dictionary = {}
var _pending_card_refs: Array[Dictionary] = []
var _translation_entries: Dictionary = {}
var _card_names: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run_pipeline")


func _run_pipeline() -> void:
	_repo_root = ProjectSettings.globalize_path("res://").simplify_path().get_base_dir()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument != "--check":
			_error("arguments", 0, "Unknown argument: %s" % argument)
	if not _errors.is_empty():
		_report_errors()
		call_deferred("_exit_after_frame", 2)
		return
	var check_only: bool = arguments.has("--check")
	if not _load_sources():
		_report_errors()
		call_deferred("_exit_after_frame", 1)
		return
	if not _resolve_references():
		_report_errors()
		call_deferred("_exit_after_frame", 1)
		return
	_collect_rules_texts()
	if not _validate_decks():
		_report_errors()
		call_deferred("_exit_after_frame", 1)
		return
	var csv_path: String = "res://localization/strings.csv"
	var generated_csv: String = _updated_localization(csv_path)
	if not _errors.is_empty():
		_report_errors()
		call_deferred("_exit_after_frame", 1)
		return
	var expected: Dictionary = _serialize_resources()
	if not _errors.is_empty():
		_report_errors()
		call_deferred("_exit_after_frame", 1)
		return
	expected[csv_path] = generated_csv
	if check_only:
		if _check_outputs(expected):
			print("Card pipeline is up to date.")
			call_deferred("_exit_after_frame", 0)
			return
		_report_errors()
		call_deferred("_exit_after_frame", 1)
	else:
		if _write_outputs(expected):
			print("Generated %d cards, %d leaders and %d decks." % [_cards.size(), _leaders.size(), _decks.size()])
			call_deferred("_exit_after_frame", 0)
			return
		_report_errors()
		call_deferred("_exit_after_frame", 1)


func _exit_after_frame(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _load_sources() -> bool:
	var cards_dir: String = _repo_root.path_join("cards")
	var factions: PackedStringArray = DirAccess.get_files_at(cards_dir)
	factions.sort()
	for filename: String in factions:
		if not filename.ends_with(".md") or filename in ["leaders.md", "starter_decks.md"]:
			continue
		var faction: String = filename.get_basename()
		var path: String = cards_dir.path_join(filename)
		var rows: Array[Dictionary] = _read_table(path, CARD_HEADER)
		for row: Dictionary in rows:
			var card: CardData = _parse_card(row, faction, path)
			if card == null:
				continue
			var card_id: String = String(card.id)
			if _cards.has(card_id):
				_error(path, int(row["line"]), "Duplicate card id: %s" % card_id)
				continue
			_cards[card_id] = card
			_card_names[card_id] = String(row["name"])
			_translation_entries["CARD_%s_NAME" % card_id.to_upper()] = String(row["name"])
			if not String(row["flavour"]).is_empty():
				_translation_entries["CARD_%s_FLAVOUR" % card_id.to_upper()] = String(row["flavour"])
			var resource_path: String = "res://data/cards/%s/%s.tres" % [faction, card_id]
			card.take_over_path(resource_path)
			_resources[resource_path] = card

	var leaders_path: String = cards_dir.path_join("leaders.md")
	for row: Dictionary in _read_table(leaders_path, LEADER_HEADER):
		var leader: LeaderData = _parse_leader(row, leaders_path)
		if leader == null:
			continue
		var leader_id: String = String(leader.id)
		if _leaders.has(leader_id):
			_error(leaders_path, int(row["line"]), "Duplicate leader id: %s" % leader_id)
			continue
		_leaders[leader_id] = leader
		_translation_entries["LEADER_%s_NAME" % leader_id.to_upper()] = String(row["name"])
		if not String(row["flavour"]).is_empty():
			_translation_entries["LEADER_%s_FLAVOUR" % leader_id.to_upper()] = String(row["flavour"])
		var leader_resource_path: String = "res://data/leaders/%s.tres" % leader_id
		leader.take_over_path(leader_resource_path)
		_resources[leader_resource_path] = leader

	if not _errors.is_empty():
		return false
	for row: Dictionary in _read_table(cards_dir.path_join("starter_decks.md"), DECK_HEADER):
		var deck: DeckData = _parse_deck(row, cards_dir.path_join("starter_decks.md"))
		if deck == null:
			continue
		var deck_id: String = String(deck.id)
		if _decks.has(deck_id):
			_error(cards_dir.path_join("starter_decks.md"), int(row["line"]), "Duplicate deck id: %s" % deck_id)
			continue
		_decks[deck_id] = deck
		var deck_resource_path: String = "res://data/decks/%s.tres" % deck_id
		deck.take_over_path(deck_resource_path)
		_resources[deck_resource_path] = deck
	return _errors.is_empty()


func _read_table(path: String, required_header: PackedStringArray) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		_error(path, 0, "Source file does not exist.")
		return rows
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error(path, 0, "Could not open source file.")
		return rows
	var header: PackedStringArray
	var line_number: int = 0
	while not file.eof_reached():
		line_number += 1
		var line: String = file.get_line().strip_edges()
		if not line.begins_with("|") or line.begins_with("|--") or line.begins_with("| -"):
			continue
		var cells: PackedStringArray = _split_table_row(line)
		if header.is_empty():
			header = cells
			if header != required_header:
				_error(path, line_number, "Expected table columns: %s" % ", ".join(required_header))
				return rows
			continue
		if cells.size() != header.size():
			_error(path, line_number, "Expected %d columns, got %d." % [header.size(), cells.size()])
			continue
		var row: Dictionary = {}
		for index: int in header.size():
			row[header[index]] = cells[index]
		row["line"] = line_number
		rows.append(row)
	if header.is_empty():
		_error(path, 0, "No Markdown table found.")
	return rows


func _split_table_row(line: String) -> PackedStringArray:
	var cells: PackedStringArray = line.trim_prefix("|").trim_suffix("|").split("|", false)
	for index: int in cells.size():
		cells[index] = cells[index].strip_edges()
	return cells


func _parse_card(row: Dictionary, faction: String, path: String) -> CardData:
	var error_count: int = _errors.size()
	var line: int = int(row["line"])
	var card_id: String = String(row["id"])
	if not _valid_id(card_id):
		_error(path, line, "Invalid card id: %s" % card_id)
		return null
	var type_name: String = String(row["type"]).to_lower()
	var rarity_name: String = String(row["rarity"]).to_lower()
	if not CARD_TYPES.has(type_name):
		_error(path, line, "Unknown card type: %s" % type_name)
		return null
	if not RARITIES.has(rarity_name):
		_error(path, line, "Unknown rarity: %s" % rarity_name)
		return null
	var cost: int = _required_int(row, "cost", 0, 10, path, line)
	var attack: int = _optional_int(row, "atk", 0, path, line)
	var health: int = _optional_int(row, "hp", 0, path, line)
	if cost < 0 or attack < 0 or health < 0:
		return null
	var card: CardData = CardData.new()
	card.id = StringName(card_id)
	card.faction = StringName(faction)
	card.type = CARD_TYPES[type_name]
	card.rarity = RARITIES[rarity_name]
	card.cost = cost
	card.attack = attack
	card.health = health
	card.subtypes = _name_list(String(row["subtypes"]))
	card.bearer = _name_list(String(row["bearer"]))
	card.leitmotifs = _name_list(String(row["leitmotifs"]))
	card.keywords = _name_list(String(row["keywords"]))
	for keyword: StringName in card.keywords:
		if not KEYWORDS.has(String(keyword)):
			_error(path, line, "Unknown or unimplemented trait: %s" % keyword)
	if String(row["name"]).strip_edges().is_empty():
		_error(path, line, "Card name is required.")
	if card.type == CardData.Type.UNIT and (attack < 0 or health < 1):
		_error(path, line, "Units need non-negative attack and positive health.")
	if card.type == CardData.Type.SPELL and String(row["abilities"]).strip_edges().is_empty():
		_error(path, line, "Spells need at least one ability.")
	if card.type != CardData.Type.UNIT and (attack != 0 or health != 0):
		_error(path, line, "Only units can have attack or health.")
	_parse_abilities(String(row["abilities"]), card.abilities, path, line)
	if _errors.size() > error_count:
		return null
	card.art = _art_for("%s.png" % card_id)
	return card


func _parse_leader(row: Dictionary, path: String) -> LeaderData:
	var line: int = int(row["line"])
	var leader_id: String = String(row["id"])
	if not _valid_id(leader_id):
		_error(path, line, "Invalid leader id: %s" % leader_id)
		return null
	var life: int = _required_int(row, "life", 1, 99, path, line)
	var ability_cost: int = _required_int(row, "ability_cost", 0, 10, path, line)
	if life < 1 or String(row["faction"]).strip_edges().is_empty() or String(row["name"]).strip_edges().is_empty():
		_error(path, line, "Leader name, faction and valid life are required.")
		return null
	var leader: LeaderData = LeaderData.new()
	leader.id = StringName(leader_id)
	leader.faction = StringName(String(row["faction"]))
	leader.life = life
	if not String(row["ability"]).strip_edges().is_empty():
		var ability: AbilityData = AbilityData.new()
		ability.cost = ability_cost
		var effect: EffectData = _parse_effect(String(row["ability"]), path, line)
		if effect != null:
			if effect.kind == EffectData.Kind.CREATE_RING:
				_error(path, line, "Leader abilities cannot create the Ring.")
			ability.effects.append(effect)
			leader.ability = ability
	leader.art = _art_for("%s_leader.png" % leader_id)
	return leader


## Artwork is found by naming convention: res://assets/art/cards/<card_id>.png or <leader_id>_leader.png.
func _art_for(file_name: String) -> Texture2D:
	var art_path: String = ART_DIRECTORY.path_join(file_name)
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D


func _parse_deck(row: Dictionary, path: String) -> DeckData:
	var line: int = int(row["line"])
	var deck_id: String = String(row["id"])
	var leader_id: String = String(row["leader"])
	if not _valid_id(deck_id):
		_error(path, line, "Invalid deck id: %s" % deck_id)
		return null
	if not _leaders.has(leader_id):
		_error(path, line, "Unknown leader id: %s" % leader_id)
		return null
	var deck: DeckData = DeckData.new()
	deck.id = StringName(deck_id)
	deck.leader = _leaders[leader_id]
	for value: String in String(row["cards"]).split(",", false):
		var card_id: String = value.strip_edges()
		if not _cards.has(card_id):
			_error(path, line, "Unknown card id: %s" % card_id)
			continue
		deck.cards.append(_cards[card_id])
	return deck


func _parse_abilities(source: String, destination: Array[AbilityData], path: String, line: int) -> void:
	if source.strip_edges().is_empty():
		return
	for clause: String in source.split(";", false):
		var separator: int = clause.find(":")
		if separator < 1:
			_error(path, line, "Ability must use trigger[condition]: effect(args).")
			continue
		var trigger_part: String = clause.substr(0, separator).strip_edges()
		var effect_text: String = clause.substr(separator + 1).strip_edges()
		var trigger: String = trigger_part
		var condition_text: String = ""
		var open_bracket: int = trigger_part.find("[")
		if open_bracket >= 0:
			if not trigger_part.ends_with("]"):
				_error(path, line, "Malformed ability condition: %s" % trigger_part)
				continue
			trigger = trigger_part.substr(0, open_bracket).strip_edges()
			condition_text = trigger_part.substr(open_bracket + 1, trigger_part.length() - open_bracket - 2).strip_edges()
		if not TRIGGERS.has(trigger):
			_error(path, line, "Unknown or unsupported trigger: %s" % trigger)
			continue
		var ability: AbilityData = AbilityData.new()
		ability.trigger = StringName(trigger)
		if not condition_text.is_empty():
			ability.condition = _parse_condition(condition_text, path, line)
		var effect: EffectData = _parse_effect(effect_text, path, line)
		if effect != null:
			ability.effects.append(effect)
		if effect != null and (condition_text.is_empty() or ability.condition != null):
			destination.append(ability)


func _parse_condition(source: String, path: String, line: int) -> ConditionData:
	var condition: ConditionData = ConditionData.new()
	if source == "holds_ring":
		condition.kind = ConditionData.Kind.HOLDS_RING
		return condition
	if source.begins_with("controls(") and source.ends_with(")"):
		var card_id: String = source.substr(9, source.length() - 10).strip_edges()
		if not _valid_id(card_id):
			_error(path, line, "Invalid card id in condition: %s" % card_id)
			return null
		condition.kind = ConditionData.Kind.CONTROLS_CARD
		condition.card_id = StringName(card_id)
		return condition
	_error(path, line, "Unknown condition: %s" % source)
	return null


func _parse_effect(source: String, path: String, line: int) -> EffectData:
	var regex: RegEx = RegEx.new()
	regex.compile("^([a-z_]+)\\((.*)\\)$")
	var found: RegExMatch = regex.search(source.strip_edges())
	if found == null:
		_error(path, line, "Malformed effect: %s" % source)
		return null
	var kind: String = found.get_string(1)
	var args: PackedStringArray = found.get_string(2).split(",", false)
	for index: int in args.size():
		args[index] = args[index].strip_edges()
	var effect: EffectData = EffectData.new()
	match kind:
		"damage":
			effect.kind = EffectData.Kind.DEAL_DAMAGE
			if not _read_target_and_amount(args, effect, path, line):
				return null
		"draw":
			effect.kind = EffectData.Kind.DRAW_CARDS
			if not _read_amount(args, effect, path, line):
				return null
		"gain_energy":
			effect.kind = EffectData.Kind.GAIN_ENERGY
			if not _read_amount(args, effect, path, line):
				return null
		"summon":
			effect.kind = EffectData.Kind.SUMMON
			if not _read_card_ref(args, effect, "unit", path, line):
				return null
		"heal":
			effect.kind = EffectData.Kind.HEAL
			if not _read_target_and_amount(args, effect, path, line):
				return null
		"buff":
			effect.kind = EffectData.Kind.BUFF
			if args.size() < 3 or args.size() > 4 or not _set_target(args[0], effect, path, line):
				_error(path, line, "buff expects target, attack, health[, trait].")
				return null
			effect.amount = _argument_int(args[1], path, line)
			effect.health_amount = _argument_int(args[2], path, line)
			if args.size() == 4:
				effect.keyword = StringName(args[3])
				if not KEYWORDS.has(args[3]):
					_error(path, line, "Unknown or unsupported trait: %s" % args[3])
					return null
		"transform":
			effect.kind = EffectData.Kind.TRANSFORM
			if args.size() != 2 or not _set_target(args[0], effect, path, line):
				_error(path, line, "transform expects target, unit_card_id.")
				return null
			_add_card_ref(effect, "card", args[1], "unit")
		"create_ring":
			effect.kind = EffectData.Kind.CREATE_RING
			if not _expect_arg_count(args, 0, kind, path, line):
				return null
		"steal_ring":
			effect.kind = EffectData.Kind.STEAL_RING
			if not _expect_arg_count(args, 0, kind, path, line):
				return null
		"return_ring":
			effect.kind = EffectData.Kind.RETURN_RING
			if not _expect_arg_count(args, 0, kind, path, line):
				return null
		"resurrect":
			effect.kind = EffectData.Kind.RESURRECT
			if args.size() > 1:
				_error(path, line, "resurrect accepts zero or one unit card id.")
				return null
			if not args.is_empty():
				_add_card_ref(effect, "card", args[0], "unit")
		"forge":
			effect.kind = EffectData.Kind.FORGE_CARD
			if args.size() != 2:
				_error(path, line, "forge expects artifact_card_id, extra_cost.")
				return null
			_add_card_ref(effect, "card", args[0], "artifact")
			effect.amount = _argument_int(args[1], path, line)
		_:
			_error(path, line, "Unknown or unsupported effect: %s" % kind)
			return null
	return effect


func _read_target_and_amount(args: PackedStringArray, effect: EffectData, path: String, line: int) -> bool:
	if args.size() != 2 or not _set_target(args[0], effect, path, line):
		_error(path, line, "Effect expects target, amount.")
		return false
	effect.amount = _argument_int(args[1], path, line)
	return effect.amount >= 0


func _read_amount(args: PackedStringArray, effect: EffectData, path: String, line: int) -> bool:
	if args.size() != 1:
		_error(path, line, "Effect expects one integer amount.")
		return false
	effect.amount = _argument_int(args[0], path, line)
	return effect.amount >= 0


func _read_card_ref(args: PackedStringArray, effect: EffectData, expected_type: String, path: String, line: int) -> bool:
	if args.size() != 1:
		_error(path, line, "Effect expects one card id.")
		return false
	_add_card_ref(effect, "card", args[0], expected_type)
	return true


func _set_target(value: String, effect: EffectData, path: String, line: int) -> bool:
	if not TARGETS.has(value):
		_error(path, line, "Unknown effect target: %s" % value)
		return false
	effect.target = TARGETS[value]
	return true


func _add_card_ref(resource: Resource, property: String, card_id: String, expected_type: String) -> void:
	_pending_card_refs.append({
		"resource": resource,
		"property": property,
		"id": card_id,
		"expected_type": expected_type,
	})


func _resolve_references() -> bool:
	for reference: Dictionary in _pending_card_refs:
		var card_id: String = reference["id"]
		if not _cards.has(card_id):
			_error("cards", 0, "Unknown card reference: %s" % card_id)
			continue
		var card: CardData = _cards[card_id]
		var expected_type: String = reference["expected_type"]
		if expected_type == "unit" and card.type != CardData.Type.UNIT:
			_error("cards", 0, "%s must reference a unit." % card_id)
			continue
		if expected_type == "artifact" and card.type != CardData.Type.ARTIFACT:
			_error("cards", 0, "%s must reference an artifact." % card_id)
			continue
		var resource: Resource = reference["resource"]
		resource.set(reference["property"], card)
	for card_id: String in _cards:
		var card: CardData = _cards[card_id]
		for ability: AbilityData in card.abilities:
			if ability.condition != null and ability.condition.kind == ConditionData.Kind.CONTROLS_CARD:
				var referenced_id: String = String(ability.condition.card_id)
				if not _cards.has(referenced_id) and not _leaders.has(referenced_id):
					_error("cards", 0, "%s references unknown controlled card or Leader %s." % [card_id, referenced_id])
			for effect: EffectData in ability.effects:
				if effect.kind == EffectData.Kind.CREATE_RING and card.faction != &"nibelungs":
					_error("cards", 0, "%s can create the Ring only from the Nibelung faction." % card_id)
	return _errors.is_empty()


## Rules texts name referenced cards (e.g. "Summon Nibelung Miner."), so they are built after references are resolved.
func _collect_rules_texts() -> void:
	for card_id: String in _cards:
		var rules: String = _rules_text(_cards[card_id])
		if not rules.is_empty():
			_translation_entries["CARD_%s_RULES" % card_id.to_upper()] = rules
	for leader_id: String in _leaders:
		var leader: LeaderData = _leaders[leader_id]
		if leader.ability != null:
			_translation_entries["LEADER_%s_RULES" % leader_id.to_upper()] = "Ability (%d Energy): %s" % [
				leader.ability.cost,
				_effect_text(leader.ability.effects[0]),
			]


func _validate_decks() -> bool:
	if _cards.size() < 1 or _leaders.size() < 1 or _decks.size() < 1:
		_error("cards", 0, "At least one card, leader and starter deck are required.")
	for deck_id: String in _decks:
		var deck: DeckData = _decks[deck_id]
		var path: String = "cards/starter_decks.md"
		if deck.cards.size() != 20:
			_error(path, 0, "%s must contain exactly 20 cards (got %d)." % [deck_id, deck.cards.size()])
		var copies: Dictionary = {}
		for card: CardData in deck.cards:
			if card.faction != deck.leader.faction and card.faction != &"neutral":
				_error(path, 0, "%s cannot include %s from faction %s." % [deck_id, card.id, card.faction])
			var count: int = int(copies.get(card.id, 0)) + 1
			copies[card.id] = count
			var limit: int = 1 if card.rarity in [CardData.Rarity.EPIC, CardData.Rarity.LEGENDARY] else 2
			if count > limit:
				_error(path, 0, "%s exceeds the %d-copy limit for %s." % [deck_id, limit, card.id])
	return _errors.is_empty()


func _updated_localization(path: String) -> String:
	var rows: Array[PackedStringArray] = []
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		_error(path, 0, "Localization CSV does not exist.")
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error(path, 0, "Could not open localization CSV.")
		return ""
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1 or (row.size() == 1 and not row[0].is_empty()):
			rows.append(row)
	if rows.is_empty() or rows[0] != PackedStringArray(["keys", "en", "de", "es", "fr"]):
		_error(path, 1, "Expected CSV header: keys,en,de,es,fr.")
		return ""
	var existing: Dictionary = {}
	for index: int in range(1, rows.size()):
		var row: PackedStringArray = rows[index]
		if row.size() != 5:
			_error(path, index + 1, "Expected five translation columns.")
			continue
		if existing.has(row[0]):
			_error(path, index + 1, "Duplicate translation key: %s" % row[0])
			continue
		existing[row[0]] = index
	var output: Array[PackedStringArray] = [rows[0]]
	for index: int in range(1, rows.size()):
		var row: PackedStringArray = rows[index]
		if row[0].begins_with("CARD_") or row[0].begins_with("LEADER_"):
			if not _translation_entries.has(row[0]):
				continue
			var previous_source: String = row[1]
			row[1] = _translation_entries[row[0]]
			# A column still equal to the old English text was never translated: it follows the new source.
			for column: int in range(2, row.size()):
				if row[column] == previous_source:
					row[column] = row[1]
			output.append(row)
		else:
			output.append(row)
	for key: String in _translation_entries:
		if existing.has(key):
			continue
		var source_text: String = _translation_entries[key]
		output.append(PackedStringArray([key, source_text, source_text, source_text, source_text]))
	var text: String = ""
	for row: PackedStringArray in output:
		text += _csv_line(row)
	return text


func _csv_line(row: PackedStringArray) -> String:
	var escaped: PackedStringArray = []
	for cell: String in row:
		escaped.append("\"%s\"" % cell.replace("\"", "\"\""))
	return ",".join(escaped) + "\n"


func _rules_text(card: CardData) -> String:
	var lines: Array[String] = []
	for keyword: StringName in card.keywords:
		lines.append(String(keyword).capitalize() + ".")
	for ability: AbilityData in card.abilities:
		var trigger: String = _trigger_text(ability.trigger)
		if ability.condition != null:
			trigger += ", %s" % _condition_text(ability.condition).to_lower()
		lines.append("%s: %s" % [trigger, _effect_text(ability.effects[0])])
	return "\n".join(lines)


func _trigger_text(trigger: StringName) -> String:
	match trigger:
		&"on_play":
			return "On play"
		&"on_death":
			return "On death"
		&"on_bearer_death":
			return "When its bearer dies"
		&"start_of_turn":
			return "At the start of your turn"
		&"end_of_turn":
			return "At the end of your turn"
		&"on_attack":
			return "When this attacks"
		&"on_damage":
			return "When this takes damage"
		_:
			return String(trigger).capitalize()


func _condition_text(condition: ConditionData) -> String:
	if condition.kind == ConditionData.Kind.HOLDS_RING:
		return "If you hold the Ring"
	if condition.kind == ConditionData.Kind.CONTROLS_CARD:
		var card_id: String = String(condition.card_id)
		if _card_names.has(card_id):
			return "If you control %s" % _card_names[card_id]
		return "If you control %s" % card_id.replace("_", " ").capitalize()
	return ""


func _effect_text(effect: EffectData) -> String:
	var target: String = _target_name(effect.target)
	match effect.kind:
		EffectData.Kind.DEAL_DAMAGE:
			return "Deal %d damage to %s." % [effect.amount, target]
		EffectData.Kind.DRAW_CARDS:
			return "Draw %d %s." % [effect.amount, "card" if effect.amount == 1 else "cards"]
		EffectData.Kind.GAIN_ENERGY:
			return "Gain %d Energy." % effect.amount
		EffectData.Kind.SUMMON:
			return "Summon %s." % _referenced_card_name(effect.card)
		EffectData.Kind.HEAL:
			return "Restore %d to %s." % [effect.amount, target]
		EffectData.Kind.BUFF:
			var stats: String = "+%d/+%d" % [effect.amount, effect.health_amount]
			var trait_text: String = " and %s" % effect.keyword if effect.keyword != &"" else ""
			return "Give %s %s%s." % [target, stats, trait_text]
		EffectData.Kind.TRANSFORM:
			return "Transform %s into %s." % [target, _referenced_card_name(effect.card)]
		EffectData.Kind.CREATE_RING:
			return "Create the Ring."
		EffectData.Kind.STEAL_RING:
			return "Take the Ring."
		EffectData.Kind.RETURN_RING:
			return "Return the Ring."
		EffectData.Kind.RESURRECT:
			return "Resurrect %s." % (_referenced_card_name(effect.card) if effect.card != null else "a Valhalla unit")
		EffectData.Kind.FORGE_CARD:
			return "Forge %s for %d extra Energy." % [_referenced_card_name(effect.card), effect.amount]
		_:
			return ""


func _target_name(target: EffectData.Target) -> String:
	match target:
		EffectData.Target.SELF:
			return "this card"
		EffectData.Target.SELECTED_UNIT:
			return "a unit"
		EffectData.Target.FRIENDLY_LEADER:
			return "your Leader"
		EffectData.Target.ENEMY_LEADER:
			return "the enemy Leader"
		EffectData.Target.ALL_FRIENDLY_UNITS:
			return "all your units"
		EffectData.Target.ALL_ENEMY_UNITS:
			return "all enemy units"
		EffectData.Target.ALL_UNITS:
			return "all units"
		EffectData.Target.ALL_LEADERS:
			return "both Leaders"
		EffectData.Target.BEARER:
			return "its bearer"
		_:
			return "the target"


func _referenced_card_name(card: CardData) -> String:
	if card == null:
		return "a card"
	return String(_card_names.get(String(card.id), String(card.id).replace("_", " ").capitalize()))


func _serialize_resources() -> Dictionary:
	var output: Dictionary = {}
	var temp_root: String = "user://card_pipeline_check"
	for path: String in _resources:
		var resource: Resource = _resources[path]
		var temp_path: String = temp_root.path_join(path.trim_prefix("res://"))
		var absolute_temp: String = ProjectSettings.globalize_path(temp_path)
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_temp.get_base_dir())
		if make_dir_error != OK:
			_error(path, 0, "Could not create temporary output directory: %s" % error_string(make_dir_error))
			continue
		var save_error: Error = ResourceSaver.save(resource, temp_path)
		if save_error != OK:
			_error(path, 0, "Could not serialize resource: %s" % error_string(save_error))
			continue
		var file: FileAccess = FileAccess.open(temp_path, FileAccess.READ)
		if file == null:
			_error(path, 0, "Could not read serialized resource.")
			continue
		output[path] = file.get_as_text()
		file.close()
		DirAccess.remove_absolute(absolute_temp)
	return output


func _check_outputs(expected: Dictionary) -> bool:
	var current_paths: PackedStringArray = _generated_paths()
	for path: String in expected:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(absolute_path):
			_error(path, 0, "Generated output is missing; run the generator.")
			continue
		var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
		if file == null or file.get_as_text() != expected[path]:
			_error(path, 0, "Generated output differs from the source; run the generator.")
		current_paths.erase(path)
	for stale_path: String in current_paths:
		_error(stale_path, 0, "Stale generated resource; remove it or restore its source.")
	return _errors.is_empty()


func _write_outputs(expected: Dictionary) -> bool:
	for path: String in expected:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		if make_dir_error != OK:
			_error(path, 0, "Could not create output directory: %s" % error_string(make_dir_error))
			continue
		var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
		if file == null:
			_error(path, 0, "Could not open generated output for writing.")
			continue
		file.store_string(expected[path])
		file.close()
	return _errors.is_empty()


func _generated_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	_collect_resource_paths("res://data/cards", paths)
	_collect_resource_paths("res://data/leaders", paths)
	_collect_resource_paths("res://data/decks", paths)
	return paths


func _collect_resource_paths(directory: String, paths: PackedStringArray) -> void:
	var absolute_directory: String = ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		return
	for entry: String in DirAccess.get_files_at(absolute_directory):
		if entry.ends_with(".tres"):
			paths.append(directory.path_join(entry))
	for child: String in DirAccess.get_directories_at(absolute_directory):
		_collect_resource_paths(directory.path_join(child), paths)


func _name_list(source: String) -> Array[StringName]:
	var names: Array[StringName] = []
	if source.strip_edges().is_empty():
		return names
	for value: String in source.split(",", false):
		var name: String = value.strip_edges()
		if not _valid_id(name):
			_error("cards", 0, "Invalid name in comma-separated list: %s" % name)
		else:
			names.append(StringName(name))
	return names


func _required_int(row: Dictionary, field: String, minimum: int, maximum: int, path: String, line: int) -> int:
	var value: String = String(row[field])
	if not value.is_valid_int():
		_error(path, line, "%s must be an integer." % field)
		return -1
	var number: int = value.to_int()
	if number < minimum or number > maximum:
		_error(path, line, "%s must be between %d and %d." % [field, minimum, maximum])
		return -1
	return number


func _optional_int(row: Dictionary, field: String, fallback: int, path: String, line: int) -> int:
	var value: String = String(row[field])
	if value.is_empty():
		return fallback
	if not value.is_valid_int():
		_error(path, line, "%s must be an integer." % field)
		return -1
	return value.to_int()


func _argument_int(value: String, path: String, line: int) -> int:
	if not value.is_valid_int():
		_error(path, line, "Expected an integer argument, got: %s" % value)
		return -1
	var number: int = value.to_int()
	if number < 0:
		_error(path, line, "Effect amounts cannot be negative.")
		return -1
	return number


func _expect_arg_count(args: PackedStringArray, count: int, kind: String, path: String, line: int) -> bool:
	if args.size() != count:
		_error(path, line, "%s expects %d arguments." % [kind, count])
		return false
	return true


func _valid_id(value: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	return regex.search(value) != null


func _error(path: String, line: int, message: String) -> void:
	var location: String = "%s:%d" % [path, line] if line > 0 else path
	_errors.append("%s: %s" % [location, message])


func _report_errors() -> void:
	for message: String in _errors:
		push_error(message)
