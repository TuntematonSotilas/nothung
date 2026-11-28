extends GdUnitTestSuite

## Leader powers: a Leader playing with a power, unlocking one (level, then Rhinegold), the power a deck
## plays with, replaying a match with it, the AI's random version.

var _saved_profile: Dictionary
var _saved_path: String


func before_test() -> void:
	_saved_profile = SaveManager.profile.duplicate(true)
	_saved_path = SaveManager.path
	SaveManager.path = create_temp_dir("leader_powers_%d" % Time.get_ticks_usec()) + "/profile.json"
	SaveManager.profile = SaveManager.default_profile()


func after_test() -> void:
	SaveManager.path = _saved_path
	SaveManager.profile = _saved_profile


func test_every_leader_has_two_powers_from_level_5_and_10() -> void:
	for leader_id: StringName in CardDatabase.leader_ids():
		var leader: LeaderData = CardDatabase.get_leader(leader_id)
		assert_int(leader.powers.size()).is_equal(2)
		assert_int(leader.powers[0].level).is_equal(5)
		assert_int(leader.powers[0].price).is_equal(300)
		assert_int(leader.powers[1].level).is_equal(10)
		assert_int(leader.powers[1].price).is_equal(600)
		assert_str(tr(leader.with_power(1).ability_key() + "_NAME")).is_not_equal(leader.with_power(1).ability_key() + "_NAME")


func test_with_power_copies_the_leader_with_that_ability() -> void:
	var wotan: LeaderData = CardDatabase.get_leader(&"wotan")
	var wrath: LeaderData = wotan.with_power(1)
	assert_object(wrath).is_not_same(wotan)
	assert_str(String(wrath.id)).is_equal("wotan")
	assert_int(wrath.power).is_equal(1)
	# Wotans Zorn: 2 damage, double against Nibelungs.
	assert_int(wrath.ability.effects[0].amount).is_equal(2)
	assert_str(String(wrath.ability.effects[0].bonus_faction)).is_equal("nibelungs")
	assert_str(wrath.ability_key()).is_equal("LEADER_WOTAN_POWER1")
	# The base Leader is left as it is; an unknown power gives it back.
	assert_str(String(wotan.ability.effects[0].bonus_faction)).is_empty()
	assert_str(wotan.ability_key()).is_equal("LEADER_WOTAN_ABILITY")
	assert_object(wotan.with_power(0)).is_same(wotan)
	assert_object(wotan.with_power(3)).is_same(wotan)


func test_brunnhildes_first_power_summons_a_valkyries_faction_hero() -> void:
	var ability: AbilityData = CardDatabase.get_leader(&"brunnhilde").powers[0].ability
	var summoned: CardData = ability.effects[0].card
	assert_str(String(summoned.id)).is_equal("slain_warrior")
	assert_str(String(summoned.faction)).is_equal("valkyries")
	assert_bool(summoned.subtypes.has(&"hero")).is_true()


func test_unlocking_needs_the_level_then_the_rhinegold() -> void:
	var wotan: LeaderData = CardDatabase.get_leader(&"wotan")
	SaveManager.add_rhinegold(1000)
	assert_dict(LeaderPowers.missing(wotan, 1)).is_equal({"level": 5, "rhinegold": 0})
	assert_bool(LeaderPowers.unlock(wotan, 1)).is_false()
	# Level 5: 20 + 30 + 40 + 50 XP.
	SaveManager.profile["xp"] = 140
	assert_bool(LeaderPowers.unlock(wotan, 1)).is_true()
	assert_bool(LeaderPowers.is_unlocked(&"wotan", 1)).is_true()
	assert_bool(LeaderPowers.is_unlocked(&"alberich", 1)).is_false()
	assert_int(SaveManager.rhinegold()).is_equal(700)
	# Once only; power 2 needs level 10.
	assert_bool(LeaderPowers.unlock(wotan, 1)).is_false()
	assert_bool(LeaderPowers.unlock(wotan, 2)).is_false()
	SaveManager.profile["xp"] = 10000
	SaveManager.profile["rhinegold"] = 599
	assert_dict(LeaderPowers.missing(wotan, 2)).is_equal({"level": 0, "rhinegold": 1})
	assert_bool(LeaderPowers.unlock(wotan, 2)).is_false()


func test_a_deck_plays_its_power_only_once_unlocked() -> void:
	var entry: Dictionary = {"id": "deck_1", "leader": "wotan", "power": 2, "cards": []}
	assert_int(DeckRules.to_deck_data(entry, CardDatabase).leader.power).is_equal(0)
	SaveManager.profile["leader_powers"] = {"wotan": [2]}
	var deck: DeckData = DeckRules.to_deck_data(entry, CardDatabase)
	assert_int(deck.leader.power).is_equal(2)
	assert_int(deck.leader.ability.cost).is_equal(2)


func test_saved_powers_are_ints_again_after_loading() -> void:
	var migrated: Dictionary = SaveManager.migrate({"version": 3, "leader_powers": {"wotan": [1.0, 2.0]}})
	assert_array(migrated["leader_powers"]["wotan"]).contains_exactly([1, 2])
	assert_int(migrated["xp"]).is_equal(0)


func test_the_engine_and_the_replay_use_the_power() -> void:
	var deck := DeckData.new()
	var gods: DeckData = CardDatabase.get_deck(&"gods_starter")
	deck.leader = gods.leader.with_power(2)
	deck.cards = gods.cards
	var engine := Match.new(deck, CardDatabase.get_deck(&"nibelungs_starter"), 3)
	assert_int(engine.get_state().player(0).leader.ability.cost).is_equal(2)
	var record := MatchRecord.create(deck, CardDatabase.get_deck(&"nibelungs_starter"), 3)
	assert_int(int(record.decks[0]["power"])).is_equal(2)
	var rebuilt: Array[DeckData] = record.rebuild_decks(CardDatabase)
	assert_int(rebuilt[0].leader.power).is_equal(2)
	assert_int(rebuilt[1].leader.power).is_equal(0)
	assert_str(MatchRecord.content_hash_of(rebuilt)).is_equal(record.content_hash)


func test_the_ai_plays_a_random_version_of_its_leader() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen: Dictionary = {}
	for index: int in 40:
		var deck: DeckData = QuickMatch.with_random_power(CardDatabase.get_deck(&"valkyries_starter"), rng)
		seen[deck.leader.power] = true
		assert_int(deck.cards.size()).is_equal(20)
	assert_array(seen.keys()).contains_exactly_in_any_order([0, 1, 2])
