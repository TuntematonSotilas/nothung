class_name Progression
extends RefCounted

## Rhinegold economy (docs/functional/06-progression.md): crafting prices in Nibelheim and Quick match
## rewards. Draft values, to tune with play.

const CRAFT_PRICES: Dictionary = {
	CardData.Rarity.COMMON: 40,
	CardData.Rarity.RARE: 100,
	CardData.Rarity.EPIC: 400,
	CardData.Rarity.LEGENDARY: 1600,
}
## Quick match win, by AI difficulty (Easy, Normal, Hard); nothing for a loss, a draw or leaving.
const QUICK_MATCH_REWARDS: Array[int] = [10, 20, 40]


static func craft_price(card: CardData) -> int:
	return CRAFT_PRICES[card.rarity]


static func quick_match_reward(difficulty: AIProfile.Difficulty) -> int:
	return QUICK_MATCH_REWARDS[clampi(difficulty, 0, QUICK_MATCH_REWARDS.size() - 1)]


## Crafting only makes sense up to the copies a deck can hold.
static func can_craft(card: CardData, owned: int) -> bool:
	return owned < card.deck_limit()
