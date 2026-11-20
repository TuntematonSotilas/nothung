# Progression

> How the player grows their collection and what keeps them playing — all offline.
> Status: Draft · Last updated: 2026-11-20

## Principles

- Everything can be earned by playing. No randomness that can be bought.
- Progress is local to the device (no account). See [technical/07-persistence.md](../technical/07-persistence.md).

## Starting collection

- One **starter deck** per faction unlocked as the campaign introduces it.
- After the tutorial: Gods starter deck + Nibelungs starter deck.
- Owning a starter deck means owning its Leader and, for each card, the copies the deck uses — not the sum over several decks: decks share the collection.

> **Decision (2026-10-30):** until the tutorial and the campaign exist, a new profile owns the **four** starter decks. The rule above applies once the campaign unlocks factions.

## Rewards

| Source | Reward |
|--------|--------|
| Campaign duel (first win) | Specific cards / Leader (fixed, story-related) |
| Campaign Quest (each ending, first time) | Card, Rhinegold or cosmetic ([Quests](05-game-modes.md#quests-non-combat-stages)) |
| Campaign chapter complete | Legendary card + faction starter deck |
| Quick match win | Rhinegold: 10 (Easy) / 20 (Normal) / 40 (Hard); nothing for a loss, a draw or leaving |
| Achievements | Rhinegold, card backs, cosmetic frames |

## Meta currency

> Distinct from in-match Energy. The progression currency is **Rhinegold**.

- Earned in quick matches and achievements.
- Spent in **Nibelheim** (the crafting screen) to craft a specific card (Common 40, Rare 100, Epic 400, Legendary 1600 — draft values), one copy at a time, up to the copies a deck can hold (2, or 1 for Epic and Legendary): beyond that a copy is useless, so Nibelheim does not offer it.
- A Quick match win pays at the end of the match and is shown on the results. Undoing the winning play from the results takes it back (it is paid again if the match is won again).
- Duplicate extra copies above the deck limit are automatically converted to Rhinegold.

> **Decision (2026-10-09):** Direct crafting only — no random card packs.

## Achievements (examples)

- *Renunciation of Love* — win a match while holding the Ring the whole game.
- *Twilight* — win with your Leader at 1 Life.
- *Notung! Notung!* — reforge Nothung in 10 matches.

## Ideas to refine (2026-11-20)

> Draft for [milestone 6](../roadmap.md#6--progression--rewards): the player's ideas first, then suggestions and open questions. **Nothing here is decided.**

### Rewards

- Ideas: a **home background** (main menu) and **deck backgrounds** (deck tiles, deck editor).
- Suggestions: card backs; card frames (gold border); alternative Leader portraits; board skins (see [Cosmetics](#cosmetics)); a title or emblem next to the deck name; a music room (the leitmotifs).
- Rhinegold stays the default reward.

### Level

- XP for each match played (more for a win, by difficulty) and for each achievement; one level every N XP.
- Possible unlocks: campaign chapters; Nibelheim (after the tutorial); factions and their starter decks (today tied to the campaign: see [Starting collection](#starting-collection)); Hard difficulty; backgrounds and skins; mini-games or "dungeons" (e.g. a run down into Nibelheim with a deck built along the way — a later mode).
- Open question: do campaign chapters open with the level, or only with the story (the previous chapter won)?

### Leader powers

- Idea: improve or change the Leader's ability.
- Suggestion: **alternative abilities** — choose 1 of 2–3 per Leader — rather than stronger numbers, so balance and the AI soak stay meaningful.
- Unlocked by Leader mastery (matches played with that Leader), bought with Rhinegold at Nibelheim, or given by levels.
- Open question: chosen in Nibelheim (a tab) or on a Leader screen (from the deck editor, tap the Leader)?

### Achievements

- Progression: play / win 10, 50, 100 matches.
- Factions: win with each Leader.
- Cards: play 20 artifacts, reforge Nothung 10 times (*Notung! Notung!*), hold the Ring at the end of a won match.
- Challenge: *Twilight*, *Renunciation of Love*, win on Hard, win without losing a unit.
- Collection: craft a first card in Nibelheim, own every card.
- Tiers (bronze / silver / gold) for the counters; rewards: Rhinegold, XP, cosmetics.
- Shown on the results screen when unlocked, and listed in an Achievements screen with their progress (e.g. 3 / 10).

## Cosmetics

- Card backs, board skins (Rhine depths, Valhalla, Nibelheim, Gibichung hall), Leader portraits.

> **Decision (2026-10-09):** Cosmetics are not sold — the game is entirely free ([01-vision](01-vision.md#scope)). They are unlocked through achievements, campaign progress or Rhinegold.
