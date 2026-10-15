# Cards

> Card anatomy, types, traits, rarities and deckbuilding rules. Card list lives in data files (see [technical/03-data-model.md](../technical/03-data-model.md)).
> Status: Draft · Last updated: 2026-10-15

## Card anatomy

```
┌─────────────────────────┐
│ (3)          WOTAN  ◆   │  cost · name · rarity gem
│                         │
│        [ artwork ]      │
│                         │
│ Unit — God      Gods ☉  │  type — subtype · faction
│ Guard.                  │  traits
│ On play: draw a card.   │  rules text
│ "Ending! Ending!"       │  flavour text (italic)
│ ⚔ 3              ♥ 5    │  attack · health
└─────────────────────────┘
```

| Field | Required | Notes |
|-------|----------|-------|
| Name | ✔ | Unique per card |
| Cost | ✔ | 0–10 Energy |
| Type | ✔ | See below |
| Subtype | – | God, Dwarf, Giant, Wälsung, Hero, Valkyrie, Relic, Weapon… (used by synergies and Bearer requirements) |
| Faction | ✔ | Or Neutral |
| Rarity | ✔ | See below |
| Attack / Health | units only | |
| Traits | – | See below |
| Rules text | – | Must be generated / validated from the card's effects |
| Flavour text | – | Libretto quote or paraphrase |
| Artwork | ✔ | |

## Card types

| Type | Behaviour |
|------|-----------|
| **Unit** | Stays on the board, can attack and be attacked |
| **Spell** | One-shot effect, then goes to the graveyard |
| **Artifact** | Stays in the artifact zone with an ongoing effect; can't be attacked, can be destroyed by effects |
| **Artifact — Relic** | Equipment: attached to one of your units instead of the artifact zone ([Relic rules](03-game-rules.md#relics-equipment)) |
| **Leader** | Not in the deck; chosen at deck creation; provides Life and Leader ability |

## Traits (initial list)

| Trait | Effect |
|---------|--------|
| **Guard** | Enemies must attack this unit first |
| **Charge** | Can attack the turn it is played |
| **Flying** | Ignores Guard: can attack any target even when the enemy has Guard units (Valkyries, the dragon…) |
| **Valhalla** | When destroyed, can be resurrected by Valkyrie effects (marks heroic units) |
| **Forge X** | Spend X extra Energy when playing to upgrade the card |
| **Leitmotif (Y)** | Bonus if you played another card with motif Y this turn |
| **Cursed** | Holder suffers a drawback (Ring and related cards) |
| **Invisible** | Cannot be targeted until it attacks (Tarnhelm) |
| **Fated** | Effect triggers when the Norns' prophecy condition is met |
| **Bearer (X)** | Relic only: can be attached only to a unit of subtype or name X (e.g. *Bearer (Wälsung)*) |

> **Decision (2026-10-15):** With a single board row ([03-game-rules](03-game-rules.md)), there is no blocking: **Flying = ignores Guard**.

> **Decision (2026-10-09):** At most **10 traits** in v1.0, so rules text stays short on a phone screen. The list above is now **full (10/10)**: any new trait must replace one.

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
| Alberich, Lord of the Nibelungs | 4 | Unit — Dwarf | Nibelungs | 3/4 | On play: gain 2 Energy. If you hold the Ring, draw a card. |
| Fafner | 8 | Unit — Giant | Neutral | 8/8 | Guard. Cannot attack the turn after it attacks. |
| Ride of the Valkyries | 5 | Spell | Valkyries | – | Return up to 2 Valhalla units from your graveyard to the board. |
| Loge's Fire | 3 | Spell | Gods | – | Deal 2 damage to all enemy units. |

## Signature cards (libretto rules)

These cards follow the [canon notes](02-lore-and-setting.md#canon-notes-libretto). Numbers are drafts to balance in playtests.

> **Decision (2026-10-13):** **Nothung** is carried only by a Wälsung (Siegmund, Siegfried) and can be reforged only if you control Siegfried.

> **Decision (2026-10-13):** **Tarnhelm** can be worn by any unit, with a bonus when worn by its bearers in the libretto: Alberich, Fafner, Siegfried.

> **Decision (2026-10-13):** **Siegfried** gets a bonus skill against the Gods (*Spear-breaker*). He does not trigger the Götterdämmerung.

| Name | Cost | Type | Faction | Stats | Text |
|------|------|------|---------|-------|------|
| Nothung (broken) | 1 | Artifact — Relic, Weapon | Heroes | – | Stays in the artifact zone; cannot be attached. **Forge 4**, only if you control **Siegfried**: becomes *Nothung*. |
| Nothung | – | Artifact — Relic, Weapon | Heroes | – | Created by forging only. **Bearer (Wälsung).** Bearer gets +3 Attack. When the bearer dies, put *Nothung (broken)* into your artifact zone (the sword shatters, as with Siegmund). |
| Tarnhelm | 3 | Artifact — Relic | Neutral | – | Bearer gains **Invisible**. If worn by **Alberich**: the first time he would be destroyed, return him to your hand instead (the toad). By **Fafner**: +3/+3 and **Guard** (the dragon). By **Siegfried**: he may ignore **Guard** when attacking (Gunther's form). |
| Siegfried | 6 | Unit — Wälsung, Hero | Heroes | 5/5 | **Valhalla.** **Spear-breaker:** deals double damage to God units and to a God Leader. |
| Siegmund | 4 | Unit — Wälsung, Hero | Heroes | 4/3 | **Valhalla.** On play: if *Nothung* is in your artifact zone or graveyard, attach it to Siegmund. |
| The Ring | 0 | Artifact | Neutral | – | Created by Nibelung cards only. Held by a player. Start of your turn: +1 Energy — or, if you control **Alberich**, +2 Energy and draw 1. **Cursed** (see [The Ring](03-game-rules.md#the-ring-signature-mechanic)). |

*Tarnhelm is Neutral so that Nibelung (Alberich), Heroes (Siegfried) and Neutral (Fafner) decks can all use it.*
