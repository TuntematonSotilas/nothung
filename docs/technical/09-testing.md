# Testing

> Test strategy and tooling.
> Status: Draft · Last updated: 2026-10-16

## Framework

> **Decision (2026-10-09):** [gdUnit4](https://github.com/MikeSchulze/gdUnit4) — richer assertions and mocking, VS Code integration, headless CLI runner. See [ADR-0004](../adr/0004-gdunit4.md).

- Addon in `game/addons/gdUnit4/`: **v6.2.2** (supports Godot 4.5 → 4.7.x), enabled as an editor plugin. The folder is **git-ignored** and installed by `bash tools/install_gdunit4.sh` (pinned version; does nothing if already installed). Run it after cloning, **before opening the editor** (otherwise Godot reports the enabled plugin as missing).
- Upgrade: change `GDUNIT4_VERSION` in the script to a release that lists Godot 4.7 as compatible, rerun it, and commit the script.
- Test files: `tests/**/test_*.gd`, classes extending `GdUnitTestSuite`.
- Tests that touch files use `create_temp_dir()` with a **unique name per test** (e.g. suffixed with `Time.get_ticks_usec()`): gdUnit4 keeps the same temp folder across the tests of a suite, so leftovers from one test would leak into the next.
- Autoload scripts are tested on fresh instances (`preload(...).new()` + `auto_free`), with their file path pointed at the temp folder — never on the live autoloads.

## Test pyramid

| Level | Scope | Location | Run |
|-------|-------|----------|-----|
| Unit | Effects, keywords, rules validation, save migration | `tests/unit/` | Before each commit |
| Integration | Full scripted matches: seed + action list → expected final state | `tests/integration/` | Before each commit |
| Card data | Validation of every `CardData` ([03-data-model](03-data-model.md#validation)) | `tests/unit/` | Before each commit |
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
"$GODOT_BIN" --headless --path . --import   # once first: also generates the .translation files
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests
```

On Windows, `GODOT_BIN` must point to the main `Godot.exe`, not the `_console.exe` wrapper (the wrapper looks for the main exe under its full versioned name).

- `--ignoreHeadlessMode` is required: gdUnit4 refuses headless runs by default because input events don't work there. Our tests don't simulate input; UI interaction tests, if any, will need a non-headless run.
- The `Remote Debugger: Unable to connect to host '127.0.0.1:0'` errors are expected: the runner uses port 0 on purpose to disable the interactive debugger.
- The runner exits with 0 when everything passes, 100 on failures. Reports (JUnit XML + HTML) go to `game/reports/` (git-ignored).
- On a fresh clone, the first `--import` logs `Cannot open file 'res://localization/strings.*.translation'` before generating them; a second run is clean.

Threaded AI ([05-ai-opponent](05-ai-opponent.md#threading)) is tested in **synchronous mode**, so tests stay deterministic.

## Manual test checklist (release)

- [ ] Install on reference device + one low-end device + one tall-aspect (20:9+) device
- [ ] Complete tutorial
- [ ] Play one match per difficulty
- [ ] Kill app mid-match / mid-save → profile intact, match resumes at the same state (incl. during the AI's turn)
- [ ] Rotate / background / resume
- [ ] Back button on every screen
- [ ] Switch language to each of DE, ES, FR → no text overflow, no missing key
