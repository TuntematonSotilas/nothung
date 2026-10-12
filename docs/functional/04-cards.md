# Cards

> Card anatomy, types, keywords, rarities and deckbuilding rules. Card list lives in data files (see [technical/03-data-model.md](../technical/03-data-model.md)).
> Status: Draft · Last updated: 2026-10-12

## Card anatomy

```
┌─────────────────────────┐
│ (3)          WOTAN  ◆   │  cost · name · rarity gem
│                         │
│        [ artwork ]      │
│                         │
│ Unit — God      Gods ☉  │  type — subtype · faction
│ Guard.                  │  keywords
│ On play: draw a card.   │  rules text
│ "Ending! Ending!"       │  flavour text (italic)
│ ⚔ 3              ♥ 5    │  attack · health
└─────────────────────────┘
```

| Field | Required | Notes |
|-------|----------|-------|
| Name | ✔ | Unique per card |
| Cost | ✔ | 0–10 Gold |
| Type | ✔ | See below |
| Subtype | – | God, Dwarf, Giant, Hero, Valkyrie, Weapon… (used by synergies) |
| Faction | ✔ | Or Neutral |
| Rarity | ✔ | See below |
| Attack / Health | units only | |
| Keywords | – | See below |
| Rules text | – | Must be generated / validated from the card's effects |
| Flavour text | – | Libretto quote or paraphrase |
| Artwork | ✔ | |

## Card types

| Type | Behaviour |
|------|-----------|
| **Unit** | Stays on the board, can attack and be attacked |
| **Spell** | One-shot effect, then goes to the graveyard |
| **Artifact** | Stays in the artifact zone with an ongoing effect; can't be attacked, can be destroyed by effects |
| **Leader** | Not in the deck; chosen at deck creation; provides Life and Leader ability |

## Keywords (initial list)

| Keyword | Effect |
|---------|--------|
| **Guard** | Enemies must attack this unit first |
| **Charge** | Can attack the turn it is played |
| **Flying** | Can only be blocked/attacked by Flying or Ranged units *(if lanes/blocking are adopted)* |
| **Valhalla** | When destroyed, can be resurrected by Valkyrie effects (marks heroic units) |
| **Forge X** | Spend X extra Gold when playing to upgrade the card |
| **Leitmotif (Y)** | Bonus if you played another card with motif Y this turn |
| **Cursed** | Holder suffers a drawback (Ring and related cards) |
| **Invisible** | Cannot be targeted until it attacks (Tarnhelm) |
| **Fated** | Effect triggers when the Norns' prophecy condition is met |

> **Decision (2026-10-09):** At most **10 keywords** in v1.0, so rules text stays short on a phone screen.

## Rarities

| Rarity | Copies per deck | Share of collection |
|--------|-----------------|---------------------|
| Common | 2 | ~45 % |
| Rare | 2 | ~30 % |
| Epic | 1 | ~15 % |
| Legendary | 1 | ~10 % (named characters, the Ring, Nothung…) |

## Deckbuilding rules

> **Decision (2026-10-12):** Decks have **20 cards** (not 30). With matches of 8–10 turns a player sees ~14 cards, i.e. ~70 % of the deck → consistent games where the deck's strategy shows. Copy limits lowered accordingly so a deck always has at least 10 different cards.

- Exactly **20 cards**.
- One **Leader**; cards must be from the Leader's faction or Neutral.
- Copy limits per rarity as above (max 2, Epic and Legendary 1).
- Starter decks provided for each faction (see [06-progression](06-progression.md)).

> **Decision (2026-10-09):** No dual-faction decks in v1.0 — one faction + Neutral only.

## Card set for v1.0 (target)

| Faction | Units | Spells | Artifacts | Total |
|---------|-------|--------|-----------|-------|
| Gods | 10 | 4 | 1 | 15 |
| Nibelungs | 9 | 3 | 3 | 15 |
| Wälsungs & Heroes | 10 | 3 | 2 | 15 |
| Valkyries | 10 | 4 | 1 | 15 |
| Neutral | 13 | 5 | 2 | 20 |
| **Total** | | | | **~80** |

Each faction has 35 eligible cards (15 faction + 20 Neutral) to build a 20-card deck — enough for several distinct decks per faction. More cards can come with post-launch expansions (e.g. Giants and Gibichungs as factions).

## Example cards (to validate the format)

| Name | Cost | Type | Faction | Stats | Text |
|------|------|------|---------|-------|------|
| Alberich, Lord of the Nibelungs | 4 | Unit — Dwarf | Nibelungs | 3/4 | On play: gain 2 Gold. If you hold the Ring, draw a card. |
| Fafner | 8 | Unit — Giant | Neutral | 8/8 | Guard. Cannot attack the turn after it attacks. |
| Nothung (broken) | 1 | Artifact — Weapon | Heroes | – | Forge 4: becomes *Nothung*: your units get +2 Attack. |
| Ride of the Valkyries | 5 | Spell | Valkyries | – | Return up to 2 Valhalla units from your graveyard to the board. |
| Loge's Fire | 3 | Spell | Gods | – | Deal 2 damage to all enemy units. |
