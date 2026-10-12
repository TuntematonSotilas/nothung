# Vision

> What the game is, who it is for, and what is in or out of scope.
> Status: Draft · Last updated: 2026-10-12

## Elevator pitch

A 1v1 collectible card game for Android in which the player relives Wagner's *Ring* cycle — from the theft of the Rhinegold to the Twilight of the Gods — by building decks of gods, giants, dwarves, heroes and Valkyries, and duelling AI opponents drawn from the operas.

## Design pillars

1. **The curse of the Ring** — power always has a price. Strong cards and the Ring itself carry drawbacks; greed is a valid but dangerous strategy.
2. **Leitmotifs** — cards and characters recur and combine; playing related cards (same motif) builds up effects, echoing Wagner's musical themes.
3. **Short, deep duels** — a match fits in 5–7 minutes on a phone (see [match length](03-game-rules.md#target-match-length)), but decisions stay meaningful.
4. **Offline and fair** — no connection required, no pay-to-win; everything is earnable by playing.

## Target audience

- Players of digital card games (Hearthstone, Gwent, Marvel Snap, Legends of Runeterra) looking for an offline, single-player experience.
- Mythology / opera enthusiasts curious about the *Ring* story.
- Age rating target: PEGI 12 (fantasy violence).

## Reference games

| Game | What we take from it |
|------|----------------------|
| Hearthstone | Readable board, mana curve, hero power |
| Gwent | Rows / lanes, narrative campaign (Thronebreaker) |
| Marvel Snap | Short matches, mobile-first UI |
| Slay the Spire | Single-player pacing, clear card text |

## Scope

### In scope (v1.0)

- 1v1 duel vs AI, full rules engine
- Campaign: 4 chapters (one per opera)
- Quick match vs AI with difficulty levels
- Deck builder and card collection
- ~80 cards across 4 factions + Neutral; 20-card decks
- Localisation: English (source language), German, Spanish, French

### Out of scope (v1.0)

- Online multiplayer (PvP duels) — planned for **v2**, see [05-game-modes](05-game-modes.md#multiplayer-planned-for-v2)
- Accounts, cloud backend, leaderboards
- iOS / desktop builds
- Real-money purchases and ads (the game is free)

> **Decision (2026-10-09):** The game is **entirely free**: no price, no in-app purchases, no ads. Everything (cards, cosmetics) is earned by playing ([06-progression](06-progression.md)).

## Success criteria

- A full match is playable end-to-end against the AI with no rule bugs.
- Average match length 5–7 min (8–10 turns per player).
- Runs at 60 fps on a mid-range Android phone (target device TBD).
