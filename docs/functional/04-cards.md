# Cards

> Card anatomy, types, traits, rarities and deckbuilding rules. Card list lives in data files (see [technical/03-data-model.md](../technical/03-data-model.md)).
> Status: Draft · Last updated: 2026-10-23

## Card anatomy

```
┌─────────────────────────┐  frame: thin border in the faction colour; its shape gives the type
│ ⚡3              ☉  [R]  │  cost · faction icon (faction colour) · rarity badge
│█ Wotan █████████████████│  name on a full-width banner in the faction colour
│                         │
│        [ artwork ]      │  illustration (when drawn)
│                         │
│ Guard.                  │  traits
│ On play: draw a card.   │  rules text
│ [       BEARER        ] │  ribbon, relics only
│ ⚔ 3  ♥ 5        Unit ▣  │  attack · health (units) · type name + icon
└─────────────────────────┘
```

> **Updated (2026-10-23):** layout as built in the game ([card frames](08-art-and-audio.md#card-frames)). Frames are drawn by the game, not painted: the faction colour is on the border and the name banner, the background stays dark until the illustration covers it. The **frame shape** encodes the type (unit: rectangle · spell: very rounded · artifact: octagon · relic: octagon + Bearer ribbon). Subtype and flavour text are not shown on the card face yet (planned for the zoomed card).

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
| **Invisible** | Cannot be attacked or targeted by the opponent until it attacks (Tarnhelm). Effects that hit all units still hit it; a hidden Guard does not force attacks |
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
| Legendary | 1 | ~10 % (major characters, the Ring, Nothung…) |

On the card, rarity is a **letter in a coloured badge** in the top-right corner: **C** Common · **R** Rare · **E** Epic · **L** Legendary ([rarity colours](08-art-and-audio.md#rarity-colours)).

> **Decision (2026-10-19):** Rarity of **named characters** depends on their weight in the story, not on having a name.
> - **Legendary** (1 copy): the major characters and objects — Wotan, Brünnhilde, Siegfried, Siegmund, Alberich, Hagen, the Ring, Nothung, the Tarnhelm… (Wotan, Alberich and Siegfried are Leaders, not cards)
>
> **Decision (2026-10-26):** **one Legendary card per faction**, so every faction has its signature piece: Gods — *Wotan's Spear*, Nibelungs — *Tarnhelm*, Wälsungs — *Nothung* (*Nothung (broken)* and its forged form count as one sword), Valkyries — *Ride of the Valkyries* (Brünnhilde is the Leader), Neutral — *Hagen*. Characters of the list above that are not the faction's Legendary are Epic (Siegmund).
> - **Common / Rare / Epic** (by power): the secondary named characters — Fricka, Freia, Donner, Froh, Loge, the eight sister Valkyries, Mime, Sieglinde, the Rhinemaidens…
>
> A card named after a character must come from the libretto: no figure from Norse mythology that Wagner does not use ([canon notes](02-lore-and-setting.md#canon-notes-libretto)).

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
| Gods | 10 | 4 | 1 | 15 (done: [`cards/gods.md`](../../cards/gods.md)) |
| Nibelungs | 9 | 3 | 3 | 15 (done: [`cards/nibelungs.md`](../../cards/nibelungs.md)) |
| Wälsungs & Heroes | 8 | 5 | 2 | 15 (done: [`cards/walsungs.md`](../../cards/walsungs.md)) |
| Valkyries | 10 | 4 | 1 | 15 (done: [`cards/valkyries.md`](../../cards/valkyries.md)) |
| Neutral | 13 | 5 | 2 | 20 (done: [`cards/neutral.md`](../../cards/neutral.md)) |
| **Total** | | | | **~80** |

Each faction has 35 eligible cards (15 faction + 20 Neutral) to build a 20-card deck — enough for several distinct decks per faction. More cards can come with post-launch expansions (e.g. Giants and Gibichungs as factions).

## Example cards (to validate the format)

| Name | Cost | Type | Faction | Stats | Text |
|------|------|------|---------|-------|------|
| Alberich, Lord of the Nibelungs | 4 | Unit — Dwarf | Nibelungs | 3/4 | On play: gain 2 Energy. If you hold the Ring, draw a card. |
| Fafner | 8 | Unit — Giant | Neutral | 8/8 | Guard. Cannot attack the turn after it attacks. |
| Ride of the Valkyries | 5 | Spell — Legendary | Valkyries | – | Return up to 2 Valhalla units from your graveyard to the board. |
| Loge | 4 | Unit — God | Gods | 2/3 | On play: deal 2 damage to all enemy units. |

## Signature cards (libretto rules)

These cards follow the [canon notes](02-lore-and-setting.md#canon-notes-libretto). Numbers are drafts to balance in playtests.

> **Decision (2026-10-13, updated 2026-10-26):** **Nothung** is carried by a Wälsung unit (Siegmund, Sieglinde). It is reforged in a Wälsungs deck — led by Siegfried — by playing Siegmund or *Notung! Notung!*.

> **Decision (2026-10-13, updated 2026-10-26):** **Tarnhelm** is the **Nibelungs' Legendary** (Mime forged it for Alberich). Any unit can wear it. The bonuses for Alberich and Siegfried were dropped: both became Leaders, so they cannot wear it.

> **Decision (2026-10-13, updated 2026-10-26):** **Siegfried** is the **Wälsungs Leader**, not a card. His ability **Spear-breaker** (2 Energy) deals 1 damage to a unit, double against Gods. At 2 damage (4 against Gods) the Wälsungs won 94 % of their matches against the Gods in the AI soak, so the base damage is 1. He does not trigger the Götterdämmerung.

| Name | Cost | Type | Faction | Stats | Text |
|------|------|------|---------|-------|------|
| Nothung (broken) | 1 | Artifact — Weapon | Wälsungs | – | Stays in your artifacts; reforged into *Nothung* by Siegmund or *Notung! Notung!*. Also brought by *Brünnhilde, Protector*. |
| Nothung | – | Artifact — Relic, Weapon | Wälsungs | – | Created by forging only. **Bearer (Wälsung).** Bearer gets +3/+0. When its bearer dies, it shatters into *Nothung (broken)* in your artifacts (as with Siegmund). |
| Tarnhelm | 2 | Artifact — Relic | Nibelungs | – | Bearer gets +2/+2 and **Invisible** (cannot be attacked or targeted by the opponent until it attacks). |
| Wotan's Spear | 5 | Artifact — Weapon | Gods | – | At the start of your turn: deal 1 damage to the enemy Leader (the treaties carved on it bind his foes). |
| Siegmund | 4 | Unit — Wälsung, Hero | Wälsungs | 5/4 | **Valhalla.** On play: if you control *Nothung (broken)*, forge *Nothung* — he carries it. |
| Notung! Notung! | 3 | Spell | Wälsungs | – | On play: if you control *Nothung (broken)*, forge *Nothung* onto a Wälsung. |
| The Ring | 0 | Artifact | Neutral | – | Created by Nibelung cards only. Held by a player. Start of your turn: +1 Energy — or, if you control **Alberich**, +2 Energy and draw 1. **Cursed** (see [The Ring](03-game-rules.md#the-ring-signature-mechanic)). |

