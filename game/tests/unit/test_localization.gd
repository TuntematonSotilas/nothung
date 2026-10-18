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
	assert_str(tr("CARD_LOGES_FIRE_NAME")).is_equal("Loge's Fire")
	assert_str(tr("LEADER_WOTAN_RULES")).is_equal("Ability (2 Energy): Deal 2 damage to a unit.")
	TranslationServer.set_locale(previous)


func _rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1 or (row.size() == 1 and not row[0].is_empty()):
			rows.append(row)
	return rows
