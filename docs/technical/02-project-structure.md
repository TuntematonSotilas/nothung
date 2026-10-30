# Project structure

> Folder layout of the repository and the Godot project, plus naming conventions.
> Status: Draft · Last updated: 2026-10-30

## Repository

```
ring_card_game/
├── docs/                  # This documentation
├── cards/                 # Card source of truth: one Markdown table per faction (gods.md, nibelungs.md…)
├── game/                  # Godot project root (project.godot lives here)
├── tools/                 # Scripts: install_gdunit4.sh, card_pipeline.gd (Markdown → .tres)
├── README.md
└── LICENSE
```

> **Decision (2026-10-09):** The Godot project lives in `game/`, so docs, card sources and tools stay out of the Godot import and export.

Card authoring flow: `cards/*.md` → `tools/` converter → `game/data/cards/**/*.tres` ([03-data-model](03-data-model.md#card-authoring-pipeline)).

## Godot project (`res://`)

```
res://
├── project.godot
├── export_presets.cfg          # No secrets committed (see 10-build-and-release)
├── autoload/                   # CardDatabase, SaveManager, SceneRouter, AudioManager, Settings
├── core/                       # Rules engine — NO Node / scene dependency
│   ├── match/                  # Match, GameState, PlayerState, Zone
│   ├── actions/                # Action base class + PlayCardAction, AttackAction, EndTurnAction…
│   ├── effects/                # Effect base class + DealDamageEffect, DrawEffect…
│   ├── events/                 # GameEvent types
│   └── rules/                  # RulesValidator, keyword handlers
├── ai/                         # AIPlayer, Easy / Normal (greedy) / Hard (MCTS), StateEvaluator, AIProfile
├── data/
│   ├── cards/                  # GENERATED from cards/*.md — one .tres per card: <faction>/<card_id>.tres
│   ├── decks/                  # Starter & campaign decks (.tres)
│   ├── leaders/
│   └── campaign/               # Chapter & duel definitions
├── scenes/
│   ├── screens/                # splash, main_menu, quick_match, collection, deck_list, deck_editor, nibelheim, settings_menu, duel…
│   ├── components/             # card_view, card_grid, card_filter_bar, card_detail, duel_fx…
│   └── popups/
├── ui/
│   ├── theme/                  # Godot Theme resources, fonts, styleboxes
│   └── icons/
├── assets/
│   ├── app_icon/               # App icon: SVG sources + PNG layers for the Android export
│   ├── art/cards/
│   ├── art/boards/
│   ├── audio/music/
│   ├── audio/sfx/
│   └── fonts/
├── localization/               # translations .csv → .translation
└── tests/
    ├── unit/                   # core/ and ai/ tests
    └── integration/            # full scripted matches
```

## Naming conventions

See [08-coding-standards](08-coding-standards.md#naming) — single reference for files, classes, IDs and translation keys. In short: files `snake_case`, classes `PascalCase` (`deal_damage_effect.gd` → `DealDamageEffect`).

Scene scripts sit next to their `.tscn`.
