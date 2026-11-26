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
| Achievements | Rhinegold and 25 XP (cosmetics later: card backs, frames…) |
| Player level reached | 40 Rhinegold, claimed in the main menu (cosmetics later); from level 5 and 10, Leader powers can be unlocked |

## Meta currency

> Distinct from in-match Energy. The progression currency is **Rhinegold**.

- Earned in quick matches, achievements and level ups.
- Spent in **Nibelheim** on [Leader powers](#leader-powers), and to craft a specific card (Common 40, Rare 100, Epic 400, Legendary 1600 — draft values), one copy at a time, up to the copies a deck can hold (2, or 1 for Epic and Legendary): beyond that a copy is useless, so Nibelheim does not offer it.
- A Quick match win pays at the end of the match and is shown on the results. Undoing the winning play from the results takes it back (it is paid again if the match is won again).
- Duplicate extra copies above the deck limit are automatically converted to Rhinegold.

> **Decision (2026-10-09):** Direct crafting only — no random card packs.

## Achievements

Quick matches count (a duel without rewards does not), and crafting in Nibelheim. Reaching a target makes an achievement available to claim in the Achievements screen; its Rhinegold and 25 XP are paid only after the player claims it. Undoing the winning play from the results takes back the match's statistics and any achievements it newly made available.

| Achievement | To do | Rhinegold |
|-------------|-------|-----------|
| *Hojotoho!* | Win a Quick match | 20 |
| *Einherjar* | Win 10 matches | 50 |
| *Valhalla* | Win 50 matches | 150 |
| *The Ring Cycle* | Play 100 matches | 100 |
| *Four Evenings* | Win with each of the four Leaders | 100 |
| *Götterdämmerung* | Win a match on Hard | 60 |
| *Twilight* | Win with your Leader at 1 Life | 40 |
| *Renunciation of Love* | Win holding the Ring, the opponent never having had it | 40 |
| *Notung! Notung!* | Reforge Nothung in 10 matches | 80 |
| *The Nibelung Hoard* | Play 20 artifacts | 40 |
| *Invulnerable* | Win without losing a unit | 60 |
| *Mime's Apprentice* | Forge a card in Nibelheim | 20 |
| *The Forging Song* | Forge 10 cards in Nibelheim | 60 |

> **Decision (2026-11-20):** first set of 13 achievements paying Rhinegold (and, since the [player level](#player-level), 25 XP each); *Renunciation of Love* becomes "win holding the Ring, the opponent never having had it" (the Ring does not exist at the start of a match). Tiers and cosmetic rewards wait for the rest of [milestone 6](../roadmap.md#6--progression--rewards).

## Player level

Every finished Quick match gives XP, and so does each achievement claimed (in a match or in Nibelheim); undoing the winning play from the results takes the match's XP back, with its levels. Each level reached gives Rhinegold (cosmetics later), **claimed by hand** from the level badge of the main menu, which glows while a reward waits.

| Source | XP |
|--------|----|
| Quick match lost or drawn | 10 |
| Quick match won | 20 (Easy) / 30 (Normal) / 40 (Hard) |
| Achievement claimed | 25 |

- From level *n* to *n* + 1: **20 + 10 × (*n* − 1)** XP — 20 for level 2 (one match), 110 from level 10 (about 5 matches), 300 for the last one; **level 30** is the cap (4,640 XP, about 230 matches).
- Each level reached: **+40 Rhinegold**, to claim (several levels are claimed together).
- Shown in the main menu (level, XP bar) and on the results (XP gained, level reached).

> **Decision (2026-11-20):** numbers above; cosmetic rewards come with their artwork, later in [milestone 6](../roadmap.md#6--progression--rewards).

> **Decision (2026-11-23):** level rewards are **claimed by hand** in the main menu, like achievements in their screen; levels reached before were already paid (profile v5).

## Leader powers

Each Leader has its base ability and **two powers**: other versions of it, a little stronger. They are unlocked in **Nibelheim** (Leaders tab) once the player level is reached, for Rhinegold; each deck then chooses the version its Leader plays with (deck editor: **Change the Leader's power**). The AI plays a version of its Leader drawn at random in each Quick match.

| Leader | Base ability | Power 1 — level 5, 300 Rhinegold | Power 2 — level 10, 600 Rhinegold |
|--------|--------------|----------------------------------|-----------------------------------|
| Wotan | 3 Energy: 2 damage to a unit | *Wotans Zorn* — 3 Energy: 2 damage, double against Nibelungs | *Walvater* — 2 Energy: 2 damage |
| Alberich | 2 Energy: summon a Nibelung Miner | *Des Ringes Herr* — 3 Energy: summon a Nibelung Host (2/3, guard) | *Verwandlung* — 2 Energy: summon *Alberich, the Toad* (2/3, invisible) |
| Siegfried | 2 Energy: 1 damage, double against Gods | *Nothungs Schneide* — 3 Energy: 2 damage, double against Gods | *Furchtlos* — 1 Energy: 1 damage, double against Gods |
| Brünnhilde | 3 Energy: summon a Fallen Hero (2/3) | *Walhalls Wahl* — 3 Energy: summon a Hero of Valhalla (2/4, guard) | *Wunschmaid* — 2 Energy: summon Ortlinde (1/4, guard) |

- Power names are the original German names, the same in every language.
- Source: `cards/leader_powers.md`. Each power wins about **10 points** more often than the base ability against the other starter decks (AI soak, [testing](../technical/09-testing.md#ai-soak)).

> **Decision (2026-11-20):** Leader powers are **upgrades** of the ability, two per Leader, unlocked in Nibelheim with a **player level and Rhinegold** (level 5 / 300, level 10 / 600) — the only thing a level locks. The deck editor chooses the version; the AI draws one at random. Strength target: about +10 points of win rate over the base ability. A first draft (power 1 stronger for the same cost, power 2 one Energy cheaper) won up to 87 % (*Alberich*, a Nibelung Miner for 1 Energy) and was retuned.

## Ideas to refine (2026-11-20)

> Draft for [milestone 6](../roadmap.md#6--progression--rewards): the player's ideas first, then suggestions and open questions. **Nothing here is decided.**

### Rewards

- Ideas: a **home background** (main menu) and **deck backgrounds** (deck tiles, deck editor).
- Suggestions: card backs; card frames (gold border); alternative Leader portraits; board skins (see [Cosmetics](#cosmetics)); a title or emblem next to the deck name; a music room (the leitmotifs).
- Rhinegold stays the default reward.

### Level

- XP for each match played (more for a win, by difficulty) and for each achievement; one level every N XP.
- Possible unlocks: campaign chapters; Nibelheim (after the tutorial); factions and their starter decks (today tied to the campaign: see [Starting collection](#starting-collection)); Hard difficulty; backgrounds and skins; mini-games or "dungeons" (e.g. a run down into Nibelheim with a deck built along the way — a later mode).

> **Decision (2026-11-20):** campaign chapters open **with the story only** (the previous chapter won), never with the level. A level up gives **cosmetics and Rhinegold** — it locks nothing (no Hard difficulty or chapter behind a level; amended the same day: [Leader powers](#leader-powers) need a level). Pace: **fast, then slower** — level 2 after the first match or two, then about 3 to 5 matches a level, slower and slower, up to a cap around level 30. **Every finished match gives XP** — a win more than a loss, with a bonus by difficulty — and each achievement gives XP when manually claimed. Numbers: see [Player level](#player-level).

### Leader powers

- Decided: see [Leader powers](#leader-powers) (upgrades, level + Rhinegold, Nibelheim tab, chosen per deck).

### Achievements

> A first set is in place ([Achievements](#achievements)); the ideas below are for the next ones.

- Progression: play / win 10, 50, 100 matches.
- Factions: win with each Leader.
- Cards: play 20 artifacts, reforge Nothung 10 times (*Notung! Notung!*), hold the Ring at the end of a won match.
- Challenge: *Twilight*, *Renunciation of Love*, win on Hard, win without losing a unit.
- Collection: craft a first card in Nibelheim, own every card.
- Tiers (bronze / silver / gold) for the counters; rewards: Rhinegold, XP, cosmetics.
- Reached achievements are shown on the results screen and listed with progress in the Achievements screen; Rhinegold and XP require a manual claim.

## Cosmetics

Backgrounds are **bought in Nibelheim** (Backgrounds tab), like Leader powers: each one from a player level, for Rhinegold.

| Background | Kind | Level | Rhinegold |
|------------|------|-------|-----------|
| *The Rhine Depths* | Home | 5 | 150 |
| *Valhalla* | Board | 10 | 200 |
| *Nibelheim* | Home | 15 | 300 |
| *The Valkyrie Rock* | Board | 20 | 400 |
| *Valhalla in Flames* | Home | 25 | 500 |
| *The Ring* | Board | 30 | 600 |

- **Home background**: behind the main menu; chosen in **Settings** (Default or one owned).
- **Board**: behind the player's own play area in a match; chosen **per deck** in the deck editor (**Change the board**, under the Leader's power). The opponent's area keeps the plain background.
- The pictures are **generated placeholders** (gradients and shapes) until the author draws them ([art](08-art-and-audio.md#duel-backgrounds)).

> **Decision (2026-11-26):** 3 home backgrounds and 3 boards, alternating every 5 levels, bought with Rhinegold in a Nibelheim tab once the level is reached; the board shows only behind the player's units. Prices are draft values.

Later ideas: card backs, Leader portraits, more boards (Gibichung hall).

> **Decision (2026-10-09):** Cosmetics are not sold — the game is entirely free ([01-vision](01-vision.md#scope)). They are unlocked through achievements, campaign progress or Rhinegold.
