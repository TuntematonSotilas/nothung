# Game rules

> Complete rules of a duel. This is the reference the rules engine implements ([technical/04-game-engine.md](../technical/04-game-engine.md)).
> Status: Draft · Last updated: 2026-10-19

All numbers below are **initial proposals** to be tuned in playtests.

## Overview

Two players (the human and the AI) each play with a deck of cards and a **Leader** (a character from the Ring). Each player starts with **20 Life**. A player loses when their Life reaches 0.

## Target match length

A match should last **5–7 minutes**, i.e. about **8–10 turns per player**. Every rule below serves that target:

| Lever | Choice | Effect on length |
|-------|--------|------------------|
| Starting Life | 20 (not 30) | Removes ~2–3 turns |
| Combat | Attacks during the Main phase, no separate phase | Fewer taps per turn |
| End-game clock | [Götterdämmerung](#götterdämmerung-turn-limit) from turn 10 | Guarantees an ending |
| AI turn | Short animations, 2× / instant option | Less waiting |

Match length is measured with AI vs AI simulations ([technical/09-testing.md](../technical/09-testing.md)).

## Match setup

1. Each player chooses a deck (20 cards) and its Leader.
2. Decks are shuffled. A coin flip decides who goes first.
3. Each player draws **4 cards**; the second player draws **5** and gets one **Energy token** (catch-up resource: +1 Energy once).
4. **Redraw (opening hand):** each player may put back any number of cards once and redraw that many.

## Zones

| Zone | Visibility | Description |
|------|------------|-------------|
| Deck | Hidden | Draw pile |
| Hand | Owner only | Max 10 cards; extra draws are discarded |
| Board | Public | Up to **6 units** per player |
| Artifacts | Public | Up to 3 artifacts per player |
| Graveyard | Public | Destroyed units and used spells |
| Banished | Public | Removed from the game (cannot be resurrected) |

> **Decision (2026-10-09):** Single board row per player (no front / back line) — readability in portrait.

## Resource: Energy

- Each player has an **Energy** pool. At the start of their turn, max Energy increases by 1 (up to 10) and the pool refills.
- Cards cost Energy to play.
- *Theme hook:* some cards (Nibelungs) produce extra Energy or let you store unspent Energy.

## Turn phases

```mermaid
stateDiagram-v2
    [*] --> Start
    Start --> Draw: refresh Energy, "start of turn" triggers, Götterdämmerung damage
    Draw --> Main: draw 1 card
    Main --> Main: play card / attack / Leader ability
    Main --> End: player taps End Turn
    End --> [*]: "end of turn" triggers, pass turn
```

1. **Start** — max Energy +1, refill Energy, "start of turn" effects, then [Götterdämmerung](#götterdämmerung-turn-limit) damage if active.
2. **Draw** — draw 1 card (nothing happens if the deck is empty).
3. **Main** — in any order: play cards, attack with ready units, activate the Leader ability (once per turn).
4. **End** — "end of turn" effects; turn passes.

## Units and combat

- Units have **Attack** and **Health**.
- During the Main phase, each ready unit may attack **once**: an enemy unit or the enemy Leader.
- A unit cannot attack on the turn it is played (*summoning sickness*) unless it has **Charge**.
- When a unit attacks a unit, both deal damage equal to their Attack simultaneously.
- Damage is **permanent**: a damaged unit stays damaged until healed or destroyed.
- A unit at 0 Health is destroyed and goes to the graveyard.
- **Guard** units must be attacked before other targets.

## Relics (equipment)

A **Relic** is an artifact that is attached to a unit instead of going to the artifact zone (Nothung, Tarnhelm…).

- When you play a Relic, choose a unit **you control** that meets its **Bearer** requirement (e.g. *Bearer (Wälsung)*). No valid unit → the Relic can't be played. A Relic without a Bearer requirement can go on any of your units.
- A unit can carry **at most 1 Relic**. Attached Relics do not count toward the 3-artifact limit.
- The Relic's bonus applies to its bearer only.
- When the bearer leaves the board, the Relic goes to the graveyard, unless its text says otherwise (e.g. *Nothung* shatters back into *Nothung (broken)*).

## Leader

- Each Leader has Life 20 and a **Leader ability** (costs Energy, once per turn).
- Starter Leaders: *Wotan* (3 Energy): deal 2 damage to a unit. *Alberich* (2 Energy): summon a Nibelung Miner — he commands his Nibelungs.

## The Ring (signature mechanic)

The Ring is a special neutral legendary artifact that enters play only through specific cards. It is held by a **player** (not attached to a unit).

> **Decision (2026-10-13):** Any player can hold the Ring and every holder suffers the curse, but only **Alberich** — who renounced love to forge it — unlocks its full power (see [canon notes](02-lore-and-setting.md#canon-notes-libretto)).

- **Bonus at the start of the holder's turn** (draft values):
  - **Full power** if the holder controls **Alberich** (as Leader or as a unit on the board): +2 Energy **and** draw 1 card.
  - **Reduced power** otherwise: +1 Energy.
- **Curse (every holder, Alberich included):** at the end of each of their turns, the holder loses Life equal to the number of turns they have held it, **capped at 3 per turn**. The count restarts when the Ring changes hands.
- **Creating the Ring:** only Nibelung cards bring the Ring into play (renunciation of love).
- **Stealing:** certain effects take the Ring from its holder (Wotan seizing it, Fafner claiming his payment, Hagen's treachery…). Returning it to the Rhine (a specific card) removes it from the game.

> **Decision (2026-10-09):** The Ring is not present by default; it enters play only through specific cards in a deck.

> **Decision (2026-10-15):** Keep the curse values (1+2+3+3 = 9 Life over 4 turns, capped at 3 per turn) as the starting point; tune bonus vs curse from playtests and AI vs AI simulations ([09-testing](../technical/09-testing.md)).

> **Decision (2026-10-19):** The curse stays as it is, but the **Nibelungs starter deck contains no card that creates the Ring** (*Renunciation of Love* stays in the card pool for built decks and the campaign). Reason: no Gods card can take the Ring back, so a starter-deck Nibelung player kept it to the end and lost 12.6 Life per match to the curse on average (AI vs AI, 40 matches: Gods won 38 / 40). Wotan's ability also went from 2 to 3 Energy. Figures: [AI soak](../technical/09-testing.md#ai-soak).

## Götterdämmerung (turn limit)

The end-game clock, themed on the burning of Valhalla.

- From the start of **turn 10** of each player, Valhalla burns: at the start of their turn, that player's Leader takes **1 damage**, then 2, then 3, and so on (+1 each turn).
- It cannot be prevented, except by specific legendary cards (e.g. Brünnhilde's sacrifice).
- The UI shows a countdown from turn 7 so the player can anticipate it.
- It replaces deck-out *fatigue*: drawing from an empty deck simply draws nothing.

> **Decision (2026-10-15):** Start at **turn 10**; move it earlier (e.g. turn 8) only if measured match length exceeds the [target](#target-match-length). The countdown stays 3 turns before the start.

## Victory and defeat

- Enemy Leader Life ≤ 0 → victory.
- Both Leaders reach 0 at the same time (e.g. Götterdämmerung, area damage) → draw.
- Campaign chapters may add **special victory conditions** (e.g. survive 8 turns, retrieve the Rhinegold).

## Timing and effect resolution

- Effects resolve one at a time, in the order they were triggered (first in, first out).
- Triggered abilities: `On play`, `On death`, `Start of turn`, `End of turn`, `On attack`, `On damage`.
- No player responses during the opponent's turn (no "instant speed") → keeps mobile play simple.
