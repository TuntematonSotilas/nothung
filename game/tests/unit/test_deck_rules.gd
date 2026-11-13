extends GdUnitTestSuite

## DeckRules.auto_fill: a legal 20-card deck from the cards owned, rarest first, units and curve balanced.


func test_full_collection_gives_a_legal_balanced_deck_with_the_rarest_cards() -> void:
	var wotan: LeaderData = CardDatabase.get_leader(&"wotan")
	var everything: Callable = func(_id: StringName) -> int: return 2
	var cards: Array[String] = DeckRules.auto_fill(wotan, CardDatabase, everything)
	assert_int(cards.size()).is_equal(DeckRules.DECK_SIZE)
	var entry: Dictionary = {"leader": "wotan", "cards": cards}
	assert_array(DeckRules.problems(entry, CardDatabase, everything)).is_empty()
	var data: Array[CardData] = []
	for card_id: String in cards:
		data.append(CardDatabase.get_card(StringName(card_id)))
	assert_int(DeckRules.type_counts(data)["unit"]).is_equal(DeckRules.FILL_UNITS)
	# Every Legendary and Epic card of the Gods and Neutral that does something is in.
	for card_id: StringName in CardDatabase.card_ids():
		var card: CardData = CardDatabase.get_card(card_id)
		if card.rarity == CardData.Rarity.LEGENDARY and DeckRules.eligible(card, wotan) and card.is_unit():
			assert_bool(cards.has(String(card_id))).override_failure_message("missing %s" % card_id).is_true()
	# The curve stays within the targets.
	var bars: Array[int] = DeckRules.curve(data)
	assert_int(bars[0] + bars[1]).is_less_equal(int(DeckRules.FILL_CURVE[1]))
	assert_int(bars[2]).is_equal(int(DeckRules.FILL_CURVE[2]))


func test_only_the_leader_s_faction_and_neutral() -> void:
	var alberich: LeaderData = CardDatabase.get_leader(&"alberich")
	var cards: Array[String] = DeckRules.auto_fill(alberich, CardDatabase, func(_id: StringName) -> int: return 2)
	for card_id: String in cards:
		assert_array(["nibelungs", "neutral"]).contains([String(CardDatabase.get_card(StringName(card_id)).faction)])


func test_a_small_collection_gives_what_it_can_never_more_than_owned() -> void:
	var wotan: LeaderData = CardDatabase.get_leader(&"wotan")
	var owned: Dictionary = {&"loge": 1, &"froh": 2, &"wotans_ravens": 2}
	var cards: Array[String] = DeckRules.auto_fill(wotan, CardDatabase, func(id: StringName) -> int: return int(owned.get(id, 0)))
	assert_int(cards.size()).is_equal(5)
	assert_int(cards.count("loge")).is_equal(1)
	assert_int(cards.count("froh")).is_equal(2)


func test_a_card_that_does_nothing_alone_comes_last() -> void:
	var siegfried: LeaderData = CardDatabase.get_leader(&"siegfried")
	var cards: Array[String] = DeckRules.auto_fill(siegfried, CardDatabase, func(_id: StringName) -> int: return 2)
	assert_bool(cards.has("nothung_broken")).is_false()
	# With only the Wälsung starter cards, it is the 20th card (Siegmund and Notung! reforge it).
	var starter: Dictionary = {}
	for card: CardData in CardDatabase.get_deck(&"walsungs_starter").cards:
		starter[card.id] = int(starter.get(card.id, 0)) + 1
	cards = DeckRules.auto_fill(siegfried, CardDatabase, func(id: StringName) -> int: return int(starter.get(id, 0)))
	assert_int(cards.size()).is_equal(DeckRules.DECK_SIZE)
	assert_bool(cards.has("nothung_broken")).is_true()
