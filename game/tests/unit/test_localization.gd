extends GdUnitTestSuite
## Every key of strings.csv must exist in all supported languages.

const CSV_PATH: String = "res://localization/strings.csv"
const LANGUAGES: PackedStringArray = ["en", "de", "es", "fr"]


func test_header_lists_all_languages() -> void:
	var header: PackedStringArray = _rows()[0]
	assert_str(header[0]).is_equal("keys")
	assert_array(Array(header.slice(1))).is_equal(Array(LANGUAGES))


func test_no_missing_translation() -> void:
	var rows: Array[PackedStringArray] = _rows()
	for row: PackedStringArray in rows.slice(1):
		assert_int(row.size()).override_failure_message("Wrong column count: %s" % row[0]).is_equal(LANGUAGES.size() + 1)
		for column: int in range(1, row.size()):
			assert_str(row[column].strip_edges()).override_failure_message(
				"Missing %s text for %s" % [LANGUAGES[column - 1], row[0]]
			).is_not_empty()


func test_translations_are_loaded() -> void:
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	assert_str(tr("UI_SPLASH_TAGLINE")).is_equal("INSPIRÉ DE DER RING DES NIBELUNGEN")
	assert_str(tr("UI_CLOSE")).is_equal("FERMER")
	assert_str(tr("UI_UNDO_PLAY")).is_equal("ANNULER LA POSE")
	assert_str(tr("UI_DROP_TO_PLAY")).is_equal("DÉPOSER ICI POUR JOUER")
	assert_str(tr("CARD_LOGE_NAME")).is_equal("Loge")
	assert_str(tr("LEADER_WOTAN_RULES")).is_equal("Capacité (3 Énergie) : Inflige 2 dégâts à une unité.")
	assert_str(tr("UI_REDRAW_CONFIRM")).is_equal("REPIOCHER LA SÉLECTION")
	assert_str(tr("UI_TYPE_ARTIFACT")).is_equal("Artefact")
	TranslationServer.set_locale(previous)


## UI and card texts must be translated, not copied from English; only names and words that are the
## same in the other language may match.
func test_texts_are_translated() -> void:
	var allowed: PackedStringArray = [
		"UI_APP_NAME", "UI_APP_SUBTITLE", "UI_START", "UI_COLLECTION", "UI_DIFFICULTY_NORMAL", "UI_FACTION_NEUTRAL", "UI_DUEL",
		"UI_PAUSE", "UI_DECK", "UI_HAND", "UI_DOOM_IN",
	]
	for row: PackedStringArray in _rows().slice(1):
		if row[0] in allowed or row[0].ends_with("_NAME"):
			continue
		# A text copied from English into every language was never translated (the card converter does
		# that for new cards); one or two may match ("Invisible." in Spanish and French).
		var untranslated: int = 0
		for column: int in range(2, row.size()):
			if row[column] == row[1]:
				untranslated += 1
		assert_int(untranslated).override_failure_message("%s is not translated" % row[0]).is_less(3)


func _rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1 or (row.size() == 1 and not row[0].is_empty()):
			rows.append(row)
	return rows
