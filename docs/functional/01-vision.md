# Vision

> What the game is, who it is for, and what is in or out of scope.
> Status: Draft · Last updated: 2026-10-13

## Name

> **Decision (2026-10-13):** The game is called **Nothung: The Ring Card Game**.

- **Nothung** is the sword of the Wälsungs: shattered by Wotan's spear, reforged by Siegfried. A broken-then-reforged sword echoes the game itself: decks are built and improved, and *Nothung* is also a card that must be forged ([04-cards](04-cards.md#example-cards-to-validate-the-format)).
- Pronunciation: German *NOH-toong* (from *Not*, "need / distress"). Not "not-hung".
- **Always use the full name with the subtitle** (store listing, title screen, icon text where possible): the subtitle makes the game findable and avoids confusion with the word "nothing" (autocorrect) and the *Nothing* phone brand.
- The name stays untranslated in every language; only the subtitle may be localised in store listings (e.g. FR *Nothung : le jeu de cartes de l'Anneau*).
- Logo: built around the sword, so the name reads at a glance ([08-art-and-audio](08-art-and-audio.md)).

Checks to complete before release:
- [ ] No existing app or game with this name on Google Play
- [ ] No conflicting trademark in class 9 (software / video games): INPI (FR), EUIPO (EU)
- [ ] Domain name and social media handles available
- [ ] Spoken test with English and Spanish speakers

## Elevator pitch

*Nothung: The Ring Card Game* is a 1v1 collectible card game for Android in which the player relives Wagner's *Ring* cycle — from the theft of the Rhinegold to the Twilight of the Gods — by building decks of gods, giants, dwarves, heroes and Valkyries, and duelling AI opponents drawn from the operas.

## Design pillars

1. **The curse of the Ring** — power always has a price. Strong cards and the Ring itself carry drawbacks; greed is a valid but dangerous strategy.
2. **Leitmotifs** — cards and characters recur and combine; playing related cards (same motif) builds up effects, echoing Wagner's musical themes.
3. **Short, deep duels** — a match fits in 5–7 minutes on a phone (see [match length](03-game-rules.md#target-match-length)), but decisions stay meaningful.
4. **Offline and fair** — no connection required, no pay-to-win; everything is earnable by playing.

## Target audience

- Players of digital collectible card games looking for an offline, single-player experience.
- Mythology / opera enthusiasts curious about the *Ring* story.
- Age rating target: PEGI 12 (fantasy violence).

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
