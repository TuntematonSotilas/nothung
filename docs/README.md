# Documentation — Nothung: The Ring Card Game

> Entry point for all project documentation.
> Status: Draft · Last updated: 2026-10-13

## Project at a glance

| Item       | Choice                                                   |
|------------|----------------------------------------------------------|
| Name       | **Nothung: The Ring Card Game** ([details](functional/01-vision.md#name)) |
| Genre      | Trading/collectible card game — 1v1 duel                 |
| Theme      | Richard Wagner's *Der Ring des Nibelungen* (4 operas)    |
| Mode       | Single player vs AI, fully offline                       |
| Platform   | Android (phones, portrait)                               |
| Price      | Entirely free — no IAP, no ads                           |
| Languages  | English (source), German, Spanish, French                |
| Engine     | Godot 4.7.2                                              |
| Language   | GDScript (statically typed)                              |

## How the docs are organised

- **[functional/](functional/)** — *what* the game is: rules, cards, modes, UX. Written for designers and anyone joining the project. No code.
- **[technical/](technical/)** — *how* it is built: architecture, data model, engine, build. Each file links back to the functional section it implements.
- **[adr/](adr/)** — Architecture Decision Records: one file per significant, hard-to-reverse decision.
- **[tools/](tools/README.md)** — recommended software for producing art and audio.

Pending decisions are written as `> **Open question:** …` in every file. List them all with:

```sh
grep -rn "Open question" docs/
```

## Functional documentation

| # | Document | Content | Status |
|---|----------|---------|--------|
| 1 | [Vision](functional/01-vision.md) | Pitch, pillars, audience, scope | Draft |
| 2 | [Lore & setting](functional/02-lore-and-setting.md) | Operas, characters, factions, artifacts | Draft |
| 3 | [Game rules](functional/03-game-rules.md) | Match flow, zones, resources, combat, victory | Draft |
| 4 | [Cards](functional/04-cards.md) | Card anatomy, types, keywords, rarities, deck rules | Draft |
| 5 | [Game modes](functional/05-game-modes.md) | Campaign, quick match, deck builder, tutorial | Draft |
| 6 | [Progression](functional/06-progression.md) | Collection, unlocks, rewards | Draft |
| 7 | [UI / UX](functional/07-ui-ux.md) | Screen flow, gestures, accessibility | Draft |
| 8 | [Art & audio](functional/08-art-and-audio.md) | Art direction, music, SFX | Draft |
| – | [Glossary](functional/glossary.md) | Game and lore terms | Draft |

## Technical documentation

| #  | Document | Content | Status |
|----|----------|---------|--------|
| 1  | [Architecture](technical/01-architecture.md) | Layers, autoloads, event flow | Draft |
| 2  | [Project structure](technical/02-project-structure.md) | Folder layout, naming | Draft |
| 3  | [Data model](technical/03-data-model.md) | Card/deck resources, effects | Draft |
| 4  | [Game engine](technical/04-game-engine.md) | State, turn machine, actions, effect resolution | Draft |
| 5  | [AI opponent](technical/05-ai-opponent.md) | Decision making, difficulty | Draft |
| 6  | [UI implementation](technical/06-ui-implementation.md) | Scenes, touch input, animation, i18n | Draft |
| 7  | [Persistence](technical/07-persistence.md) | Save data, versioning | Draft |
| 8  | [Coding standards](technical/08-coding-standards.md) | GDScript conventions | Draft |
| 9  | [Testing](technical/09-testing.md) | Test framework, strategy | Draft |
| 10 | [Build & release](technical/10-build-and-release.md) | Android export, Play Store, CI | Draft |

## Architecture Decision Records

| ADR | Title | Status |
|-----|-------|--------|
| [0000](adr/0000-template.md) | Template | – |
| [0001](adr/0001-godot-gdscript-android.md) | Godot 4.7.2 + GDScript, Android only | Accepted |
| [0002](adr/0002-cards-authored-in-markdown.md) | Cards authored as Markdown tables | Accepted |
| [0003](adr/0003-ai-on-worker-thread.md) | AI search on a worker thread | Accepted |
| [0004](adr/0004-gdunit4.md) | gdUnit4 as test framework | Accepted |

## Tools

| Document | Content |
|----------|---------|
| [Tools overview](tools/README.md) | Free starter kit |
| [Art tools](tools/art-tools.md) | Illustration, frames, icons, mockups |
| [Audio tools](tools/audio-tools.md) | MIDI / leitmotifs, orchestration, SFX |

## Document conventions

- Header block on every file: title, one-line purpose, `Status` (Draft / Review / Stable), last-updated date.
- Functional docs describe behaviour only; technical docs reference them with relative links.
- Diagrams use [Mermaid](https://mermaid.js.org/) (rendered by GitHub and the VS Code Markdown preview with a Mermaid extension).
- When a decision is made, replace the `Open question` block with `> **Decision (YYYY-MM-DD):** …`; record it as an ADR if it is architectural. List decisions with `grep -rn "Decision (" docs/`.
