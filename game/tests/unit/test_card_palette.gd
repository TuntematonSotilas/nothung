extends GdUnitTestSuite


func test_card_text_is_readable_and_every_frame_stands_out_from_the_background() -> void:
	assert_float(CardPalette.contrast(CardPalette.TEXT_LIGHT, CardPalette.BACKGROUND)).is_greater_equal(4.5)
	var palettes: Array = CardPalette.FACTIONS.values()
	palettes.append(CardPalette.RING)
	for colors: Dictionary in palettes:
		assert_float(CardPalette.contrast(colors["frame"], CardPalette.BACKGROUND)).is_greater_equal(1.5)


func test_palette_matches_the_art_doc() -> void:
	var doc: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/functional/08-art-and-audio.md"))
	assert_str(doc).is_not_empty()
	for colors: Dictionary in CardPalette.FACTIONS.values():
		for key: String in ["frame", "trim"]:
			assert_str(doc).contains("`#%s`" % (colors[key] as Color).to_html(false).to_upper())
	for rarity_color: Color in CardPalette.RARITY_COLORS.values():
		assert_str(doc).contains("`#%s`" % rarity_color.to_html(false).to_upper())
	assert_str(doc).contains("`#%s`" % CardPalette.RING["frame"].to_html(false).to_upper())


func test_card_view_shape_follows_the_type() -> void:
	var unit: CardView = await _view(CardData.Type.UNIT)
	var spell: CardView = await _view(CardData.Type.SPELL)
	var artifact: CardView = await _view(CardData.Type.ARTIFACT)
	var unit_style: StyleBoxFlat = unit.get_theme_stylebox("normal") as StyleBoxFlat
	var spell_style: StyleBoxFlat = spell.get_theme_stylebox("normal") as StyleBoxFlat
	var artifact_style: StyleBoxFlat = artifact.get_theme_stylebox("normal") as StyleBoxFlat
	# Every frame is a rectangle with small corners.
	for style: StyleBoxFlat in [unit_style, spell_style, artifact_style]:
		assert_int(style.corner_radius_top_left).is_less_equal(8)


func test_card_view_colours_follow_faction_rarity_and_ring() -> void:
	var valkyrie: CardView = await _view(CardData.Type.UNIT, &"valkyries", CardData.Rarity.EPIC)
	var style: StyleBoxFlat = valkyrie.get_theme_stylebox("normal") as StyleBoxFlat
	# Faction colour on the frame (border), dark background.
	assert_str(style.border_color.to_html(false)).is_equal("e0a0b8")
	assert_str(style.bg_color.to_html(false)).is_equal("16181d")
	var name_label: Label = valkyrie.find_child("NameLabel", true, false) as Label
	# Name on a banner in the faction colour, in that faction's text colour (dark on Valkyries).
	var banner: PanelContainer = valkyrie.find_child("NameBanner", true, false) as PanelContainer
	assert_str((banner.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.to_html(false)).is_equal("e0a0b8")
	assert_str(name_label.get_theme_color("font_color").to_html(false)).is_equal("1c1a17")
	var rules_label: Label = valkyrie.find_child("RulesLabel", true, false) as Label
	assert_str(rules_label.get_theme_color("font_color").to_html(false)).is_equal("f4efe4")
	# Cost, attack and health have no pill around them.
	assert_object(valkyrie.find_child("AttackStone", true, false).get_theme_stylebox("panel")).is_instanceof(StyleBoxEmpty)
	# Rarity: a letter on the rarity colour.
	var badge_panel: PanelContainer = valkyrie.find_child("RarityBadge", true, false) as PanelContainer
	assert_str((badge_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.to_html(false)).is_equal("8e44ad")
	assert_str((valkyrie.find_child("RarityLabel", true, false) as Label).text).is_equal("E")

	var ring: CardView = await _view(CardData.Type.ARTIFACT, &"nibelungs", CardData.Rarity.LEGENDARY, true)
	assert_str((ring.get_theme_stylebox("normal") as StyleBoxFlat).border_color.to_html(false)).is_equal("7a5a14")


func test_highlight_glows_without_hiding_the_faction_frame() -> void:
	var view: CardView = await _view(CardData.Type.UNIT, &"gods")
	view.set_highlight(&"target")
	var style: StyleBoxFlat = view.get_theme_stylebox("normal") as StyleBoxFlat
	assert_str(style.border_color.to_html(false)).is_equal("2e4a7d")
	assert_int(style.shadow_size).is_greater(0)
	assert_str(style.shadow_color.to_html(false)).is_equal(Palette.LIFE.to_html(false))


func test_double_border_motif_tells_the_type() -> void:
	var unit: CardView = await _view(CardData.Type.UNIT)
	assert_bool((unit.find_child("FrameBand", true, false) as CardFrameBand).visible).is_false()
	var expected: Dictionary = {
		CardFrameBand.Pattern.ZIGZAG: await _view(CardData.Type.SPELL, &"valkyries"),
		CardFrameBand.Pattern.HATCH: await _view(CardData.Type.ARTIFACT, &"valkyries"),
		CardFrameBand.Pattern.BEADS: await _view(CardData.Type.ARTIFACT, &"valkyries", CardData.Rarity.RARE, false, [&"relic"]),
	}
	for pattern: CardFrameBand.Pattern in expected:
		var band: CardFrameBand = (expected[pattern] as CardView).find_child("FrameBand", true, false) as CardFrameBand
		assert_bool(band.visible).is_true()
		assert_int(band.pattern).is_equal(pattern)
		# Drawn in the faction colour.
		assert_str(band.color.to_html(false)).is_equal("e0a0b8")
	# The face sits inside the double border.
	var face: Control = (expected[CardFrameBand.Pattern.HATCH] as CardView).find_child("CardFace", true, false) as Control
	var unit_face: Control = unit.find_child("CardFace", true, false) as Control
	assert_float(face.offset_left).is_greater(unit_face.offset_left)


func _view(
	type: CardData.Type,
	faction: StringName = &"gods",
	rarity: CardData.Rarity = CardData.Rarity.COMMON,
	is_ring: bool = false,
	subtypes: Array[StringName] = []
) -> CardView:
	var data: CardData = CardData.new()
	data.id = &"palette_test"
	data.type = type
	data.faction = faction
	data.rarity = rarity
	data.is_ring = is_ring
	data.subtypes = subtypes
	data.attachable = subtypes.has(&"relic")
	var view: CardView = auto_free(CardView.new()) as CardView
	view.set_card(data)
	add_child(view)
	await get_tree().process_frame
	return view


func test_every_faction_has_its_icon_on_the_card() -> void:
	for faction: StringName in [&"gods", &"nibelungs", &"walsungs", &"valkyries", &"neutral"]:
		var view: CardView = await _view(CardData.Type.UNIT, faction)
		var icon: TextureRect = view.find_child("FactionIcon", true, false) as TextureRect
		assert_bool(icon.visible).override_failure_message("No icon for %s" % faction).is_true()
		assert_object(icon.texture).is_not_null()
