# Game modes

> Every way the player can play, and how modes connect.
> Status: Draft · Last updated: 2026-10-12

## Overview

| Mode | Purpose | Unlocked |
|------|---------|----------|
| Tutorial | Teach the rules | First launch (skippable) |
| Campaign | Story through the four operas | After tutorial |
| Quick match | Free play vs AI | After tutorial |
| Deck builder | Create / edit decks | After tutorial |

## Tutorial

- Integrated into the *Rheingold* prologue: the player plays Wotan against Alberich.
- Teaches step by step: playing a unit, Gold, attacking, Leader ability, keywords, the Ring.
- Scripted hands and AI moves (deterministic).

## Campaign

Four chapters, each with 5–8 duels following the opera's story.

- Each duel has a **fixed opponent** (character + preconstructed deck) and optionally **special rules** (e.g. "Fafner's lair: the enemy Leader starts with 35 Life").
- Story is told between duels with illustrated text panels (no voice acting in v1.0).
- Rewards: new cards, new Leaders, decks.
- The player can switch to their own deck or a chapter-provided deck.

```mermaid
flowchart LR
    P[Prologue / Tutorial<br/>Das Rheingold] --> W[Ch.1<br/>Die Walküre]
    W --> S[Ch.2<br/>Siegfried]
    S --> G[Ch.3<br/>Götterdämmerung]
    G --> E[Epilogue<br/>Ring returns to the Rhine]
```

> **Decision (2026-10-09):** Linear campaign in v1.0 — duels follow the story order. A node map with optional side duels (e.g. Mime's riddle game) is a post-launch idea.

## Quick match

- Choose your deck, choose opponent deck (or random), choose difficulty (Easy / Normal / Hard).
- Gives small rewards (see [06-progression](06-progression.md)).

## Deck builder

- Browse collection with filters (faction, cost, type, rarity, keyword, owned/not owned).
- Create, rename, duplicate, delete decks; live validation of deck rules.
- Mana-curve chart and card-type breakdown.
- Number of deck slots: 12 (proposal).

## Optional / post-launch ideas

- **Challenges**: puzzles ("win this turn").
- **Gauntlet**: chain of AI duels with escalating difficulty, roguelike-lite.
- **Daily duel**: offline seed-based daily challenge.

## Multiplayer (planned for v2)

Not part of v1.0 (single player vs AI only). Mentioned here so v1.0 choices don't block it later.

> **Decision (2026-10-12):** v2 multiplayer = **online duel** against another player (friend invite and/or matchmaking). No local pass-and-play on a single device.

Points to define when v2 is designed:
- Accounts, collection and anti-cheat (the v1.0 collection is stored only on the device).
- Fairness: whether online duels use the player's collection or pre-built / fully unlocked decks.
- Turn timer (none in v1.0) and disconnection handling.
