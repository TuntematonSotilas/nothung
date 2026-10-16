# ADR-0002: Cards authored as Markdown tables

- **Status:** Accepted
- **Date:** 2026-10-09
- **Deciders:** Gaël

## Context

The game will have ~80 cards at launch across 4 factions + Neutral, growing with expansions. Card definitions must be easy to read, compare and balance, reviewable in git, and loaded by Godot as typed `CardData` resources ([technical/03-data-model.md](../technical/03-data-model.md)).

## Decision

- The source of truth for cards is **one Markdown table per faction** in `cards/<faction>.md`.
- A GDScript converter in `tools/`, run with headless Godot, generates `game/data/cards/<faction>/<id>.tres` and the English localisation entries.
- Generated `.tres` files are committed but never edited by hand; the converter's check mode fails if regenerating them produces a diff (run before committing).
- Card abilities use a small text syntax (`trigger[condition]: effect(args)`), validated by the converter.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Godot inspector only (`.tres`) | No tooling to write | One card per file, hard to compare and balance; inspector editing of nested effects is slow |
| Spreadsheet / CSV | Great for numbers, sorting | Binary (`.xlsx`) or awkward (`.csv`) diffs; separate tool outside the repo |
| **Markdown tables** | Readable on GitHub / VS Code, clean diffs, one page per faction | Needs a parser + validator; long `abilities` cells can get hard to read |

## Consequences

- A converter + validator must be written before the card count grows (early milestone).
- Rules text is generated from abilities → it can never disagree with the actual behaviour.
- If `abilities` cells become too long, complex cards may move to a dedicated section below the table (same file), referenced by `id`.
