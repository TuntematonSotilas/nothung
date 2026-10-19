# Testing

> Test strategy and tooling.
> Status: Draft · Last updated: 2026-10-19

## Framework

> **Decision (2026-10-09):** [gdUnit4](https://github.com/MikeSchulze/gdUnit4) — richer assertions and mocking, VS Code integration, headless CLI runner. See [ADR-0004](../adr/0004-gdunit4.md).

- Addon in `game/addons/gdUnit4/`: **v6.2.2** (supports Godot 4.5 → 4.7.x), enabled as an editor plugin. The folder is **git-ignored** and installed by `bash tools/install_gdunit4.sh` (pinned version; does nothing if already installed). Run it after cloning, **before opening the editor** (otherwise Godot reports the enabled plugin as missing).
- The project configures gdUnit4 to look in `tests/` and enables automatic discovery when the editor opens. To rediscover manually, use the circular-arrows button in the gdUnit4 inspector.
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

### AI soak

Run the seeded Easy-AI vs Easy-AI baseline from `game/`:

```sh
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests/soak
```

The soak alternates the two starter decks between player positions, verifies every selected action with `Match.is_legal()`, requires every match to finish within the action limit, and prints aggregate turn and action counts plus win rates and draws per deck.

Initial first-legal-action Easy-AI baseline (40 seeded matches, 2026-10-18):

| Metric | Result |
|--------|--------|
| Average match length | 16.2 turns |
| Average actions | 60.7 |
| Gods starter wins | 39 / 40 (97.5%) |
| Nibelungs starter wins | 1 / 40 (2.5%) |
| Draws | 0 |

The first-legal-action baseline is not a balance conclusion: deck matchup and AI decision quality are confounded.

After adding the Easy action-scoring heuristic, before the mulligan heuristic, the same seeds produced:

| Metric | Result |
|--------|--------|
| Average match length | 15.5 turns |
| Average actions | 62.7 |
| Gods starter wins | 36 / 40 (90%) |
| Nibelungs starter wins | 4 / 40 (10%) |
| Draws | 0 |

The Nibelungs win rate improved from 2.5% to 10% under the heuristic, but Gods still dominate this mirrored-AI sample. Treat this as an initial signal rather than a deck-balance verdict.

With the mulligan heuristic enabled, the same 40 seeds produce:

| Metric | Result |
|--------|--------|
| Average match length | 16.6 turns |
| Average actions | 68.2 |
| Gods starter wins | 38 / 40 (95%) |
| Nibelungs starter wins | 2 / 40 (5%) |
| Draws | 0 |

The opening-hand policy did not improve the Nibelungs result in this small sample. More matchups and a stronger Normal profile are needed before changing card or turn-balance rules.

After the Gods canon rename (2026-10-19: same stats, except *Loge's Fire*, a 3-cost common spell, becoming **Loge**, a 4-cost rare 2/3 unit with the same on-play effect), the same 40 seeds produce:

| Metric | Result |
|--------|--------|
| Average match length | 15.6 turns |
| Average actions | 63.0 |
| Gods starter wins | 37 / 40 (92.5%) |
| Nibelungs starter wins | 3 / 40 (7.5%) |
| Draws | 0 |

Loge as a unit barely moves the balance; the Gods starter still dominates.

**Nibelungs rebalance (2026-10-19).** The Nibelungs starter was rewritten from the libretto (Mime, Hoard Bearers, Smiths of Nibelheim, Alberich's Whip, Mime's Brew, The Giant Serpent…) and Alberich's ability, which cost 2 Energy to gain 2, now summons a Nibelung Miner. Still 38 / 40 for the Gods. A diagnostic run over the same seeds showed two causes:

- **The Ring curse**: the Nibelungs created the Ring in 39 / 40 matches and lost 12.6 Life per match to it, since no Gods card can take it back.
- **Wotan's ability** (2 damage for 2 Energy) was used 96 times and removed the small dwarves every turn.

Variants measured in memory (same 40 seeds, Gods wins / Nibelungs wins):

| Variant | Result |
|---------|--------|
| Rewritten Nibelungs, Ring card in the deck | 38 / 2 |
| Ring card removed | 26 / 14 |
| Ring kept, no curse | 26 / 14 |
| Curse capped at 1 | 31 / 9 |
| Ring card removed + Wotan's ability at 3 Energy | 18 / 22 |
| Wotan's ability dealing 1 damage | 11–14 / 26–29 |

Retained ([game rules](../functional/03-game-rules.md#the-ring-signature-mechanic)): Ring card out of the starter deck, replaced by *Nibelung Host* (2/3 Guard, +1 Energy on death); Wotan's ability at 3 Energy. Result:

| Metric | Result |
|--------|--------|
| Average match length | 21.3 turns (~10.6 per player) |
| Average actions | 82.6 |
| Gods starter wins | 24 / 40 (60%) |
| Nibelungs starter wins | 16 / 40 (40%) |
| Draws | 0 |

Matches are slightly above the 8–10 turns per player target.

## Manual test checklist (release)

- [ ] Install on reference device + one low-end device + one tall-aspect (20:9+) device
- [ ] Complete tutorial
- [ ] Play one match per difficulty
- [ ] Kill app mid-match / mid-save → profile intact, match resumes at the same state (incl. during the AI's turn)
- [ ] Rotate / background / resume
- [ ] Back button on every screen
- [ ] Switch language to each of DE, ES, FR → no text overflow, no missing key
