# Testing

> Test strategy and tooling.
> Status: Draft · Last updated: 2026-10-15

## Framework

> **Decision (2026-10-09):** [gdUnit4](https://github.com/MikeSchulze/gdUnit4) — richer assertions and mocking, VS Code integration, headless CLI runner. See [ADR-0004](../adr/0004-gdunit4.md).

- Installed as an addon in `game/addons/gdUnit4/` (version compatible with Godot 4.7.2, pinned).
- Test files: `tests/**/test_*.gd`, classes extending `GdUnitTestSuite`.

## Test pyramid

| Level | Scope | Location | Run |
|-------|-------|----------|-----|
| Unit | Effects, keywords, rules validation, save migration | `tests/unit/` | Every commit (CI) |
| Integration | Full scripted matches: seed + action list → expected final state | `tests/integration/` | Every commit (CI) |
| Card data | Validation of every `CardData` ([03-data-model](03-data-model.md#validation)) | `tests/unit/` | Every commit (CI) |
| AI soak | AI vs AI for N matches: no crash, no illegal move, no infinite loop; win-rate stats per deck | `tests/soak/` | Nightly / manual |
| Manual | UI, feel, device testing | Checklist below | Before each release |

## What must be tested

- Every keyword and every effect type has at least one unit test.
- Every rule in [functional/03-game-rules.md](../functional/03-game-rules.md) has a test named after its section.
- Each bug fix adds a regression test (often a recorded action list from the debug log).

## Determinism helpers

- Tests create matches with a fixed seed and stacked decks (`Match.create_for_test(deck_order_a, deck_order_b)`).
- A replay test re-applies a saved action list and compares the final state hash.
- **Resume tests** ([07-persistence](07-persistence.md#resume-an-interrupted-match)): save `current_match.json` at random points of scripted matches, rebuild, and check the state hash equals the live one; a file with a wrong `content_hash` or an illegal action is rejected cleanly.

## Running headless

gdUnit4 ships a command-line runner in its addon folder (`runtest.sh` / `runtest.cmd`), which uses the Godot binary given by the `GODOT_BIN` environment variable:

```sh
# from game/
export GODOT_BIN=/path/to/godot-4.7.2
./addons/gdUnit4/runtest.sh -a res://tests
```

Check the exact options against the gdUnit4 version installed, and update this section with the final command. The runner writes JUnit-style XML reports that CI can publish.

Threaded AI ([05-ai-opponent](05-ai-opponent.md#threading)) is tested in **synchronous mode**, so tests stay deterministic.

## Manual test checklist (release)

- [ ] Install on reference device + one low-end device + one tall-aspect (20:9+) device
- [ ] Complete tutorial
- [ ] Play one match per difficulty
- [ ] Kill app mid-match / mid-save → profile intact, match resumes at the same state (incl. during the AI's turn)
- [ ] Rotate / background / resume
- [ ] Back button on every screen
- [ ] Switch language to each of DE, ES, FR → no text overflow, no missing key
